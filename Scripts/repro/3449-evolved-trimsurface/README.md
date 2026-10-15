# #3449: BRepOffsetAPI_MakeEvolved SIGSEGV in BRepFill_TrimSurfaceTool::IntersectWith

`./run.sh <px> <py> <face 0|1> <cx> <cy> <mode> <dx> <dy> <dz> <axeProf 0|1>` builds `probe.cpp`
against the local xcframework and runs it. The spine is a radius-20 circle centred at `(cx, cy, 0)`
(a wire, or its face when `face` is 1). The profile is the segment from `(px, py, 0)` to
`(px+dx, py+dy, dz)` (mode 0), reversed (mode 1), or through `(px, py, 0)` (mode 2). A SIGSEGV
prints a backtrace; the top frame is `BRepFill_TrimSurfaceTool::IntersectWith`, called from
`BRepFill_Evolved::ElementaryPerform`.

## Measured (pinned kernel, macOS arm64, `axeProf` false unless stated)

| profile (start -> end) | result |
|---|---|
| (0,0,0) -> (0,2,3), wire or face spine, centre at (0,0) or (5,7) | SIGSEGV |
| (0,0,0) -> (2,0,3), (0,0,0) -> (0,2,-3), (0,0,0) -> (0,-2,3) | SIGSEGV |
| (0,0,-3) -> (0,2,0), first vertex on the axis, below the plane | SIGSEGV |
| (1e-9 / 1e-8 / 1e-7, 0, 0) -> (same x, 2, 3) | SIGSEGV |
| (3e-7 .. 1e-3, 0, 0) -> (same x, 2, 3), parallel to the axis | builds |
| (1e-3 / 1e-2 / 0.1 / 1, 0, 0) -> (0, 2, 3), skewed | SIGSEGV |
| (5, 0, 0) -> (0, 2, 3) and (5, 0, 0) -> (0, -2, 3), skewed | builds |
| (0,2,3) -> (0,0,0), ends on the centre; profile through the centre | builds |
| (0,0,0) -> (0,2,0), in the spine plane | builds |
| (0,0,0) -> (0,2,3) with `axeProf` true | builds |
| (0,1,0) .. (0,19,0) -> (0,+-2,+-3), radial, off the axis | builds |

## Why no guard

The faulting set is not a point. A start on the circle's axis crashes, but so does a start 1 away
from it (radius 20) when the segment is skewed toward the axis, while the same start with the
segment parallel to the axis builds down to 3e-7, and (5,0,0) -> (0,2,3) builds. The trigger
depends on the profile's direction as well as its start, so no distance threshold on the start
vertex separates crashing inputs from building ones, and any tolerance chosen from these rows
would be a guess. A guard drawn around the point the issue reported (first vertex within
`Precision::Confusion` of the centre) was written and then dropped: it was refused by its own
evidence, since (1,0,0) -> (0,2,3) crashes with the start 1 from the axis.

The fault itself is not located below the frame `IntersectWith+164`. The likely site, from
`BRepFill_TrimSurfaceTool.cxx` (`EvalParameters`), is `occ::down_cast<Geom2d_TrimmedCurve>` of the
bisector or of the projected edge curve returning null in the "elongate curves" branch and being
dereferenced by `SetTrim`; that is a reading of the source, not a measurement. A kernel patch (or
an upstream report) is the route, not a bridge guard.
