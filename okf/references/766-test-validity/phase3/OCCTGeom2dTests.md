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
