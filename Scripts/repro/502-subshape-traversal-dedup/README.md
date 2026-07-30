# OCCTSwift#502 probe: `TopExp_Explorer` vs `TopExp::MapShapes` as sub-shape enumerators

Ground truth for the two traversals the bridge used to answer one question, against the pinned
OCCT 8.0.0p1 kernel.

#502 found that `OCCTShapeGetSolids`/`GetShells`/`GetWires` drive a bare `TopExp_Explorer` while
`OCCTShapeGetSubShapeCount`/`GetSubShapeByTypeIndex` build a `TopTools_IndexedMapOfShape` through
`TopExp::MapShapes`, and that the second deduplicates while the first does not. That reading of the
headers is correct. This probe asks the three things the headers cannot answer:

1. **Do the counts actually diverge, and on what geometry?** A construction nobody writes is not a
   defect worth changing an API over.
2. **When they diverge, which occurrence does the map keep, and is anything lost beyond the count?**
3. **Is the map path's order the explorer's order**, so that one implementation could serve both
   without renumbering anyone's indices?

No fixture files needed: every case builds its geometry from a primitive.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/502-subshape-traversal-dedup/occt_502_traversal_dedup.mm -o /tmp/occt_502
/tmp/occt_502
```

## What it does

Thirteen fixtures, each walked both ways for SOLID, SHELL, FACE, WIRE, EDGE and VERTEX. For every
divergence it reports which occurrence was dropped and which surviving entry absorbed it, with
`IsSame`'s three components (TShape, location, orientation) broken out, so "deduplicated" is
attributed to a specific bit rather than assumed. It also checks whether the map's sequence is a
prefix-preserving subsequence of the explorer's, and probes the argument domain of the generic
type+index API (raw type values `0`, `1`, `8`, `9`, `-1`).

The fixtures are grouped: shapes with no sharing (primitives, a hollow solid, two distinct bodies);
the same sub-shape reachable twice (one shape compounded with itself, two placements of one body,
a reversed copy, #502's own reused-shell case, one wire in two faces); sharing that arises from
ordinary modelling rather than hand-built topology (a sewn stack, a compsolid, a folded shell).

## Result

**The divergence is real, and it is not the shape #502 implies.**

- **For EDGE and VERTEX it is universal, not exceptional.** A plain 10mm box: 24 edge occurrences
  over 12 edges, 48 vertex occurrences over 8 vertices. Every edge is visited once per adjacent
  face. Every drop is attributed to orientation alone (`sameTShape=1 sameLocation=1
  sameOrientation=0`), which is exactly what `IsSame` is documented to ignore.

- **For SOLID, SHELL and WIRE, the three types the explorer-backed accessors covered, the two
  agree on every ordinary shape**: box, sphere, cylinder, a hollow solid's two shells, a compound of
  two distinct bodies, **two placements of one body** (2 vs 2, since `IsSame` compares the location, so
  instancing survives deduplication), a sewn stack, a compsolid. They diverge exactly when one
  sub-shape is reachable from two parents:

  | fixture | explorer | map |
  |---|---|---|
  | `compound(box, THE SAME box)` | 2 solids | 1 |
  | `compound(box, box.Reversed())` | 2 solids | 1 |
  | `compound(solidFromShells(sh), solidFromShells(THE SAME sh))` | 2 shells | 1 (solids stay 2) |
  | `compound(face(w), otherFace(THE SAME w))` | 2 wires | 1 |
  | `shell(face, face.Reversed())` | 2 faces / 2 wires | 1 / 1 |

- **Order is preserved in all thirteen fixtures, for all six types** (`order=same`). Reading
  `TopExp.cxx:34-45` explains why it must be: the three-argument `TopExp::MapShapes` is *literally*
  a `TopExp_Explorer` walk piped into the map. The two are not independent primitives: the
  deduplicated sequence is the explorer's sequence with later repeats removed. That is what makes
  one shared implementation possible with no index moving.

- **The argument domain is benign.** Raw type `8` (`TopAbs_SHAPE`), `9` and `-1` all answer 0 on
  both paths without throwing, so `ShapeType.unknown` (raw `-1`) was never crashing, but it was
  reaching `static_cast<TopAbs_ShapeEnum>(-1)`, a value the enum has no name for. The shared helper
  now range-checks instead, which keeps the same answer without the cast.

- **A shape is its own sub-shape** when it is of the requested type, on both paths: a solid asked
  for SOLID answers 1, a shell asked for SHELL answers 1. Neither path invents a COMPOUND for a box.

## What was done with it

Deduplicated is the answer this API already gave everywhere it mattered (`edgeCount` reported 12 for
a box, not 24), so that is the answer all of it gives now. `occtMapSubShapes` in
`OCCTBridge_Internal.h` is the one enumeration; the six `TopExp_Explorer` entry points behind
`solids`/`shells`/`wires` are gone, as is `OCCTShapeGetEdgeCount`, an explorer count with no caller
that disagreed with `OCCTShapeGetTotalEdgeCount`. Cross-checks live in
`Tests/OCCTTopologyTests/Issue502SubShapeTraversalTests.swift`.

Not an upstream defect (both OCCT primitives behave as documented), so nothing to file or patch.
`Shape.faces()` is still an explorer walk and is filed separately as #541.
