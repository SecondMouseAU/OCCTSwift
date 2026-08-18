# #943: is a legitimately zero-size bounding box reachable, and where?

`Shape.bounds` and its three siblings became Optional in #943. The question that decides *how* they
report "no box" is whether a real shape can measure to exactly `(0,0,0)-(0,0,0)`, because if it can,
a Swift-side `min == .zero && max == .zero` test cannot tell that shape from a void one.

This probe measures it rather than reasoning about it.

## Running it

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/943-bounds-void-vs-zero/occt_943_probe.mm -o /tmp/occt_943_probe
/tmp/occt_943_probe
```

`probe-output.txt` is the transcript against the pinned `v3.0.0-kernel.1` kernel.

## What it measures

| case | result |
|---|---|
| 1. vertex at the origin, default tolerance, `BRepBndLib::Add` | `IsVoid=0`, box `±1e-07`, **not** all-zero |
| 2. same vertex after `ShapeFix_ShapeTolerance::LimitTolerance(0, 0)` | unchanged, `±1e-07` |
| 3. far-disjoint intersection (the reachable void fixture) | `IsVoid=1` |
| 4/5. a sphere's polar degenerate edge at the origin, `Add` | `IsVoid=0`, box `±1e-07` |
| 6. the same vertex through `Add(useTriangulation=false)` | `±1e-07` |
| 7. the same vertex through `BRepBndLib::AddOptimal` | `IsVoid=0`, `gap=0`, **exactly all-zero** |

## What that means

**Through `BRepBndLib::Add`, an exactly-zero box is not reachable for a non-void shape.**
`BRep_Tool::Tolerance` floors every vertex/edge/face tolerance at `Precision::Confusion()`
(`BRep_Tool.cxx`, `if (p > pMin) …` with `pMin = Precision::Confusion()`), and `Add` enlarges the box
by that tolerance for every sub-shape it visits, so the box lands on `±1e-7`. Case 2 shows the one
public lever that looks like it could defeat this does not: `LimitTolerance(0, 0)` writes 0 into the
`BRep_TVertex`, and `BRep_Tool::Tolerance` floors it straight back on read.
`ShapeFix_ShapeTolerance::SetTolerance(shape, 0)` is a documented no-op (`preci <= 0` returns early).

**Through `BRepBndLib::AddOptimal` it is reachable and routine.** `AddOptimal` defaults
`useShapeTolerance` to false, so it does not enlarge by the shape tolerance at all, and a vertex at
the world origin measures exactly six zeros with `gap=0`. That is #900's live repro, re-measured
here, and it is byte-identical to what every failure path in the bridge writes.

So the value sentinel is not currently wrong on the `Add` path (which is what `Shape.bounds`,
`Edge.bounds`, `Face.bounds` and `Face.exactBounds` all use), and it is demonstrably wrong one flag
away on the `AddOptimal` path. Its correctness on the paths where it happens to hold rests on a
kernel constant this package neither controls nor pins, and #943 puts all six bounds entry points
behind one shared helper, where a sentinel would be wrong for all of them at once. That is why the
verdict is carried as a `bool` from `Bnd_Box::IsVoid()` instead.

## The injection matrix this fed

`Tests/OCCTAnalysisTests/Issue943BoundsVoidTests.swift` is pinned by six injections, recorded in
PR #944's body. Two results worth keeping here:

- Removing `if (box.IsVoid()) return false;` from the shared helper on its own **fails nothing**:
  `Bnd_Box::Get()` throws `Standard_ConstructionError` for a void box and the surrounding
  `catch (...)` returns false anyway. The guard is the cheap path, not the load-bearing one.
- Restoring the Swift-side sentinel on `Edge.bounds` **fails nothing either**, for exactly the
  reason measured above. The injection that does fail is the sentinel placed in the shared helper,
  which breaks the vertex-at-origin case through `AddOptimal`.
