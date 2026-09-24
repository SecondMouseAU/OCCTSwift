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
### 766-math-gce-make (#1983, measured)
| **gce_MakeCirc Tests** | circleThrough3Points | `OCCTGceMakeCircFrom3Points` | p2 built as (y, x, z), which equals p1: gce refuses, bridge returns nil | red | green | PASS |
| **gce_MakeCirc Tests** | circleFromCenterNormal | `OCCTGceMakeCircFromCenterNormal` | radius halved | red | green | PASS |
| **gce_MakeCone Tests** | coneFrom2PointsRadii | `OCCTSurfaceConicalFromPointsRadii` | r1 and r2 swapped | red | green | PASS |
| **gce_MakeCone Tests** | parityWithConicalSurface | `OCCTSurfaceConicalFromPointsRadii (both routes)` | Swift: coneFrom2PointsRadii forwards the radii swapped | red | green | PASS |
| **gce_MakeCylinder Tests** | cylinderFrom3Points | `OCCTSurfaceCylindricalFromPoints` | p1 and p3 swapped | red | green | PASS |
| **gce_MakeCylinder Tests** | parityWithCylindricalSurface | `OCCTSurfaceCylindricalFromPoints (both routes)` | Swift: cylinderFrom3Points forwards p1 and p3 swapped | red | green | PASS |
| **gce_MakeDir Tests** | directionFrom2Points | `OCCTGceMakeDir` | points passed in reverse order | red | green | PASS |
| **gce_MakeElips Tests** | ellipseFromCenterNormal | `OCCTGceMakeElips` | radii swapped: gce refuses, bridge returns nil | red | green | PASS |
| **gce_MakeHypr Tests** | hyperbolaFromCenterNormal | `OCCTGceMakeHypr` | radii swapped | red | green | PASS |
| **gce_MakeLin Tests** | lineFrom2Points | `OCCTGceMakeLinFrom2Points` | points passed in reverse order | red | green | PASS |
| **gce_MakeParab Tests** | parabolaFromCenterNormal | `OCCTGceMakeParab` | focal doubled | red | green | PASS |
| **gce_MakePln Tests** | planeFromEquation | `OCCTGceMakePlnFromEquation` | d negated | red | green | PASS |
| **gce_MakePln Tests** | planeFrom3Points | `OCCTSurfacePlaneFromPoints` | p2 and p3 swapped | red | green | PASS |
### 766-math-gc-circle-cone-cylinder (#1983, measured)
| **GC_MakeCircle Tests** | circleFromAxisAndRadius | `OCCTGCMakeCircle` | radius doubled | red | green | PASS |
| **GC_MakeCircle Tests** | circleFrom3Points | `OCCTGCMakeCircle3Points` | p2 built as (x, z, y): a circle in the XZ plane | red | green | PASS |
| **GC_MakeCircle Tests** | circleCenterNormal | `OCCTGCMakeCircleCenterNormal` | centre z dropped | red | green | PASS |
| **GC_MakeCircle Tests** | circleParallel | `OCCTGCMakeCircleParallel` | distance negated | red | green | PASS |
| **GC_MakeConicalSurface Tests** | conicalFromAxisAngleRadius | `OCCTGCMakeConicalSurface` | semi-angle doubled | red | green | PASS |
| **GC_MakeConicalSurface Tests** | conicalFrom2PtsRadii | `OCCTGCMakeConicalSurface2Pts` | r1 and r2 swapped | red | green | PASS |
| **GC_MakeConicalSurface Tests** | conicalFrom4Pts | `OCCTGCMakeConicalSurface4Pts` | p3 and p4 swapped | red | green | PASS |
| **GC_MakeCylindricalSurface Tests** | cylindricalFromAxisRadius | `OCCTGCMakeCylindricalSurface` | radius doubled | red | green | PASS |
| **GC_MakeCylindricalSurface Tests** | cylindricalFrom3Pts | `OCCTGCMakeCylindricalSurface3Pts` | p1 and p3 swapped | red | green | PASS |
| **GC_MakeCylindricalSurface Tests** | cylindricalFromCircle | `OCCTGCMakeCylindricalSurfaceFromCircle` | circle radius doubled | red | green | PASS |
| **GC_MakeCylindricalSurface Tests** | cylindricalParallel | `OCCTGCMakeCylindricalSurfaceParallel` | distance negated | red | green | PASS |
| **GC_MakeCylindricalSurface Tests** | cylindricalFromAxis | `OCCTGCMakeCylindricalSurfaceAxis` | radius doubled | red | green | PASS |
### 766-math-geometry-construction (#1983, measured)
| **Geometry Construction Tests** | Create face from rectangular wire | `OCCTShapeCreateFaceFromWire` | OCCTShapeCreateFaceFromWire returns nullptr after MakeFace | red | green | PASS |
| **Geometry Construction Tests** | Create face from circular wire | `OCCTShapeCreateFaceFromWire` | OCCTShapeCreateFaceFromWire returns nullptr after MakeFace | red | green | PASS |
| **Geometry Construction Tests** | Create face with hole | `OCCTShapeCreateFaceWithHoles` | hole wires never added to BRepBuilderAPI_MakeFace (area becomes 400) | red | green | PASS |
| **Geometry Construction Tests** | Create face with multiple holes | `OCCTShapeCreateFaceWithHoles` | hole wires never added (area becomes 900) | red | green | PASS |
| **Geometry Construction Tests** | Extrude face to create solid | `OCCTShapeCreateExtrusion` | prism vector doubled (volume 300) | red | green | PASS |
### 766-math-geom-vector3d (#1983, measured)
| **GeomVector3D Tests** | magnitude | `OCCTGeomVector3DMagnitude` | SquareMagnitude instead of Magnitude | red | green | PASS |
| **GeomVector3D Tests** | from two points | `OCCTGeomVector3DFromPoints` | first point ignored (vector from the origin to p2) | red | green | PASS |
| **GeomVector3D Tests** | dot product | `OCCTGeomVector3DDot` | dot with itself instead of other (14) | red | green | PASS |
| **GeomVector3D Tests** | added | `OCCTGeomVector3DAdded` | Subtracted instead of Added | red | green | PASS |
| **GeomVector3D Tests** | multiplied | `OCCTGeomVector3DMultiplied` | multiplied by 1/scalar | red | green | PASS |
| **GeomVector3D Tests** | normalized | `OCCTGeomVector3DNormalized` | return an unnormalized copy | red | green | PASS |
| **GeomVector3D Tests** | crossed | `OCCTGeomVector3DCrossed` | operands swapped (other x self) | red | green | PASS |
### 766-math-gp-dir-vec-extras (#1983, measured)
| **gp_Dir Extras v0.120.0** | isOpposite | `OCCTDirIsOpposite` | IsOpposite result negated | red | green | PASS |
| **gp_Dir Extras v0.120.0** | isNotOpposite | `OCCTDirIsOpposite` | IsOpposite result negated | red | green | PASS |
| **gp_Dir Extras v0.120.0** | isNormal | `OCCTDirIsNormal` | IsParallel instead of IsNormal | red | green | PASS |
| **gp_Dir Extras v0.120.0** | isNotNormal | `OCCTDirIsNormal` | IsParallel instead of IsNormal | red | green | PASS |
| **gp_Dir Extras v0.120.0** | isNormalDiagonal | `OCCTDirIsNormal` | IsParallel instead of IsNormal | red | green | PASS |
| **gp_Vec Extras v0.120.0** | crossMagnitude | `OCCTVecCrossMagnitude` | Dot instead of CrossMagnitude | red | green | PASS |
| **gp_Vec Extras v0.120.0** | crossMagnitudeParallel | `OCCTVecCrossMagnitude` | Dot instead of CrossMagnitude (2) | red | green | PASS |
| **gp_Vec Extras v0.120.0** | crossSquareMagnitude | `OCCTVecCrossSquareMagnitude` | Dot instead of CrossSquareMagnitude | red | green | PASS |
| **gp_Vec Extras v0.120.0** | crossMagnitudeScaled | `OCCTVecCrossMagnitude` | Dot instead of CrossMagnitude | red | green | PASS |
### 766-math-intrv (#1983, measured)
| **Intrv_Intervals Tests** | create from single interval | `OCCTIntrvIntervalsCreate / OCCTIntrvIntervalsValue` | Value() reads start and end into each other's slots | red | green | PASS |
| **Intrv_Intervals Tests** | create empty | `OCCTIntrvIntervalsCreateEmpty` | empty set seeded with [0, 0] | red | green | PASS |
| **Intrv_Intervals Tests** | unite non-overlapping | `OCCTIntrvIntervalsUnite` | united interval's end replaced by its start ([5,5] instead of [5,8]) | red | green | PASS |
| **Intrv_Intervals Tests** | unite overlapping merges | `OCCTIntrvIntervalsUnite` | united interval's end replaced by its start | red | green | PASS |
| **Intrv_Intervals Tests** | subtract middle | `OCCTIntrvIntervalsSubtract` | subtracted interval end + 1 | red | green | PASS |
| **Intrv_Intervals Tests** | intersect | `OCCTIntrvIntervalsIntersect` | Intersect skipped | red | green | PASS |
| **Intrv_Intervals Tests** | xUnite symmetric difference | `OCCTIntrvIntervalsXUnite` | xUnite interval end - 1 | red | green | PASS |
| **Intrv_Interval Tests** | create and get bounds | `OCCTIntrvIntervalBounds` | Bounds() reads start and end into each other's slots | red | green | PASS |
| **Intrv_Interval Tests** | create with tolerances | `OCCTIntrvIntervalCreate` | tolStart and tolEnd exchanged at construction | red | green | PASS |
| **Intrv_Interval Tests** | probably empty | `OCCTIntrvIntervalIsProbablyEmpty` | IsProbablyEmpty negated | red | green | PASS |
| **Intrv_Interval Tests** | before and after | `OCCTIntrvIntervalIsBefore / OCCTIntrvIntervalIsAfter` | IsBefore and IsAfter exchanged | red | green | PASS |
| **Intrv_Interval Tests** | inside and enclosing | `OCCTIntrvIntervalIsInside / OCCTIntrvIntervalIsEnclosing` | IsInside and IsEnclosing exchanged | red | green | PASS |
| **Intrv_Interval Tests** | similar | `OCCTIntrvIntervalIsSimilar` | IsSimilar negated | red | green | PASS |
| **Intrv_Interval Tests** | position | `OCCTIntrvIntervalPosition` | receiver and argument exchanged (b.Position(a) = 12, Intrv_After) | red | green | PASS |
| **Intrv_Interval Tests** | set and modify bounds | `OCCTIntrvIntervalSetEnd` | SetEnd calls SetStart | red | green | PASS |
| **Intrv_Interval Tests** | fuse and cut | `OCCTIntrvIntervalFuseAtStart (and FuseAtEnd/CutAtStart/CutAtEnd)` | FuseAtStart calls CutAtStart (start stays 3) | red | green | PASS |
### 766-math-issue1443-ax3-empty-catch (#1983, measured)
| **Issue #1443: gp_Ax3 bridge functions' empty catch** | OCCTAx3Create: parallel direction/xDirection overwrites sentinel outputs, not left untouched | `OCCTAx3Create` | catch returns right after recording the exception: the pre-#1443 empty catch | red | green | PASS |
| **Issue #1443: gp_Ax3 bridge functions' empty catch** | OCCTAx3CreateFromNormal: zero-length normal overwrites sentinel outputs, not left untouched | `OCCTAx3CreateFromNormal` | pre-#1443 empty catch | red | green | PASS |
| **Issue #1443: gp_Ax3 bridge functions' empty catch** | OCCTAx3MirrorPoint: degenerate input axis overwrites sentinel outputs with the input point unmoved | `OCCTAx3MirrorPoint` | pre-#1443 empty catch | red | green | PASS |
| **Issue #1443: gp_Ax3 bridge functions' empty catch** | OCCTAx3Rotate: zero-length rotation axis overwrites sentinel outputs with the input point unmoved | `OCCTAx3Rotate` | pre-#1443 empty catch | red | green | PASS |
| **Issue #1443: gp_Ax3 bridge functions' empty catch** | OCCTAx3Translate: degenerate input axis overwrites sentinel outputs with the input point unmoved | `OCCTAx3Translate` | pre-#1443 empty catch | red | green | PASS |
### 766-math-line-logsample-crout (#1983, measured)
| **LineGeometry_Operations** | distanceToPointOnLine | `OCCTLineDistanceToPoint` | gp_Lin::Distance(point) + 0.5 | red | green | PASS |
| **LineGeometry_Operations** | distanceToPointOffLine | `OCCTLineDistanceToPoint` | gp_Lin::Distance(point) + 0.5 | red | green | PASS |
| **LineGeometry_Operations** | distanceBetweenParallelLines | `OCCTLineDistanceToLine` | gp_Lin::Distance(line) + 0.5 | red | green | PASS |
| **LineGeometry_Operations** | distanceBetweenIntersectingLines | `OCCTLineDistanceToLine` | gp_Lin::Distance(line) + 0.5 | red | green | PASS |
| **LineGeometry_Operations** | containsPointTrue | `OCCTLineContainsPoint` | negate gp_Lin::Contains | red | green | PASS |
| **LineGeometry_Operations** | containsPointFalse | `OCCTLineContainsPoint` | negate gp_Lin::Contains | red | green | PASS |
| **GeomLib_LogSample Tests** | logarithmicSampling | `OCCTLogSample` | linear spacing a + (b - a) * i / n instead of GetParameter(i) | red | green | PASS |
| **GeomLib_LogSample Tests** | singleSample | `OCCTLogSample` | linear spacing a + (b - a) * i / n (gives 10 for n = 1) | red | green | PASS |
| **MathCrout Tests** | symmetricSolve | `OCCTMathCroutSolve` | swap X(1) and X(n) after math_Crout::Solve | red | green | PASS |
| **MathCrout Tests** | determinant | `OCCTMathCroutDeterminant` | negate math_Crout::Determinant | red | green | PASS |
### 766-math-matrix-polyroots (#1983, measured)
| **MathMatrix Tests** | createAndQuery | `OCCTMathMatrixRows` | RowNumber() + 1 | red | green | PASS |
| **MathMatrix Tests** | setGetValue | `OCCTMathMatrixGetValue` | read row (row % RowNumber) + 1 (off-by-one row) | red | green | PASS |
| **MathMatrix Tests** | determinant | `OCCTMathMatrixDeterminant` | negate math_Matrix::Determinant | red | green | PASS |
| **MathMatrix Tests** | invert | `OCCTMathMatrixInvert` | skip math_Matrix::Invert, still return true | red | green | PASS |
| **MathPolynomialRoots Tests** | quadratic | `OCCTMathPolynomialRoots` | math_DirectPolynomialRoots::Value(i) + 0.5 | red | green | PASS |
| **MathPolynomialRoots Tests** | linear | `OCCTMathPolynomialRoots` | math_DirectPolynomialRoots::Value(i) + 0.5 | red | green | PASS |
| **MathPolynomialRoots Tests** | noRealRoots | `OCCTMathPolynomialRoots` | take the IsDone-false path (return -1) for every polynomial | red | green | PASS |
### 766-math-polyrc4-bfgs-brent (#1983, measured)
| **MathPolyRc4** | linear | `OCCTMathPolyLinear` | constant coefficient passed to MathPoly::* off by +0.01 (small enough to keep the root count, so no index trap) | red | green | PASS |
| **MathPolyRc4** | linearDegenerate | `OCCTMathPolyLinear` | drop the IsDone() check (InfiniteSolutions returns 0 roots as success) | red | green | PASS |
| **MathPolyRc4** | quadratic | `OCCTMathPolyQuadratic` | constant coefficient passed to MathPoly::* off by +0.01 (small enough to keep the root count, so no index trap) | red | green | PASS |
| **MathPolyRc4** | quadraticNoRealRoots | `OCCTMathPolyQuadratic` | report failure (-1) for every quadratic | red | green | PASS |
| **MathPolyRc4** | cubic | `OCCTMathPolyCubic` | constant coefficient passed to MathPoly::* off by +0.01 (small enough to keep the root count, so no index trap) | red | green | PASS |
| **MathPolyRc4** | quartic | `OCCTMathPolyQuartic` | constant coefficient passed to MathPoly::* off by +0.01 (small enough to keep the root count, so no index trap) | red | green | PASS |
| **MathSolver BFGS v0.110** | minimizeQuadratic | `OCCTMathBFGS` | location + 0.05 in every coordinate | red | green | PASS |
| **MathSolver BFGS v0.110** | minimizeRosenbrock | `OCCTMathBFGS` | location + 0.05 in every coordinate | red | green | PASS |
| **MathSolver BrentMinimum v0.110** | minimizeQuadratic | `OCCTMathBrentMinimum` | Location() + 0.05 | red | green | PASS |
| **MathSolver BrentMinimum v0.110** | minimizeSine | `OCCTMathBrentMinimum` | Location() + 0.05 | red | green | PASS |
### 766-math-functionroots-gaussintegrate (#1983, measured)
| **MathSolver FunctionRoots v0.111** | findAllRootsQuadratic | `OCCTMathFunctionRoots` | root values + 0.05 in OCCTMathFunctionRoots (this call resolves to the `findAllRoots(in:samples:function:)` overload that reaches it) | red | green | PASS |
| **MathSolver FunctionRoots v0.111** | findAllRootsSin | `OCCTMathFunctionRoots` | root values + 0.05 in OCCTMathFunctionRoots (this call resolves to the `findAllRoots(in:samples:function:)` overload that reaches it) | red | green | PASS |
| **MathSolver FunctionRoot v0.110** | findRoot(near:) finds both roots of x^2 - 4 | `OCCTMathFunctionRoot` | Root() + 0.5 | red | green | PASS |
| **MathSolver FunctionRoot v0.110** | findRootBounded | `OCCTMathFunctionRootBounded` | Root() + 0.5 | red | green | PASS |
| **MathSolver FunctionRoot v0.110** | findRootBisection | `OCCTMathBissecNewton` | Root() + 0.5 | red | green | PASS |
| **MathSolver FunctionRoot v0.110** | findRootCubic | `OCCTMathFunctionRoot` | Root() + 0.5 | red | green | PASS |
| **MathSolver GaussIntegrate v0.111** | integrateSin | `OCCTMathGaussIntegrate` | math_GaussSingleIntegration::Value() * 1.001 | red | green | PASS |
| **MathSolver GaussIntegrate v0.111** | integratePolynomial | `OCCTMathGaussIntegrate` | math_GaussSingleIntegration::Value() * 1.001 | red | green | PASS |
| **MathSolver GaussIntegrate v0.111** | integrateConstant | `OCCTMathGaussIntegrate` | math_GaussSingleIntegration::Value() * 1.001 | red | green | PASS |
### 766-math-globopt-powell-pso-systems-svd (#1983, measured)
| **MathSolver GlobOptMin v0.111** | globalMinBowl | `OCCTMathGlobOptMin` | point + 0.3 in every coordinate, minimum + 0.3 | red | green | PASS |
| **MathSolver GlobOptMin v0.111** | globalMin1D | `OCCTMathGlobOptMin` | point + 0.3, minimum + 0.3 | red | green | PASS |
| **MathSolver NewtonSystem v0.111** | solveCircleLine | `OCCTMathNewtonFuncSetRoot` | return the start point instead of Root() | red | green | PASS |
| **MathSolver Powell v0.110** | minimizeBowl | `OCCTMathPowell` | location + 0.5 in every coordinate | red | green | PASS |
| **MathSolver PSO v0.111** | minimizeBowl | `OCCTMathPSO` | point + 0.5 in every coordinate, minimum + 0.5 | red | green | PASS |
| **MathSolver PSO v0.111** | minimizeRosenbrock | `OCCTMathPSO` | point + 0.5 in every coordinate, minimum + 0.5 | red | green | PASS |
| **MathSolver SystemOfEquations v0.110** | solveCircleLine | `OCCTMathFunctionSetRoot` | return the start point instead of Root() | red | green | PASS |
| **MathSolver SystemOfEquations v0.110** | solveLinearSystem | `OCCTMathFunctionSetRoot` | return the start point instead of Root() | red | green | PASS |
| **MathSVD Tests** | leastSquares | `OCCTMathSVDSolve` | swap X(1) and X(cols) after math_SVD::Solve | red | green | PASS |
### 766-math-period (#1983, measured)
| **Period Tests** | createFromComponents | `OCCTPeriodValues` | swap hours and minutes after Quantity_Period::Values | red | green | PASS |
| **Period Tests** | createFromSeconds | `OCCTPeriodTotalSeconds` | swap seconds and microseconds out of Values(sec, usec) | red | green | PASS |
| **Period Tests** | addPeriods | `OCCTPeriodAdd` | p1 - p2 instead of p1 + p2 | red | green | PASS |
| **Period Tests** | subtractPeriods | `OCCTPeriodSubtract` | p1 + p2 instead of p1 - p2 | red | green | PASS |
| **Period Tests** | equality | `OCCTPeriodCompare` | never report equal | red | green | PASS |
| **Period Tests** | comparison | `OCCTPeriodCompare` | invert the < branch | red | green | PASS |
| **Period Tests** | isValidComponents | `OCCTPeriodIsValid` | negate Quantity_Period::IsValid | red | green | PASS |
| **Period Tests** | isValidSeconds | `OCCTPeriodIsValidSeconds` | negate Quantity_Period::IsValid(ss, mics) | red | green | PASS |
| **Period Tests** | withMilliseconds | `OCCTPeriodValues` | swap milliseconds and microseconds after Values | red | green | PASS |
| **Period Tests** | zeroPeriod | `OCCTPeriodCreateFromSeconds` | reject ss == 0 as invalid | red | green | PASS |
### 766-math-plane-construction-parity (#1983, measured)
| **GC_MakePlane** | Plane from 3 points | `OCCTSurfacePlaneFromPoints` | pass p2, p1, p3 to GC_MakePlane (origin moves to p2, normal flips) | red | green | PASS |
| **GC_MakePlane** | Plane from point and normal | `OCCTSurfacePlaneFromPointNormal` | negate the normal passed to GC_MakePlane | red | green | PASS |
| **Surface plane factory parity (#421)** | Well-separated points: both entry points agree | `OCCTSurfacePlaneFromPoints` | pass p2, p1, p3 to GC_MakePlane | red | green | PASS |
| **Surface plane factory parity (#421)** | Collinear-but-distinct points: both entry points return nil | `OCCTSurfacePlaneFromPoints` | on !IsDone() return a default +Z plane through p1 instead of nil | red | green | PASS |
| **Surface plane factory parity (#421)** | Collinear, unevenly spaced points: both entry points return nil | `OCCTSurfacePlaneFromPoints` | on !IsDone() return a default +Z plane through p1 instead of nil | red | green | PASS |
| **Surface plane factory parity (#421)** | Two coincident points: both entry points return nil | `OCCTSurfacePlaneFromPoints` | on !IsDone() return a default +Z plane through p1 instead of nil | red | green | PASS |
| **Surface plane factory parity (#421)** | All three points coincident: both entry points return nil | `OCCTSurfacePlaneFromPoints` | on !IsDone() return a default +Z plane through p1 instead of nil | red | green | PASS |
| **Surface plane factory parity (#421)** | Valid normal: both entry points agree | `OCCTSurfacePlaneFromPointNormal` | negate the normal passed to GC_MakePlane | red | green | PASS |
| **Surface plane factory parity (#421)** | Zero-length normal: both entry points return nil | `OCCTSurfacePlaneFromPointNormal` | substitute a default +Z plane for a zero-length normal instead of letting gp_Dir refuse it | red | green | PASS |
| **Surface plane factory parity (#421)** | Near-zero-length normal: both entry points return nil | `OCCTSurfacePlaneFromPointNormal` | substitute a default +Z plane for a zero-length normal instead of letting gp_Dir refuse it | red | green | PASS |
### 766-math-plane-geometry (#1983, measured)
| **PlaneGeometry_Operations** | distanceToPointOnPlane | `OCCTPlaneDistanceToPoint` | gp_Pln::Distance(point) + 0.5 | red | green | PASS |
| **PlaneGeometry_Operations** | distanceToPointAbovePlane | `OCCTPlaneDistanceToPoint` | gp_Pln::Distance(point) + 0.5 | red | green | PASS |
| **PlaneGeometry_Operations** | distanceToParallelLine | `OCCTPlaneDistanceToLine` | gp_Pln::Distance(line) + 0.5 | red | green | PASS |
| **PlaneGeometry_Operations** | distanceToIntersectingLine | `OCCTPlaneDistanceToLine` | gp_Pln::Distance(line) + 0.5 | red | green | PASS |
| **PlaneGeometry_Operations** | containsPointTrue | `OCCTPlaneContainsPoint` | negate gp_Pln::Contains | red | green | PASS |
| **PlaneGeometry_Operations** | containsPointFalse | `OCCTPlaneContainsPoint` | negate gp_Pln::Contains | red | green | PASS |
### 766-math-polynomial-precision (#1983, measured)
| **Polynomial Solvers** | Solve quadratic x²-5x+6=0 | `OCCTSolveQuadratic` | each root + 0.5 in occtSolvePolynomial | red | green | PASS |
| **Polynomial Solvers** | Quadratic with no real roots | `OCCTSolveQuadratic` | NbSolutions() + 1 reported as the count | red | green | PASS |
| **Polynomial Solvers** | Quadratic with one root | `OCCTSolveQuadratic` | each root + 0.5 | red | green | PASS |
| **Polynomial Solvers** | Solve cubic x³-6x²+11x-6=0 | `OCCTSolveCubic` | each root + 0.5 | red | green | PASS |
| **Polynomial Solvers** | Solve quartic x⁴-10x²+9=0 | `OCCTSolveQuartic` | each root + 0.5 | red | green | PASS |
| **Precision Tests** | confusion | `OCCTPrecisionConfusion` | Confusion() * 10 | red | green | PASS |
| **Precision Tests** | angular | `OCCTPrecisionAngular` | returns Confusion() instead of Angular() | red | green | PASS |
| **Precision Tests** | isInfinite | `OCCTPrecisionIsInfinite` | predicate negated | red | green | PASS |
| **Precision Tests** | ordering | `OCCTPrecisionIntersection` | Intersection() returns Approximation() | red | green | PASS |
| **Precision Tests** | infinite | `OCCTPrecisionInfinite` | returns 1e10 instead of Infinite() | red | green | PASS |
| **Precision Tests** | pConfusion | `OCCTPrecisionPConfusion` | returns Confusion() (drops the /100) | red | green | PASS |
### 766-math-quaternion (#1983, measured)
| **Quaternion Interpolation** | slerpMidpoint | `OCCTQuaternionSLerp` | returns the start quaternion, ignoring t | red | green | PASS |
| **Quaternion Interpolation** | nlerpEndpoints | `OCCTQuaternionNLerp` | parameter reversed (1 - t), so t = 0 gives the end quaternion | red | green | PASS |
| **Quaternion Interpolation** | transformInterpolate | `OCCTTrsfInterpolate` | end transform built with the start translation x (tx1 for tx2) | red | green | PASS |
| **Quaternion Tests** | identity | `OCCTQuaternionCreate` | components passed in (w, x, y, z) order | red | green | PASS |
| **Quaternion Tests** | fromAxisAngle | `OCCTQuaternionCreateFromAxisAngle` | angle halved | red | green | PASS |
| **Quaternion Tests** | fromVectors | `OCCTQuaternionCreateFromVectors` | from and to swapped | red | green | PASS |
| **Quaternion Tests** | eulerAngles | `OCCTQuaternionGetEulerAngles` | alpha and gamma outputs swapped | red | green | PASS |
| **Quaternion Tests** | matrix | `OCCTQuaternionGetMatrix` | (1,2) and (2,1) entries swapped (transpose of the rotation part) | red | green | PASS |
| **Quaternion Tests** | multiply | `OCCTQuaternionMultiply` | returns q1, dropping q2 | red | green | PASS |
| **Quaternion Tests** | axisAngle | `OCCTQuaternionGetVectorAndAngle` | angle output halved | red | green | PASS |
| **Quaternion Tests** | rotationAngle | `OCCTQuaternionGetRotationAngle` | angle halved | red | green | PASS |
| **Quaternion Tests** | normalize | `OCCTQuaternionNormalize` | Normalize() skipped | red | green | PASS |
### 766-math-gauss-householder-integ-jacobi (#1983, measured)
| **MathGauss Tests** | solve2x2 | `OCCTMathGaussSolve` | swap X(1) and X(n) after math_Gauss::Solve | red | green | PASS |
| **MathGauss Tests** | determinant | `OCCTMathGaussDeterminant` | negate math_Gauss::Determinant | red | green | PASS |
| **MathHouseholder Tests** | overdetermindedSolve | `OCCTMathHouseholderSolve` | swap sol(1) and sol(cols) after math_Householder::Value | red | green | PASS |
| **MathIntegRc4** | gauss | `OCCTMathIntegGauss` | upper bound * 0.99 (integral drops by about 4.9e-4) | red | green | PASS |
| **MathIntegRc4** | gaussAdaptive | `OCCTMathIntegGaussAdaptive` | upper bound * 0.99 (integral drops by about 4.9e-4) | red | green | PASS |
| **MathIntegRc4** | kronrod | `OCCTMathIntegKronrod` | upper bound * 0.99 (integral drops by about 4.9e-4) | red | green | PASS |
| **MathIntegRc4** | kronrodAdaptive | `OCCTMathIntegKronrodAdaptive` | upper bound * 0.99 (integral drops by about 4.9e-4) | red | green | PASS |
| **MathIntegRc4** | tanhSinh | `OCCTMathIntegTanhSinh` | upper bound * 0.99 (integral drops by about 4.9e-4) | red | green | PASS |
| **MathJacobi Tests** | eigenvalues | `OCCTMathJacobiEigenvalues` | math_Jacobi::Value(i) + 0.5 | red | green | PASS |
### 766-math-shape-transforms (#1983, measured)
| **GC_MakeMirror** | Mirror box about point | `OCCTShapeMirrorAboutPoint` | mirror centre replaced by the origin | red | green | PASS |
| **GC_MakeMirror** | Mirror box about axis | `OCCTShapeMirrorAboutAxis` | axis direction components reversed, (dz, dy, dx): mirrors about X instead of Z | red | green | PASS |
| **GC_MakeScale** | Scale box about origin | `OCCTShapeScaleAboutPoint` | factor inverted (1 / factor) | red | green | PASS |
| **GC_MakeScale** | Scale with factor 0.5 | `OCCTShapeScaleAboutPoint` | factor inverted (1 / factor) | red | green | PASS |
| **GC_MakeTranslation** | Translate box from point to point | `OCCTShapeTranslateByPoints` | from and to points swapped | red | green | PASS |
### 766-math-surface-transform (#1983, measured)
| **Surface Transform** | Translate surface | `OCCTSurfaceTransform` | translation dz dropped (dx, dy, 0) | red | green | PASS |
| **Surface Transform** | Rotate surface | `OCCTSurfaceTransform` | rotation angle negated | red | green | PASS |
| **Surface Transform** | Scale surface | `OCCTSurfaceTransform` | scale factor inverted (1 / factor) | red | green | PASS |
| **Surface Transform** | Mirror surface through point | `OCCTSurfaceTransform` | point mirror built as a plane mirror (normal Z) through the point | red | green | PASS |
| **Surface Transform** | Mirror surface through axis | `OCCTSurfaceTransform` | axis mirror built as a plane mirror (gp_Ax2 for gp_Ax1) | red | green | PASS |
| **Surface Transform** | Mirror surface through plane | `OCCTSurfaceTransform` | plane mirror built as an axis mirror (gp_Ax1 for gp_Ax2) | red | green | PASS |
| **Surface Transform** | Transform BezierSurface values | `OCCTSurfaceTransform (surface from OCCTSurfaceBezierFill2)` | translation dz dropped | red | green | PASS |
| **TransformedCurve, Curve with Translation** | translateCircle | `OCCTGeomAdaptorTransformedCurveCreate` | tx and ty swapped | red | green | PASS |
### 766-math-transform-factory-trig (#1983, measured)
| **gce Transform Factory 3D Tests** | pointMirror | `OCCTMakeMirrorPoint` | point mirror built as an axis mirror (Z) through the point | red | green | PASS |
| **gce Transform Factory 3D Tests** | planeMirror | `OCCTMakeMirrorPlane` | plane mirror built as an axis mirror about the normal | red | green | PASS |
| **gce Transform Factory 3D Tests** | rotation90 | `OCCTMakeRotation` | angle negated | red | green | PASS |
| **gce Transform Factory 3D Tests** | scaleBy2 | `OCCTMakeScaleTransform` | factor inverted | red | green | PASS |
| **gce Transform Factory 3D Tests** | translationVector | `OCCTMakeTranslationVec` | vector x and y swapped | red | green | PASS |
| **gce Transform Factory 3D Tests** | translationPoints | `OCCTMakeTranslationPoints` | from and to swapped | red | green | PASS |
| **gce Transform Factory 3D Tests** | axisMirror | `OCCTMakeMirrorAxis` | axis mirror built as a plane mirror with the axis as normal | red | green | PASS |
| **math_TrigonometricFunctionRoots** | sinZero | `OCCTTrigRoots` | last root dropped (NbSolutions() - 1) | red | green | PASS |
| **math_TrigonometricFunctionRoots** | cosHalf | `OCCTTrigRoots` | last root dropped | red | green | PASS |
| **math_TrigonometricFunctionRoots** | infiniteRoots | `OCCTTrigRootsInfinite` | InfiniteRoots() negated | red | green | PASS |
### 766-math-trimmed-trsf-extras (#1983, measured)
| **GC_MakeTrimmedCone** | Trimmed cone from endpoints and radii | `OCCTSurfaceTrimmedCone` | r1 and r2 swapped | red | green | PASS |
| **GC_MakeTrimmedCylinder** | Trimmed cylinder from axis, radius, height | `OCCTSurfaceTrimmedCylinder` | radius and height swapped | red | green | PASS |
| **gp_Trsf_Extras** | transformFromMatrix | `OCCTShapeTransformFromMatrix` | translation column (a14, a24, a34) dropped | red | green | PASS |
| **gp_Trsf_Extras** | transformIsNegative | `OCCTShapeTransformIsNegative` | identity-location branch reports true | red | green | PASS |
| **gp_Trsf_Extras** | mirrorTransformProducesResult | `OCCTShapeTransformFromMatrix` | a11 read from a22 (identity instead of the X mirror) | red | green | PASS |
| **gp_Trsf_Extras** | displacement | `OCCTTrsfDisplacement` | from and to frames swapped | red | green | PASS |
| **gp_Trsf_Extras** | transformation | `OCCTTrsfTransformation` | SetDisplacement used instead of SetTransformation | red | green | PASS |
| **gp_Trsf_Extras** | invalidMatrixSize | `none (pure Swift: the deprecated transformed(byMatrix: [Double]) overload in Shape+Math.swift refuses before any bridge call)` | Swift injection: a short array padded with the identity instead of refused | red | green | N/A |
| **gp_Trsf_Extras** | transformFromMatrixInterleavedLayoutTranslatesAsDocumented | `OCCTShapeTransformFromMatrix` | translation column dropped | red | green | PASS |
### 766-math-trsfmod-uzawa-vector2d (#1983, measured)
| **BRepTools_TrsfModification** | apply translation via modifier | `OCCTShapeTrsfModification` | translation column (a14, a24, a34) dropped | red | green | PASS |
| **BRepTools_TrsfModification** | apply rotation via modifier | `OCCTShapeTrsfModification` | a12 and a21 swapped (rotation by -90 deg) | red | green | PASS |
| **Uzawa** | constrainedOptimization | `OCCTMathUzawa` | constraint right-hand side negated | red | green | PASS |
| **Vector2DMath** | modulus | `OCCTXYModulus` | SquareModulus() returned | red | green | PASS |
| **Vector2DMath** | cross | `OCCTXYCrossed` | operands reversed | red | green | PASS |
| **Vector2DMath** | dot | `OCCTXYDot` | y term dropped | red | green | PASS |
| **Vector2DMath** | normalize | `OCCTXYNormalize` | normalized x and y swapped | red | green | PASS |
### 766-math-vector3d (#1983, measured)
| **Vector3DMath** | modulus | `OCCTXYZModulus` | SquareModulus() returned | red | green | PASS |
| **Vector3DMath** | cross | `OCCTXYZCrossed` | operands reversed | red | green | PASS |
| **Vector3DMath** | dot | `OCCTXYZDot` | z term dropped | red | green | PASS |
| **Vector3DMath** | dotCross | `OCCTXYZDotCross` | b and c swapped in the triple product | red | green | PASS |
| **Vector3DMath** | normalize | `OCCTXYZNormalize` | normalized x and y swapped | red | green | PASS |
### 766-math-newton-nonuniformscale (#1983, measured)
| **math_NewtonMinimum Tests** | minimizeQuadratic | `OCCTMathNewtonMinimum` | location + 0.05 in every coordinate | red | green | PASS |
| **math_NewtonMinimum Tests** | minimizeRosenbrock | `OCCTMathNewtonMinimum` | location + 0.05 in every coordinate | red | green | PASS |
| **NewtonRoot** | findRoot | `OCCTMathNewtonFunctionRoot` | Root() + 0.5 | red | green | PASS |
| **Non-Uniform Scale** | Scale box non-uniformly | `OCCTShapeNonUniformScale` | drop sz (scale z by 1) | red | green | PASS |
| **Non-Uniform Scale** | Non-uniform scale preserves volume ratio | `OCCTShapeNonUniformScale` | drop sz (scale z by 1) | red | green | PASS |
