# OCCTSwift#489 ground truth: what `BRepFilletAPI_MakeFillet` does with an invalid radius

Two standalone probes, run against the pinned `OCCT.xcframework` (8.0.0p1 + our carried patches),
that establish what OCCT actually does when the radius handed to the edge-list fillet family is
zero, negative or NaN. They are what the #489 fix is calibrated against: the finding assumed a bad
radius reaching OCCT was the bug, and the measurement says otherwise.

No fixture files: every case is a 10×10×10 box.

## Compile and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/489-fillet-radius-validation/occt_489_add_radius.mm -o /tmp/occt_489_add_radius
/tmp/occt_489_add_radius
```

Same recipe for `occt_489_setradius_and_bounds.mm`.

## `occt_489_add_radius.mm`: the `Add(radius, edge)` path

`OCCTShapeFilletEdges` and `OCCTShapeBlendEdges` both reach OCCT through
`BRepFilletAPI_MakeFillet::Add(radius, edge)`.

| input | measured |
|---|---|
| `Add(2.0, e)` | `IsDone=1`, volume 991.415927, `BRepCheck_Analyzer` valid |
| `Add(0.0, e)` | `IsDone=0`, `NbFaultyContours=1` |
| `Add(-5.0, e)` | `IsDone=0`, `NbFaultyContours=1` |
| `Add(2.0, e1)` + `Add(0.0, e2)` | `IsDone=0`, `NbFaultyContours=1` |
| `Add(2.0, e1)` + `Add(-5.0, e2)` | `IsDone=0`, `NbFaultyContours=1` |

No throw, no crash, and no wrong shape. OCCT fails `IsDone()`, which the bridge already turned into
`nullptr`, so a non-positive radius that reached OCCT was already reported as failure, and one bad
radius already poisoned the whole batch. The precondition still belongs in the bridge (OCCT's own
`*_Raise_if` checks are compiled out of this Release build by `No_Exception`, so nothing inside the
library is load-bearing here), but it buys rejection *before* a full fillet build attempt rather
than a different answer.

## `occt_489_setradius_and_bounds.mm`: the law path, and the case that did escape

| input | measured |
|---|---|
| no contour added at all | `Build()` throws `Standard_Failure`: "There are no suitable edges for chamfer or fillet" |
| `Add(e)` + `SetRadius(0.0, …)` at both ends | `IsDone=0` |
| `Add(e)` + `SetRadius(-5.0, …)` at both ends | `IsDone=0` |
| `Add(NaN, e)` | `IsDone=0` |
| one valid edge only | `IsDone=1`, volume 991.415927, valid |

The last row is the observable defect. `OCCTShapeBlendEdges` bounds-checked each caller index and
`continue`d past an out-of-range one *before* the radius was ever used, so
`blendedEdges([(0, 2.0), (99999, -5.0)])` skipped the invalid pair, built from edge 0 alone, and
returned a shape: success for a request that was never fully honoured. Every other invalid-radius
combination already surfaced as `nil` by way of `IsDone=0`.

The first row is why the bounds check can stay a skip rather than a rejection: when it skips
everything, `Build()` throws and the bridge's `catch (...)` reports `nullptr` anyway.

## Fix

Bridge-only, no kernel patch, no xcframework rebuild. `occtShapeFilletEdgeList` in
`Sources/OCCTBridge/src/OCCTBridge_Internal.h` is now the one skeleton behind
`OCCTShapeFilletEdges`, `OCCTShapeFilletEdgesLinear` and `OCCTShapeBlendEdges`, and
`occtValidFilletRadius` / `occtValidFilletRadii` are the one precondition all three apply.
Regression tests: `Tests/OCCTModelingTests/Issue489FilletRadiusTests.swift`.

Nothing filed upstream: `Add()` reporting failure through `IsDone()` is OCCT's documented
`BRepBuilderAPI_MakeShape` contract, not a defect.
