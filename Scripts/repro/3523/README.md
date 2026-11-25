# OCCTSwift#3523 ground truth: contour and edge indices outside their range, `BRepFilletAPI_MakeChamfer`

`occt_3523_chamfer_index_matrix.mm` runs every `(builder state, accessor, index)` triple in its own
forked child, so a SIGSEGV is a cell in the table and not the end of the probe. `probe-output.txt` is
its full output on the pinned kernel (OCCT V8_0_2 plus the carried patches, `macos-arm64`). `SEGV` in a
cell is SIGSEGV or SIGBUS: which of the two a wild address raises varies between runs. `SEGV[set;]` is
a fault in the readback after the setter returned, and is a fault of the readback on a builder with no
contour, not of the setter.

It is the chamfer half of `Scripts/repro/3518/`, which measured thirteen of the accessors with the
fillet and left the chamfer unchanged. This matrix covers all twenty contour-indexed functions
`ChamferBuilder` wraps, including the three setters and `IsSymetric`, which that one did not.

The rows are nine builder states (fresh; one edge added and never built; two contours never built;
`Build()` with no contour; declined at distance 20; built with one contour; built with two; built then
`Reset()`; declined then `Reset()`), eight indices (`-1 0 1 2 3 1e5 INT_MAX INT_MIN`) and, for the edge
index inside a contour, the same eight values for `J`: 1,584 cells, 498 faults.

## Compile and run

```bash
XC=Libraries/OCCT.xcframework      # or .build/artifacts/<package>/OCCT/OCCT.xcframework
clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/3523/occt_3523_chamfer_index_matrix.mm -o /tmp/occt_3523
/tmp/occt_3523 > Scripts/repro/3523/probe-output.txt      # about a minute
/tmp/occt_3523 SetDist                                      # only the accessors whose name contains it
```

## Why it faults

`ChFi3d_Builder::Value(I)` (`ChFi3d_Builder_1.cxx:1201`) walks `myListStripe` `I - 1` times and
dereferences the iterator it ends on, so `I <= 1` runs no steps and answers contour 1 (0 and every
negative index alias it), `I` past the end steps onto a null node, and any `I` on a builder with no
contour dereferences an empty list at once. `NbElements()` counts the same list and is safe in every
state.

`BRepFilletAPI_MakeChamfer::NbEdges` and `::Edge` call `Value(I)` with no test at all. So do
`GetDist`, `Dists` and `GetDistAngle`, and `IsSymetric`, `IsTwoDistances` and `IsDistanceAngle`
through `ChFi3d_ChBuilder::IsChamfer(IC)`, each after a `down_cast` it never tests. `Length`,
`Closed`, `ClosedAndTangent`, `FirstVertex`, `LastVertex`, `Abscissa`, `RelativeAbscissa`,
`SetDist`, `SetDists`, `SetDistAngle` and `ResetContour` test only `IC <= NbElements()`
(`ChFi3d_Builder_1.cxx:1281-1355`, `ChFi3d_ChBuilder.cxx:280-560`): the upper bound, never the
lower. The lower bound is the one that matters, because `Standard_OutOfRange_Raise_if` is compiled
out of this build and nothing catches `Value(0)`. The edge index inside a contour (`Edge(I, J)`)
indexes `ChFiDS_Spine`'s edge sequence with no test either.

## Measured, `BRepFilletAPI_MakeChamfer`

An index is out of range when it is not in `1..NbContours()` (`nc`), or for `J` not in
`1..NbEdges(IC)`.

| accessor | outside the range | disposition |
|---|---|---|
| `NbEdges(IC)`, `IsSymetric`, `IsTwoDistances`, `IsDistanceAngle`, `GetDist`, `Dists`, `GetDistAngle`, `Edge(IC, 1)` | SEGV for every `IC` when `nc` is 0; SEGV for `IC > nc` in the other states; `0`, `-1` and `INT_MIN` answer contour 1 | bridge guard: `0`, `false`, `-1`, null |
| `Length`, `Closed`, `ClosedAndTangent`, `FirstVertex`, `LastVertex`, `Abscissa`, `RelativeAbscissa` | `IC > nc` answers the documented sentinel (`-1`, `false`, null); `0`, `-1` and `INT_MIN` answer contour 1's value when `nc >= 1` and SEGV when `nc` is 0 | bridge guard, the sentinel |
| `SetDist`, `SetDists`, `SetDistAngle` | `0`, `-1` and `INT_MIN` WRITE contour 1 (the readback shows it) and SEGV when `nc` is 0; `IC > nc` does nothing and the bridge answered `true` | bridge guard, `false` |
| `Edge(1, J)` | `J = 0` SEGV in every state with a contour; `J` past the end answers a stale node | bridge guard, null |
| `NbSurf(IC)`, `Simulate(IC)` then `NbSurf(1)` | a contour never run, after `Reset()`, and contour 2 after only `Simulate(1)` fault | #3522, not this defect |

The header documents the refusal for every one of these (`BRepFilletAPI_MakeChamfer.hxx`: "Returns 0
if I is outside the bounds of the table of contours", "-1. is returned if IC is outside the bounds",
"Returns a null shape if ... J is outside the bounds"), so the guards give what OCCT says it gives.

## Upstream

OCCT#1733 and its fix PR OCCT#1737 add the two missing checks (`Value`, `StripeStatus`) with the bound
`NbElements()`. They are open on `IR`, which is not in 8.0.2, and they do not check the edge index `J`.
The bridge guard stays correct either way, since it sits in front of the kernel.
