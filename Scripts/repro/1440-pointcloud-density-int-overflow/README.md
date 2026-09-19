# #1440 finding 3 verification, and a separate defect found along the way

`OCCTBridge_Mesh.mm`'s `OCCTPointCloudCollector` used to construct its `BRepLib_PointCloudShape`
base with a hardcoded tolerance of `0.0` instead of the class's own documented default
`Precision::Confusion()`. Fixed by passing no tolerance argument (taking the header's default).

This directory holds the ground-truth reproducer used to verify that fix, and to characterize a
**separate, previously-undiscovered defect** found while designing the regression test, which
this PR does NOT fix (it needs an OCCT kernel patch, out of scope for a bridge-only PR).

## The separate defect: `NbPointsByDensity`'s per-face point count divides by the wrong variable

`BRepLib_PointCloudShape::NbPointsByDensity` (`BRepLib_PointCloudShape.cxx`):

```cpp
int BRepLib_PointCloudShape::NbPointsByDensity(const double theDensity)
{
  clear();
  double aDensity = (theDensity < Precision::Confusion() ? computeDensity() : theDensity);
  if (aDensity < Precision::Confusion())
  {
    return 0;
  }

  int aNbPoints = 0;
  for (TopExp_Explorer aExpF(myShape, TopAbs_FACE); aExpF.More(); aExpF.Next())
  {
    double anArea = faceArea(aExpF.Current());
    int aNbPnts = std::max((int)std::ceil(anArea / theDensity), 1);   // <-- theDensity, not aDensity
    ...
```

The per-face point count divides by `theDensity`, the caller's ORIGINAL argument, not `aDensity`,
the (possibly auto-computed) density actually used for the threshold check three lines above. At
an exact `density: 0.0` (the obvious way to request "auto"), this is `anArea / 0.0` = `+Infinity`
for any face with positive area, and `(int)std::ceil(+Infinity)` is undefined behavior in C++;
measured directly on this platform (arm64 macOS) it saturates to `INT_MAX` (2147483647). Every
face then requests ~2.1 billion points from `addDensityPoints`, which is not itself infinite but
is, in practice, an effectively unbounded hang (confirmed: did not return within several minutes
before being killed).

**This is independent of Finding 3.** It reproduces on an ORDINARY shape with no near-zero-area
face at all (a plain box), regardless of `myTol`, any time `computeDensity()`'s own answer clears
`Precision::Confusion()` (i.e., any time the early-return at the top of the function does NOT
fire). Finding 3's fix does not create this defect; it only changes which shapes hit it (see
below).

### Why Finding 3's fix doesn't make this worse in practice

Before Finding 3's fix (`myTol == 0.0`), a shape with a poisoning near-zero-area face has its
auto-computed density poisoned down near zero too, so `NbPointsByDensity` takes the FAST early
return (`aDensity < Precision::Confusion()` → `return 0`) before ever reaching the broken
per-face loop. After the fix, that same shape's density is computed correctly, clears
`Precision::Confusion()`, and now DOES reach the broken loop -- trading a fast, wrong "0 points"
for the same hang every other shape with a legitimate density already had. It is a consistency
fix (uniform behavior across shapes), not a new hazard: ordinary shapes were already hanging on
literal `density: 0.0` before this PR, this PR does not change that.

### Verification

`occt_1440_density_probe.mm` in this directory:

```
$ clang++ -std=c++17 -ObjC++ -w \
    -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
    -L"Libraries/OCCT.xcframework/macos-arm64" \
    -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
    occt_1440_density_probe.mm -o /tmp/probe
$ /tmp/probe
tol=0.0 (bug)  -> GeneratePointsByDensity=0, count=0
tol=Confusion (fix) -> GeneratePointsByDensity=1, count=5002
explicit density 1e-5 (bypasses computeDensity) -> ok=1 count=12
```

Confirms, against the real `BRepLib_PointCloudShape`/`NbPointsByDensity` (not just the hand
calculation): with the pre-fix tolerance, the fixture's poisoned auto-density returns 0 points
fast; with the fixed tolerance, it correctly excludes the sliver and generates 5002 points, fast
(not the billions the `theDensity`/`0.0` combination would produce -- this reproducer
deliberately uses a small non-zero density, `2e-8`, for exactly the reason
`Tests/OCCTTopologyTests/Issue1440PointCloudToleranceTests.swift` documents).

A companion probe (`(int)std::ceil(1.0/0.0)` in isolation) confirmed the `INT_MAX`-saturation
behavior on this platform before this file was written; not kept here since it's a two-line
standard-library fact, not something specific to this codebase.

Not yet filed upstream or fixed. Tracked as [#1452](https://github.com/SecondMouseAU/OCCTSwift/issues/1452);
needs an OCCT kernel patch (`aNbPnts` should divide by `aDensity`, matching the
`Precision::Confusion()` check three lines above it) since the divergence is inside
`BRepLib_PointCloudShape.cxx` itself, not reachable from the bridge side.
