# OCCTSwift#541 probe: what a "face index" addresses

Ground truth for the three ways the bridge answered "which face is index `i`", against the pinned
OCCT 8.0.0p1 kernel.

#502 established the kernel fact this builds on: `TopExp::MapShapes(S, T, M)` is *literally* a
`TopExp_Explorer` walk piped into an indexed map (`TopExp.cxx:34-45`), so the map's sequence is the
explorer's sequence with later repeats removed. #502 converged the sub-shape accessors onto the map
but deliberately left the `Face` family alone, because a face index is an addressing token the Swift
API hands out (`Face.index`, written from `Shape.faces()`) and takes back (`drafted(faces:)`,
`shelled(openFaces:)`, `withoutFeatures(faces:)`, and ~30 more).

The three schemes in the bridge before this fix:

| scheme | enumeration | base | entry points |
|---|---|---|---|
| **A** | `TopExp_Explorer`, one entry per *occurrence* | 0 | `OCCTShapeGetFaces` (which writes `Face.index`) + 13 index consumers |
| **B** | `TopExp::MapShapes`, one entry per *distinct* face | 0 | `OCCTShapeGetFaceCount` / `GetFaceAtIndex` + ~16 index consumers |
| **C** | `TopExp::MapShapes` | **1** | `OCCTShapeOffsetPerFace`, `OCCTLocOpeBuildWires`, `OCCTLocOpeSplitByWireOnFace`, the `Poly_Connect` mesh family, and the `OCCTEdgeAdjacentFaces` / `OCCTVertexAdjacentEdges` index *outputs* |

## The four questions the headers cannot answer

1. **Does the A/B divergence arise from ordinary modelling, or only from hand-built topology?**
   #502's face-divergent fixture was a hand-assembled shell of a face and its own reverse, and #541
   reproduces with `Shape.compound([face, face])`. A construction nobody writes is not worth moving
   an index over.
2. **When A and B diverge, from which index onwards?**
3. **Do A and B ever address *different* faces at an index both accept, or does A merely run
   longer?** These are different defects: silently operating on the wrong face vs. returning nil.
4. **Is the map's order the explorer's order on the shapes the fix must not disturb**, so
   converging A onto B moves no index on any shape without a shared face?

No fixture files: every case builds its geometry from a primitive.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/541-face-index-contract/occt_541_face_index_contract.mm -o /tmp/occt_541
/tmp/occt_541
```

## Result

**The divergence is not a hand-built curiosity. One ordinary modelling operation produces it, and
on that shape the two schemes name different faces rather than one merely running longer.**

Fifteen fixtures, five divergent:

| fixture | provenance | explorer | map |
|---|---|---|---|
| box / cylinder / sphere / torus | ordinary | 6 / 3 / 1 / 1 | same |
| hollow solid (cut) | ordinary | 12 | 12 |
| fuse of two touching boxes | ordinary | 10 | 10 |
| common of two overlapping boxes | ordinary | 6 | 6 |
| compsolid of two separately-cut halves | ordinary | 12 | 12 |
| **box split by a plane (one splitter run)** | **ordinary** | **12** | **11** |
| sewn two-face sheet | ordinary | 2 | 2 |
| `compound(face, THE SAME face)` | hand-built | 2 | 1 |
| `shell(face, face.Reversed())` | hand-built | 2 | 1 |
| `compound(box, THE SAME box)` | hand-built | 12 | 6 |
| `compound(box, box.Moved())` | hand-built | 12 | 12 |
| `compound(box, one of its own faces)` | hand-built | 7 | 6 |

- **`BRepAlgoAPI_Splitter` is the ordinary case.** One splitter run cutting a box with a plane
  yields two solids that *share* the single cut face, so the explorer visits it once per solid. This
  is what an assembly split, a slice or an imprint produces. Note the control directly above it: two
  halves cut by two *separate* `Common` calls and assembled into a compsolid do **not** diverge (12
  vs 12), because each half got its own copy of the wall. Sharing comes from one operation producing
  both parents, not from the assembly.

- **On the split box the schemes name different faces from index 10 onwards**: the trailing
  duplicate is not at the end of the explorer's walk, so every index after it is shifted. A caller
  holding `Face.index == 10` from `faces()` and passing it to `drafted(faces:)`,
  `withoutFeatures(faces:)` or `shelled(openFaces:)` (all map-backed) drafts, deletes or opens **a
  different face than the one it selected**, with no error. On the four hand-built fixtures the
  duplicate *is* last, so there A merely runs longer and the surplus indices are the ones
  `face(at:)` answers nil for, #541's reported symptom, which turns out to be the milder half of
  the defect.

- **Order is preserved on all ten agreeing fixtures**, face-by-face and not merely by count. So
  converging `faces()` onto the map moves no index on any shape that does not share a face, which is
  every shape the existing tests build.

- **`compound(box, box.Moved())` does not collapse** (12 vs 12). `IsSame` compares the location, so
  instancing survives deduplication; the map is not merging placements.

- **C is B shifted by one.** Measured on a box: `C(1)` is identical to `B(0)`, `C(6)` to `B(5)`,
  `C(0)` is never a face and `B(5)` is reachable through C only as `C(6)`. A caller holding a
  0-based `Face.index` and calling a C-scheme entry point addresses **the face before the one it
  named**, and can never name the last face at all.

- **`ShapeAnalysis_ShapeContents` is a fourth answer, and a fifth.** `Shape.contents`'s `NbFaces`
  tracks the explorer exactly (occurrences). Its `NbSharedFaces` sibling, surfaced through
  `Shape.contentsExtended()`: is a *third* dedup rule: it strips the location before adding to its
  map (`ShapeAnalysis_ShapeContents.cxx:167`, `face.Location(TopLoc_Location())`), so unlike
  `IsSame` it also collapses two placements of one face. On `compound(box, box.Moved())` the three
  read 12 / 12 / **6**. Neither column is `faceCount`'s answer on every fixture, which is why
  `contents` is documented as a complexity metric rather than converged.

## What was done with it

One enumeration and one base for every face index in the API: `occtMapSubShapes` / `occtSubShapeAt`
(`OCCTBridge_Internal.h`, added in #502), 0-based. `OCCTShapeGetFaces` reads it, the fourteen
explorer-backed consumers read it, and the 1-based entry points and index outputs were moved to
0-based to match `Face.index`. Cross-checks live in
`Tests/OCCTTopologyTests/Issue502SubShapeTraversalTests.swift`, alongside #502's.

Not an upstream defect, both OCCT primitives behave exactly as documented, and the kernel is not
involved in the base convention at all. Nothing to file or patch upstream.
