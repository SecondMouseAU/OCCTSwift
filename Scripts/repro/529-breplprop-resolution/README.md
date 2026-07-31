# OCCTSwift#529 probes — the `BRepLProp_*` `Resolution` argument

Standalone, deterministic probes for the tolerance divergence #529 fixed, the curvature-inversion
defect it widened, and the two decisions the change does *not* move. Everything but the last probe
builds its geometry from a primitive; the decision sweep optionally takes `.brep` files on the
command line.

Companion to [`../494-lprop-resolution/`](../494-lprop-resolution), which measured the same argument
on the `Geom_`-handle side.

## `BRepLProp_SLProps` is `GeomLProp_SLProps`

The issue's stated reason for deferring this half of #494 was that `BRepLProp_*` is "a different
class family" whose factories "are not reusable as written". Reading the pinned headers first says
otherwise. `BRepLProp_SLProps.hxx` in OCCT 8.0.0p1, in full, minus the licence block:

```cpp
#include <BRepAdaptor_Surface.hxx>
#include <GeomLProp_SLProps.hxx>

//! Alias for surface local properties using BRepAdaptor_Surface.
using BRepLProp_SLProps = GeomLProp_SLPropsBase<BRepAdaptor_Surface>;
```

and `GeomLProp_SLProps.hxx` ends with

```cpp
using GeomLProp_SLProps = GeomLProp_SLPropsBase<occ::handle<Geom_Surface>>;
```

Same for the curve pair. One header-only template, two instantiations, one argument apart. So the
`Resolution` means exactly what #494 measured it to mean, and the factories differ only in the type
they take.

## Building

```bash
L=Libraries/OCCT.xcframework/macos-arm64
clang++ -std=c++17 -ObjC++ -w -I"$L/Headers" -L"$L" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/529-breplprop-resolution/occt_529_adaptor_sweep.cpp -o /tmp/occt_529_sweep
/tmp/occt_529_sweep
```

Same command for the other three. In a git worktree `Libraries/` does not exist — point `L` at the
main checkout's copy, or symlink it (see `docs/guides/building-occt.md`).

## The four probes

### `occt_529_adaptor_sweep.cpp` — where `1e-6` and `Precision::Confusion()` disagree

Sweeps both values over a cone face approaching its apex, a sphere face approaching its pole, and a
family of cubic Bezier edges whose first two poles sit a controlled distance apart, and prints the
`GeomLProp_*` answer at `Precision::Confusion()` alongside as the reference. Output on 8.0.0p1:

```
=== SLProps on a FACE: cone (semi-angle 30 deg, apex radius 0), u=0 ===
v         | BRepLProp @ 1e-6 (today)    | BRepLProp @ Confusion (fix) | GeomLProp @ Confusion
1e-05     | def H=-8.66e+04   K=-0      | def H=-8.66e+04   K=-0      | def H=-8.66e+04   K=-0
3e-06     | def H=-2.887e+05  K=-0      | def H=-2.887e+05  K=-0      | def H=-2.887e+05  K=-0
1.5e-06   | UNDEFINED (normal def)      | def H=-5.774e+05  K=-0      | def H=-5.774e+05  K=-0
1e-06     | UNDEFINED (normal def)      | def H=-8.66e+05   K=-0      | def H=-8.66e+05   K=-0
3e-07     | UNDEFINED (normal def)      | def H=-2.887e+06  K=-0      | def H=-2.887e+06  K=-0
1e-07     | UNDEFINED (normal def)      | UNDEFINED (normal def)      | UNDEFINED (normal def)
0         | UNDEFINED (normal undef)    | UNDEFINED (normal undef)    | UNDEFINED (normal undef)
```

Note the `(normal def)` on every row but the last: the curvature is what the resolution decides here,
not the normal. That distinction is what the third probe is about.

Two things this probe also settles:

- **The adaptor and the raw handle agree exactly on an analytic surface, and to about one ULP on a
  Bezier or BSpline curve.** `GeomAdaptor_Curve` evaluates a Bezier through a cache the handle does
  not use, so the same curvature comes out as `0.67461923686773151` through the adaptor and
  `0.6746192368677314` through the handle. Parity assertions have to compare definedness exactly and
  values relatively.
- **A cusped edge answers `RealLast()` at both resolutions**, so the sentinel is not something the
  resolution change removes. It needs its own gate — the next probe.

### `occt_529_edge_inversion.cpp` — the `(nan, inf, nan)` centre of curvature

`LProp_CurveUtils::Curvature()` returns `RealLast()` when the first significant derivative has order
> 1, on a path that never assigns the `myCurvature` field. `Normal()` rejects the sentinel by name;
`CentreOfCurvature()` tests only `|Curvature()| <= resolution`, which `RealLast()` passes, then
divides by the unassigned field. So the failure mode is not an exception, it is a point that is not
a point, returned as a success. #494 found this on the `Geom_` side; the same template does it here.

The resolution decides how wide the window is. At `u = 0`, by pole spacing:

| spacing | at `1e-6` | at `Precision::Confusion()` |
|---|---|---|
| 1e-3, 1e-5, 1e-6 | real centre | real centre |
| 3e-7 | `(nan, inf, nan)` | real centre `(0, 1.35e-13, 0)` |
| 1e-7 | `(inf, inf, nan)` | real centre `(2.80e-30, 1.5e-14, 0)` |
| 1e-8, 1e-9, 1e-12 | `(nan, inf, nan)` | `(nan, inf, nan)` |
| 0 | throws (`gp_Vec::Normalize() - vector has zero norm`) | throws |

