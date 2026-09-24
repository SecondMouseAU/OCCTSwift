# Phase 3: OCCTGeom2dTests Injection Matrix

**Target**: `OCCTGeom2dTests` (545 tests) — 2D geometry, curves, adaptors
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (crash fixes #345, #603, #636, #477 in 2D)

---

## Test Inventory by Suite (Top by Count)

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| BSpline Curve 2D Manipulation Tests | 22 | WR |
| Curve2D Primitive Tests | 18 | WR |
| Curve2D Operations Tests | 17 | WR |
| BSplineCurve 2D Completions v121 | 15 | WR |
| **Arc length stops being one quadrature per span (#603, 2D)** | **14** | **CR/WR (#603)** |
| Curve2D Conic Factory Families | 13 | WR |
| Analytical conversion contract (#492) | 12 | WR |
| Bezier Curve 2D Manipulation Tests | 11 | WR |
| Curve2D Plane Projection Tests | 10 | WR |
| The nearest point is on the curve, not on its basis (#539) | 10 | WR |
| Curve2D Conic Family Tests | 10 | WR |
| Curve2D Continuity Queries v0.120.0 | 9 | WR |
| Curve2D arc-length accuracy on multi-span curves (#477) | 9 | CR/WR (#477) |
| Issue #211/#212, EdgeCurve arc-length adaptor | 9 | CR/WR |
| v0.114.0 - Curve2D DN | 8 | WR |
| Curve2D Extras v0.109 | 8 | WR |
| v0.115.0 - GCPnts Expansion (2D) | 7 | WR |
| GeomEval, Circular Helix Curve (2D) | 7 | WR |
| GeomEval, Elliptical Helix Curve | 7 | WR |
| Geom2dAdaptor Curve Tests | 7 | WR |
| Geom2dGccSolver Tests | 7 | WR |
| Geom2d_Hatching Tests | 7 | WR |
| Geom2d_Bisector Tests | 7 | WR |
| Geom2d_Conversion Tests | 7 | WR |
| ... | ... | ... |

**Total**: 545 tests across ~70 suites

---

## Injection Matrix: Critical Crash-Related Tests First

### #345: gp_Dir2d Zero Vector Crash (Bridge Fix)

**Issue**: `gp_Dir2d` constructor throws `Standard_ConstructionError` for zero-length direction vector.

**Bridge Fix**: Wrapped constructors in `try { } catch (...) { <safe fallback> }`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| mirrorAxisZeroDirection (2D) | `OCCTMakeMirror2dAxis` → `gp_Dir2d` | Zero direction vector | Remove `try/catch` |  |  | SIGABRT |
| geomDirection2dZeroVector | `OCCTGeomDirection2dCreate` → `Geom2d_Direction` | Zero vector handled | N/A | N/A |  | Graceful |

### #603: CPnts_AbscissaPoint 2D Single Quadrature (Bridge + Kernel Fix)

**Issue**: `CPnts_AbscissaPoint::Length` on 2D curves uses single quadrature → arc length errors.

**Bridge Fix**: Adaptive quadrature in `occtAdaptorArcLength` (2D version).

**Kernel Patch**: `0021` — applies to 2D as well.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| A whole ellipse measures its own circumference (2D) | `Curve2D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature |  |  | Error up to 1.7% |
| A parabola over a wide range measures its arc (2D) | `Curve2D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature |  |  | Error 3% |
| The closed forms stay exact (2D) | `Curve2D.arcLength` → closed-form | Control | No injection |  |  | Line/circle |
| Accurate sub-ranges sum to whole (2D) | `Curve2D.arcLength(from:to:)` | Single quadrature | Remove adaptive quadrature |  |  | Error accumulates |
| parameterAtLength walks correctly (2D) | `Curve2D.parameterAtLength` | Single quadrature | Remove adaptive quadrature |  |  | Inverse wrong |

### #636: Curve2D extrema on Parallel Curves (Bridge Fix)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Two unbounded parallel lines: extrema is empty (2D) | `Curve2D.extrema(to:)` → `Geom2dAPI_ExtremaCurveCurve` | Parallel crash | Remove `isParallel` guard |  |  | SIGSEGV |
| Two bounded parallel segments: extrema is empty (2D) | `Curve2D.extrema(to:)` → `Geom2dAPI_ExtremaCurveCurve` | Parallel crash | Remove `isParallel` guard |  |  | SIGSEGV |

### #477: Arc-Length Per-Span Split (2D) (Bridge Fix)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| length of a multi-span interpolated BSpline matches reference (2D) | `Curve2D.arcLength` → `occtAdaptorArcLength` | No per-span adaptive | Remove adaptive quadrature |  |  | Error > 1e-9 |
| length(from:to:) over a sub-range matches reference (2D) | `Curve2D.arcLength(from:to:)` | No per-span adaptive | Remove adaptive quadrature |  |  | Error > 1e-9 |

---

## Injection Matrix: Borrowed Handles (Curve2D *Properties)

**From #965**: 7 `*Properties` views in Curve2D.swift stored raw handles. Fixed by conforming to `NativeHandleView`.

| Test | Properties Type | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| every Curve2D *Properties accessor keeps its parent alive | Circle/Ellipse/Hyperbola/Parabola/Line/BSpline/Bezier | Raw handle storage | Revert to `fileprivate let handle` |  |  | SIGSEGV (use-after-free) |
| a view outliving its parent still reads the right values | Same | Raw handle storage | Revert to raw handle |  |  | SIGSEGV |
| a view outliving its parent survives 400 intervening allocations | Same | Raw handle storage | Revert to raw handle |  |  | SIGSEGV |

---

## Injection Matrix: Null-Handle Guards (Curve2D Entry Points)

From `check-null-handle-guards.py` ALLOWED table - 8 Curve2D entry points need `curve.IsNull()` guard.

| Bridge Function | OCCT Call | Test Coverage | Injection Status |
|-----------------|-----------|---------------|------------------|
| `OCCTGeomLibToolParameter2D` | `GeomLib_Tool::Parameter` | Geom2dTests | |
| `OCCTExtremaLocateExtCC2d` | `Geom2dAdaptor_Curve` | Geom2dTests | |
| `OCCTGeom2dConvertApproxArcsSegments` | `Geom2dAdaptor_Curve` | Geom2dTests | |
| `OCCTGeom2dConvertApproxArcsSegments` (local handle) | `BRep_Tool::CurveOnSurface` | StressTests | |

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| BSpline Curve 2D Manipulation Tests | 22 |  |  |  |  |
| Curve2D Primitive Tests | 18 |  |  |  |  |
| Curve2D Operations Tests | 17 |  |  |  |  |
| BSplineCurve 2D Completions v121 | 15 |  |  |  |  |
| **Arc length stops being one quadrature per span (#603, 2D)** | **14** |  |  |  |  |
| Curve2D Conic Factory Families | 13 |  |  |  |  |
| Analytical conversion contract (#492) | 12 |  |  |  |  |
| ... | ... |  |  |  |  |

**Total**: 545 tests

### #1979 executed: `Curve2DInteriorTangentTests.swift`, `Curve2DInterpolatePeriodicParityTests.swift`

Probe: `Scripts/repro/766-geom2d-interpolate-tangents-periodic/`. Every row was run red with the injection applied and green after it was reverted.

| Test | Bridge function | Injection | Red | Green | Parity | Notes |
|---|---|---|---|---|---|---|
| Curve2D Interior Tangent Interpolation Tests::Interpolate with no tangent constraints matches basic interpolate | `OCCTCurve2DInterpolateWithInteriorTangents` | drop the last point | ✅ | ✅ | MATCH | start points to 0.01 inside `if let`; now the domain and mid point to 1e-9 |
| Curve2D Interior Tangent Interpolation Tests::Tangent constraint at start and end | `OCCTCurve2DInterpolateWithInteriorTangents` | skip Load(tangents, flags) | ✅ | ✅ | MATCH | tangent `abs(y) < 0.1` inside two `if let`s; now exact and the pole count |
| Curve2D Interior Tangent Interpolation Tests::Tangent constraint at interior point | `OCCTCurve2DInterpolateWithInteriorTangents` | skip Load(tangents, flags) | ✅ | ✅ | MATCH | `poleCount != nil`; now the horizontal tangent at the constrained point |
| Curve2D Interior Tangent Interpolation Tests::Closed curve with interior tangent constraint | `OCCTCurve2DInterpolateWithInteriorTangents` | skip Load(tangents, flags) | ✅ | ✅ | MATCH | "may or may not succeed" inside `if let`; the kernel succeeds, now required |
| Curve2D Interior Tangent Interpolation Tests::Minimum 2-point interpolation with tangent constraints | `OCCTCurve2DInterpolateWithInteriorTangents` | skip Load(tangents, flags) | ✅ | ✅ | MATCH | `!= nil`; now pins poles and a point |
| Curve2D periodic interpolation delegates (#412)::Default tolerance: the two entry points produce the same curve | `OCCTCurve2DInterpolate` | ignore closed | ✅ | ✅ | MATCH | agreement only; now pins the domain and point(20) |
| Curve2D periodic interpolation delegates (#412)::A non-default tolerance is now reachable through interpolatePeriodic | `OCCTCurve2DInterpolate` | pin the tolerance to 1e-6 | ✅ | ✅ | MATCH | tolerance-insensitive input; now adds a case the tolerance decides |
| Curve2D periodic interpolation delegates (#412)::A 2-point periodic interpolation is accepted by both entry points | `OCCTCurve2DInterpolate` | ignore closed | ✅ | ✅ | MATCH | flags inside `if let`; now required, with the domain |
| Curve2D periodic interpolation delegates (#412)::Both entry points reject a single point | `OCCTCurve2DInterpolate` | fabricate a second point for a one-point input | ✅ | ✅ | MATCH |  |
### #1979 executed: `BatchCurve2DTests.swift`, `BisectorBisecAnaTests.swift`, `BisectorIntersectionTests.swift`
Probe: `Scripts/repro/766-geom2d-batch-bisector/`. Every row was run red with the injection applied and green after it was reverted.
| Batch Curve2D Evaluation::Evaluate grid on circle | `OCCTCurve2DEvaluateGrid` | swap x and y in each evaluated point | ✅ | ✅ | MATCH |  |
| Batch Curve2D Evaluation::Evaluate grid D1 on circle | `OCCTCurve2DEvaluateGridD1` | swap the D1 components | ✅ | ✅ | MATCH |  |
| Batch Curve2D Evaluation::Empty parameters returns empty | `OCCTCurve2DEvaluateGrid` | Swift wrapper returns one zero point for an empty parameter list instead of [] | ✅ | ✅ | MATCH |  |
| Batch Curve2D Evaluation::Grid evaluation matches individual evaluation | `OCCTCurve2DEvaluateGrid` | swap x and y in each evaluated point | ✅ | ✅ | MATCH |  |
| Batch Curve2D Evaluation::Grid D1 matches individual D1 | `OCCTCurve2DEvaluateGridD1` | swap the D1 components | ✅ | ✅ | MATCH |  |
| Batch Curve2D Evaluation::Segment batch evaluation | `OCCTCurve2DEvaluateGrid` | swap x and y in each evaluated point | ✅ | ✅ | MATCH |  |
| Bisector_BisecAna::Bisector between two lines | `OCCTBisectorBisecAnaCurveCurve` | return the second input line instead of the bisector | ✅ | ✅ | MATCH | asserted only `bisector != nil` inside `if let`; now pins two points of the returned line |
| Bisector_BisecAna::Bisector between two points | `OCCTBisectorBisecAnaPointPoint` | move the second point 2 along x | ✅ | ✅ | MATCH | asserted only `bisector != nil`; now pins x = 5 at two parameters |
| Bisector Intersection Tests::perpendicular bisectors of right angle | `OCCTBisectorInterPointPoint` | move B 2 along x | ✅ | ✅ | MATCH | `let _ = results`, no assertion; now uses the pair order whose half-lines meet and pins (5, 5) |
| Bisector Intersection Tests::collinear point bisectors | `OCCTBisectorInterPointPoint` | swap C and D, turning the second half-line to +x | ✅ | ✅ | MATCH | `let _ = results`, no assertion; now pins the empty result of the diverging half-lines |
### #1979 executed: `BSplineCurve2DCompletionsV121Tests.swift`, `BSplineCurve2dKnotSplitTests.swift`
Probe: `Scripts/repro/766-geom2d-bspline-completions/`. Every row was run red with the injection applied and green after it was reverted.
| BSplineCurve 2D Completions v121::SetNotPeriodic on 2D curve | `OCCTCurve2DBSplineSetNotPeriodic` | skip SetNotPeriodic() | ✅ | ✅ | MATCH | the helper curve was already non-periodic and only the returned Bool was checked |
| BSplineCurve 2D Completions v121::IncreaseMultiplicity 2D | `OCCTCurve2DBSplineIncreaseMultiplicity` | pass mult - 1 | ✅ | ✅ | MATCH | only the returned Bools, inside `if let` |
| BSplineCurve 2D Completions v121::Reverse 2D | `OCCTCurve2DBSplineReverse` | skip Reverse() | ✅ | ✅ | MATCH | only the returned Bool, inside `if let` |
| BSplineCurve 2D Completions v121::SetKnots 2D | `OCCTCurve2DBSplineSetKnots` | skip SetKnots() | ✅ | ✅ | MATCH | only the returned Bool, inside `if let` |
| BSplineCurve 2D Completions v121::MovePointAndTangent 2D | `OCCTCurve2DBSplineMovePointAndTangent` | report success regardless of errorStatus | ✅ | ✅ | MATCH | nested in `if let curve`; now also pins that the failed edit left the curve unchanged |
| BSplineCurve 2D Completions v121::MovePointAndTangent 2D with unordered independent conditions | `OCCTCurve2DBSplineMovePointAndTangent` | pass the starting condition as the ending one | ✅ | ✅ | MATCH | only the returned Bool, inside `if let`; now pins the moved point |
| BSplineCurve 2D Completions v121::IncrementMultiplicity 2D | `OCCTCurve2DBSplineIncrementMultiplicity` | increment only index1 | ✅ | ✅ | MATCH | only the returned Bools, inside `if let` |
| BSplineCurve 2D Completions v121::SetOrigin 2D fails on non-periodic | `OCCTCurve2DBSplineSetOrigin` | return true without calling SetOrigin | ✅ | ✅ | MATCH | nested in `if let curve`, so a nil curve passed |
| BSplineCurve2d KnotSplitting Tests::knotSplits | `OCCTCurve2DSplitAtDiscontinuities` | split at continuity 3 whatever is asked | ✅ | ✅ | MATCH | `(indices?.count ?? 0) >= 0` is true for every result including nil |
### #1979 executed: `BSplineCurve2DManipulationTests.swift`
Probe: `Scripts/repro/766-geom2d-bspline-manipulation/`. Every row was run red with the injection applied and green after it was reverted.
| BSpline Curve 2D Manipulation Tests::knotCount | `OCCTCurve2DBSplineKnotCount` | NbKnots() + 1 | ✅ | ✅ | MATCH | `nk > 0`, nested in `if let bsp`, so a nil curve passed |
| BSpline Curve 2D Manipulation Tests::poleCount | `OCCTCurve2DBSplinePoleCount` | NbPoles() + 1 | ✅ | ✅ | MATCH | `np >= 4`, nested in `if let bsp`, so a nil curve passed |
| BSpline Curve 2D Manipulation Tests::degree | `OCCTCurve2DBSplineDegree` | Degree() + 1 | ✅ | ✅ | MATCH | `deg >= 1`, nested in `if let bsp`, so a nil curve passed |
| BSpline Curve 2D Manipulation Tests::isRational | `OCCTCurve2DBSplineIsRational` | negate IsRational() | ✅ | ✅ | MATCH | `let _ = bsp.bspline.isRational`, no assertion |
| BSpline Curve 2D Manipulation Tests::setPole | `OCCTCurve2DBSplineSetPole` | store y + 1 | ✅ | ✅ | MATCH | the pole read-back was nested in `if let bsp`, so a nil curve passed; now also pins the moved midpoint |
| BSpline Curve 2D Manipulation Tests::resolution | `OCCTCurve2DBSplineResolution` | double the resolution | ✅ | ✅ | MATCH | `res > 0`, nested in `if let bsp`, so a nil curve passed |
| BSpline Curve 2D Manipulation Tests::insertKnot | `OCCTCurve2DBSplineInsertKnot` | return true without inserting | ✅ | ✅ | MATCH | only the returned Bool, nested in `if let bsp`, so a nil curve passed |
| BSpline Curve 2D Manipulation Tests::segment | `OCCTCurve2DBSplineSegment` | return true without segmenting | ✅ | ✅ | MATCH | only the returned Bool, nested in `if let bsp`, so a nil curve passed |
| BSpline Curve 2D Manipulation Tests::increaseDegree | `OCCTCurve2DBSplineIncreaseDegree` | return true without raising the degree | ✅ | ✅ | MATCH | nested in `if let bsp`, so a nil curve passed; now also pins the multiplicities and pole count |
| BSpline Curve 2D Manipulation Tests::setWeight | `OCCTCurve2DBSplineSetWeight` | return true without setting the weight | ✅ | ✅ | MATCH | `let _ = setWeight(...)`, no assertion |
| BSpline Curve 2D Manipulation Tests::removeKnot | `OCCTCurve2DBSplineRemoveKnot` | return true without removing | ✅ | ✅ | MATCH | `let _ = removeKnot(...)`, no assertion |
### #1979 executed: `AHTBezierCurve2DTests.swift`, `AnaFilletTests.swift`, `ApproxArcsSegmentsTests.swift`, `ApproxCurve2DTests.swift`, `AxisPlacement2DTests.swift`
Probe: `Scripts/repro/766-geom2d-aht-axisplacement/`. Every row was run red with the injection applied and green after it was reverted.
| Geom2dEval AHTBezier 2D Curve::createAndEval | `OCCTGeom2dEvalAHTBezierCurveCreate` | reverse the pole order before constructing Geom2dEval_AHTBezierCurve | ✅ | ✅ | MATCH | asserted only `domain.lowerBound >= 0` and `upperBound > 0`, which a curve built from the wrong poles satisfies; now pins the domain and point(0.5) |
| ChFi2d_AnaFilletAlgo::Analytical fillet between two edges in XY plane | `OCCTChFi2dAnaFillet` | fillet radius x 1.5 | ✅ | ✅ | MATCH | asserted only isValid on the three edges, which a fillet of any radius satisfies; now pins the fillet length (pi) and trimmed edge 1 (8) |
| Geom2dConvert_ApproxArcsSegments::approximate circle as arcs | `OCCTGeom2dConvertApproxArcsSegments` | report one curve fewer than GetResult() holds | ✅ | ✅ | MATCH | the only assertion (`count >= 1`) sat inside `if let`; now requires exactly the 2 arcs from (5,0) to (-5,0) |
| Geom2dConvert_ApproxArcsSegments::approximate line | `OCCTGeom2dConvertApproxArcsSegments` | report one curve fewer than GetResult() holds | ✅ | ✅ | MATCH | same `if let` + `count >= 1` gap; now requires the single (0,0)-(10,0) segment |
| Approx Curve2D Tests::Approximate 2D circle as BSpline | `OCCTApproxCurve2d` | approximate only the first half of the requested range | ✅ | ✅ | MATCH | `upperBound > lowerBound` inside `if let` passed an approximation of any sub-range; now pins [0, 2pi] and the point at pi/3 |
| AxisPlacement2D::createAxis | `OCCTAxisPlacement2DCreate` | swap the direction components | ✅ | ✅ | MATCH |  |
| AxisPlacement2D::reversed | `OCCTAxisPlacement2DReversed` | skip Reverse() on the copy | ✅ | ✅ | MATCH | `guard ... else { return }` passed green when construction or reversal returned nil; now `#require` |
| AxisPlacement2D::angle | `OCCTAxisPlacement2DAngle` | halve the angle | ✅ | ✅ | MATCH | same early-return guard; now `#require` |
### #1979 executed: `ChFi2dBuilderTests.swift`, `ChFi2dChamferAPITests.swift`, `ChFi2dFilletAlgoTests.swift`, `ChFi2dFilletAPITests.swift`, `CompBezier2dToBSpline2dTests.swift`
Probe: `Scripts/repro/766-geom2d-chfi2d-compbezier/`. Every row was run red with the injection applied and green after it was reverted.
| ChFi2d_Builder Tests::add fillet at vertex | `OCCTChFi2dAddFillet` | fillet radius x 1.5 | ✅ | ✅ | MATCH | `if let` on face and result, and `newEdges > origEdges`; now pins 5 edges and area 96 + pi |
| ChFi2d_Builder Tests::add chamfer between edges | `OCCTChFi2dAddChamfer` | second distance x 1.5 | ✅ | ✅ | MATCH | same `if let` + count gap; now pins area 98 |
| ChFi2d_Builder Tests::add chamfer with angle | `OCCTChFi2dAddChamferAngle` | angle x 1.2 | ✅ | ✅ | MATCH | same `if let` + count gap; now pins area 98 |
| ChFi2d_ChamferAPI Tests::chamfer between two linear edges | `OCCTChFi2dChamferEdges` | second distance x 1.5 | ✅ | ✅ | MATCH | `isValid` inside `if let r`; now pins the chamfer and trimmed edge lengths |
| ChFi2d FilletAlgo Tests::Iterative 2D fillet between two line edges | `OCCTChFi2dFilletAlgo` | radius x 1.5 | ✅ | ✅ | MATCH | `isValid` and `resultCount >= 1`; now pins one solution, fillet pi, edges 8 and 8 |
| ChFi2d_FilletAPI Tests::fillet between two edges | `OCCTChFi2dFilletEdges` | radius x 1.5 | ✅ | ✅ | MATCH | `solutionCount >= 1` inside `if let r`; now pins the fillet and both trimmed edges |
| ChFi2d_FilletAPI Tests::fillet plane origin off world origin stays connected to the input edges (#1459) | `OCCTChFi2dFilletEdges` | radius x 1.5 | ✅ | ✅ | MATCH | strengthened: `solutionCount >= 1` is now `== 1` and the fillet length (pi/2) is pinned |
| Convert_CompBezierCurves2dToBSplineCurve2d Tests::singleQuadraticSegment2D | `OCCTConvertCompBezier2dToBSpline2d` | shift every pole x by 0.5 | ✅ | ✅ | MATCH | `if let` and `poles.last!` inside `#expect`; now pins every pole, knot and multiplicity |
| Convert_CompBezierCurves2dToBSplineCurve2d Tests::twoCubicSegments2D | `OCCTConvertCompBezier2dToBSpline2d` | shift every pole x by 0.5 | ✅ | ✅ | MATCH | `poles.count >= 4` inside `if let`; now pins the six poles and the multiplicity-2 junction knot |
| Convert_CompBezierCurves2dToBSplineCurve2d Tests::emptySegmentsReturnsNil2D | `OCCTConvertCompBezier2dToBSpline2d` | Swift wrapper returns an empty result instead of nil for no segments | ✅ | ✅ | MATCH |  |
| Convert_CompBezierCurves2dToBSplineCurve2d Tests::manySegmentsExceedingCapacityReturnsNil2D | `OCCTConvertCompBezier2dToBSpline2d` | report success with the counts clamped to the 100-pole/50-knot buffers | ✅ | ✅ | MATCH |  |
### #1979 executed: `Curve2DApproximatedOverloadParityTests.swift`, `Curve2DArcLengthFailureTests.swift`, `Curve2DArcTypesTests.swift`
Probe: `Scripts/repro/766-geom2d-approx-arclength-arctypes/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D Approximated Overload Parity Tests::Both overloads succeed on the same curve using only their own implicit defaults | `OCCTCurve2DApproximate / OCCTApproxCurve2d` | OCCTApproxCurve2d approximates only half the range | ✅ | ✅ | MATCH | two `!= nil` checks; now pins both fits |
| Curve2D Approximated Overload Parity Tests::Whole-domain overload's implicit default tolerance produces a real, non-trivial fit error | `OCCTCurve2DApproximate` | tolerance x 10 | ✅ | ✅ | MATCH |  |
| Curve2D Approximated Overload Parity Tests::Ranged overload's implicit default tolerance produces a near-exact fit | `OCCTApproxCurve2d` | approximate only half the range | ✅ | ✅ | MATCH |  |
| Curve2D Approximated Overload Parity Tests::Both overloads independently succeed on the same curve; neither promises to structurally match the other | `OCCTCurve2DApproximate / OCCTApproxCurve2d` | whole-domain tolerance x 10 | ✅ | ✅ | MATCH | `degree != nil` on both; now pins degree 8 / 27 poles on both |
| Curve2D Approximated Overload Parity Tests::Whole-domain overload's continuity is a live knob; ranged overload has none | `OCCTCurve2DApproximate` | ignore continuity (always C2) | ✅ | ✅ | MATCH | two `!= nil` checks could not show the knob is live; now pins 15 poles at C0 and 13 at C2 |
| Curve2D.arcLength(from:to:) distinguishes failure from zero (#409)::A genuine failure is reported as -1.0, not 0.0 | `OCCTCurve2DGetLengthBetween` | skip the parameter-range validation | ✅ | ✅ | MATCH |  |
| Curve2D.arcLength(from:to:) distinguishes failure from zero (#409)::Equal bounds are a genuine zero-length result, not the failure sentinel | `OCCTCurve2DGetLengthBetween` | report a zero-width interval as failure (-1) | ✅ | ✅ | MATCH |  |
| Curve2D.arcLength(from:to:) distinguishes failure from zero (#409)::Both spellings tolerate a reversed range and agree on it | `OCCTCurve2DGetLengthBetween` | scale every length by 1.01 | ✅ | ✅ | MATCH | agreement between the spellings passed a length both got wrong; now pins 6.34269563057 |
| Curve2D Arc Types Tests::Arc of hyperbola creation | `OCCTCurve2DCreateArcOfHyperbola` | double the start parameter | ✅ | ✅ | MATCH | non-nil, open and two samples; now pins both end points |
| Curve2D Arc Types Tests::Arc of parabola creation | `OCCTCurve2DCreateArcOfParabola` | double the focal length | ✅ | ✅ | MATCH | non-nil, open and two samples; now pins both end points |
### #1979 executed: `Curve2DBezierCompletionsTests.swift`, `Curve2DBezierTests.swift`
Probe: `Scripts/repro/766-geom2d-bezier/`. Every row was run red with the injection applied and green after it was reverted.
| v0.126.0 — Curve2D Bezier completions::InsertPoleAfter increases pole count | `OCCTCurve2DBezierInsertPoleAfter` | insert (x, y + 1) | ✅ | ✅ | MATCH | nested in `if let c`, so a nil curve passed; now pins the poles |
| v0.126.0 — Curve2D Bezier completions::RemovePole decreases pole count | `OCCTCurve2DBezierRemovePole` | remove index - 1 | ✅ | ✅ | MATCH | nested in `if let c`, so a nil curve passed; now pins the poles |
| v0.126.0 — Curve2D Bezier completions::Segment restricts domain | `OCCTCurve2DBezierSegment` | segment to u2 + 0.1 | ✅ | ✅ | MATCH | only the returned Bool; now pins the segmented poles |
| v0.126.0 — Curve2D Bezier completions::IncreaseDegree succeeds | `OCCTCurve2DBezierIncreaseDegree` | return true without raising the degree | ✅ | ✅ | MATCH | nested in `if let c`, so a nil curve passed; now also pins the poles |
| v0.126.0 — Curve2D Bezier completions::StartPoint and EndPoint | `OCCTCurve2DBezierStartPoint / OCCTCurve2DBezierEndPoint` | swap StartPoint and EndPoint | ✅ | ✅ | MATCH | nested in `if let c`, so a nil curve passed |
| v0.126.0 — Curve2D Bezier completions::GetPoles returns correct poles | `OCCTCurve2DBezierGetPoles` | shift each x by 1 | ✅ | ✅ | MATCH | nested in `if let c`, so a nil curve passed; now checks y as well as x |
| v0.126.0 — Curve2D Bezier completions::Reverse swaps start and end | `OCCTCurve2DBezierReverse` | return true without reversing | ✅ | ✅ | MATCH | nested in `if let c`, so a nil curve passed |
| Curve2D_Bezier_Properties::degreeAndPoleCount | `OCCTCurve2DBezierDegree / OCCTCurve2DBezierPoleCount` | degree + 1 and pole count + 1 | ✅ | ✅ | MATCH | nested in `if let c`, so a nil curve passed |
| Curve2D_Bezier_Properties::getPole | `OCCTCurve2DBezierGetPole` | read pole index + 1 | ✅ | ✅ | MATCH | nested in `if let c`, so a nil curve passed; now also pins pole 2 |
| Curve2D_Bezier_Properties::setPole | `OCCTCurve2DBezierSetPole` | store y + 1 | ✅ | ✅ | MATCH | nested in `if let c`, so a nil curve passed |
| Curve2D_Bezier_Properties::isRational | `OCCTCurve2DBezierIsRational` | negate IsRational() | ✅ | ✅ | MATCH | nested in `if let c`, so a nil curve passed |
| Curve2D_Bezier_Properties::resolution | `OCCTCurve2DBezierResolution` | double the resolution | ✅ | ✅ | MATCH | `r > 0`, nested in `if let c`, so a nil curve passed |
### #1979 executed: `Curve2DBSplineKnotQueryTests.swift`
Probe: `Scripts/repro/766-geom2d-bspline-knot-query/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D BSpline Knot Queries::FirstUKnotIndex and LastUKnotIndex | `OCCTCurve2DBSplineFirstUKnotIndex / OCCTCurve2DBSplineLastUKnotIndex` | both indices + 1 | ✅ | ✅ | MATCH | `fk > 0`, `lk >= fk`, nested in `if let c` |
| Curve2D BSpline Knot Queries::Knot value by index | `OCCTCurve2DBSplineKnot` | knot + 1 | ✅ | ✅ | MATCH | `k.isFinite`, nested in `if let c` |
| Curve2D BSpline Knot Queries::KnotDistribution | `OCCTCurve2DBSplineKnotDistribution` | report 0 (NonUniform) | ✅ | ✅ | MATCH | `d >= 0 && d <= 3` accepts every value; now `== 3` (PiecewiseBezier) |
| Curve2D BSpline Knot Queries::Multiplicity by index | `OCCTCurve2DBSplineMultiplicity` | multiplicity + 1 | ✅ | ✅ | MATCH | `m > 0`, nested in `if let c` |
| Curve2D BSpline Knot Queries::GetMultiplicities bulk | `OCCTCurve2DBSplineGetMultiplicities` | each multiplicity + 1 | ✅ | ✅ | MATCH | `count > 0` and `first > 0`, nested in `if let c` |
| Curve2D BSpline Knot Queries::StartPoint and EndPoint | `OCCTCurve2DBSplineStartPoint / OCCTCurve2DBSplineEndPoint` | swap StartPoint and EndPoint | ✅ | ✅ | MATCH | nested in `if let c` |
| Curve2D BSpline Knot Queries::GetPoles bulk | `OCCTCurve2DBSplineGetPoles` | shift each x by 1 | ✅ | ✅ | MATCH | compared the count with itself, nested in `if let c`; now pins the poles |
| Curve2D BSpline Knot Queries::IsClosed and IsPeriodic | `OCCTCurve2DBSplineIsClosed / OCCTCurve2DBSplineIsPeriodic` | negate both | ✅ | ✅ | MATCH | nested in `if let c` |
| Curve2D BSpline Knot Queries::Continuity and IsCN | `OCCTCurve2DBSplineContinuity / OCCTCurve2DBSplineIsCN` | report continuity 2 (C1) | ✅ | ✅ | MATCH | `cont >= 0`, nested in `if let c` |
### #1979 executed: `Curve2DCircleFactoryParityTests.swift`, `Curve2DConicFactoryParityTests.swift`
Probe: `Scripts/repro/766-geom2d-conic-factory-parity/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D circle factories agree (#411)::Both factories reject zero and negative radius | `OCCTGceMakeCirc2dFromCenterRadius` | skip the radius precondition | ✅ | ✅ | MATCH |  |
| Curve2D circle factories agree (#411)::Both factories build the identical circle for a valid radius | `OCCTGceMakeCirc2dFromCenterRadius` | centre x + 1 | ✅ | ✅ | MATCH | returned early when either factory gave nil and compared only with each other; now pins (8, -4) |
| Curve2D conic factories agree (#487)::Ellipse: both families reject zero, negative and inverted radii | `OCCTGceMakeElips2d` | skip the radius precondition | ✅ | ✅ | MATCH |  |
| Curve2D conic factories agree (#487)::Hyperbola: both families reject a zero or negative radius | `OCCTGceMakeHypr2d` | skip the radius precondition | ✅ | ✅ | MATCH |  |
| Curve2D conic factories agree (#487)::Parabola: both families reject zero and negative focal length | `OCCTGceMakeParab2d` | skip the focal precondition | ✅ | ✅ | MATCH |  |
| Curve2D conic factories agree (#487)::Hyperbola: a minor radius larger than the major is accepted by both families | `OCCTGceMakeHypr2d` | reject minor > major | ✅ | ✅ | MATCH |  |
| Curve2D conic factories agree (#487)::Ellipse: equal radii are accepted by both families | `OCCTGceMakeElips2d` | reject minor >= major | ✅ | ✅ | MATCH |  |
| Curve2D conic factories agree (#487)::Valid ellipse radii still build the identical curve in both families | `OCCTGceMakeElips2d` | centre x + 1 | ✅ | ✅ | MATCH | returned early on nil and compared only the two factories; now pins two points |
| Curve2D conic factories agree (#487)::Valid hyperbola radii still build the identical curve in both families | `OCCTGceMakeHypr2d` | centre x + 1 | ✅ | ✅ | MATCH | returned early on nil and compared only the two factories; now pins the vertex |
| Curve2D conic factories agree (#487)::Valid focal length still builds the identical parabola in both families | `OCCTGceMakeParab2d` | vertex x + 1 | ✅ | ✅ | MATCH | returned early on nil and compared only the two factories; now pins point(2) |
### #1979 executed: `Curve2DCircleInvoluteTests.swift`
Probe: `Scripts/repro/766-geom2d-circle-involute/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D — Circle Involute::createCircleInvolute | `OCCTGeom2dEvalCircleInvoluteCurveCreate` | bridge returns nil | ✅ | ✅ | MATCH | optional-chained flags; now `#require` and the domain start |
| Curve2D — Circle Involute::createCircleInvoluteRejectsZeroRadius | `OCCTGeom2dEvalCircleInvoluteCurveCreate` | Swift guard skipped and the bridge clamps radius <= 0 to 1 | ✅ | ✅ | MATCH |  |
| Curve2D — Circle Involute::createCircleInvoluteRejectsNegativeRadius | `OCCTGeom2dEvalCircleInvoluteCurveCreate` | Swift guard skipped and the bridge clamps radius <= 0 to 1 | ✅ | ✅ | MATCH |  |
| Curve2D — Circle Involute::circleInvolutePointAtZero | `OCCTGeom2dEvalCircleInvoluteCurveCreate` | origin x + 1 | ✅ | ✅ | MATCH | u = 0 only, where the involute term vanishes; now also pins C(1) |
| Curve2D — Circle Involute::circleInvoluteTranslated | `OCCTGeom2dEvalCircleInvoluteCurveCreate` | origin x + 1 | ✅ | ✅ | MATCH | u = 0 only; now also pins C(1) |
| Curve2D — Circle Involute::circleInvoluteRotated | `OCCTGeom2dEvalCircleInvoluteCurveCreate` | ignore the direction (always +x) | ✅ | ✅ | MATCH | u = 0 only; now also pins C(1) |
| Curve2D — Circle Involute::circleInvoluteMirroredFlank | `OCCTGeom2dEvalCircleInvoluteCurveCreate` | ignore the direction (always +x) | ✅ | ✅ | MATCH | signs only, force-unwraps, and a comment placing the mirrored C(0) at (2, 0); now pins both curves |
| Curve2D — Circle Involute::circleInvoluteCanBuildEdge | `OCCTMakeEdge2dCurveRange` | build the edge on half the requested range | ✅ | ✅ | MATCH | edge count only; now pins the arc length R u^2 / 2 = 4 |
| Curve2D — Circle Involute::createCircleInvoluteRejectsZeroLengthDirection | `OCCTGeom2dEvalCircleInvoluteCurveCreate` | Swift guard skipped, zero direction replaced by (1, 0) | ✅ | ✅ | MATCH |  |
| Curve2D — Circle Involute::createCircleInvoluteRejectsNearZeroLengthDirection | `OCCTGeom2dEvalCircleInvoluteCurveCreate` | Swift guard skipped, near-zero direction replaced by (1, 0) | ✅ | ✅ | MATCH |  |
| Curve2D — Circle Involute::circleInvoluteD0WithPlacementRejectsZeroLengthDirection | `OCCTGeom2dEvalCircleInvoluteD0WithPlacement` | Swift guard skipped, zero direction replaced by (1, 0) | ✅ | ✅ | MATCH |  |
| Curve2D — Circle Involute::circleInvoluteD1WithPlacementRejectsZeroLengthDirection | `OCCTGeom2dEvalCircleInvoluteD1WithPlacement` | Swift guard skipped, zero direction replaced by (1, 0) | ✅ | ✅ | MATCH |  |
### #1979 executed: `Curve2DContinuityQueriesTests.swift`, `Curve2DContinuityTests.swift`, `Curve2DConvertExtrasTests.swift`
Probe: `Scripts/repro/766-geom2d-continuity-convert/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D Continuity Queries v0.120.0::segmentContinuityClass | `OCCTCurve2DGetContinuity` | report 3 (C1) | ✅ | ✅ | MATCH | nested in `if let c` |
| Curve2D Continuity Queries v0.120.0::isCN | `OCCTCurve2DIsCN` | negate IsCN() | ✅ | ✅ | MATCH | nested in `if let c` |
| Curve2D Continuity Queries v0.120.0::reversedParameter | `OCCTCurve2DReversedParameter` | return u unchanged | ✅ | ✅ | MATCH | `rp.isFinite`; now pins -0.2 and -0.5 |
| Curve2D Continuity Queries v0.120.0::bezierMaxDegree | `OCCTCurve2DBezierMaxDegree` | MaxDegree() - 1 | ✅ | ✅ | MATCH | `md >= 25`; now `== 25` |
| Curve2D Continuity Queries v0.120.0::bsplineMaxDegree | `OCCTCurve2DBSplineMaxDegree` | MaxDegree() - 1 | ✅ | ✅ | MATCH | `md >= 25`; now `== 25` |
| Curve2D Continuity Tests::line2DContinuity | `OCCTCurve2DGetContinuity` | report 3 (C1) | ✅ | ✅ | MATCH | `c >= 0`; now `== 6` (GeomAbs_CN) |
| Curve2D Continuity Tests::bspline2DContinuity | `OCCTCurve2DGetContinuity` | report 3 (C1) | ✅ | ✅ | MATCH | `c >= 0`; now `== 4` (GeomAbs_C2) |
| Curve2D Convert Extras Tests::Approximate circle as BSpline | `OCCTCurve2DApproximate` | tolerance x 10 | ✅ | ✅ | MATCH | `degree != nil`; now pins degree 7 and 13 poles |
| Curve2D Convert Extras Tests::Split BSpline at discontinuities | `OCCTCurve2DSplitAtDiscontinuities` | split at continuity 3 whatever is asked | ✅ | ✅ | MATCH | `indices != nil`; now pins both split lists |
| Curve2D Convert Extras Tests::Convert to arcs and segments | `OCCTCurve2DToArcsAndSegments` | drop the last curve | ✅ | ✅ | MATCH | `count >= 1`; now `== 2` |
### #1979 executed: `Curve2DInterpolateTangentsParityTests.swift`, `Curve2DIsLinearTests.swift`, `Curve2DLineTests.swift`
Probe: `Scripts/repro/766-geom2d-tangents-islinear-line/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D tangent interpolation entry points agree (#410)::Default tolerance: the two entry points produce the same curve | `OCCTCurve2DInterpolateWithTangents` | swap the start and end tangents | ✅ | ✅ | MATCH | agreement only; now pins the pole count and a point |
| Curve2D tangent interpolation entry points agree (#410)::A non-default tolerance is now reachable through interpolate(points:...) | `OCCTCurve2DInterpolateWithTangents` | pin the tolerance to 1e-6 | ✅ | ✅ | MATCH | tolerance-insensitive input; now adds a case the tolerance decides |
| Curve2D tangent interpolation entry points agree (#410)::Both entry points reject a single point | `OCCTCurve2DInterpolateWithTangents` | fabricate a second point for a one-point input | ✅ | ✅ | MATCH |  |
| Curve2D IsLinear Tests::Linear BSpline is detected as linear | `OCCTCurve2DIsLinear` | negate the verdict | ✅ | ✅ | MATCH | two nested `if let`s; now required, with the deviation |
| Curve2D IsLinear Tests::Non-linear curve is detected as non-linear | `OCCTCurve2DIsLinear` | negate the verdict | ✅ | ✅ | MATCH | two nested `if let`s; now required |
| Curve2D IsLinear Tests::Non-BSpline curve returns nil, not a false result | `OCCTCurve2DIsLinear` | report (false, 0) for a non-BSpline (the #1542 defect) | ✅ | ✅ | MATCH |  |
| GC_MakeLine2d::Create 2D line through two points | `OCCTCurve2DMakeLineThroughPoints` | swap the two points | ✅ | ✅ | MATCH | `!= nil`; now pins the line |
| GC_MakeLine2d::Create 2D line parallel to direction at distance | `OCCTCurve2DMakeLineParallel` | negate the distance | ✅ | ✅ | MATCH | `!= nil`; now pins the offset side |
### #1979 executed: `Curve2DLocalPropertiesTests.swift`
Probe: `Scripts/repro/766-geom2d-localprops-operations/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D Local Properties Tests::Curvature of circle equals 1/radius | `OCCTCurve2DGetCurvature` | curvature + 0.1 | ✅ | ✅ | MATCH |  |
| Curve2D Local Properties Tests::Curvature of line is zero | `OCCTCurve2DGetCurvature` | curvature + 0.1 | ✅ | ✅ | MATCH |  |
| Curve2D Local Properties Tests::Normal on circle points toward center | `OCCTCurve2DGetNormal` | reverse the normal | ✅ | ✅ | MATCH | unit length only passed an outward normal; now pins (-1, 0) |
| Curve2D Local Properties Tests::Tangent direction on segment is along direction | `OCCTCurve2DGetTangentDir` | reverse the tangent | ✅ | ✅ | MATCH | `abs(t.y)` passed a reversed tangent; now pins (1, 0) |
| Curve2D Local Properties Tests::Center of curvature on circle is at center | `OCCTCurve2DGetCenterOfCurvature` | centre x + 1 | ✅ | ✅ | MATCH | nested in `if let cc`; now required |
| Curve2D Local Properties Tests::Inflection points of cubic BSpline | `OCCTCurve2DGetInflectionPoints` | report no inflections | ✅ | ✅ | MATCH | `count >= 1` inside `if let`; now one inflection at u = 10.3042 |
| Curve2D Local Properties Tests::Curvature extrema of ellipse | `OCCTCurve2DGetCurvatureExtrema` | drop the last extremum | ✅ | ✅ | MATCH | `count >= 2`; now all four parameters |
| Curve2D Local Properties Tests::All special points of ellipse | `OCCTCurve2DGetAllSpecialPoints` | drop the last point | ✅ | ✅ | MATCH | `count >= 2`; now `== 4` |
### #1979 executed: `Curve2DOperationsTests.swift`
| Curve2D Operations Tests::Trim circle to quarter arc | `OCCTCurve2DTrim` | trim to half the upper bound | ✅ | ✅ | MATCH | nested in `if let arc`; now required |
| Curve2D Operations Tests::Offset segment | `OCCTCurve2DOffset` | negate the offset | ✅ | ✅ | MATCH | `!= nil` only; now pins the offset segment |
| Curve2D Operations Tests::Reverse segment swaps endpoints | `OCCTCurve2DReversed` | return a copy, not reversed | ✅ | ✅ | MATCH |  |
| Curve2D Operations Tests::Translate segment | `OCCTCurve2DTranslate` | dx + 1 | ✅ | ✅ | MATCH |  |
| Curve2D Operations Tests::Rotate quarter turn | `OCCTCurve2DRotate` | half the angle | ✅ | ✅ | MATCH |  |
| Curve2D Operations Tests::Scale by 2x | `OCCTCurve2DScale` | factor + 1 | ✅ | ✅ | MATCH |  |
| Curve2D Operations Tests::Mirror across X axis | `OCCTCurve2DMirrorAxis` | swap the axis direction components | ✅ | ✅ | MATCH |  |
| Curve2D Operations Tests::Mirror across point | `OCCTCurve2DMirrorPoint` | mirror point x + 1 | ✅ | ✅ | MATCH |  |
| Curve2D Operations Tests::Circle length approximately 2*pi*r | `OCCTCurve2DGetLength` | length x 1.01 | ✅ | ✅ | MATCH |  |
| Curve2D Operations Tests::Segment length approximately Euclidean distance | `OCCTCurve2DGetLength` | length x 1.01 | ✅ | ✅ | MATCH |  |
### #1979 executed: `Curve2DProjectionParityTests.swift`, `Curve2DSimplifyBSplineTests.swift`, `Curve2DTransformTests.swift`, `Direction2DUtilityTests.swift`
Probe: `Scripts/repro/766-geom2d-projection-simplify-transform/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D projection entry points agree (#413)::All five entry points agree for an ordinary projection | `occtNearestProjectionOnCurve2d (OCCTCurve2DProjectPoint, OCCTCurve2DProjectPoint2D, OCCTPoint2DDistanceToCurve, OCCTCurve2DNearestParameter)` | shift the shared helper: parameter + 0.1, distance + 0.5 | ✅ | ✅ | MATCH | compared the spellings only with each other; now pins each case to the kernel |
| Curve2D projection entry points agree (#413)::The four nearest-point entry points agree where there is no perpendicular foot | `occtNearestProjectionOnCurve2d` | shift the shared helper: parameter + 0.1, distance + 0.5 | ✅ | ✅ | MATCH |  |
| Curve2D projection entry points agree (#413)::Parameter zero is a success, not a failure signal | `occtNearestProjectionOnCurve2d` | shift the shared helper: parameter + 0.1, distance + 0.5 | ✅ | ✅ | MATCH | `guard ... else { return }` and `if let`; now `#require` |
| Curve2D SimplifyBSpline Tests::Simplify a BSpline curve | `OCCTCurve2DSimplifyBSpline` | return true without simplifying | ✅ | ✅ | MATCH | `_ = simplified`, no assertion; now pins the simplification |
| Curve2D Transform::Translate 2D curve | `OCCTCurve2DTransform` | translation dx + 1 | ✅ | ✅ | MATCH | only the returned Bool, inside `if let` |
| Curve2D Transform::Rotate 2D curve | `OCCTCurve2DTransform` | half the angle | ✅ | ✅ | MATCH | only the returned Bool, inside `if let` |
| Curve2D Transform::Scale 2D curve | `OCCTCurve2DTransform` | factor + 1 | ✅ | ✅ | MATCH | only the returned Bool, inside `if let` |
| Curve2D Transform::Mirror 2D curve through point | `OCCTCurve2DTransform` | mirror point x + 1 | ✅ | ✅ | MATCH | only the returned Bool, inside `if let` |
| Curve2D Transform::Mirror 2D curve through axis | `OCCTCurve2DTransform` | swap the axis direction components | ✅ | ✅ | MATCH | only the returned Bool, inside `if let` |
| Direction2D Utilities::normalize | `OCCTDirection2DNormalize` | swap the components | ✅ | ✅ | MATCH | unit length only; now pins (0.6, 0.8) |
| Direction2D Utilities::angle | `OCCTDirection2DAngle` | half the angle | ✅ | ✅ | MATCH |  |
| Direction2D Utilities::cross | `OCCTDirection2DCross` | negate | ✅ | ✅ | MATCH |  |
### #1979 executed: `Extrema2dTests.swift`, `ExtremaLocateExtCC2dTests.swift`, `Fillet2DTests.swift`
Probe: `Scripts/repro/766-geom2d-extrema-fillet2d/`. Every row was run red with the injection applied and green after it was reverted.
| Extrema 2D::Distance between parallel lines | `OCCTExtremaExtElC2dLinLin` | squared distance x 1.1 | ✅ | ✅ | MATCH | `if let r = results.first` and 0.1 slack |
| Extrema 2D::Parallel line matched points actually achieve the reported distance (#1494) | `OCCTExtremaExtElC2dLinLin` | squared distance x 1.1 | ✅ | ✅ | MATCH |  |
| Extrema 2D::Distance between line and circle | `OCCTExtremaExtElC2dLinCirc` | circle centre y + 1 | ✅ | ✅ | MATCH | `count >= 1`, 0.1 slack; now both extrema |
| Extrema 2D::Closest point on circle to external point | `OCCTExtremaExtPElC2dCirc` | point x + 1 | ✅ | ✅ | MATCH | `count >= 1`, 0.1 slack; now both extrema |
| Extrema 2D::Closest point on line to point | `OCCTExtremaExtPElC2dLin` | point y + 1 | ✅ | ✅ | MATCH | `count >= 1`, 0.1 slack |
| Extrema 2D::Distance between two curves | `OCCTExtremaExtCC2d` | measure curve 1 against itself | ✅ | ✅ | MATCH | `if let` and 0.1 slack on the minimum; now all four extrema |
| Extrema_LocateExtCC2d Tests::localExtremum2d | `OCCTExtremaLocateExtCC2d` | seed u + pi | ✅ | ✅ | MATCH | `if let` and 0.5 slack |
| 2D Fillet and Chamfer::Fillet single vertex of rectangular face | `OCCTFace2DFillet` | radius x 1.5 | ✅ | ✅ | MATCH | edge count only; now the area too |
| 2D Fillet and Chamfer::Fillet multiple vertices | `OCCTFace2DFillet` | radius x 1.5 | ✅ | ✅ | MATCH | edge count only; now the area too |
| 2D Fillet and Chamfer::Fillet with zero count returns nil | `OCCTFace2DFillet` | Swift wrapper returns the face unchanged for an empty list | ✅ | ✅ | MATCH |  |
| 2D Fillet and Chamfer::Chamfer between adjacent edges | `OCCTFace2DChamfer` | second distance x 1.5 | ✅ | ✅ | MATCH | edge count only; now the area too |
| 2D Fillet and Chamfer::Chamfer mismatched arrays returns nil | `OCCTFace2DChamfer` | Swift wrapper pads missing distances with 1.0 | ✅ | ✅ | MATCH |  |
### #1979 executed: `GccAnaCirc2d3TanTests.swift`, `GccAnaLin2d2TanTests.swift`
Probe: `Scripts/repro/766-geom2d-gccana-circ3tan-lines/`. Every row was run red with the injection applied and green after it was reverted.
| GccAna Circ2d3Tan Tests::threePoints | `OCCTGccAnaCirc2d3TanPoints` | third point y + 1 | ✅ | ✅ | MATCH | `radius > 0`; now centre and radius |
| GccAna Circ2d3Tan Tests::threeLines | `OCCTGccAnaCirc2d3TanLines` | third line x + 2 | ✅ | ✅ | MATCH | `count >= 1`; now pins the solution set |
| GccAna Circ2d3Tan Tests::threeCircles | `OCCTGccAnaCirc2d3TanCircles` | third radius + 1 | ✅ | ✅ | MATCH | `count >= 1`; now pins the solution set |
| GccAna Circ2d3Tan Tests::twoCirclesPoint | `OCCTGccAnaCirc2d2CirclesPoint` | point y + 1 | ✅ | ✅ | MATCH | `count >= 1`; now pins the solution set |
| GccAna Circ2d3Tan Tests::circleAndTwoPoints | `OCCTGccAnaCirc2dCircle2Points` | second point x + 1 | ✅ | ✅ | MATCH | `count >= 1`; now pins the solution set |
| GccAna Circ2d3Tan Tests::twoLinesPoint | `OCCTGccAnaCirc2d2LinesPoint` | point x + 1 | ✅ | ✅ | MATCH | `count >= 1`; now pins the solution set |
| GccAna Lin2d2Tan Tests::line through two points | `OCCTGccAnaLin2d2TanPntPnt` | second point y + 1 | ✅ | ✅ | MATCH | `|dx| == |dy|` inside `if let`; now the signed direction |
| GccAna Lin2d2Tan Tests::lines tangent to circle through point | `OCCTGccAnaLin2d2TanCircPnt` | point x + 1 | ✅ | ✅ | MATCH | `count >= 1`; now pins the solution set |
### #1979 executed: `GccAnaLineSolverTests.swift`, `GccCircleOnConstraintTests.swift`
| GccAna Line Solvers::Line through point parallel to reference | `OCCTGccAnaLin2dTanParPt` | point y + 1 | ✅ | ✅ | MATCH | `count >= 1`, direction to 0.01 |
| GccAna Line Solvers::Lines tangent to circle parallel to reference | `OCCTGccAnaLin2dTanParCirc` | circle radius + 1 | ✅ | ✅ | MATCH | count only; now the two lines |
| GccAna Line Solvers::Line through point perpendicular to reference | `OCCTGccAnaLin2dTanPerPtLin` | point x + 1 | ✅ | ✅ | MATCH | `count >= 1`, `|dy| > 0.9` |
| GccAna Line Solvers::Lines tangent to circle perpendicular to reference | `OCCTGccAnaLin2dTanPerCircLin` | circle radius + 1 | ✅ | ✅ | MATCH | count only; now the two lines |
| GccAna Line Solvers::Line through point at angle to reference | `OCCTGccAnaLin2dTanOblPt` | half the angle | ✅ | ✅ | MATCH | `count >= 1` |
| GccAna Line Solvers::Lines tangent to curve at angle (Geom2dGcc) | `OCCTGeom2dGccLin2dTanObl` | half the angle | ✅ | ✅ | MATCH | `count >= 1` inside `if let` |
| GccAna/Geom2dGcc Circle On-Constraint Solvers::Circle tangent to 2 lines center on line | `OCCTGccAnaCirc2d2TanOnLinLin` | second line y + 2 | ✅ | ✅ | MATCH | `count >= 1`, radius to 0.1 |
| GccAna/Geom2dGcc Circle On-Constraint Solvers::Circle tangent to line center on line given radius | `OCCTGccAnaCirc2dTanOnRadLin` | radius + 1 | ✅ | ✅ | MATCH | `count >= 1` |
| GccAna/Geom2dGcc Circle On-Constraint Solvers::Geom2dGcc circle tangent to 2 curves center on curve | `OCCTGeom2dGccCirc2d2TanOn` | pass the first curve twice | ✅ | ✅ | MATCH | `count >= 1` inside `if let` |
| GccAna/Geom2dGcc Circle On-Constraint Solvers::Geom2dGcc circle tangent to curve center on curve given radius | `OCCTGeom2dGccCirc2dTanOnRad` | radius + 1 | ✅ | ✅ | MATCH | `count >= 1` inside `if let` |
### #1979 executed: `GceMakeCirc2dTests.swift`, `GceMakeElips2dTests.swift`, `GceMakeHypr2dTests.swift`, `GceMakeLin2dTests.swift`, `GceMakeParab2dTests.swift`, `Geom2dAPIInterpolateTests.swift`, `Geom2dAPIPointsToBSplineTests.swift`
Probe: `Scripts/repro/766-geom2d-gce-geom2dapi/`. Every row was run red with the injection applied and green after it was reverted.
| gce_MakeCirc2d Tests::circleFromCenterRadius | `OCCTGceMakeCirc2dFromCenterRadius` | centre x + 1 | ✅ | ✅ | MATCH | `upperBound > lowerBound` inside `if let`: any curve, and a nil one, passed |
| gce_MakeCirc2d Tests::circleThrough3Points | `OCCTGceMakeCirc2dFrom3Points` | second point y + 1 | ✅ | ✅ | MATCH | `upperBound > lowerBound` inside `if let`: any curve, and a nil one, passed |
| gce_MakeElips2d Tests::ellipseFromCenterDir | `OCCTGceMakeElips2d` | centre x + 1 | ✅ | ✅ | MATCH | `upperBound > lowerBound` inside `if let`: any curve, and a nil one, passed |
| gce_MakeHypr2d Tests::hyperbolaFromCenterDir | `OCCTGceMakeHypr2d` | centre x + 1 | ✅ | ✅ | MATCH | `upperBound > lowerBound` inside `if let`: any curve, and a nil one, passed |
| gce_MakeLin2d Tests::lineFrom2Points | `OCCTGceMakeLin2dFrom2Points` | first point x + 1 | ✅ | ✅ | MATCH | `upperBound > lowerBound` inside `if let`: any curve, and a nil one, passed |
| gce_MakeLin2d Tests::lineFromEquation | `OCCTGceMakeLin2dFromEquation` | c - 1 | ✅ | ✅ | MATCH | `upperBound > lowerBound` inside `if let`: any curve, and a nil one, passed |
| gce_MakeParab2d Tests::parabolaFromCenterDir | `OCCTGceMakeParab2d` | vertex x + 1 | ✅ | ✅ | MATCH | `upperBound > lowerBound` inside `if let`: any curve, and a nil one, passed |
| Geom2dAPI Interpolate Tests::basicInterpolation | `OCCTCurve2DInterpolate2D` | drop the last point | ✅ | ✅ | MATCH | `!= nil` only |
| Geom2dAPI Interpolate Tests::periodicInterpolation | `OCCTCurve2DInterpolate2D` | ignore periodic | ✅ | ✅ | MATCH | `!= nil` only |
| Geom2dAPI PointsToBSpline Tests::basicApproximation | `OCCTCurve2DApproximate2D` | last point y + 1 | ✅ | ✅ | MATCH | `!= nil` only |
### #1979 executed: `GCMake2dConicTests.swift`
Probe: `Scripts/repro/766-geom2d-gcmake2d-conic/`. Every row was run red with the injection applied and green after it was reverted.
| GC_Make*2d Conic Tests::circle2dCenterRadius | `OCCTCurve2DMakeCircleCenterRadius` | radius + 1 | ✅ | ✅ | MATCH | `!= nil` and `isClosed` only |
| GC_Make*2d Conic Tests::circle2d3Points | `OCCTCurve2DMakeCircle3Points` | second point y + 1 | ✅ | ✅ | MATCH | `!= nil` and `isClosed` only |
| GC_Make*2d Conic Tests::circle2dCenterPoint | `OCCTCurve2DMakeCircleCenterPoint` | point x + 1 | ✅ | ✅ | MATCH | `!= nil` and `isClosed` only |
| GC_Make*2d Conic Tests::circle2dAxis | `OCCTCurve2DMakeCircleAxis` | radius + 1 | ✅ | ✅ | MATCH | `!= nil` and `isClosed` only |
| GC_Make*2d Conic Tests::circle2dParallel | `OCCTCurve2DMakeCircleParallel` | negate the distance | ✅ | ✅ | MATCH | nested in `if let c` |
| GC_Make*2d Conic Tests::circle2dParallelInward | `OCCTCurve2DMakeCircleParallel` | negate the distance | ✅ | ✅ | MATCH | nested in `if let c` |
| GC_Make*2d Conic Tests::ellipse2dFromAxis | `OCCTCurve2DMakeEllipse` | minor radius - 1 | ✅ | ✅ | MATCH | `!= nil` and `isClosed` only |
| GC_Make*2d Conic Tests::ellipse2dFrom3Points | `OCCTCurve2DMakeEllipse3Points` | second point y + 1 | ✅ | ✅ | MATCH | nested in `if let e` |
| GC_Make*2d Conic Tests::ellipse2dFromAx22d | `OCCTCurve2DMakeEllipseAxis22d` | reverse the y direction | ✅ | ✅ | MATCH | `!= nil` and `isClosed` only |
| GC_Make*2d Conic Tests::hyperbola2dFromAxis | `OCCTCurve2DMakeHyperbola` | major radius + 1 | ✅ | ✅ | MATCH | `!= nil` only |
| GC_Make*2d Conic Tests::hyperbola2dFrom3Points | `OCCTCurve2DMakeHyperbola3Points` | second point y + 1 | ✅ | ✅ | MATCH | nested in `if let h` |
| GC_Make*2d Conic Tests::parabola2dFromAxis | `OCCTCurve2DMakeParabola` | focal + 1 | ✅ | ✅ | MATCH | `!= nil` only |
| GC_Make*2d Conic Tests::parabola2dFromDirectrixFocus | `OCCTCurve2DMakeParabolaDirectrixFocus` | focus x + 1 | ✅ | ✅ | MATCH | `!= nil` only |
### #1979 executed: `Geom2dEllipseTests.swift`, `Geom2dEvalArchimedeanSpiralTests.swift`
Probe: `Scripts/repro/766-geom2d-gtrsf-circle-ellipse-spiral/`. Every row was run red with the injection applied and green after it was reverted.
| Geom2d_Ellipse Properties::ellipse2DRadii | `OCCTCurve2DEllipseMajorRadius / OCCTCurve2DEllipseMinorRadius` | major radius + 1 | ✅ | ✅ | MATCH | nested in `if let e` |
| Geom2d_Ellipse Properties::ellipse2DSetRadii | `OCCTCurve2DEllipseSetMajorRadius` | skip SetMajorRadius() | ✅ | ✅ | MATCH | nested in `if let e` |
| Geom2d_Ellipse Properties::ellipse2DEccentricity | `OCCTCurve2DEllipseEccentricity` | eccentricity + 0.01 | ✅ | ✅ | MATCH | `> 0`, nested in `if let e` |
| Geom2d_Ellipse Properties::ellipse2DFocal | `OCCTCurve2DEllipseFocal` | focal + 0.01 | ✅ | ✅ | MATCH | `> 0`, nested in `if let e` |
| Geom2d_Ellipse Properties::ellipse2DFocus1 | `OCCTCurve2DEllipseFocus1` | negate x (report focus 2) | ✅ | ✅ | MATCH | `let _ = f`, no assertion |
| Geom2dEval — Archimedean Spiral::spiralD0AtZero | `OCCTGeom2dEvalArchimedeanSpiralD0` | initial radius + 1 | ✅ | ✅ | MATCH |  |
| Geom2dEval — Archimedean Spiral::spiralD0AtTwoPi | `OCCTGeom2dEvalArchimedeanSpiralD0` | initial radius + 1 | ✅ | ✅ | MATCH |  |
| Geom2dEval — Archimedean Spiral::spiralD1 | `OCCTGeom2dEvalArchimedeanSpiralD1` | growth rate + 1 | ✅ | ✅ | MATCH | `speed > 0`; now D1 = (b, a) |
| Geom2dEval — Archimedean Spiral::spiralWithInitialRadius | `OCCTGeom2dEvalArchimedeanSpiralD0` | initial radius + 1 | ✅ | ✅ | MATCH |  |
### #1979 executed: `Geom2dEvalCircleInvolutePlacementTests.swift`, `Geom2dEvalCircleInvoluteTests.swift`, `Geom2dEvalLogSpiralTests.swift`
Probe: `Scripts/repro/766-geom2d-eval-involute-logspiral/`. Every row was run red with the injection applied and green after it was reverted.
| Geom2dEval — Circle Involute with Placement::involuteD0WithPlacementAtOrigin | `OCCTGeom2dEvalCircleInvoluteD0WithPlacement` | origin x + 1 | ✅ | ✅ | MATCH |  |
| Geom2dEval — Circle Involute with Placement::involuteD0WithPlacementTranslated | `OCCTGeom2dEvalCircleInvoluteD0WithPlacement` | origin x + 1 | ✅ | ✅ | MATCH |  |
| Geom2dEval — Circle Involute with Placement::involuteD0WithPlacementRotated | `OCCTGeom2dEvalCircleInvoluteD0WithPlacement` | origin x + 1 | ✅ | ✅ | MATCH |  |
| Geom2dEval — Circle Involute with Placement::involuteD0PlacementDiffersFromIdentity | `OCCTGeom2dEvalCircleInvoluteD0WithPlacement` | origin x + 1 | ✅ | ✅ | MATCH | "differ" only; now both points pinned |
| Geom2dEval — Circle Involute with Placement::involuteD1WithPlacement | `OCCTGeom2dEvalCircleInvoluteD1WithPlacement` | radius + 1 | ✅ | ✅ | MATCH | `speed > 0`; now |D1| = R t and D1 pinned |
| Geom2dEval — Circle Involute::involuteD0AtZero | `OCCTGeom2dEvalCircleInvoluteD0` | radius + 1 | ✅ | ✅ | MATCH |  |
| Geom2dEval — Circle Involute::involuteGrows | `OCCTGeom2dEvalCircleInvoluteD0` | radius + 1 | ✅ | ✅ | MATCH | `r2 > r1` only |
| Geom2dEval — Circle Involute::involuteD1 | `OCCTGeom2dEvalCircleInvoluteD1` | radius + 1 | ✅ | ✅ | MATCH | `speed > 0` only |
| Geom2dEval — Logarithmic Spiral::logSpiralD0AtZero | `OCCTGeom2dEvalLogSpiralD0` | scale + 1 | ✅ | ✅ | MATCH |  |
| Geom2dEval — Logarithmic Spiral::logSpiralGrows | `OCCTGeom2dEvalLogSpiralD0` | scale + 1 | ✅ | ✅ | MATCH | `r2 > r1` only |
| Geom2dEval — Logarithmic Spiral::logSpiralD1 | `OCCTGeom2dEvalLogSpiralD1` | growth exponent + 0.1 | ✅ | ✅ | MATCH | `speed > 0` only |
### #1979 executed: `Geom2dEvalSineWaveTests.swift`, `Geom2dHyperbolaTests.swift`, `Geom2dLineTests.swift`
Probe: `Scripts/repro/766-geom2d-conic-props-sine-lprop/`. Every row was run red with the injection applied and green after it was reverted.
| Geom2dEval — 2D Sine Wave::sineWave2DD0AtZero | `OCCTGeom2dEvalSineWaveD0` | phase + 0.5 | ✅ | ✅ | MATCH |  |
| Geom2dEval — 2D Sine Wave::sineWave2DD0Peak | `OCCTGeom2dEvalSineWaveD0` | phase + 0.5 | ✅ | ✅ | MATCH | y only; x = t now pinned too |
| Geom2dEval — 2D Sine Wave::sineWave2DD1 | `OCCTGeom2dEvalSineWaveD1` | omega + 1 | ✅ | ✅ | MATCH |  |
| Geom2d_Hyperbola Properties::hyperbola2DRadii | `OCCTCurve2DHyperbolaMajorRadius` | major radius + 1 | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Geom2d_Hyperbola Properties::hyperbola2DEccentricity | `OCCTCurve2DHyperbolaEccentricity` | eccentricity + 0.01 | ✅ | ✅ | MATCH | `e > 1` inside `if let`; now sqrt(34)/5 |
| Geom2d_Hyperbola Properties::hyperbola2DFocal | `OCCTCurve2DHyperbolaFocal` | focal + 0.01 | ✅ | ✅ | MATCH | `focal > 0` inside `if let`; now 2 sqrt(34) |
| Geom2d_Hyperbola Properties::hyperbola2DFocus1 | `OCCTCurve2DHyperbolaFocus1` | focus x + 0.5 | ✅ | ✅ | MATCH | `x > 0` inside `if let`; now (sqrt 34, 0) |
| Geom2d_Line Properties::line2DDirection | `OCCTCurve2DLineDirection` | direction components swapped | ✅ | ✅ | MATCH | `if let`; now `#require` and both components |
| Geom2d_Line Properties::line2DLocation | `OCCTCurve2DLineLocation` | location x + 1 | ✅ | ✅ | MATCH | `if let`; now `#require` and both components |
| Geom2d_Line Properties::line2DSetDirection | `OCCTCurve2DLineSetDirection` | SetDirection skipped | ✅ | ✅ | MATCH | `if let`; now `#require` and both components |
| Geom2d_Line Properties::line2DSetLocation | `OCCTCurve2DLineSetLocation` | SetLocation skipped | ✅ | ✅ | MATCH | `if let`; now `#require` and both components |
| Geom2d_Line Properties::line2DDistance | `OCCTCurve2DLineDistance` | distance + 1 | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Geom2d_Line Properties::line2DLin2d | `OCCTCurve2DLineLin2d` | location x + 1 | ✅ | ✅ | MATCH | `if let`; now `#require` and location pinned |
### #1979 executed: `Geom2dLPropTests.swift`, `Geom2dOffsetTests.swift`, `Geom2dParabolaTests.swift`
| Geom2dLProp Curvature Analysis::Curvature extrema on ellipse | `OCCTCurve2DGetCurvatureExtrema` | last extremum dropped | ✅ | ✅ | MATCH | `count >= 1` inside `if let`; now four typed extrema |
| Geom2dLProp Curvature Analysis::Inflection points on S-curve | `OCCTCurve2DGetInflectionPoints` | inflections never collected | ✅ | ✅ | MATCH | `count >= 0`, which cannot fail; now one inflection at u = 20.638 |
| Geom2dLProp Curvature Analysis::CurInfType mirrors Curve2DSpecialPointType case-for-case | `CurInfType.init (Swift)` | .minCurvature mapped to .curvatureMaximum | ✅ | ✅ | MATCH |  |
| Geom2dLProp Curvature Analysis::curvatureExtremaDetailed() agrees with curvatureExtrema() on the same curve | `OCCTCurve2DGetCurvatureExtrema` | last extremum dropped | ✅ | ✅ | MATCH | `count >= 2` inside `if let`; now 4 |
| Geom2dLProp Curvature Analysis::inflectionPointsDetailed() agrees with inflectionPoints() on the same curve | `OCCTCurve2DGetInflectionPoints` | inflections never collected | ✅ | ✅ | MATCH | `count >= 1` inside `if let`; now 1 |
| Geom2d_OffsetCurve Properties::offset2DValue | `OCCTCurve2DOffsetValue` | offset + 1 | ✅ | ✅ | MATCH | two `if let`s; now `#require` |
| Geom2d_OffsetCurve Properties::offset2DSetValue | `OCCTCurve2DOffsetSetValue` | SetOffsetValue skipped | ✅ | ✅ | MATCH | two `if let`s; now `#require` |
| Geom2d_OffsetCurve Properties::offset2DBasisCurve | `OCCTCurve2DOffsetBasisCurve` | returns the offset curve, not its basis | ✅ | ✅ | MATCH | asserted nothing (`let _ = basis.domain`); now pins basis(2) |
| Geom2d_Parabola Properties::parabola2DFocal | `OCCTCurve2DParabolaFocal` | focal + 1 | ✅ | ✅ | MATCH | `focal > 0` inside `if let`; now 3 |
| Geom2d_Parabola Properties::parabola2DSetFocal | `OCCTCurve2DParabolaSetFocal` | SetFocal skipped | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Geom2d_Parabola Properties::parabola2DFocus | `OCCTCurve2DParabolaFocus` | focus x + 1 | ✅ | ✅ | MATCH | asserted nothing (`let _ = f`); now (0, 0) |
| Geom2d_Parabola Properties::parabola2DEccentricity | `OCCTCurve2DParabolaEccentricity` | eccentricity + 0.1 | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Geom2d_Parabola Properties::parabola2DParameter | `OCCTCurve2DParabolaParameter` | parameter + 1 | ✅ | ✅ | MATCH | `p > 0` inside `if let`; now 6 |
### #1979 executed: `Issue1407EvaluatorGuardTests.swift`, `Issue1474Curve2DApproxDetailsTests.swift`, `Issue1477Geom2dCurvesTests.swift`, `Issue1511Curve2DCurveTypeOtherCurveFallbackTests.swift`
Probe: `Scripts/repro/766-geom2d-issue-regressions-a/`. Every row was run red with the injection applied and green after it was reverted.
| Issue #1407, 2D evaluator guards::A zero-amplitude sine wave does not abort | `OCCTGeom2dEvalSineWaveD0` | amplitude 0 replaced by 1 | ✅ | ✅ | MATCH |  |
| Issue #1407, 2D evaluator guards::A zero-radius circle involute does not abort | `OCCTGeom2dEvalCircleInvoluteD0` | radius 0 replaced by 1 | ✅ | ✅ | MATCH |  |
| Issue #1407, 2D evaluator guards::A zero-growth Archimedean spiral does not abort | `OCCTGeom2dEvalArchimedeanSpiralD0` | growth rate 0 replaced by 1 | ✅ | ✅ | MATCH |  |
| Curve2D.approxWithDetails surfaces MaxError (#1474)::approxWithDetails reports the true maxError for a starved (over-tolerance) fit | `OCCTGeomConvertApproxCurve2D` | MaxError discarded (reported as 0) | ✅ | ✅ | MATCH | `guard` + `Issue.record`; now `#require`, maxError pinned |
| Curve2D.approxWithDetails surfaces MaxError (#1474)::approximated and approxWithDetails agree on a well-converged fit | `OCCTCurve2DApproximate` | plain entry point tolerance x 1e-4 | ✅ | ✅ | MATCH | `guard` + `Issue.record`; now `#require`, poles and degree pinned |
| #1477: Geom2d_Curves.mm buffer-count and silent-drop fixes::returned count never exceeds a small buffer's capacity, and matches what was written | `OCCTGeom2dConvertApproxArcsSegments` | returns written - 1 | ✅ | ✅ | MATCH | fixture precondition now `#require`, full count pinned |
| #1477: Geom2d_Curves.mm buffer-count and silent-drop fixes::join fails (returns nil) when a curve cannot attach, rather than silently dropping it | `OCCTCurve2DJoinToBSpline` | failed Add ignored | ✅ | ✅ | MATCH |  |
| #1477: Geom2d_Curves.mm buffer-count and silent-drop fixes::join fails when curves are out of order and don't chain end-to-end | `OCCTCurve2DJoinToBSpline` | failed Add ignored | ✅ | ✅ | MATCH |  |
| #1477: Geom2d_Curves.mm buffer-count and silent-drop fixes::join still succeeds for genuinely continuous curves | `OCCTCurve2DJoinToBSpline` | returns nullptr | ✅ | ✅ | MATCH | `!= nil`; now endpoints pinned |
| Issue #1511 Finding 2: OCCTCurve2DCurveType OtherCurve fallback::a null OCCTCurve2DRef returns GeomAbs_OtherCurve (8), not GeomAbs_OffsetCurve (7) | `OCCTCurve2DCurveType` | null fallback back to 7 | ✅ | ✅ | MATCH |  |
| Issue #1511 Finding 2: OCCTCurve2DCurveType OtherCurve fallback::an ordinary line's curve type is unaffected (Line = 0) | `OCCTCurve2DCurveType` | GetType result replaced by 1 | ✅ | ✅ | MATCH |  |
### #1979 executed: `Issue1050BisectorDomainTests.swift`
Probe: `Scripts/repro/766-geom2d-bisector-domain-nonfinite/`. Every row was run red with the injection applied and green after it was reverted.
| Issue1050 bisector intersection domain::A meeting point past the old window is found | `OCCTBisectorInterPointPoint` | both IntRes2d_Domain upper bounds clamped to 100 (the pre-#1050 window) | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Issue1050 bisector intersection domain::A meeting point inside the old window is unchanged | `OCCTBisectorInterPointPoint` | A.y - 2 | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Issue1050 bisector intersection domain::Parallel bisectors still report no intersection | `OCCTBisectorInterPointPoint` | returns 1 when nothing was found | ✅ | ✅ | MATCH |  |
| Issue1050 bisector intersection domain::A crossing on the dead side of the half-line reports no intersection | `OCCTBisectorInterPointPoint` | returns 1 when nothing was found | ✅ | ✅ | MATCH |  |
| Issue1050 bisector intersection domain::A meeting point past any input-derived bound is found | `OCCTBisectorInterPointPoint` | both IntRes2d_Domain upper bounds clamped to 100 | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Issue1050 bisector intersection domain::The documented circumcentre example holds, and its three reorderings do not | `OCCTBisectorInterPointPoint` | A.y - 2 | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Issue1050 bisector intersection domain::Coincident points return no intersection rather than crashing | `OCCTBisectorInterPointPoint` | catch returns 1 instead of 0 | ✅ | ✅ | MATCH |  |
| Issue1050BisectorDomainTests.swift (free function)::Coincident bisectors report intersection segment endpoints | `OCCTBisectorInterPointPoint` | segment endpoints never collected | ✅ | ✅ | MATCH | `#expect(count == 2)` then `hits[0]`: a short result crashed the run; now `#require` |
| Issue1085 bisector non-finite coordinates::NaN in first point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::NaN in second point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::NaN in third point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::NaN in fourth point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::Positive infinity in first point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::Positive infinity in second point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::Positive infinity in third point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::Positive infinity in fourth point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::Negative infinity in first point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::Negative infinity in second point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::Negative infinity in third point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::Negative infinity in fourth point returns empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::Large finite coordinates exceeding 1e150 return empty | `bisectorIntersections (Swift guard)` | guard sanitises a refused coordinate to 0 instead of refusing | ✅ | ✅ | MATCH |  |
| Issue1085 bisector non-finite coordinates::Coordinates near but below threshold still work | `OCCTBisectorInterPointPoint` | maxSafeMagnitude lowered to 1e148 | ✅ | ✅ | MATCH | asserted nothing (`_ = hits`) on a fixture whose C and D coincide in Double at 1e149; new fixture pinned to (0, 5) |
### #1979 executed: `Issue1646EvaluatorContractTests.swift`
Probe: `Scripts/repro/766-geom2d-evaluator-contract/`. Every row was run red with the injection applied and green after it was reverted.
| Issue #1646, 2D evaluator contract::Every D0 evaluator refuses the argument its OCCT constructor rejects | `OCCTGeom2dEval*D0` | Swift wrapper ignores the bridge's bool (the pre-#1646 void contract) | ✅ | ✅ | MATCH |  |
| Issue #1646, 2D evaluator contract::Every D1 evaluator refuses the argument its OCCT constructor rejects | `OCCTGeom2dEval*D1` | Swift wrapper ignores the bridge's bool | ✅ | ✅ | MATCH |  |
| Issue #1646, 2D evaluator contract::The same evaluators answer the accepted argument beside each rejected one | `OCCTGeom2dEval*D0/D1` | D0 writer adds 1e-3 to x | ✅ | ✅ | MATCH | `isFinite` only; now all five pinned |
| Issue #1646, 2D evaluator contract::A legitimate evaluation at the origin is a value, not a refusal | `OCCTGeom2dEvalSineWaveD0` | D0 writer refuses an exact (0, 0) | ✅ | ✅ | MATCH |  |
| Issue #1646, 2D evaluator contract::A NaN argument is refused, not answered with a NaN point | `occtEval2dWriteD0/D1` | finite-output check skipped | ✅ | ✅ | MATCH |  |
| Issue #1646, 2D evaluator contract::A NaN parameter is refused, and EvalD0 never raises on one | `occtEval2dWriteD0/D1` | finite-output check skipped | ✅ | ✅ | MATCH |  |
| Issue #1646, 2D evaluator contract::A finite argument whose evaluation overflows is refused | `OCCTGeom2dEvalLogSpiralD0` | finite-output check skipped | ✅ | ✅ | MATCH | neighbour was `isFinite`; now pinned |
| Issue #1646, 2D evaluator contract::The placement overloads refuse a bad radius, direction, or non-finite argument | `OCCTGeom2dEvalCircleInvoluteD0/D1WithPlacement` | Swift wrapper ignores the bridge's bool | ✅ | ✅ | MATCH |  |
| Issue #1646, 2D evaluator contract::The placement overloads answer a well-formed call | `OCCTGeom2dEvalCircleInvoluteD0/D1WithPlacement` | D0 writer adds 1e-3 to x | ✅ | ✅ | MATCH | D1 row was `isFinite` on one component each; now both pinned |
### #1979 executed: `Issue478Curve2DTransformParityTests.swift`
Probe: `Scripts/repro/766-geom2d-transform-split-continuity/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D Transform Family Parity (#478)::translate vs translated(by:) | `OCCTCurve2DTransform vs OCCTCurve2DTranslate` | in-place dispatcher only: first transform parameter + 1e-3 | ✅ | ✅ | MATCH |  |
| Curve2D Transform Family Parity (#478)::rotate vs rotated(around:angle:) | `OCCTCurve2DTransform vs OCCTCurve2DRotate` | in-place dispatcher only: first transform parameter + 1e-3 | ✅ | ✅ | MATCH |  |
| Curve2D Transform Family Parity (#478)::scale vs scaled(from:factor:) about a non-origin centre | `OCCTCurve2DTransform vs OCCTCurve2DScale` | in-place dispatcher only: first transform parameter + 1e-3 | ✅ | ✅ | MATCH |  |
| Curve2D Transform Family Parity (#478)::scale parity holds for a negative factor | `OCCTCurve2DTransform vs OCCTCurve2DScale` | in-place dispatcher only: first transform parameter + 1e-3 | ✅ | ✅ | MATCH |  |
| Curve2D Transform Family Parity (#478)::mirrorPoint vs mirrored(acrossPoint:) | `OCCTCurve2DTransform vs OCCTCurve2DMirrorPoint` | in-place dispatcher only: first transform parameter + 1e-3 | ✅ | ✅ | MATCH |  |
| Curve2D Transform Family Parity (#478)::mirrorAxis vs mirrored(acrossLine:direction:) | `OCCTCurve2DTransform vs OCCTCurve2DMirrorAxis` | in-place dispatcher only: first transform parameter + 1e-3 | ✅ | ✅ | MATCH |  |
| Curve2D Transform Absolute Geometry (#478)::translation moves both endpoints by the delta | `buildTrsf2D (both families)` | shared builder: first transform parameter + 1e-3 (parity tests stay green) | ✅ | ✅ | MATCH |  |
| Curve2D Transform Absolute Geometry (#478)::rotation turns both endpoints about the centre | `buildTrsf2D (both families)` | shared builder: first transform parameter + 1e-3 (parity tests stay green) | ✅ | ✅ | MATCH |  |
| Curve2D Transform Absolute Geometry (#478)::scale moves both endpoints away from the centre, not the origin | `buildTrsf2D (both families)` | shared builder: first transform parameter + 1e-3 (parity tests stay green) | ✅ | ✅ | MATCH |  |
| Curve2D Transform Absolute Geometry (#478)::a negative scale factor reflects through the centre | `buildTrsf2D (both families)` | shared builder: first transform parameter + 1e-3 (parity tests stay green) | ✅ | ✅ | MATCH |  |
| Curve2D Transform Absolute Geometry (#478)::point mirror reflects both endpoints through the point | `buildTrsf2D (both families)` | shared builder: first transform parameter + 1e-3 (parity tests stay green) | ✅ | ✅ | MATCH |  |
| Curve2D Transform Absolute Geometry (#478)::axis mirror reflects both endpoints across the line | `buildTrsf2D (both families)` | shared builder: first transform parameter + 1e-3 (parity tests stay green) | ✅ | ✅ | MATCH |  |
### #1979 executed: `Issue480Curve2DKnotSplitContinuityTests.swift`, `Issue485Curve2DContinuityTests.swift`, `Issue486Curve2DBatchTests.swift`
| Curve2D knot-splitting continuity range (#480)::A cubic 2D BSpline with simple interior knots reports interior splits only at .c3 | `OCCTCurve2DSplitAtDiscontinuities` | requested continuity passed one lower | ✅ | ✅ | MATCH |  |
| Curve2D knot-splitting continuity range (#480)::The .c1 default reports a real kink | `OCCTCurve2DSplitAtDiscontinuities` | requested continuity passed one lower | ✅ | ✅ | MATCH |  |
| Curve2D measured continuity (#485)::Knot multiplicity drives the measured class, at GeomAbs_Shape's own ordinals | `OCCTCurve2DGetContinuity` | pre-#485 encoding (C2 = 2, G1 = -2, CN = 99) | ✅ | ✅ | MATCH | three `if let`s; now `#require` |
| Curve2D measured continuity (#485)::Analytic 2D curves report CN as ordinal 6, not 99 | `OCCTCurve2DGetContinuity` | pre-#485 encoding | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Curve2D measured continuity (#485)::A G1-only 2D curve is reachable and reports ordinal 1 | `OCCTCurve2DGetContinuity` | pre-#485 encoding | ✅ | ✅ | MATCH | `guard` + `Issue.record`; now `#require` |
| Curve2D measured continuity (#485)::continuity and continuityClass agree on the same curve, in every class | `OCCTCurve2DGetContinuity` | pre-#485 encoding | ✅ | ✅ | MATCH |  |
| Issue 486: Curve2D batch-eval spellings agree::empty parameters give an empty result, not one padded with zeroes | `Curve2D.evaluateGrid (Swift)` | empty input returns one zero point | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
### #1979 executed: `Issue549Curve2DArcLengthRangeTests.swift`
Probe: `Scripts/repro/766-geom2d-arclength-zero-radius/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D ranged arc-length contract after the #549 bridge removal::A reversed in-domain range measures the span, not the failure sentinel | `OCCTCurve2DGetLengthBetween` | u1 > u2 returns -1 | ✅ | ✅ | MATCH |  |
| Curve2D ranged arc-length contract after the #549 bridge removal::A reversed range on a single-span curve measures the span too | `OCCTCurve2DGetLengthBetween` | u1 > u2 returns -1 | ✅ | ✅ | MATCH |  |
| Curve2D ranged arc-length contract after the #549 bridge removal::Parameters past both ends clamp to the domain instead of extrapolating | `OCCTCurve2DGetLengthBetween` | pre-bounded adaptor over [u1, u2] (the pre-#549 extrapolation) | ✅ | ✅ | MATCH |  |
| Curve2D ranged arc-length contract after the #549 bridge removal::A range wholly outside the domain measures zero, not a fragment of the extrapolation | `OCCTCurve2DGetLengthBetween` | pre-bounded adaptor over [u1, u2] | ✅ | ✅ | MATCH |  |
| Curve2D ranged arc-length contract after the #549 bridge removal::Equal parameters are still a genuine zero, not the failure sentinel | `OCCTCurve2DGetLengthBetween` | u1 == u2 returns -1 | ✅ | ✅ | MATCH |  |
| Curve2D ranged arc-length contract after the #549 bridge removal::The -1.0 sentinel still reports a genuine failure | `OCCTCurve2DGetLengthBetween` | NaN bound measured as 0 | ✅ | ✅ | MATCH |  |
| Curve2D ranged arc-length contract after the #549 bridge removal::The two spellings are one computation, on the ranges that used to diverge | `Curve2D.arcLength (Swift)` | arcLength returns -1 on a reversed range while length(from:to:) measures it | ✅ | ✅ | MATCH |  |
| Curve2D ranged arc-length contract after the #549 bridge removal::2D and 3D answer the same on a reversed and an out-of-domain range | `OCCTCurve2DGetLengthBetween` | u1 > u2 returns -1 | ✅ | ✅ | MATCH |  |
### #1979 executed: `Issue791ConvertCircleHelperTests.swift`, `Issue815Curve2DExtremaSelfIntersectTests.swift`, `Issue840ClassifyPoint2dToleranceTests.swift`, `Issue881PerpendicularBasisTests.swift`
Probe: `Scripts/repro/766-geom2d-issue-regressions-b/`. Every row was run red with the injection applied and green after it was reverted.
| Issue791 Circle 2D BSpline helper consolidation::fullCircleOriginMatchesPriorBaseline | `OCCTConvertCircleToBSpline2D` | radius + 1e-3 | ✅ | ✅ | MATCH |  |
| Issue791 Circle 2D BSpline helper consolidation::offsetArcMatchesPriorBaseline | `OCCTConvertCircleToBSpline2D` | radius + 1e-3 | ✅ | ✅ | MATCH |  |
| Issue791 Circle 2D BSpline helper consolidation::convertedCircleStaysOnTheAnalyticCircle | `OCCTConvertCircleToBSpline2D` | radius + 1e-3 | ✅ | ✅ | MATCH |  |
| Curve2D Extrema and Self-Intersection (#815)::allExtrema between two separated circles: exactly a nearest and a farthest point pair | `OCCTCurve2DAllExtrema` | each distance + 1e-3 | ✅ | ✅ | MATCH | min/max inside `if let`, 0.1 slack; now all four pinned |
| Curve2D Extrema and Self-Intersection (#815)::Self-intersections of a looped cubic Bezier curve | `OCCTCurve2DSelfIntersect` | result count flipped (none found / phantom one) | ✅ | ✅ | MATCH | `if let`, 0.1 slack; now exact |
| Curve2D Extrema and Self-Intersection (#815)::A circle (convex, simple) reports no self-intersections | `OCCTCurve2DSelfIntersect` | result count flipped (none found / phantom one) | ✅ | ✅ | MATCH | force-unwrapped fixture; now `#require` |
| Issue #840: classifyPoint2d default tolerance alignment::classifyPoint2d agrees with Face.classify and classifyPoint2D on a borderline point | `OCCTIntToolsFClass2dPerform` | default tolerance back to 1e-7 (pre-#840) | ✅ | ✅ | MATCH |  |
| Issue #840: classifyPoint2d default tolerance alignment::well-inside point is unaffected by the tolerance change | `OCCTIntToolsFClass2dPerform` | IN and OUT swapped in the state mapping | ✅ | ✅ | MATCH |  |
| Issue #840: classifyPoint2d default tolerance alignment::well-outside point is unaffected by the tolerance change | `OCCTIntToolsFClass2dPerform` | IN and OUT swapped in the state mapping | ✅ | ✅ | MATCH |  |
| perpendicularBasis unification: Section2D (#881)::sectionPlaneBasis's auto-derived (u, v) matches OCCT's gp_Ax2 canonical basis | `Shape.sectionPlaneBasis (Swift)` | u and v swapped | ✅ | ✅ | MATCH |  |
| perpendicularBasis unification: Section2D (#881)::sectionPlaneBasis with an explicitU is unaffected by the unification | `Shape.sectionPlaneBasis (Swift)` | explicit u not orthogonalised against the normal | ✅ | ✅ | MATCH |  |
### #1979 executed: `Issue965Curve2DPropertyLifetimeTests.swift`, `Issue999Curve2DParametersTests.swift`
| Curve2D *Properties views keep their parent alive (#965)::every Curve2D *Properties accessor keeps its parent alive | `Curve2D.circleProperties (Swift)` | view built on a different owner, so the parent is released | ✅ | ✅ | MATCH |  |
| Curve2D *Properties views keep their parent alive (#965)::a view outliving its parent still reads the right values | `Curve2D.circleProperties (Swift)` | view built on a different owner | ✅ | ✅ | MATCH |  |
| Curve2D *Properties views keep their parent alive (#965)::a view outliving its parent survives 400 intervening allocations | `Curve2D.circleProperties (Swift)` | view built on a different owner | ✅ | ✅ | MATCH |  |
| Curve2D *Properties views keep their parent alive (#965)::a setter called through a view is visible on the parent | `OCCTCurve2DCircleSetRadius` | setRadius reports success without setting | ✅ | ✅ | MATCH |  |
| Curve2D conversion and bisector parameters are live (#999)::Each parameterisation gives a structurally different B-spline | `OCCTCurve2DToBSpline` | requested parameterisation ignored (always TgtThetaOver2) | ✅ | ✅ | MATCH |  |
| Curve2D conversion and bisector parameters are live (#999)::Every parameterisation but polynomial reproduces the circle exactly | `OCCTCurve2DToBSpline` | requested parameterisation ignored | ✅ | ✅ | MATCH |  |
| Curve2D conversion and bisector parameters are live (#999)::A parameterisation OCCT rejects for this arc returns nil rather than a wrong curve | `OCCTCurve2DToBSpline` | requested parameterisation ignored | ✅ | ✅ | MATCH |  |
| Curve2D conversion and bisector parameters are live (#999)::The trimming distance bounds the bisector, and a longer one extends it | `OCCTCurve2DBisectorPC` | maxDistance ignored (always 500) | ✅ | ✅ | MATCH |  |
### #1979 executed: `Point2DCreationTests.swift`, `Point2DDistanceTests.swift`, `Point2DTransformTests.swift`
Probe: `Scripts/repro/766-geom2d-point-matrix-polygon/`. Every row was run red with the injection applied and green after it was reverted.
| Point2D Creation::createPoint | `OCCTPoint2DCreate` | x + 1e-3 | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Point2D Creation::createFromSIMD | `OCCTPoint2DCreate` | x + 1e-3 | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Point2D Creation::setCoords | `OCCTPoint2DSetCoords` | SetCoord skipped | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Point2D Distance::distanceBetweenPoints | `OCCTPoint2DDistance` | distance + 1e-3 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Point2D Distance::squareDistance | `OCCTPoint2DSquareDistance` | square distance + 1e-3 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Point2D Distance::distanceToCurve | `OCCTPoint2DDistanceToCurve` | distance + 1e-3 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` |
| Point2D Transforms::translate | `OCCTPoint2DTranslated` | dx + 1e-3 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` and `if let` |
| Point2D Transforms::rotate | `OCCTPoint2DRotated` | angle negated | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` and `if let` |
| Point2D Transforms::scale | `OCCTPoint2DScaled` | factor + 1 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` and `if let` |
| Point2D Transforms::mirrorPoint | `OCCTPoint2DMirroredPoint` | mirror point x + 1 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` and `if let` |
| Point2D Transforms::mirrorAxis | `OCCTPoint2DMirroredAxis` | axis origin y + 1 | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` and `if let` |
| Point2D Transforms::transformedByTransform2D | `OCCTPoint2DTransformed` | identity applied instead of the transform | ✅ | ✅ | MATCH | `guard ... else { return }`; now `#require` and `if let` |
### #1979 executed: `Polygon2DTests.swift`, `Matrix2DTests.swift`
| Poly_Polygon2D::create and query | `OCCTPolyPolygon2DNode` | 0-based index passed through (off by one) | ✅ | ✅ | MATCH | two `if let`s; now `#require` |
| Poly_Polygon2D::deflection | `OCCTPolyPolygon2DSetDeflection` | Deflection() setter skipped | ✅ | ✅ | MATCH | `if let`; now `#require` |
| Poly_Polygon2D::all nodes | `OCCTPolyPolygon2DNode` | 0-based index passed through (off by one) | ✅ | ✅ | MATCH | `if let`, and `#expect(count)` before `nodes[2]` crashed the run; now `#require` |
| Matrix2D::identity | `OCCTMat2dIdentity` | (1,2) + 1e-3 | ✅ | ✅ | MATCH | determinant only; now every entry |
| Matrix2D::rotation | `OCCTMat2dRotation` | angle negated | ✅ | ✅ | MATCH | determinant only (1 for every rotation); now every entry |
| Matrix2D::scale | `OCCTMat2dScale` | factor negated | ✅ | ✅ | MATCH | determinant only (9 for +-3); now every entry |
| Matrix2D::multiplyAndInvert | `OCCTMat2dMultiply` | returns A instead of A*B | ✅ | ✅ | MATCH | one entry; now every entry |
| Matrix2D::transpose | `OCCTMat2dTranspose` | returns the input | ✅ | ✅ | MATCH | one entry; now every entry |
| Matrix2D::invert | `OCCTMat2dInvert` | returns the input | ✅ | ✅ | MATCH | `if let`, one entry of the product; now `#require`, the inverse and the product pinned |
### #1979 executed: `MakeEdge2dTests.swift`, `MakeEdge2dExtensionsTests.swift`
Probe: `Scripts/repro/766-geom2d-makeedge2d/`. Every row was run red with the injection applied and green after it was reverted.
| BRepBuilderAPI MakeEdge2d::Edge 2D from points | `OCCTMakeEdge2dFromPoints` | end x + 1 | ✅ | ✅ | MATCH | `!= nil` and edge type; now vertices pinned |
| BRepBuilderAPI MakeEdge2d::Edge 2D from circle arc | `OCCTMakeEdge2dFromCircle` | end parameter halved | ✅ | ✅ | MATCH | `!= nil` and edge type; now vertices pinned |
| BRepBuilderAPI MakeEdge2d::Edge 2D from line | `OCCTMakeEdge2dFromLine` | end parameter + 1 | ✅ | ✅ | MATCH | `!= nil` and edge type; now vertices pinned |
| BRepLib_MakeEdge2d Extensions Tests::edge2dFullCircle | `OCCTMakeEdge2dFullCircle` | radius + 1 | ✅ | ✅ | MATCH | `nbChildren >= 0` (cannot fail) in `if let` |
| BRepLib_MakeEdge2d Extensions Tests::edge2dEllipse | `OCCTMakeEdge2dEllipse` | major radius + 1 | ✅ | ✅ | MATCH | `nbChildren >= 0` (cannot fail) in `if let` |
| BRepLib_MakeEdge2d Extensions Tests::edge2dEllipseArc | `OCCTMakeEdge2dEllipseArc` | end parameter halved | ✅ | ✅ | MATCH | `nbChildren >= 0` (cannot fail) in `if let` |
| BRepLib_MakeEdge2d Extensions Tests::edge2dFromCurve | `OCCTMakeEdge2dCurveRange` | end parameter + 1 | ✅ | ✅ | MATCH | `nbChildren >= 0` (cannot fail) in two `if let`s |
| BRepLib_MakeEdge2d Extensions Tests::edge2dFromCurveFullRange | `OCCTMakeEdge2dCurve` | start parameter + 1 (no longer closed) | ✅ | ✅ | MATCH | `nbChildren >= 0` (cannot fail) in two `if let`s |
### #1979 executed: `Curve2DParameterAtLengthTests.swift`, `Curve2DPoint2DIntegrationTests.swift`
Probe: `Scripts/repro/766-geom2d-param-at-length-point2d/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D parameterAtLength Tests::Parameter at full arc length of a circle arc | `OCCTCurve2DParameterAtLength` | parameter + 0.5 | ✅ | ✅ | MATCH | nested `if let`s and 0.01/0.05 tolerances; now required, to 1e-9 |
| Curve2D parameterAtLength Tests::Parameter at zero length returns start parameter | `OCCTCurve2DParameterAtLength` | parameter + 0.5 | ✅ | ✅ | MATCH | nested in `if let` |
| Curve2D parameterAtLength Tests::Parameter at full length of a segment | `OCCTCurve2DParameterAtLength` | parameter + 0.5 | ✅ | ✅ | MATCH | nested in `if let`, 0.01 tolerance |
| Curve2D parameterAtLength Tests::Parameter at length from non-start parameter | `OCCTCurve2DParameterAtLength` | parameter + 0.5 | ✅ | ✅ | MATCH | nested in `if let`, 0.1 tolerance |
| Curve2D parameterAtLength Tests::parameterAtLength returns nil on failure | `OCCTCurve2DParameterAtLength` | parameter + 0.5 | ✅ | ✅ | MATCH | `_ = result`, no assertion |
| Curve2D parameterAtLength Tests::Trim curve to exact arc length using parameterAtLength | `OCCTCurve2DParameterAtLength` | parameter + 0.5 | ✅ | ✅ | MATCH | three nested `if let`s, 0.01 tolerance |
| Curve2D Point2D Integration::pointAtParameter | `OCCTCurve2DPointAt` | evaluate at t + 1 | ✅ | ✅ | MATCH | `guard ... else { return }` and `if let` |
| Curve2D Point2D Integration::segmentFromPoints | `OCCTCurve2DSegmentFromPoints` | half-length segment | ✅ | ✅ | MATCH | `guard ... else { return }`; now checks both samples fully |
| Curve2D Point2D Integration::projectPoint | `OCCTCurve2DProjectPoint2D` | distance + 1 | ✅ | ✅ | MATCH | `guard ... else { return }` and `if let` |
### #1979 executed: `GeneralTransform2DTests.swift`, `Geom2dCircleTests.swift`
| GeneralTransform2D::affinity | `OCCTGTrsf2dAffinity` | ratio + 1 | ✅ | ✅ | MATCH | `matrix.count == 4` passed any matrix |
| GeneralTransform2D::multiply | `OCCTGTrsf2dMultiply` | return the left operand | ✅ | ✅ | MATCH | `let _ = a.multiplied(by: b)`, no assertion |
| GeneralTransform2D::invert | `OCCTGTrsf2dInvert` | return the input uninverted | ✅ | ✅ | MATCH | `inverted() != nil` only |
| GeneralTransform2D::transformPoint | `OCCTGTrsf2dTransformPoint` | result y + 1 | ✅ | ✅ | MATCH | checked only the unchanged x; now y too |
| GeneralTransform2D::zeroLengthAxisDirectionIsRefused | `OCCTGTrsf2dAffinity` | replace a zero direction with (1, 0) | ✅ | ✅ | MATCH |  |
| GeneralTransform2D::vanishinglySmallAxisDirectionIsRefused | `OCCTGTrsf2dAffinity` | replace a zero direction with (1, 0) | ✅ | ✅ | MATCH |  |
| Geom2d_Circle Properties::circle2DRadius | `OCCTCurve2DCircleRadius` | radius + 1 | ✅ | ✅ | MATCH | nested in `if let c` |
| Geom2d_Circle Properties::circle2DSetRadius | `OCCTCurve2DCircleSetRadius` | skip SetRadius() | ✅ | ✅ | MATCH | nested in `if let c` |
| Geom2d_Circle Properties::circle2DEccentricity | `OCCTCurve2DCircleEccentricity` | eccentricity + 0.1 | ✅ | ✅ | MATCH | nested in `if let c` |
| Geom2d_Circle Properties::circle2DCenter | `OCCTCurve2DCircleCenter` | centre x + 1 | ✅ | ✅ | MATCH | nested in `if let c` |
| Geom2d_Circle Properties::circle2DXAxis | `OCCTCurve2DCircleXAxis` | swap the direction components | ✅ | ✅ | MATCH | nested in `if let c`; checked only the direction x, now position too |
### #1979 executed: `Curve2DGccTests.swift`, `Curve2DHatchingTests.swift`
Probe: `Scripts/repro/766-geom2d-gcc-hatching/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D Gcc Tests::Circle through three points | `OCCTGccCircle2d3Pt` | centre x + 1 | ✅ | ✅ | MATCH | `radius > 0`; now pins centre and radius |
| Curve2D Gcc Tests::Circles through two points with radius | `OCCTGccCircle2d2PtRad` | centre y x 0.5 | ✅ | ✅ | MATCH | radius only; now pins both centres |
| Curve2D Gcc Tests::Circle tangent to curve with center | `OCCTGccCircle2dTanCen` | radius + 0.5 | ✅ | ✅ | MATCH | `count >= 1` inside `if let first`; now one solution, radius to 1e-9 |
| Curve2D Gcc Tests::Lines tangent to circle through point | `OCCTGccLine2dTanPt` | drop the qualifier (unqualified) | ✅ | ✅ | MATCH | `count >= 1`; now pins the single outside tangent |
| Curve2D Gcc Tests::Circles tangent to curve and point with radius | `OCCTGccCircle2dTanPtRad` | point x + 1 | ✅ | ✅ | MATCH | `count >= 1`; now pins both centres |
| Curve2D Hatching Tests::Hatch a rectangular boundary | `OCCTCurve2DHatch` | spacing x 1.25 | ✅ | ✅ | MATCH | `count >= 1`; now pins the four interior lines |
| Curve2D Hatching Tests::Hatch output is not silently truncated at half the buffer's real capacity (#1420) | `OCCTCurve2DHatch` | spacing x 1.25 | ✅ | ✅ | MATCH | strengthened: the (2048, 4096] bounds are kept and the exact kernel count 2999 is pinned |
| Curve2D Hatching Tests::Hatch result is independent of boundary winding direction (#1496) | `OCCTCurve2DHatch` | always add boundary elements FORWARD (the #1496 defect) | ✅ | ✅ | MATCH | not rewritten: it already compares the clockwise hatch with the counter-clockwise one |
### #1979 executed: `GccAnaBisectorTests.swift`, `GccAnaCirc2d2TanRadTests.swift`, `GccAnaCirc2dTanCenTests.swift`
Probe: `Scripts/repro/766-geom2d-gccana-bisector-circ/`. Every row was run red with the injection applied and green after it was reverted.
| GccAna Bisectors::Perpendicular bisector of two points | `OCCTGccAnaPnt2dBisec` | second point x + 2 | ✅ | ✅ | MATCH | either-axis direction to 0.01 inside `if let` |
| GccAna Bisectors::Angle bisectors of two lines | `OCCTGccAnaLin2dBisec` | second line direction (1, 1) | ✅ | ✅ | MATCH | count only |
| GccAna Bisectors::Bisector between line and point | `OCCTGccAnaLinPnt2dBisec` | point y + 1 | ✅ | ✅ | MATCH | type only |
| GccAna Bisectors::Bisectors between two circles | `OCCTGccAnaCirc2dBisec` | second centre x + 1 | ✅ | ✅ | MATCH | `count >= 1` |
| GccAna Bisectors::Bisectors between circle and line | `OCCTGccAnaCircLin2dBisec` | line y + 1 | ✅ | ✅ | MATCH | `count >= 1` |
| GccAna Bisectors::Bisectors between circle and point | `OCCTGccAnaCircPnt2dBisec` | point x + 1 | ✅ | ✅ | MATCH | `count >= 1` |
| GccAna Circ2d2TanRad Tests::circles through two points with radius | `OCCTGccAnaCirc2d2TanRadPntPnt` | second point x + 1 | ✅ | ✅ | MATCH | count and the input radius only; now pins the centres |
| GccAna Circ2d2TanRad Tests::circles tangent to two perpendicular lines | `OCCTGccAnaCirc2d2TanRadLineLin` | radius + 1 | ✅ | ✅ | MATCH | count only; now pins the four centres |
| GccAna Circ2dTanCen Tests::circle through point centered | `OCCTGccAnaCirc2dTanCenPntPnt` | centre x + 1 | ✅ | ✅ | MATCH | nested in `if let r` |
| GccAna Circ2dTanCen Tests::circle tangent to line centered | `OCCTGccAnaCirc2dTanCenLinPnt` | centre x + 1 | ✅ | ✅ | MATCH | nested in `if let r` |
### #1979 executed: `Issue553GccZeroRadiusTests.swift`
| Issue553 zero-radius circle solver arguments::circleBisectorRejectsZeroRadius | `OCCTGccAnaCirc2dBisec` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::circleBisectorAcceptsValidRadii | `OCCTGccAnaCirc2dBisec` | every occtValidCircleRadius guard refuses (valid radius refused) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::pointBisectorAnswersWhatZeroRadiusCannot | `OCCTGccAnaCircPnt2dBisec` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH | `if let` + `Issue.record`; now `#require` |
| Issue553 zero-radius circle solver arguments::circlePointBisectorAcceptsValidRadius | `OCCTGccAnaCircPnt2dBisec` | every occtValidCircleRadius guard refuses (valid radius refused) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::circleLineBisectorRejectsZeroRadius | `OCCTGccAnaCircLin2dBisec` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::tangentParallelLinesRejectZeroRadius | `OCCTGccAnaLin2dTanParCirc` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::tangentPerpendicularLinesRejectZeroRadius | `OCCTGccAnaLin2dTanPerCircLin` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::tangentLineThroughPointRejectsZeroRadius | `OCCTGccAnaLin2d2TanCircPnt` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::circleTangentToThreeCirclesRejectsZeroRadius | `OCCTGccAnaCirc2d3TanCircles` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::circleTangentToTwoCirclesAndPointRejectsZeroRadius | `OCCTGccAnaCirc2d2CirclesPoint` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::circleTangentToCircleAndTwoPointsRejectsZeroRadius | `OCCTGccAnaCirc2dCircle2Points` | every occtValidCircleRadius guard refuses (valid radius refused) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::lineCircleIntersectionRejectsZeroRadius | `OCCTIntAna2dLinCirc` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::circleCircleIntersectionRejectsZeroRadius | `OCCTIntAna2dCircCirc` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::lineCircleExtremaRejectZeroRadius | `OCCTExtremaExtElC2dLinCirc` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::pointCircleExtremaRejectZeroRadius | `OCCTExtremaExtPElC2dCirc` | every occtValidCircleRadius guard refuses (valid radius refused) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::requestedRadiusOfZeroIsRejected | `OCCTGccAnaCirc2d2TanRadLineLin / Circ2d2TanRadPntPnt / Circ2dTanOnRadLin` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::requestedRadiusOfZeroIsRejectedOnCurves | `OCCTGeom2dGccCirc2dTanOnRad` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH | `guard` + `Issue.record`; now `#require` |
| Issue553 zero-radius circle solver arguments::requestedRadiusAcceptsValidValues | `OCCTGccAnaCirc2d2TanRadLineLin / Circ2d2TanRadPntPnt / Circ2dTanOnRadLin` | every occtValidCircleRadius guard refuses (valid radius refused) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::circleEdgeRejectsZeroRadius | `OCCTMakeEdge2dFromCircle` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::gceCircleFactoriesRejectZeroRadius | `OCCTCurve2DMakeCircleCenterRadius / OCCTCurve2DMakeCircleAxis` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH |  |
| Issue553 zero-radius circle solver arguments::parallelCircleRejectsCollapsingOffset | `OCCTCurve2DMakeCircleParallel` | every occtValidCircleRadius guard passes (zero radius reaches OCCT) | ✅ | ✅ | MATCH | `if let` + `Issue.record`; now `#require` |
| Issue553 zero-radius circle solver arguments::negativeRadiusWasAlreadyRejected | `OCCTGccAnaCirc2dBisec` | bisector wrapper passes abs(radius1) | ✅ | ✅ | MATCH |  |
### #1979 executed: `Issue562Curve2DKnotSplitDuplicateTests.swift`, `Issue615Curve2DNearestPointTests.swift`, `Issue619Curve2DContinuityEncodingTests.swift`
| Curve2D knot-splitting duplicates (#562)::A curve with more splits than the first-pass buffer reports all of them | `Curve2D.splitIndicesAtDiscontinuities (retry)` | no retry: result cut at 256 | ✅ | ✅ | MATCH |  |
| Curve2D knot-splitting duplicates (#562)::The retry boundary is exact at 255, 256 and 257 splits | `Curve2D.splitIndicesAtDiscontinuities (retry)` | no retry: result cut at 256 | ✅ | ✅ | MATCH |  |
| Curve2D reports the nearest point over the range (#615)::A half circle queried from below answers with the near end, not the far side | `occtNearestProjectionOnCurve2d` | pre-#615 projection: Geom2dAPI_ProjectPointOnCurve interior extrema only, ends ignored | ✅ | ✅ | MATCH |  |
| Curve2D reports the nearest point over the range (#615)::A point on the circle but off the arc answers with the arc's end | `occtNearestProjectionOnCurve2d` | pre-#615 projection: Geom2dAPI_ProjectPointOnCurve interior extrema only, ends ignored | ✅ | ✅ | MATCH |  |
| Curve2D reports the nearest point over the range (#615)::A point past the end is answered, not refused | `occtNearestProjectionOnCurve2d` | pre-#615 projection: Geom2dAPI_ProjectPointOnCurve interior extrema only, ends ignored | ✅ | ✅ | MATCH |  |
| Curve2D reports the nearest point over the range (#615)::All four nearest-point spellings agree on every query | `OCCTPoint2DDistanceToCurve` | Point2D.distance(to: curve) + 1e-3 | ✅ | ✅ | MATCH |  |
| Curve2D reports the nearest point over the range (#615)::The 2D and 3D answers match for the same geometry | `occtNearestProjectionOnCurve2d` | pre-#615 projection: Geom2dAPI_ProjectPointOnCurve interior extrema only, ends ignored | ✅ | ✅ | MATCH |  |
| Curve2D measured continuity encoding after the retirement (#619)::An analytic 2D curve reports CN as ordinal 6, the old encoding's 99 is unreachable | `OCCTCurve2DGetContinuity` | pre-#485 encoding in Curve2D.continuity (C1 = 1, C2 = 2, CN = 99) | ✅ | ✅ | MATCH |  |
| Curve2D measured continuity encoding after the retirement (#619)::A C1 pcurve reports C1 as ordinal 2, not 1 | `OCCTCurve2DGetContinuity` | pre-#485 encoding in Curve2D.continuity (C1 = 1, C2 = 2, CN = 99) | ✅ | ✅ | MATCH |  |
| Curve2D measured continuity encoding after the retirement (#619)::A raw threshold of 2 now admits a merely-C1 pcurve; satisfies(.c2) still refuses it | `OCCTCurve2DGetContinuity` | pre-#485 encoding in Curve2D.continuity (C1 = 1, C2 = 2, CN = 99) | ✅ | ✅ | MATCH |  |
### #1979 executed: `Curve2DBisectorTests.swift`, `Curve2DBoundingBoxTests.swift`, `Curve2DBSplineExtrasTests.swift`
Probe: `Scripts/repro/766-geom2d-bisector-bbox-weights/`. Every row was run red with the injection applied and green after it was reverted.
| Curve2D Bisector Tests::Bisector between two lines | `OCCTCurve2DBisectorCC` | return the curve even when IsEmpty() | ✅ | ✅ | MATCH | the assertion sat inside `if let bis` and the kernel returns empty, so nothing was ever checked; now pins nil |
| Curve2D Bisector Tests::Bisector between point and line | `OCCTCurve2DBisectorPC` | move the point 1 up | ✅ | ✅ | MATCH | `pts.count >= 2` inside `if let bis`; now pins the parabola y = (x^2 + 25) / 10 |
| Curve2D Bounding Box Tests::Bounding box of segment | `OCCTCurve2DGetBoundingBox` | BndLib_Add2dCurve gap 0 -> 1 | ✅ | ✅ | MATCH | one-sided bounds; now pins all four |
| Curve2D Bounding Box Tests::Bounding box of circle | `OCCTCurve2DGetBoundingBox` | BndLib_Add2dCurve gap 0 -> 1 | ✅ | ✅ | MATCH | one-sided bounds; now pins all four |
| Curve2D_BSpline_Extras::getWeight | `OCCTCurve2DBSplineGetWeight` | weight + 1 | ✅ | ✅ | MATCH | nested in `if let c` |
| Curve2D_BSpline_Extras::getAllWeights | `OCCTCurve2DBSplineGetWeights` | each weight + 1 | ✅ | ✅ | MATCH | `!weights.isEmpty` inside `if let c`; now pins six weights of 1 |
| Curve2D_BSpline_Extras::setPeriodic | `OCCTCurve2DBSplineSetPeriodic` | return true without SetPeriodic() | ✅ | ✅ | MATCH | `#expect(true)`; now pins the non-periodic -> periodic change and 6 poles |
