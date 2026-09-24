# Phase 3: OCCTMathTests Injection Matrix

**Target**: `OCCTMathTests` (342 tests) — Mathematical algorithms, geometry construction, interpolation, solving
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (crash fixes #345, #603, #636, #477, #408, #491)

---

## Test Inventory by Suite

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| gce_MakeLin Tests | 26 | WR/CR |
| gce_MakeCirc Tests | 24 | WR/CR |
| gce_MakeHypr Tests | 22 | WR/CR |
| gce_MakeElips Tests | 20 | WR/CR |
| gce_MakeParab Tests | 18 | WR/CR |
| GC_MakeTranslation | 16 | WR |
| GC_MakeTrimmedCylinder Tests | 15 | WR |
| GC_MakePipe Tests | 14 | WR |
| Convert_CompPolynomialToPoles | 13 | WR |
| MathJacobi Tests | 12 | WR/CR |
| MathSolver Powell v0.110 | 11 | WR |
| Vector2DMath | 10 | WR |
| LineGeometry_Operations | 9 | WR |
| MathSolver FunctionRoot v0.110 | 8 | WR |
| BRepTools_TrsfModification | 8 | WR |
| MathSolver GaussIntegrate v0.111 | 7 | WR |
| ... | ... | ... |

**Total**: 342 tests across ~25 suites

---

## Injection Matrix: Critical Crash-Related Tests First

### #345: gp_Dir Zero Vector Crash (Bridge Fix)

**Issue**: `gp_Dir` constructor throws `Standard_ConstructionError` for zero-length direction/normal vector. Multiple math bridge functions construct `gp_Dir`/`gp_Ax1`/`gp_Ax2`/`gp_Ax3`/`Geom_Direction` from caller-supplied doubles with no try/catch.

**Bridge Fix**: Wrapped all affected bridge functions in `try { } catch (...) { <safe fallback> }`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| mirrorAxisZeroDirection | `OCCTMakeMirrorAxis` → `gp_Dir` | Zero direction vector | Remove `try/catch` in bridge |  |  | Uncaught `Standard_ConstructionError` |
| mirrorPlaneZeroNormal | `OCCTMakeMirrorPlane` → `gp_Dir` | Zero normal vector | Remove `try/catch` in bridge |  |  | Uncaught `Standard_ConstructionError` |
| geomDirectionZeroVector | `OCCTGeomDirectionCreate` → `Geom_Direction` | Zero vector handled gracefully | N/A | N/A |  | `Geom_Direction` returns NaN, no exception |

### #603: CPnts_AbscissaPoint Single Quadrature (Bridge + Kernel Fix)

**Issue**: `CPnts_AbscissaPoint::Length` uses ONE fixed-order Gauss rule over whole range → arc length errors up to 1.7% (ellipse) / 3% (parabola).

**Bridge Fix**: Adaptive quadrature in `occtAdaptorArcLength` / `occtArcWalkToLength` — halve each `GeomAbs_CN` interval until two levels agree to 1e-9 relative.

**Kernel Patch**: `0021` — `CPnts_AdaptiveIntegration.hxx` does same doubling for all 4 `Length` overloads and `Value`/`Values`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| A whole ellipse measures its own circumference, not 0.3-1.7% more | `Curve3D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature in bridge |  |  | Error up to 1.7% |
| A parabola over a wide range measures its arc, not 3% less | `Curve3D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature in bridge |  |  | Error 3% (worst case) |

### #636: Curve3D extrema on Parallel Curves (Bridge Fix)

**Issue**: `BRepExtrema_ExtCC` crashes (SIGSEGV) when edges are parallel — `ExtCC` returns `isParallel=true` but caller accesses points without checking.

**Bridge Fix**: Guard with `if (result.isParallel) { return result; }` before accessing points.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Two unbounded parallel lines: extrema is empty, not a crash | `Curve3D.extrema(to:)` → `BRepExtrema_ExtCC` | Parallel crash | Remove `isParallel` guard |  |  | SIGSEGV |

### #477: Arc-Length Per-Span Split (Bridge Fix)

**Issue**: `GCPnts_AbscissaPoint::Length` splits at `GeomAbs_CN` intervals but not within → 8x3 ellipse 0.337% error over `[0,2pi]`, exact over `[0,pi/2]`.

**Bridge Fix**: Adaptive quadrature inside each interval — halve until two levels agree to 1e-9.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| length of a multi-span interpolated BSpline matches reference | `Curve3D.arcLength` → `occtAdaptorArcLength` | No per-span adaptive | Remove adaptive quadrature |  |  | Error > 1e-9 |

### #408: Arc-Length Failure vs Zero-Length Distinguishability

**Issue**: Genuine zero-width interval returns 0.0, not failure sentinel; failing computation distinguishable from real zero.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| A genuine zero-width interval reports exactly 0.0, not a failure sentinel | `Curve3D.arcLength(from:to:)` → `occtArcWalkToLength` | Zero vs failure confusion | Remove distinction |  |  | Wrong result |

### #491: Surface Approximation Parity (Kernel Patch 0019)

**Issue**: `AdvApp2Var_ApproxF2var::mma2ce1_` fills the U Jacobi-maxima buffer from the V slot — `GeomConvert_ApproxSurface` at `GeomAbs_C0` returned a surface nowhere near its input while reporting `IsDone()` and a `MaxError()` five orders of magnitude too small.

**Kernel Patch**: `0019` — target `ipt4` from the U call instead of `ipt5`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Surface approximation at C0/C0 matches kernel | `GeomConvert_ApproxSurface` | U buffer filled from V | Revert patch 0019 |  |  | MaxError 25000x wrong |

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| gce_MakeLin Tests | 26 |  |  |  |  |
| gce_MakeCirc Tests | 24 |  |  |  |  |
| gce_MakeHypr Tests | 22 |  |  |  |  |
| ... | ... |  |  |  |  |

**Total**: 342 tests

### 766-math-arcs-axes (#1983, measured)

| Suite | Test | Bridge function | Injection | Red | Green | Parity |
|-------|------|-----------------|-----------|-----|-------|--------|
| **GC_MakeArcOfHyperbola** | Arc of hyperbola between parameters | `OCCTCurve3DArcOfHyperbola` | major and minor radius swapped into gp_Hypr | red | green | PASS |
| **GC_MakeArcOfParabola** | Arc of parabola between parameters | `OCCTCurve3DArcOfParabola` | focal distance doubled (original test green; vertex offset +1 in x also turned the original red) | red | green | PASS |
| **Axis1Placement Tests** | create and read | `OCCTAxis1PlacementLocation` | location x + 1 | red | green | PASS |
| **Axis1Placement Tests** | reverse | `OCCTAxis1PlacementReverse` | Reverse() skipped | red | green | PASS |
| **Axis1Placement Tests** | reversed copy | `OCCTAxis1PlacementReversed` | returns an unreversed copy | red | green | PASS |
| **Axis1Placement Tests** | setDirection and setLocation | `OCCTAxis1PlacementSetDirection / OCCTAxis1PlacementSetLocation` | SetDirection skipped; SetLocation skipped (each red on its own line) | red | green | PASS |
| **Axis2Placement Tests** | create and read directions | `OCCTAxis2PlacementYDirection` | Y direction y negated | red | green | PASS |
| **Axis2Placement Tests** | location | `OCCTAxis2PlacementLocation` | location x + 1 | red | green | PASS |
| **Axis2Placement Tests** | setDirection | `OCCTAxis2PlacementSetDirection` | SetDirection skipped | red | green | PASS |
| **Axis2Placement Tests** | setXDirection | `OCCTAxis2PlacementSetXDirection` | SetXDirection skipped | red | green | PASS |
### 766-math-roots-cones-coordsys (#1983, measured)
| **BracketedRoot** | findRoot | `OCCTMathBracketedRoot` | returns bound1 instead of Root() | red | green | PASS |
| **BracketedRoot** | findSinRoot | `OCCTMathBracketedRoot` | returns bound1 instead of Root() | red | green | PASS |
| **BracketMinimum** | bracketQuadratic | `OCCTMathBracketMinimum` | fa and fb written to each other | red | green | PASS |
| **GC_MakeConicalSurface** | Conical surface from axis and angle | `OCCTSurfaceConicalFromAxis` | semi-angle doubled | red | green | PASS |
| **GC_MakeConicalSurface** | Conical surface from points and radii | `OCCTSurfaceConicalFromPointsRadii` | r1 and r2 swapped | red | green | PASS |
| **Coordinate System Tests** | zUpDirection | `OCCTCoordSystemUpDirection` | XDirection() returned instead of Direction() | red | green | PASS |
| **Coordinate System Tests** | yUpDirection | `OCCTCoordSystemUpDirection` | XDirection() returned instead of Direction() | red | green | PASS |
| **Coordinate System Tests** | convertWithScaling | `OCCTCoordSystemConvert` | SetInputLengthUnit skipped | red | green | PASS |
| **Coordinate System Tests** | convertZupToYup | `OCCTCoordSystemConvert` | SetOutputCoordinateSystem skipped | red | green | PASS |
### 766-math-coordinate-system-3d (#1983, measured)
| **CoordinateSystem3D** | defaultXYZ | `OCCTAx3Create` | Y direction y negated | red | green | PASS |
| **CoordinateSystem3D** | fromNormal | `OCCTAx3CreateFromNormal` | isDirect inverted | red | green | PASS |
| **CoordinateSystem3D** | angle | `OCCTAx3Angle` | a1.Angle(a1) instead of a1.Angle(a2) | red | green | PASS |
| **CoordinateSystem3D** | isCoplanar | `OCCTAx3IsCoplanar` | second origin built as (x, z, y) | red | green | PASS |
| **CoordinateSystem3D** | mirrorPoint | `OCCTAx3MirrorPoint` | origin x read from the unmirrored axis | red | green | PASS |
| **CoordinateSystem3D** | rotate | `OCCTAx3Rotate` | angle negated | red | green | PASS |
| **CoordinateSystem3D** | translate | `OCCTAx3Translate` | vector x and y swapped | red | green | PASS |
| **CoordinateSystem3D** | createWithParallelDirectionAndXDirectionSignalsFailure | `OCCTAx3Create` | catch falls back to a default (1,0,0)/(0,1,0) frame instead of zeros | red | green | PASS |
| **CoordinateSystem3D** | createFromNormalWithZeroDirectionSignalsFailure | `OCCTAx3CreateFromNormal` | catch falls back to a default (1,0,0)/(0,1,0) frame instead of zeros | red | green | PASS |
| **CoordinateSystem3D** | mirrorPointWithDegenerateSourceFallsBackToUnmoved | `OCCTAx3MirrorPoint` | catch no longer writes the input point back (pre-#1443 empty catch) | red | green | PASS |
| **CoordinateSystem3D** | rotateWithZeroAxisDirectionFallsBackToUnmoved | `OCCTAx3Rotate` | catch no longer writes the input point back (pre-#1443 empty catch) | red | green | PASS |
| **CoordinateSystem3D** | translateWithDegenerateSourceFallsBackToUnmoved | `OCCTAx3Translate` | catch no longer writes the input point back (pre-#1443 empty catch) | red | green | PASS |
### 766-math-curve-transform-cylinder (#1983, measured)
| **Curve3D Transform** | Translate BSpline curve | `OCCTCurve3DTransform` | translation vector x and y swapped | red | green | PASS |
| **Curve3D Transform** | Rotate curve | `OCCTCurve3DTransform` | rotation angle negated | red | green | PASS |
| **Curve3D Transform** | Scale curve | `OCCTCurve3DTransform` | scale factor inverted | red | green | PASS |
| **Curve3D Transform** | Mirror curve through point | `OCCTCurve3DTransform` | identity transform instead of the mirror | red | green | PASS |
| **Curve3D Transform** | Mirror curve through axis | `OCCTCurve3DTransform` | point mirror through the axis origin instead of the axis mirror | red | green | PASS |
| **Curve3D Transform** | Mirror curve through plane | `OCCTCurve3DTransform` | point mirror through the plane origin instead of the plane mirror | red | green | PASS |
| **GC_MakeCylindricalSurface** | Cylindrical surface from axis and radius | `OCCTSurfaceCylindricalFromAxis` | radius doubled | red | green | PASS |
| **GC_MakeCylindricalSurface** | Cylindrical surface from 3 points | `OCCTSurfaceCylindricalFromPoints` | point1 and point3 swapped | red | green | PASS |
### 766-math-drawing-eigen-solvers (#1983, measured)
| **v0.144 Drawing transform + bounds** | Drawing.bounds returns finite box for a projected box | `OCCTDrawingCreate (bounds() is Swift over its edge polylines)` | Swift: bounds reads (y, x) instead of (x, y) | red | green | PASS |
| **v0.144 Drawing transform + bounds** | transformed(translate:scale:) returns non-nil wrapper | `N/A (pure Swift: Drawing.transformed stores translate/scale)` | Swift: transformed() drops the scale | red | green | N/A |
| **v0.144 Drawing transform + bounds** | DXFWriter.collectFromDrawing accepts TransformedDrawing | `OCCTDrawingCreate (DXF writer is Swift)` | Swift: collectFromDrawing(TransformedDrawing) drops the translation | red | green | PASS |
| **EigenValues** | tridiagonal | `OCCTMathEigenValues` | off-diagonals placed in slots 1..n-1 (the pre-#1643 convention) | red | green | PASS |
| **EigenValues** | withVectors | `OCCTMathEigenValuesAndVectors` | off-diagonals placed in slots 1..n-1 (the pre-#1643 convention) | red | green | PASS |
| **GC_MakeEllipse, 3 Points** | Create ellipse through three points | `OCCTCurve3DMakeEllipseThreePoints` | S2 built as (x, z, y) | red | green | PASS |
| **FRPR Minimizer** | minimizeQuadratic | `OCCTMathFRPR` | returns the start point instead of Location() | red | green | PASS |
| **FunctionAllRoots** | sinRoots | `OCCTMathFunctionRoots` | every root + 0.05 (despite the suite name, `findAllRoots(in:)` resolves to the overload that calls OCCTMathFunctionRoots; injections in OCCTMathFunctionAllRoots left it green) | red | green | PASS |
| **GaussLeastSquare** | overdetermined | `OCCTMathGaussLeastSquare` | matrix read column-major | red | green | PASS |
### 766-math-elclib-elslib (#1983, measured)
| **ElCLib Tests** | valueOnLine | `OCCTElCLibValueOnLine` | u negated | red | green | PASS |
| **ElCLib Tests** | valueOnCircle | `OCCTElCLibValueOnCircle` | x and y outputs swapped | red | green | PASS |
| **ElCLib Tests** | valueOnEllipse | `OCCTElCLibValueOnEllipse` | x from the minor radius | red | green | PASS |
| **ElCLib Tests** | d1OnCircle | `OCCTElCLibD1OnCircle` | tangent reversed | red | green | PASS |
| **ElCLib Tests** | parameterOnLine | `OCCTElCLibParameterOnLine` | line direction negated | red | green | PASS |
| **ElCLib Tests** | inPeriod | `OCCTElCLibInPeriod` | returns uFirst | red | green | PASS |
| **ElSLib Tests** | valueOnPlane | `OCCTElSLibValueOnPlane` | u and v swapped | red | green | PASS |
| **ElSLib Tests** | valueOnSphere | `OCCTElSLibValueOnSphere` | radius doubled | red | green | PASS |
| **ElSLib Tests** | valueOnCylinder | `OCCTElSLibValueOnCylinder` | u and v swapped | red | green | PASS |
| **ElSLib Tests** | valueOnTorus | `OCCTElSLibValueOnTorus` | major and minor radius swapped | red | green | PASS |
| **ElSLib Tests** | parametersOnSphere | `OCCTElSLibParametersOnSphere` | point x and y swapped | red | green | PASS |