So tightening the resolution closes one decade of it and `occtCurveCurvatureIsInvertible` closes the
rest. Only the exactly-coincident case was ever safe, and only by accident: the throw is absorbed by
the bridge's `catch (...)` into `(0, 0, 0)`.

### `occt_529_face_normal_decisions.cpp` — the change that is inert, measured rather than assumed

`OCCTFaceGetNormal` evaluates the normal at the parametric midpoint of a face and reports it
(`Face.normal`), and `isHorizontal` / `isUpwardFacing` / `isDownwardFacing` / `isVertical` are all
predicates over that one normal. This probe compares definedness, direction and the resulting
horizontal/upward classification at both resolutions, for every face of every shape it is given.

```
box 10x20x30              faces=6    definedness -/+ = 0/0  direction changed = 0  horizontal 2->2  upward 1->1
cone r1=5 r2=0 h=12       faces=2    definedness -/+ = 0/0  direction changed = 0  horizontal 1->1  upward 0->0
half sphere (pole at v mid) faces=2  definedness -/+ = 0/0  direction changed = 0  horizontal 1->1  upward 0->0
filleted box (r=1.5)      faces=26   definedness -/+ = 0/0  direction changed = 0  horizontal 2->2  upward 1->1
unify-crash-mmd-kiha10-body5.brep faces=662  definedness -/+ = 0/0  direction changed = 0  horizontal 18->18  upward 9->9
extrusion skewed by 1e-06 rad  faces=1  definedness -/+ = 0/1 ...   <-- CHANGED
extrusion skewed by 5e-07 rad  faces=1  definedness -/+ = 0/1 ...   <-- CHANGED
```

The mechanism behind the zeros, from `CSLib.cxx`:

```cpp
if (aD1UMag <= gp::Resolution() && aD1VMag <= gp::Resolution())  theStatus = CSLib_D1IsNull;
...
const double aSin2 = aD1UxD1V.SquareMagnitude() / (aD1UMag * aD1VMag);
if (aSin2 < theSinTol * theSinTol)                               theStatus = CSLib_D1uIsParallelD1v;
```

The nullity tests use `gp::Resolution()`, a fixed ~1e-300 epsilon, **not** the caller's value. The
caller's value is a *sine* tolerance on the angle between the two parametric directions, and that
test is scale-invariant. So a surface whose derivatives merely shrink — a cone at its apex, a sphere
at its pole — keeps a defined normal all the way down, and the resolution never enters. Only a
nearly *singular parameterisation* is affected, which is what the skewed extrusion constructs: a
line extruded along a direction 5e-7 radians off its own.

This is also why the curvature sites move and the normal sites do not. `IsCurvatureDefined()` goes
through `IsTangentUDefined()` / `IsTangentVDefined()`, which are absolute
`SquareMagnitude() > tol * tol` tests.

**Probe artefact worth recording**: an earlier version compared directions with
`gp_Dir::IsEqual(other, 0.0)` and reported 384 of the 662 fixture faces as changed. `gp_Dir::Angle`
returns ~1.5e-17 rather than 0 for two *bit-identical* directions whenever the dot product rounds
just below 1 and it takes the `asin(CrossMagnitude)` branch — comparing two props objects built at
the same resolution shows the same 1.5e-17. The probe now compares components exactly.

### `occt_529_raycast_tolerance.cpp` — the one site that took its resolution from the caller

`OCCTShapeRaycast` passed its `tolerance` parameter to `IntCurvesFace_ShapeIntersector::Load`, where
it is an intersection distance, *and* to `BRepLProp_SLProps`, where it is the sine tolerance above.
`Shape.raycast`'s default is `0.001`. A sine tolerance is dimensionless and saturates at 1:

```
=== sphere r=5, ray straight down the Z axis ===
loadTol=0.001  resolution=0.001  hits=2   hit1 normal (6.123e-17, 0, 1)   hit2 normal (6.123e-17, 0, -1)
loadTol=0.9    resolution=0.9    hits=2   hit1 normal (6.123e-17, 0, 1)   hit2 normal (6.123e-17, 0, -1)
loadTol=1      resolution=1      hits=2   hit1 normal UNDEFINED -> reported as (0, 0, 1)   hit2 normal UNDEFINED -> ...
loadTol=2      resolution=2      hits=2   hit1 normal UNDEFINED -> reported as (0, 0, 1)   hit2 normal UNDEFINED -> ...

=== box 10x10x10, ray straight down ===
loadTol=1      resolution=1      hits=2   hit1 normal (0, 0, 1)   hit2 normal (-0, -0, -1)
loadTol=5      resolution=5      hits=2   hit1 normal UNDEFINED -> reported as (0, 0, 1)   hit2 normal UNDEFINED -> ...

=== the same hits, resolution decoupled from the load tolerance ===
loadTol=5      resolution=1e-07  hits=2   hit1 normal (0, 0, 1)   hit2 normal (-0, -0, -1)
```

The box surviving `resolution=1` where the sphere does not is the boundary being exact: a plane's
`aSin2` is exactly 1, and the test is `<`, not `<=`.

The fallback makes it worse than a missing answer. `RayHit.normal` is `(0, 0, 1)` when the normal is
undefined, so at `tolerance: 5.0` a box's *downward* face reported an upward normal. `RayHit` now
carries `normalDefined` alongside it.
