# OCCTSwift#3518 ground truth: contour and edge indices outside their range, `BRepFilletAPI_MakeFillet`

`occt_3518_contour_index_matrix.mm` runs every `(builder state, accessor, index)` triple in its own
forked child, so a SIGSEGV is a cell in the table and not the end of the probe.
`probe-output.txt` is its full output on the `v4.0.0-kernel.8` `macos-arm64` slice, the asset
`Package.swift` pins. `SEGV` in a cell is SIGSEGV or SIGBUS: which of the two a wild address raises
varies between runs. `X[set;]` is a fault in the readback after the setter returned.

The rows are nine builder states (fresh; one edge added and never built; two contours never built;
`Build()` with no contour; declined at radius 20; built with one contour; built with two; built then
`Reset()`; declined then `Reset()`), eight indices (`-1 0 1 2 3 1e5 INT_MAX INT_MIN`) and, for the
edge index inside a contour, the same eight values for `J`.

## Compile and run

```bash
XC=.build/artifacts/<package>/OCCT/OCCT.xcframework      # or Libraries/OCCT.xcframework
clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/3518/occt_3518_contour_index_matrix.mm -o /tmp/occt_3518
/tmp/occt_3518               # everything, about four minutes
/tmp/occt_3518 NbEdges       # only the accessors whose name contains the argument
```

## Why it faults

`ChFi3d_Builder::Value(I)` (`ChFi3d_Builder_1.cxx:1201`) walks `myListStripe` `I - 1` times and
dereferences the iterator it ends on:

```cpp
NCollection_List<occ::handle<ChFiDS_Stripe>>::Iterator itel(myListStripe);
for (int ic = 1; ic < I; ic++) itel.Next();
return itel.Value()->Spine();
```

So `I <= 1` runs no steps and answers contour 1 (0 and every negative index alias it), `I` past the
end steps onto a null node, and any `I` on a builder with no contour dereferences an empty list at
once. `NbElements()` counts the same list and is safe in every state.

`BRepFilletAPI_MakeFillet::NbEdges` and `::Edge` call `Value(I)` with no test at all. `StripeStatus`
walks the stripe list and dereferences the stripe it failed to find. `Length`, `Radius`,
`IsConstant`, `Closed`, `ClosedAndTangent`, `FirstVertex`, `LastVertex`, `Abscissa`,
`RelativeAbscissa`, `ResetContour` and the whole `SetRadius` family test only `IC <= NbElements()`
(`ChFi3d_Builder_1.cxx:1281-1355`, `ChFi3d_FilBuilder.cxx:245-400`): the upper bound, never the lower.
The lower bound is the one that matters, because `Standard_OutOfRange_Raise_if` is compiled out of
this build and nothing catches `Value(0)`. The edge index inside a contour (`Edge(I, J)`,
`SetRadius(R1, R2, IC, IinC)`) indexes `ChFiDS_Spine`'s edge sequence and abscissa table
(`ChFiDS_Spine.cxx:237-251`) with no test either.

## Measured, `BRepFilletAPI_MakeFillet`

An index is out of range when it is not in `1..NbContours()` (`nc`), or for `J` not in
`1..NbEdges(IC)`.

| accessor | outside the range | disposition |
|---|---|---|
| `NbEdges(IC)`, `Edge(IC, 1)` | SEGV for every `IC` when `nc` is 0 (fresh, no-contour build); SEGV for `IC > nc` in the other seven states; `0`, `-1` and `INT_MIN` answer contour 1 | bridge guard, `0` and null |
| `StripeStatus(IC)` | SEGV for every `IC` outside `1..nc` in all nine states, `0` and the negatives included | bridge guard, `-1` |
| `Edge(1, J)` | `J = 0` SEGV; `J = 2` and `3` answer memory that faults when it is read; `-1`, `1e5`, `INT_MAX` and `INT_MIN` answer edge 1 again (the sequence's cached node), as if they were `1` | bridge guard, null |
| `Length`, `Radius`, `IsConstant`, `Closed`, `ClosedAndTangent`, `FirstVertex`, `LastVertex`, `Abscissa`, `RelativeAbscissa` | `IC > nc` answers the documented sentinel (`-1`, `false`, null); `0`, `-1` and `INT_MIN` answer contour 1's value when `nc >= 1` and SEGV when `nc` is 0 | bridge guard, the sentinel |
| `SetRadius(R, IC, edge)`, `SetRadius(R, IC, vertex)`, `SetRadius(R1, R2, IC, IinC)` | `0`, `-1` and `INT_MIN` WRITE contour 1 (readback shows it) and SEGV when `nc` is 0; `IC > nc` does nothing and the bridge answered `true` | bridge guard, `false` |
| `SetRadius(R1, R2, IC, J)` | `J = INT_MAX` or `INT_MIN`: SEGV; other `J` outside the contour's edges are accepted and write a point into the radius law at an abscissa the spine does not have | bridge guard, `false` |
| `ResetContour(IC)` | `0`, `-1` and `INT_MIN` reset contour 1; SEGV when `nc` is 0; `IC > nc` does nothing | bridge guard, no-op |
| `GetBounds`, `GetLaw` (and `SetLaw`, the same walk) | the same as the row above for `IC <= 0`: SEGV at `nc` 0, contour 1's answer otherwise | already guarded since #505 by `occtFilletContourHoldsEdge`, which now shares the range helper |
| `NbComputedSurfaces(IC)`, `FaultyContour(I)`, `FaultyVertex(I)`, `Simulate(IC)` | `0`, null or no effect for every index in every state: they search the list and stop | unchanged |
| `NbSurf(IC)` | `0` for every `IC` outside the range; SEGV for a valid `IC` on a contour that was never simulated and after `Reset()` | #3519, not this defect |

## Found, not changed here

- `SetRadius(R, IC, vertex)` and `SetRadius(R1, R2, IC, IinC)` fault with a **valid** index after a
  build that completed (`built ok`, one or two contours, every `IC` and `J` in range): no `set;`
  marker in the cell, so the setter itself faults. `ChFiDS_FilSpine::SetRadius(UandR, IinC)` replays
  the law when `splitdone` is true and reads `elspines`' first element, and the list is empty once
  the build is over. `SetRadius(R, IC, edge)` resets `splitdone` first and does not. Not an index
  defect, so no range check helps.
- `BRepFilletAPI_MakeChamfer` shares the base class and has the same defect, with a larger surface:
  `NbEdges`, `Edge`, `Length`, `Closed`, `ClosedAndTangent`, `FirstVertex`, `LastVertex`,
  `Abscissa`, `RelativeAbscissa` and `ResetContour` as in the table, plus `GetDist`, `Dists`,
  `GetDistAngle`, `IsTwoDistances` and `IsDistanceAngle`, which SEGV for any `IC > nc` and answer
  contour 1 for `IC <= 0`. The `ChamferBuilder` bridge functions are unchanged by this fix.
