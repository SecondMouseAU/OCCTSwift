# OCCTSwift#494 probes, the `GeomLProp_*` `Resolution` argument

Standalone, deterministic probes for the tolerance divergence #494 fixed, plus the `RealLast()`
centre-of-curvature defect found while measuring it. No fixture files and no kernel patch: every
case builds its geometry from a primitive.

## What `Resolution` is

`GeomLProp_SLProps` / `GeomLProp_CLProps` / `GeomLProp_CLProps2d` take a `Resolution` their headers
describe as "the linear tolerance (it is used to test if a vector is null)". It is not a comparison
or display tolerance. It decides whether a derivative at one `(u, v)` counts as null, and therefore
whether the tangent, normal and curvature are reported as *existing* at that point:

```cpp
// LProp_CurveUtils.hxx, IsTangentDefined
const double aTolSq = theLinTol * theLinTol;
...
if (aV.SquareMagnitude() > aTolSq) { theSigOrder = anOrder; theTanStatus = LProp_Defined; return true; }
```

Note the direction: a **smaller** resolution is the **more permissive** one. The `1e-10` the
`Local*` family used to pass called derivatives significant that `Precision::Confusion()` (`1e-7`)
calls null, three decades *more* willing to treat a degenerate point as well-conditioned. That is
the opposite of how a tolerance usually reads, and it is why the drift survived #405's audit, whose
own commit message describes the value it removed as "looser".

For surfaces the resolution reaches `IsCurvatureDefined()` indirectly, via `IsNormalDefined()` and
`IsTangentUDefined()`/`IsTangentVDefined()`, all three of which take `myLinTol`
(`GeomLProp_SurfaceUtils.hxx`). `IsCurvatureDefined()` itself takes no tolerance argument, which is
why grepping for it does not reveal the dependency.

## Building

```bash
L=Libraries/OCCT.xcframework/macos-arm64
clang++ -std=c++17 -ObjC++ -w -I"$L/Headers" -L"$L" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/494-lprop-resolution/occt_494_resolution_sweep.cpp -o /tmp/occt_494_sweep
/tmp/occt_494_sweep
```

Same command for the other two files. In a git worktree `Libraries/` does not exist, point `L` at
the main checkout's copy (see `docs/guides/building-occt.md`).

## The three probes

### `occt_494_resolution_sweep.cpp`, where the three values disagree

Sweeps `1e-10`, `Precision::Confusion()` and `1e-6` over a cone approaching its apex, a cubic Bezier
whose first two poles are a controlled distance apart, and a set of classic degeneracies. Output on
OCCT 8.0.0p1:

```
=== SLProps: cone (semi-angle 30 deg, apex radius 0), u=0, varying v ===
v            | 1e-10 (Local)                | Confusion                    | 1e-6 (LProp*)
1e-09        | def K=-0        H=-8.66e+08  | UNDEFINED                    | UNDEFINED
1e-08        | def K=-0        H=-8.66e+07  | UNDEFINED                    | UNDEFINED
1e-07        | def K=-0        H=-8.66e+06  | UNDEFINED                    | UNDEFINED
1e-06        | def K=-0        H=-8.66e+05  | def K=-0        H=-8.66e+05  | UNDEFINED
1e-05        | def K=-0        H=-8.66e+04  | def K=-0        H=-8.66e+04  | def K=-0        H=-8.66e+04
```

Three sampled `v` values where the `Local*` family reported a defined mean curvature of up to
`-8.7e8` and every canonical entry point reported the same point undefined. The curve half shows the
same window as a curvature value: `6.7e19` from `1e-10` against `RealLast()` from
`Precision::Confusion()`.

It also confirms two things the fix depends on: well-conditioned geometry gives bit-identical values
at all three resolutions (so converging them changes nothing away from a degeneracy), and the
`SLProps` curvature accessors *raise* when `IsCurvatureDefined()` is false rather than returning
zero (so the bridge's `isDefined` check is load-bearing, not belt-and-braces).

### `occt_494_reallast_centre.cpp`, the `(nan, inf, nan)` centre of curvature

At a cusp, first significant derivative of order 2, e.g. a Bezier whose first two poles coincide,
OCCT returns `RealLast()` from `Curvature()` to mean *infinite* curvature. `IsTangentDefined()` is
still true, and `RealLast()` passes any "is the curvature big enough to invert" test, so it used to
flow into `CentreOfCurvature()`:

```
  d=1e-12    Confusion  tan=1 curv=1.798e+308  centre=(nan, inf, nan)   normal=THROW
  d=1e-09    Confusion  tan=1 curv=1.798e+308  centre=(inf, inf, nan)   normal=THROW
```

The mechanism is upstream and independent of which resolution is passed, the probe shows it at all
three. `LProp_CurveUtils::Curvature()` returns the sentinel on an early path:

```cpp
if (theSigOrder > 1)
  return RealLast();                                  // theCurvature NOT assigned
theCurvature = ComputeCurvature(theD1, theD2, theLinTol * theLinTol);
```

so `myCurvature` keeps its `= 0.0` initializer, and `CentreOfCurvature()`'s own guard
(`if (std::abs(theProps.Curvature()) <= theLinTol) throw`) sees `RealLast()`, passes, and calls
`ComputeCentreOfCurvature(..., theCurvature = 0.0, ...)`, which does `aNorm.Divide(0.0)`.
`Normal()` was never exposed because it tests for the sentinel by name
(`if (aCurvature == RealLast() || ...) throw`).

The bridge now rejects the sentinel before either accessor, via
`occtCurveCurvatureIsInvertible()` in `OCCTBridge_Internal.h`.

### `occt_494_isumbilic_ulp.cpp`, `IsUmbilic()` is a one-ULP test

Not part of the fix; it corrects a docs claim. `Surface.localCurvatureDirections(u:v:)` returns `nil`
at umbilic points, and was documented as though that covered a sphere. OCCT's test is
`|maxCurv - minCurv| < Epsilon(maxCurv)`: one ULP, not a geometric tolerance:

```
Sphere R=3 (analytically umbilic EVERYWHERE):
  sphere  (u=0 v=0.3)  max=-0.33333333333333331 min=-0.33333333333333331 |diff|=0        umbilic=1
  sphere  (u=0 v=1)    max=-0.33333333333333331 min=-0.33333333333333337 |diff|=5.55e-17 umbilic=0

Plane (both principal curvatures exactly 0):
  plane   (u=1 v=2)    max=0 min=0 |diff|=0 Epsilon=4.94e-324 umbilic=1
```

So an analytically-umbilic sphere is detected as umbilic only where the two computed curvatures
round to the same `Double`, it depends on the radius and the parameter. A plane always qualifies.
This is why the regression suite asserts the curvature-defined-but-no-directions asymmetry on a
plane, where it is exact, rather than on a sphere, where it would be flaky.

## What the fix was

Bridge-only; no kernel patch, no `OCCT.xcframework` rebuild. All 28 `GeomLProp_*` constructions in
the bridge now go through `occtSurfaceLocalProps` / `occtCurveLocalProps` / `occtCurve2dLocalProps`
in `OCCTBridge_Internal.h`, which take their resolution from `occtLocalPropsResolution()`; every
curvature inversion goes through `occtCurveCurvatureIsInvertible()`. Regression coverage is
`LocalPropsParityTests` in `Tests/OCCTAnalysisTests/OCCTAnalysisTests.swift`.

The 19 `BRepLProp_SLProps`/`BRepLProp_CLProps` constructions still on a literal `1e-6` are
[#529](https://github.com/SecondMouseAU/OCCTSwift/issues/529).
