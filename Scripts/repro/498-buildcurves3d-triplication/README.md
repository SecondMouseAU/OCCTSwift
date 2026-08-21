# OCCTSwift#498 probe, what `BRepLib::BuildCurves3d`'s two overloads actually do

Ground truth for the operation behind three separate bridge C entry points, against the pinned
OCCT 8.0.0p1 kernel. It exists because #498's framing needed checking before anything was merged
together: the issue describes "one legitimate two-way split (tolerance vs. no-tolerance overload)"
plus one accidental byte-identical copy, and says the two Swift wrappers' defaults having drifted
100x apart is a real cost.

The split is not legitimate, it is a forwarder, and the drift cost is real and measurable.

No fixture files needed: every case builds its geometry from scratch.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/498-buildcurves3d-triplication/occt_498_buildcurves3d.cpp -o /tmp/occt_498
/tmp/occt_498
```

## What it measures

### 1. The no-tolerance overload is a forwarder, not an algorithm

`BRepLib.cxx:460-464` is the whole of it:

```cpp
bool BRepLib::BuildCurves3d(const TopoDS_Shape& S)
{
  return BRepLib::BuildCurves3d(S, 1.0e-5);
}
```

Measured on a pcurve-only edge whose 3D geometry is a helix on a cylinder (edge tolerance 1e-9,
so the requested tolerance is what drives the result):

| Call | returned | curve | degree | poles | edge tolerance | max deviation |
|---|---|---|---|---|---|---|
| `BuildCurves3d(S)` | true | `Geom_BSplineCurve` | 6 | 7 | 1.000e-05 | 2.638e-06 |
| `BuildCurves3d(S, 1e-5)` | true | `Geom_BSplineCurve` | 6 | 7 | 1.000e-05 | 2.638e-06 |
| `BuildCurves3d(S, 1e-7)` | true | `Geom_BSplineCurve` | 7 | 8 | 1.000e-07 | 9.037e-08 |
| `BuildCurves3d(S, 1e-3)` | true | `Geom_BSplineCurve` | 5 | 6 | 1.000e-03 | 7.103e-05 |

So there was never a two-way split to preserve: all three bridge entry points reached one
algorithm, and OCCT's own default for the parameter is the same 1e-5 the no-tolerance overload
hard-codes.

Two things the tolerance does, only one of which is obvious:

- it bounds the approximation (the measured deviations sit just inside each request), and
- it becomes the rebuilt edge's tolerance **floor**, `BRepLib.cxx:428` reads
  `max_deviation = std::max(tolerance, Tolerance);` and feeds that to `B.UpdateEdge`, with the line
  that would have used the deviation the approximator actually achieved commented out just above
  it. A tolerance of 1e-7 therefore claims an accuracy the approximation is only asked, not
  required, to deliver.

### 2. Both pre-existing tests were tautological

Both tests that covered this operation called it on a `BRepPrimAPI_MakeBox`:

```
    tolerance 1e-07    returned true   edges 24  curves changed 0  tols changed 0
    tolerance 1e-05    returned true   edges 24  curves changed 0  tols changed 0
    tolerance 1e-01    returned true   edges 24  curves changed 0  tols changed 0
    tolerance 4e+01    returned true   edges 24  curves changed 0  tols changed 0
```

Every box edge already has a 3D curve, so `BuildCurve3d` returns true at its first line
(`BRepLib.cxx:320-324`) and computes nothing. A tolerance of 42 is indistinguishable from 1e-7,
and both tests asserted only `true`, so neither could have caught the defaults drifting, or
either implementation changing.

(24, not 12: `TopExp_Explorer` reaches each box edge twice, once per adjoining face. The
`NCollection_Map` inside `BuildCurves3d` is what makes the second visit a no-op.)

### 3. The tolerance stops mattering entirely on a plane

A pcurve on a `Geom_Plane` takes the analytic branch, `GeomLib::To3d`, then
`B.UpdateEdge(AnEdge, C3d, LocalLoc, 0.0e0)`: which never sees `Tolerance`:

| Call | curve | edge tolerance | max deviation |
|---|---|---|---|
| plane, tol 1e-07 | `Geom_Line` | 1.000e-07 | 0.000e+00 |
| plane, tol 1e-05 | `Geom_Line` | 1.000e-07 | 0.000e+00 |
| plane, tol 1e-01 | `Geom_Line` | 1.000e-07 | 0.000e+00 |

Exact, and identical for every request (1e-7 is `Precision::Confusion()`, the floor a fresh edge
gets anyway). So the 100x default drift was unobservable for planar pcurves, which is most of
what the bridge's other, internal `BuildCurves3d` call sites deal with, and bit only on curved
support surfaces.

### 4. What the `void` entry point discarded

```
    (a) degenerate edge on a cylinder: returned false  no 3D curve built
    (b) 1 good + 1 degenerate edge:      returned false  good edge built, bad edge not built
```

`false` means "at least one edge failed", and the edges that succeeded are still modified. The
oldest of the three entry points, `void OCCTShapeBuildCurves3d`, threw that away, and it was the
one backing `Shape.allEdgePolylinesIndexed`, i.e. the bulk path over arbitrary imported shapes,
which is exactly where a partial failure is likeliest.

### 5. An edge with no representation at all throws rather than crashing

`BuildCurve3d`'s approximation branch reads `first[0]` / `Curve2dArray[0]` whether or not its
`CurveOnSurface` loop found anything (`BRepLib.cxx:404-410`: `jj == 0` leaves both uninitialised).
Reaching it with an edge that has no 3D curve, no pcurve, and no degenerate flag:

```
    threw Standard_NullObject:
```

The null pcurve handle is dereferenced before the uninitialised `first[0]` is used for anything, so
this is a catchable `Standard_Failure`, not a signal, no new upstream crash to file, but the
bridge's `catch (...)` is what turns it into `false`, and the deleted `void` entry point's `catch`
swallowed it into silence. Reachable from the Swift API (`removeEdgeCurve3d` + `removeEdgePCurve`
on each adjoining face), so it is covered by a test rather than left as a note.

## What #498 changed

Three C entry points became one, `OCCTBRepLibBuildCurves3dForShape`:

| Deleted | Was | Now |
|---|---|---|
| `OCCTBRepLibBuildCurves3dAll` (v0.122.0) | byte-identical body to the survivor (v0.114.0), ~1700 header lines apart | `Shape.buildCurves3dAll` is a deprecated forwarder onto `Shape.buildCurves3d` |
| `void OCCTShapeBuildCurves3d` (oldest) | the forwarder overload, success flag discarded | `Shape.allEdgePolylinesIndexed` calls the survivor with 1e-5 spelled out |

`Shape.buildCurves3d`'s default changed from `1e-7` to `1e-5`, matching OCCT's own default for the
operation and the value the other two entry points already used. On the helix above that is the
difference between a 7-pole and an 8-pole approximation, and between an edge tolerance of 1e-5 and
one of 1e-7; callers who want the tighter curve pass `tolerance: 1e-7` explicitly.
