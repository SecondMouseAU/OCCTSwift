# #1423: OCCTShapeAnalyzeEdgeConcavity vs OCCTShapeCountEdgeConcavity — not reproducible as filed

## The filed concern

`OCCTShapeAnalyzeEdgeConcavity` (`OCCTBridge_Topology_Analysis.mm`) classifies each edge using only
the first `BRepOffset_Interval` `BRepOffset_Analyse::Type(edge)` returns
(`break; // One classification per edge`), while its sibling `OCCTShapeCountEdgeConcavity` scans
*every* interval and counts the edge if *any* interval matches the requested type. If a single edge
could legitimately carry two or more intervals of different `ChFiDS_TypeOfConcavity`, the two
functions would disagree on that edge for the same shape/angle. The issue was filed at moderate
confidence: the structural inconsistency is real and directly readable, but no concrete input had
been constructed to force a live divergence.

## Verdict: structurally unreachable via this bridge's call path, not merely untested

`BRepOffset_Analyse::Type(edge)` returns `myMapEdgeType(edge)`
(`BRepOffset_Analyse.cxx:891-894`), a pure accessor with no post-processing. Every writer of
`myMapEdgeType` was read directly:

- `Perform()`'s main loop (`BRepOffset_Analyse.cxx:308-359`): for an edge shared by exactly two
  faces, `EdgeAnalyse()` appends **exactly one** `BRepOffset_Interval` spanning the edge's whole
  parametric range, whatever `ChFiDS_TypeOfConcavity` it computes — including the `ChFiDS_Mixed`
  case for two spline faces whose continuity varies along the edge (`CheckMixedContinuity`, lines
  149-272): that still collapses to **one** interval typed `Mixed`, not two intervals of different
  types. For an edge shared by exactly one face (a free boundary), the loop appends exactly one
  interval too (`ChFiDS_Other` or `ChFiDS_FreeBound`).
- The only other writer, the artificial-tangent-face-insertion code in `TreatTangentFaces()`
  (lines 371 onward, called from `Perform()` at line 361), is the one place that can `Clear()` an
  edge's interval list and re-append — but `TreatTangentFaces()` itself early-returns
  (`BRepOffset_Analyse.cxx:374-379`) whenever `myFaceOffsetMap.IsEmpty()`, and `myFaceOffsetMap` is
  populated *only* by the explicit `SetFaceOffsetMap()` setter (`BRepOffset_Analyse.hxx:122-126`).

Both `OCCTShapeAnalyzeEdgeConcavity` and `OCCTShapeCountEdgeConcavity` construct their analyser as
`BRepOffset_Analyse analyser(shape->shape, angle);` and never call `SetFaceOffsetMap()`. So
`TreatTangentFaces()` always takes its early-return branch, and `myMapEdgeType(edge).Extent()` is
provably always 0 or 1 for every edge reachable through this bridge's call path. The `break`
(analyze) vs. scan-all (count) difference cannot select a different answer today, because there is
never a second interval to disagree about.

## Empirical confirmation

`occt_1423_probe.mm` builds the analyser exactly as the bridge does (no `SetFaceOffsetMap`) and
reports the max interval count seen on any edge, across five geometries chosen to maximize the
chance of a curvature transition within one edge: a plain box, a box+sphere fuse, a fully-filleted
box, a triangle-to-square `BRepOffsetAPI_ThruSections` loft (BSpline side faces), and a
cylinder+box fuse — 122 edges total.

```
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  occt_1423_probe.mm -o /tmp/occt_1423_probe && /tmp/occt_1423_probe
```

Result: `maxIntervalsOnAnyEdge == 1` on every one of the five shapes, `mixedIntervals == 0`. No
edge, in any geometry tried, ever carried more than one interval.

## Conclusion

The structural inconsistency the issue describes is real (the two functions do handle a
hypothetical multi-interval edge differently), but it is dead code under this bridge's own usage:
reaching it would require a caller to opt into `SetFaceOffsetMap()`, which neither entry point does
and neither has any reason to (that setter exists to support offset-specific tangent-face handling,
unrelated to what these two functions are for). No fix applied; `OCCTBridge_Topology_Analysis.mm`
carries a comment recording this so a future reader doesn't have to re-derive it. Recommend closing
#1423 on this evidence — reopen if a future caller ever threads `SetFaceOffsetMap()` through to one
of these entry points, which would make the divergence live.
