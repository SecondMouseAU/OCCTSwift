# Phase 3: OCCTCurveTests Injection Matrix

**Target**: `OCCTCurveTests` (530 tests) — 3D curves, arc length, extrema, interpolation
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (crash fixes #345, #603, #636, #477, #408)

---

## Test Inventory by Suite (Top by Count)

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| Issue554 3D conic degenerate dimensions | 26 | DG/CR |
| BSpline Curve 3D Manipulation Tests | 15 | WR |
| **Arc length stops being one quadrature per span (#603)** | **15** | **CR/WR (#603)** |
| Analytical conversion contract (#492) | 12 | WR |
| The nearest point is on the curve, not on its basis (#539) | 12 | WR |
| Curve3D Primitive Tests | 12 | WR |
| Curve3D Operations Tests | 11 | WR |
| An out-of-domain range measures the curve, not its extrapolation (#600) | 10 | WR |
| Bezier Curve Manipulation Tests | 9 | WR |
| Non-finite arc-length bounds report failure (#548) | 9 | DG/RF |
| Helix Curves | 9 | WR |
| Bezier Curve 3D Completions | 9 | WR |
| Curve3D arc-length accuracy on multi-span curves (#477) | 8 | CR/WR (#477) |
| BSplineCurve 3D Completions v121 | 8 | WR |
| Law Function Tests | 8 | WR |
| ... | ... | ... |

**Total**: 530 tests across ~90 suites

---

## Injection Matrix: Critical Crash-Related Tests First

### #345: gp_Dir Zero Vector Crash (Bridge Fix)

**Issue**: `gp_Dir` constructor throws `Standard_ConstructionError` for zero-length direction/normal vector. 49 bridge functions construct `gp_Dir`/`gp_Ax1`/`gp_Ax2`/`gp_Ax3`/`Geom_Direction` from caller-supplied doubles with no try/catch.

**Bridge Fix**: Wrapped all 49 in `try { } catch (...) { <safe fallback> }`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| mirrorAxisZeroDirection | `OCCTMakeMirrorAxis` → `gp_Dir` | Zero direction vector | Remove `try/catch` in bridge | ✅ SIGABRT | ✅ Pass | Uncaught `Standard_ConstructionError` |
| mirrorPlaneZeroNormal | `OCCTMakeMirrorPlane` → `gp_Dir` | Zero normal vector | Remove `try/catch` in bridge | ✅ SIGABRT | ✅ Pass | Uncaught `Standard_ConstructionError` |
| geomDirectionZeroVector | `OCCTGeomDirectionCreate` → `Geom_Direction` | Zero vector handled gracefully | N/A | N/A | ✅ Pass | `Geom_Direction` returns NaN, no exception |

### #603: CPnts_AbscissaPoint Single Quadrature (Bridge + Kernel Fix)

**Issue**: `CPnts_AbscissaPoint::Length` uses ONE fixed-order Gauss rule over whole range → arc length errors up to 1.7% (ellipse) / 3% (parabola).

**Bridge Fix**: Adaptive quadrature in `occtAdaptorArcLength` / `occtArcWalkToLength` — halve each `GeomAbs_CN` interval until two levels agree to 1e-9 relative.

**Kernel Patch**: `0021` — `CPnts_AdaptiveIntegration.hxx` does same doubling for all 4 `Length` overloads and `Value`/`Values`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| A whole ellipse measures its own circumference, not 0.3-1.7% more | `Curve3D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature in bridge |  |  | Error up to 1.7% |
| A parabola over a wide range measures its arc, not 3% less | `Curve3D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature in bridge |  |  | Error 3% (worst case) |
| A hyperbola over a wide range measures its arc | `Curve3D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature in bridge |  |  | Error +0.067% |
| A whipping cubic Bezier | `Curve3D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature in bridge |  |  | Error -0.189% |
| The closed forms stay exact | `Curve3D.arcLength` → closed-form paths | Control | No injection |  |  | Line/circle/2-pole Bezier |
| Accurate sub-ranges sum to whole | `Curve3D.arcLength(from:to:)` → `occtArcWalkToLength` | Single quadrature | Remove adaptive quadrature |  |  | Error accumulates |
| A wound range winds correctly | `Curve3D.arcLength(from:to:)` | Single quadrature | Remove adaptive quadrature |  |  | Error accumulates |
| A fraction of the length matches | `Curve3D.arcLength(from:to:)` | Single quadrature | Remove adaptive quadrature |  |  | Error accumulates |
| A negative abscissa measures correctly | `Curve3D.arcLength(from:to:)` | Single quadrature | Remove adaptive quadrature |  |  | Error accumulates |
| A 2D ellipse measures correctly | `Curve2D.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature |  |  | Error accumulates |
| An elliptical edge measures correctly | `Shape.edgeArcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature |  |  | Error accumulates |
| A wire containing elliptical edges | `Wire.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature |  |  | Error accumulates |
| An EdgeCurve measures correctly | `EdgeCurve.arcLength` → `occtAdaptorArcLength` | Single quadrature | Remove adaptive quadrature |  |  | Error accumulates |
| parameterAtLength walks correctly | `Curve3D.parameterAtLength` → `occtArcWalkToLength` | Single quadrature | Remove adaptive quadrature |  |  | Inverse also wrong |

**Note**: Injection testing showed that removing the adaptive quadrature loop (returning single quadrature) did not cause test failures with the current test expectations. The tests use independent references (Richardson-extrapolated chord sum and Simpson quadrature) with 1e-9 tolerance. Further investigation needed to confirm the injection actually reaches the code path under test.

### #636: Curve3D extrema on Parallel Curves (Bridge Fix)

**Issue**: `BRepExtrema_ExtCC` crashes (SIGSEGV) when edges are parallel — `ExtCC` returns `isParallel=true` but caller accesses points without checking.

**Bridge Fix**: Guard with `if (result.isParallel) { return result; }` before accessing points.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Two unbounded parallel lines: extrema is empty, not a crash | `Curve3D.extrema(to:)` → `BRepExtrema_ExtCC` | Parallel crash | Remove `isParallel` guard |  |  | SIGSEGV |
| Two bounded parallel segments with overlapping ranges: extrema is empty | `Curve3D.extrema(to:)` → `BRepExtrema_ExtCC` | Parallel crash | Remove `isParallel` guard |  |  | SIGSEGV |
| minDistance(to:) keeps reporting true offset for parallel pairs | `Curve3D.minDistance(to:)` → `BRepExtrema_ExtCC` | Parallel crash | Remove `isParallel` guard |  |  | SIGSEGV |
| The extrema doc snippet is runnable and its printed values are true | `Curve3D.extrema(to:)` → `BRepExtrema_ExtCC` | Control | No injection |  |  | Should pass |

### #477: Arc-Length Per-Span Split (Bridge Fix)

**Issue**: `GCPnts_AbscissaPoint::Length` splits at `GeomAbs_CN` intervals but not within → 8x3 ellipse 0.337% error over `[0,2pi]`, exact over `[0,pi/2]`.

**Bridge Fix**: Adaptive quadrature inside each interval — halve until two levels agree to 1e-9.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| length of a multi-span interpolated BSpline matches reference | `Curve3D.arcLength` → `occtAdaptorArcLength` | No per-span adaptive | Remove adaptive quadrature |  |  | Error > 1e-9 |
| length(from:to:) over a sub-range matches reference | `Curve3D.arcLength(from:to:)` → `occtArcWalkToLength` | No per-span adaptive | Remove adaptive quadrature |  |  | Error > 1e-9 |
| all five arc-length spellings agree with same reference | `Curve3D.arcLength` / `length` / `parameterAtLength` | No per-span adaptive | Remove adaptive quadrature |  |  | Inconsistent results |

### #408: Arc-Length Failure vs Zero-Length Distinguishability

**Issue**: Genuine zero-width interval returns 0.0, not failure sentinel; failing computation distinguishable from real zero.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| A genuine zero-width interval reports exactly 0.0, not a failure sentinel | `Curve3D.arcLength(from:to:)` → `occtArcWalkToLength` | Zero vs failure confusion | Remove distinction |  |  | Wrong result |
| A genuinely failing computation is distinguishable from real zero-length | `Curve3D.arcLength(from:to:)` → `occtArcWalkToLength` | Zero vs failure confusion | Remove distinction |  |  | Wrong result |

---

## Injection Matrix: Borrowed Handles (Curve3D *Properties)

**From #965**: 7 `*Properties` views in Curve3D.swift stored raw handles. Fixed by conforming to `NativeHandleView`.

| Test | Properties Type | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| the chained access the issue reports reads the right radius | Circle/Ellipse/Hyperbola/Parabola/BSpline/Bezier | Raw handle storage | Revert to `fileprivate let handle` |  |  | SIGSEGV (use-after-free) |
| every Curve3D *Properties accessor keeps its parent alive | Same | Raw handle storage | Revert to raw handle |  |  | SIGSEGV |
| a view outliving its parent still reads the right values | Same | Raw handle storage | Revert to raw handle |  |  | SIGSEGV |
| a view outliving its parent survives 400 intervening allocations | Same | Raw handle storage | Revert to raw handle |  |  | SIGSEGV |

---

## Injection Matrix: Null-Handle Guards (Curve3D Entry Points)

From `check-null-handle-guards.py` ALLOWED table - 14 Curve3D entry points need `curve.IsNull()` guard.

| Bridge Function | OCCT Call | Test Coverage | Injection Status |
|-----------------|-----------|---------------|------------------|
| `OCCTGeomLibToolParameter3D` | `GeomLib_Tool::Parameter` | AnalysisTests | |
| `OCCTGeomConvertIsCanonical` | `GeomConvert_CurveToAnaCurve::IsCanonical` | CurveTests | |
| `OCCTApproxSameParameter` (3x) | `Approx_SameParameter` | CurveTests | |
| `OCCTExtremaExtCC` | `GeomAdaptor_Curve` | AnalysisTests | |
| `OCCTExtremaExtCCPoint` | `GeomAdaptor_Curve` | AnalysisTests | |
| `OCCTExtremaExtCS` | `GeomAdaptor_Curve` + Surface | AnalysisTests | |
| `OCCTExtremaExtCSPoint` | `GeomAdaptor_Curve` + Surface | AnalysisTests | |
| `OCCTExtremaLocateExtCC` | `GeomAdaptor_Curve` | AnalysisTests | |
| `OCCTGeom2dConvertApproxArcsSegments` | `Geom2dAdaptor_Curve` | Geom2dTests | |
| `OCCTGeomFillCoonsAlgPatchEval` | `GeomAdaptor_Curve` (local handle) | StressTests | |
| `OCCTBRepToolsEvalAndUpdateTol` | `BRepTools::EvalAndUpdateTol` (local handle) | StressTests | |

---

## Injection Procedure Per Test

```bash
# 1. Focused compile (3s)
swift build --target OCCTCurveTests

# 2. For each test:
#    a. Identify defect and bridge function
#    b. Create injection (remove try/catch, remove adaptive quadrature, remove isParallel guard, etc.)
#    c. Run single test: swift test --filter <TestStructName>
#    d. Confirm FAIL (red) - crash, wrong result, or timeout
#    e. Restore fix
#    f. Confirm PASS (green)
#    g. Record in matrix above

# 3. Create PR for OCCTCurveTests
# 4. User reviews PR → merge what makes sense
# 5. Proceed to next domain (OCCTGeom2dTests)
```

---

## Kernel Crash Protocol

Per `upstream-occt-patch-process.md`:
- If injection triggers kernel crash (SIGSEGV/SIGABRT not in CLAUDE.md):
  1. Create reproducer in `Scripts/repro/766-crash-<issue>/`
  2. File upstream issue with reproducer
  3. **Do NOT attempt bridge fix** — prefer kernel fix
  4. Note existing TSan issues waiting to be fixed
  5. Link to #766

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| Issue554 3D conic degenerate dimensions | 26 |  |  |  |  |
| BSpline Curve 3D Manipulation Tests | 15 |  |  |  |  |
| **Arc length stops being one quadrature per span (#603)** | **15** |  |  |  |  |
| Analytical conversion contract (#492) | 12 |  |  |  |  |
| The nearest point is on the curve (#539) | 12 |  |  |  |  |
| Curve3D Primitive Tests | 12 |  |  |  |  |
| Curve3D Operations Tests | 11 |  |  |  |  |
| An out-of-domain range measures the curve (#600) | 10 |  |  |  |  |
| Bezier Curve Manipulation Tests | 9 |  |  |  |  |
| Non-finite arc-length bounds report failure (#548) | 9 |  |  |  |  |
| Helix Curves | 9 |  |  |  |  |
| Bezier Curve 3D Completions | 9 |  |  |  |  |
| Curve3D arc-length accuracy on multi-span curves (#477) | 8 |  |  |  |  |
| BSplineCurve 3D Completions v121 | 8 |  |  |  |  |
| Law Function Tests | 8 |  |  |  |  |
| ... | ... |  |  |  |  |

**Total**: 530 tests

## Measured records (#766 execution)

Rows appended per PR, each run red under the named injection and green once it was reverted.

| Suite | Test | Bridge function | Injection | Red (first failing line) | Green | Parity | Note |
|---|---|---|---|---|---|---|---|
| Adaptor3d IsoCurve | U-iso points on cylinder face | `OCCTAdaptor3dIsoCurveEval` | U and V iso type swapped | `Adaptor3dIsoCurveTests.swift:35 abs(p.z - zk) < 1e-6` | ✅ | MATCH | Rewritten: picked any face, checked only the count |
| Adaptor3d IsoCurve | V-iso points on cylinder face | `OCCTAdaptor3dIsoCurveEval` | U and V iso type swapped | `Adaptor3dIsoCurveTests.swift:50 abs(p.x - 10 * cos(u)) < 1e-9` | ✅ | MATCH | Rewritten: picked any face, checked only the count |
| Adaptor3d IsoCurve | U-iso curve edge from face | `OCCTAdaptor3dIsoCurveEdge` | U and V iso type swapped | `Adaptor3dIsoCurveTests.swift:65 edge.edgeAdaptorCurveType == 0` | ✅ | MATCH | Rewritten: checked only shapeType == .edge |
| Adaptor3d IsoCurve | V-iso curve edge from face | `OCCTAdaptor3dIsoCurveEdge` | U and V iso type swapped | `Adaptor3dIsoCurveTests.swift:84 edge.edgeAdaptorCurveType == 1` | ✅ | MATCH | Rewritten: checked only shapeType == .edge |
| Approx CurvilinearParameter | Arc-length reparameterize circle edge | `OCCTApproxCurvilinearParameter` | return the input edge instead of Approx_CurvilinearParameter's curve | `ApproxCurvilinearParameterTests.swift:27 result.edgeAdaptorCurveType == 6` | ✅ | MATCH | Rewritten: checked only isValid |
| Approx SameParameter Tests | same parameter on line/plane | `OCCTApproxSameParameter` | IsSameParameter() negated | `ApproxSameParameterTests.swift:25 r.isSameParameter` | ✅ | MATCH | Rewritten: `if let` let a nil result pass unchecked |
| Analytical conversion contract (#492) | Curve result does not alias the input curve | `OCCTGeomConvertCurveToAnalytical` | return the input curve handle instead of the Copy() | `AnalyticalConversionContractTests.swift:61 Self.dist(before, after) < 1e-9` | ✅ | MATCH |  |
| Analytical conversion contract (#492) | Range-aware curve result does not alias the input curve | `OCCTGeomConvertCurveToAnalytical` | return the input curve handle instead of the Copy() | `AnalyticalConversionContractTests.swift:83 Self.dist(before, after) < 1e-9` | ✅ | MATCH |  |
| Analytical conversion contract (#492) | Surface result does not alias the input surface | `OCCTGeomConvertSurfToAnalytical` | return the input surface handle instead of the Copy() | `AnalyticalConversionContractTests.swift:97 Self.dist(before, after) < 1e-9` | ✅ | MATCH |  |
| Analytical conversion contract (#492) | Gap-returning surface result does not alias the input surface | `OCCTGeomConvertSurfToAnalytical` | return the input surface handle instead of the Copy() | `AnalyticalConversionContractTests.swift:111 Self.dist(before, after) < 1e-9` | ✅ | MATCH |  |
| Analytical conversion contract (#492) | Both curve spellings agree over the curve's own range | `OCCTGeomConvertCurveToAnalytical` | Swift toAnalyticalWithGap starts its range 1e-3 late | `AnalyticalConversionContractTests.swift:135 Self.dist(plain.point(at: u), ranged.curve.point(at: u)) < 1e-9` | ✅ | MATCH |  |
| Analytical conversion contract (#492) | Full-range curve spelling agrees with the explicit-range spelling | `OCCTGeomConvertCurveToAnalytical` | Swift toAnalyticalWithGap starts its range 1e-3 late | `AnalyticalConversionContractTests.swift:160 full.newLast == explicit.newLast` | ✅ | MATCH |  |
| Analytical conversion contract (#492) | Both surface spellings agree on success and on geometry | `OCCTGeomConvertSurfToAnalytical` | Swift Surface.toAnalytical returns self unconverted | `AnalyticalConversionContractTests.swift:181 (plain == nil) == (withGap == nil)` | ✅ | MATCH |  |
| Analytical conversion contract (#492) | Already-analytical inputs convert rather than being rejected | `OCCTGeomConvertCurveToAnalytical` | both conversions report failure | `AnalyticalConversionContractTests.swift:201 circle.toAnalytical(tolerance: 1e-4) != nil` | ✅ | MATCH |  |
| Analytical conversion contract (#492) | Freeform inputs are rejected by every spelling | `OCCTGeomConvertCurveToAnalytical` | Swift toAnalytical returns self unconverted | `AnalyticalConversionContractTests.swift:219 curve.toAnalytical(tolerance: 1e-6) == nil` | ✅ | MATCH |  |
| Analytical conversion contract (#492) | UV-bounded conversion recognizes a plane over full bounds and over a sub-range | `OCCTGeomConvertSurfToAnalyticalBounded` | both conversions report failure | `AnalyticalConversionContractTests.swift:249 full != nil` | ✅ | MATCH |  |
| Analytical conversion contract (#492) | UV-bounded conversion rejects inverted bounds instead of trapping | `OCCTGeomConvertSurfToAnalyticalBounded` | bridge swaps inverted UV bounds into order | `AnalyticalConversionContractTests.swift:274 bspline.toAnalyticalWithGap(... inverted ...) == nil` | ✅ | MATCH |  |
| Analytical conversion contract (#492) | Explicit sub-range reparameterizes the recognized curve | `OCCTGeomConvertCurveToAnalytical` | newLast set to newFirst | `AnalyticalConversionContractTests.swift:304 result.newLast - result.newFirst > 0` | ✅ | MATCH | Pinned newFirst/newLast to the kernel's values |
| Batch Curve3D Evaluation | Evaluate grid on circle | `OCCTCurve3DEvaluateGrid` | results written in reverse order | `BatchCurve3DTests.swift:23 abs(p.x - 5 * cos(u)) < 1e-10` | ✅ | MATCH | Rewritten: checked only the first sample |
| Batch Curve3D Evaluation | Evaluate grid D1 on circle | `OCCTCurve3DEvaluateGridD1` | D1.Y negated | `BatchCurve3DTests.swift:40 simd_distance(results[0].tangent, SIMD3(0, 5, 0)) < 1e-10` | ✅ | MATCH | Rewritten: checked the first tangent's x and y only |
| Batch Curve3D Evaluation | Grid matches individual evaluation | `OCCTCurve3DEvaluateGrid` | results written in reverse order | `BatchCurve3DTests.swift:58 simd_distance(g, p) < 1e-10` | ✅ | MATCH |  |
| Bezier Conversion Tests | Cylinder converts to Bezier | `OCCTShapeConvertToBezier` | return the input shape unconverted | `BezierConversionTests.swift:28 bezier.subShapeCount(ofType: .edge) == 17` | ✅ | MATCH | Rewritten: faceCount > 0 and edgeCount > 0 passed an unconverted shape |
| Bezier Conversion Tests | Sphere converts to Bezier | `OCCTShapeConvertToBezier` | return the input shape unconverted | `BezierConversionTests.swift:40 bezier.subShapeCount(ofType: .edge) == 6` | ✅ | MATCH | Rewritten: faceCount > 0 passed an unconverted shape |
| Bezier Conversion Tests | Box converts to Bezier | `OCCTShapeConvertToBezier` | return the input shape unconverted | `BezierConversionTests.swift:54 Self.faceTypes(bezier) == Array(repeating: 5, count: 6)` | ✅ | MATCH | Rewritten: 6 faces and 12 edges also describe the unconverted box |
| Bezier Conversion Tests | Cone converts to Bezier | `OCCTShapeConvertToBezier` | return the input shape unconverted | `BezierConversionTests.swift:68 bezier.subShapeCount(ofType: .edge) == 17` | ✅ | MATCH | Rewritten: faceCount > 0 passed an unconverted shape |
| BSpline Bezier Patch Grid | BSpline surface decomposes to Bezier patches | `OCCTSurfaceBSplineToBezierPatches` | NbUPatches reported one too many | `BezierPatchGridTests.swift:39 grid.uCount == 1` | ✅ | MATCH | Rewritten: `if let` and >= 1 bounds |
| BSplineCurve 3D Completions v121 | SetNotPeriodic on non-periodic curve | `OCCTCurve3DBSplineSetNotPeriodic` | SetPeriodic called instead | `BSplineCurve3DCompletionsV121Tests.swift:34 !curve.isPeriodic` | ✅ | MATCH | Rewritten: checked only the returned Bool |
| BSplineCurve 3D Completions v121 | IncreaseMultiplicity | `OCCTCurve3DBSplineIncreaseMultiplicity` | IncreaseMultiplicity skipped | `BSplineCurve3DCompletionsV121Tests.swift:46 Self.near(curve.bsplineKnotSequence(), [0, 0, 0, 0, 0.5, 0.5, 1, 1, 1, 1])` | ✅ | MATCH | Rewritten: checked only the returned Bool |
| BSplineCurve 3D Completions v121 | IncrementMultiplicity | `OCCTCurve3DBSplineIncrementMultiplicity` | IncrementMultiplicity skipped | `BSplineCurve3DCompletionsV121Tests.swift:56 Self.near(curve.bsplineKnotSequence(), [0, 0, 0, 0, 0.3, 0.3, 0.7, 0.7, 1, 1, 1, 1])` | ✅ | MATCH | Rewritten: checked only the returned Bool |
| BSplineCurve 3D Completions v121 | Reverse parameterization | `OCCTCurve3DBSplineReverse` | Reverse skipped | `BSplineCurve3DCompletionsV121Tests.swift:66 simd_distance(curve.startPoint, SIMD3(10, 0, 0)) < 1e-12` | ✅ | MATCH |  |
| BSplineCurve 3D Completions v121 | SetKnots batch | `OCCTCurve3DBSplineSetKnots` | SetKnots skipped | `BSplineCurve3DCompletionsV121Tests.swift:75 curve.domain == 0...2` | ✅ | MATCH | Rewritten: checked only the returned Bool |
| BSplineCurve 3D Completions v121 | SetKnot single index | `OCCTCurve3DBSplineSetKnot` | SetKnot skipped | `BSplineCurve3DCompletionsV121Tests.swift:87 Self.near(seq, [-1, -1, -1, -1, 3, 3, 3, 3])` | ✅ | MATCH |  |
| BSplineCurve 3D Completions v121 | SetOrigin fails on non-periodic | `OCCTCurve3DBSplineSetOrigin` | report success without calling SetOrigin on a non-periodic curve | `BSplineCurve3DCompletionsV121Tests.swift:95 !curve.bsplineSetOrigin(index: 1)` | ✅ | MATCH |  |
| BSplineCurve 3D Completions v121 | MovePointAndTangent | `OCCTCurve3DBSplineMovePointAndTangent` | errorStatus test inverted | `BSplineCurve3DCompletionsV121Tests.swift:110 !r` | ✅ | MATCH |  |
| BSplineCurve 3D Completions v121 | MovePointAndTangent with unordered independent conditions | `OCCTCurve3DBSplineMovePointAndTangent` | errorStatus test inverted | `BSplineCurve3DCompletionsV121Tests.swift:126 r` | ✅ | MATCH |  |
| BSplineCurve3D LocalD v129 | LocalD0 matches LocalValue | `OCCTCurve3DBSplineLocalD0` | LocalD0 y + 0.5 (and separately LocalValue x + 0.5) | `BSplineCurve3DLocalDTests.swift:39 Self.near(val, d0)` | ✅ | MATCH | Strengthened: pinned to the kernel point, not only to each other |
| BSplineCurve3D LocalD v129 | LocalD1 returns point + tangent | `OCCTCurve3DBSplineLocalD1` | LocalD1 V1.x + 0.5 | `BSplineCurve3DLocalDTests.swift:50 Self.near(result.d1, Self.d1)` | ✅ | MATCH | Rewritten: asserted only \|d1\| > 0.01 |
| BSplineCurve3D LocalD v129 | LocalD2 returns curvature information | `OCCTCurve3DBSplineLocalD2` | LocalD2 V2.y + 0.5 | `BSplineCurve3DLocalDTests.swift:60 Self.near(result.d2, Self.d2)` | ✅ | MATCH | Rewritten: never checked d2 |
| BSplineCurve3D LocalD v129 | LocalD3 returns all derivatives | `OCCTCurve3DBSplineLocalD3` | LocalD3 V3.y + 0.5 | `BSplineCurve3DLocalDTests.swift:71 Self.near(result.d3, Self.d3)` | ✅ | MATCH | Rewritten: never checked d2 or d3 |
| BSplineCurve3D LocalD v129 | LocalDN matches D1 for n=1 | `OCCTCurve3DBSplineLocalDN` | LocalDN y + 0.5 | `BSplineCurve3DLocalDTests.swift:80 Self.near(dn1, d1result.d1)` | ✅ | MATCH |  |
| Bezier Curve 3D Completions | StartPoint and EndPoint | `OCCTCurve3DBezierStartPoint` | StartPoint and EndPoint swapped | `BezierCurve3DCompletionTests.swift:24 simd_distance(c.bezierStartPoint, SIMD3(0, 0, 0)) < 1e-10` | ✅ | MATCH | Rewritten: `if let` body, x only |
| Bezier Curve 3D Completions | GetPoles bulk | `OCCTCurve3DBezierGetPoles` | each pole's Y written into X | `BezierCurve3DCompletionTests.swift:32 p == Self.open` | ✅ | MATCH | Rewritten: `if let` body, x only |
| Bezier Curve 3D Completions | GetWeights returns nil for non-rational | `OCCTCurve3DBezierGetWeights` | report all-1.0 weights for a non-rational curve | `BezierCurve3DCompletionTests.swift:39 c.bezierWeights == nil` | ✅ | MATCH | Rewritten: accepted nil or all-1.0, and `if let` hid a nil curve |
| Bezier Curve 3D Completions | GetWeights returns values for rational | `OCCTCurve3DBezierGetWeights` | Weights() treated as null | `BezierCurve3DCompletionTests.swift:48 c.bezierWeights == [1.0, 2.0, 1.0]` | ✅ | MATCH |  |
| Bezier Curve 3D Completions | IsClosed for open curve | `OCCTCurve3DBezierIsClosed` | IsClosed() negated | `BezierCurve3DCompletionTests.swift:54 !c.bezierIsClosed` | ✅ | MATCH |  |
| Bezier Curve 3D Completions | IsClosed for closed curve | `OCCTCurve3DBezierIsClosed` | IsClosed() negated | `BezierCurve3DCompletionTests.swift:67 c.bezierIsClosed` | ✅ | MATCH |  |
| Bezier Curve 3D Completions | IsPeriodic always false for Bezier | `OCCTCurve3DBezierIsPeriodic` | IsPeriodic() negated | `BezierCurve3DCompletionTests.swift:73 !c.bezierIsPeriodic` | ✅ | MATCH |  |
| Bezier Curve 3D Completions | Continuity is CN for Bezier | `OCCTCurve3DBezierContinuity` | Continuity() - 1 | `BezierCurve3DCompletionTests.swift:79 c.bezierContinuity == 6` | ✅ | MATCH |  |
| Bezier Curve 3D Completions | IsCN always true for Bezier | `OCCTCurve3DBezierIsCN` | IsCN() negated | `BezierCurve3DCompletionTests.swift:85 c.bezierIsCN(0)` | ✅ | MATCH |  |
| Bezier Curve Manipulation Tests | degreeAndPoleCount | `OCCTCurve3DBezierDegree` | Degree() + 1 | `BezierCurveManipulationTests.swift:29 bez.bezier.degree == 3` | ✅ | MATCH |  |
| Bezier Curve Manipulation Tests | isRational | `OCCTCurve3DBezierIsRational` | IsRational() negated | `BezierCurveManipulationTests.swift:35 !bez.bezier.isRational` | ✅ | MATCH |  |
| Bezier Curve Manipulation Tests | getPole | `OCCTCurve3DBezierGetPole` | index + 1 read | `BezierCurveManipulationTests.swift:41 Self.near(bez.bezier.pole(at: i + 1), p)` | ✅ | MATCH | Strengthened: all four poles, not pole 1 alone |
| Bezier Curve Manipulation Tests | setPole | `OCCTCurve3DBezierSetPole` | SetPole skipped | `BezierCurveManipulationTests.swift:48 Self.near(bez.bezier.pole(at: 2), SIMD3(3, 8, 0))` | ✅ | MATCH |  |
| Bezier Curve Manipulation Tests | segment | `OCCTCurve3DBezierSegment` | Segment skipped | `BezierCurveManipulationTests.swift:58 Self.near(bez.bezier.pole(at: 1), SIMD3(2.40625, 2.8125, 0))` | ✅ | MATCH | Rewritten: checked only the returned Bool |
| Bezier Curve Manipulation Tests | increaseDegree | `OCCTCurve3DBezierIncreaseDegree` | Increase skipped | `BezierCurveManipulationTests.swift:68 bez.bezier.degree == 5` | ✅ | MATCH |  |
| Bezier Curve Manipulation Tests | insertPoleAfter | `OCCTCurve3DBezierInsertPoleAfter` | InsertPoleAfter skipped | `BezierCurveManipulationTests.swift:78 bez.bezier.poleCount == 5` | ✅ | MATCH |  |
| Bezier Curve Manipulation Tests | removePole | `OCCTCurve3DBezierRemovePole` | RemovePole skipped | `BezierCurveManipulationTests.swift:91 bez.bezier.poleCount == 4` | ✅ | MATCH |  |
| Bezier Curve Manipulation Tests | setWeight | `OCCTCurve3DBezierSetWeight` | SetWeight skipped | `BezierCurveManipulationTests.swift:98 bez.bezier.isRational` | ✅ | MATCH |  |
| BiTgte CurveOnEdge v0.112 | createFromEdges | `OCCTBiTgteCurveOnEdgeDomain` | LastParameter + 1 | `BiTgteCurveOnEdgeTests.swift:36 c.domain == 0...10` | ✅ | MATCH | Rewritten: checked only that the bounds were finite |
| BiTgte CurveOnEdge v0.112 | evaluatePoint | `OCCTBiTgteCurveOnEdgeValue` | D0 z + 1 | `BiTgteCurveOnEdgeTests.swift:43 simd_distance(curve.point(at: mid), SIMD3(-5, -5, 5)) < 1e-9` | ✅ | MATCH | Rewritten: checked only that the point was finite |
| BiTgte CurveOnEdge v0.112 | domainIsValid | `OCCTBiTgteCurveOnEdgeDomain` | LastParameter + 1 | `BiTgteCurveOnEdgeTests.swift:49 abs(curve.domain.upperBound - curve.domain.lowerBound - 10) < 1e-12` | ✅ | MATCH | Rewritten: upper >= lower held for any domain |
| BiTgte CurveOnEdge v0.112 | sameEdgeCreation | `OCCTBiTgteCurveOnEdgeValue` | D0 z + 1 (and LastParameter + 1) | `BiTgteCurveOnEdgeTests.swift:61 simd_distance(c.point(at: 5), SIMD3(-5, -5, 0)) < 1e-9` | ✅ | MATCH | Rewritten: checked only a finite lower bound |
| BRepAdaptor PCurve | PCurve params on box face | `OCCTEdgePCurveParams` | LastParameter halved | `BRepAdaptorPCurveTests.swift:36 params.last == 30` | ✅ | MATCH | Rewritten: any increasing range passed |
| BRepAdaptor PCurve | PCurve value evaluation | `OCCTEdgePCurveValue` | u reported as v | `BRepAdaptorPCurveTests.swift:48 abs(uv.x - 15) < 1e-9` | ✅ | MATCH | Rewritten: ended in #expect(Bool(true)), could not fail |
| BSplineApproxInterp, Constrained Least-Squares Fitting | basicApproximation | `OCCTBSplineApproxInterpMaxError` | maxError doubled plus 1e-6 (and, separately, done = false) | `BSplineApproxInterpTests.swift:31 abs(solver.maxError - 0.00022151330264909389) < 1e-9` | ✅ | MATCH | Rewritten: maxError >= 0 and domain != nil could not fail |
| BSplineApproxInterp, Constrained Least-Squares Fitting | withInterpolationConstraints | `OCCTBSplineApproxInterpMaxError` | maxError doubled plus 1e-6 (and, separately, done = false) | `BSplineApproxInterpTests.swift:57 abs(solver.maxError - 0.00027501864739553364) < 1e-9` | ✅ | MATCH |  |
| BSplineApproxInterp, Constrained Least-Squares Fitting | performOptimal | `OCCTBSplineApproxInterpPerformOptimal` | maxError doubled plus 1e-6 (and, separately, done = false) | `BSplineApproxInterpTests.swift:72 abs(solver.maxError - 0.00045471476354564305) < 1e-9` | ✅ | MATCH | Rewritten: domain != nil could not fail |
| BSplineApproxInterp, Constrained Least-Squares Fitting | setters | `OCCTBSplineApproxInterpSetProjectionTol` | maxError doubled plus 1e-6 (and, separately, done = false) | `BSplineApproxInterpTests.swift:99 solver.maxError < 1e-12` | ✅ | MATCH |  |
| BSplineApproxInterp: documented no-op / advisory contracts (#507) | The 3D fit tolerance does change the fitted curve | `OCCTBSplineApproxInterpSetConvergenceTol` | setConvergenceTolerance made a no-op | `BSplineApproxInterpContractTests.swift:58 Self.maxDeviation(a, b) > 1e-9` | ✅ | MATCH |  |
| BSplineApproxInterp: documented no-op / advisory contracts (#507) | setParametrizationAlpha / setMinPivot / setClosedTolerance / setKnotInsertionTolerance are no-ops | `OCCTBSplineApproxInterpSetClosedTol` | setClosedTolerance wired to the fit tolerance | `BSplineApproxInterpContractTests.swift:80 Self.maxDeviation(a, b) == 0.0` | ✅ | MATCH | A first injection, setMinPivot(1e-3) setting the fit tolerance, stayed green because 1e-3 is already the default tolerance |
| BSplineApproxInterp: documented no-op / advisory contracts (#507) | interpolatePoint is a no-op, with or without a kink | `OCCTBSplineApproxInterpInterpolatePoint` | interpolatePoint nudges the constrained point by 0.01 in z | `BSplineApproxInterpContractTests.swift:99 Self.maxDeviation(a, b) == 0.0` | ✅ | MATCH |  |
| BSplineApproxInterp: documented no-op / advisory contracts (#507) | performOptimal matches perform and ignores maxIterations | `OCCTBSplineApproxInterpPerformOptimal` | maxIterations <= 1 loosens the fit tolerance to 1e-1 | `BSplineApproxInterpContractTests.swift:117 Self.maxDeviation(a, b) == 0.0` | ✅ | MATCH |  |
| BSplineApproxInterp: documented no-op / advisory contracts (#507) | nbControlPoints and continuousIfClosed are advisory | `OCCTBSplineApproxInterpCreate` | nbControlPoints caps the maximum degree | `BSplineApproxInterpContractTests.swift:138 Self.maxDeviation(a, b) == 0.0` | ✅ | MATCH |  |
| BSplineApproxInterp: documented no-op / advisory contracts (#507) | setConvergenceTolerance and setProjectionTolerance drive one shared tolerance | `OCCTBSplineApproxInterpSetProjectionTol` | setProjectionTolerance assigns instead of taking the minimum | `BSplineApproxInterpContractTests.swift:166 Self.maxDeviation(a, b) == 0.0` | ✅ | MATCH |  |
| BSplineApproxInterp: documented no-op / advisory contracts (#507) | maxError is the worst back-projection distance from an input point to the fit | `OCCTBSplineApproxInterpMaxError` | maxError doubled plus 1e-6 | `BSplineApproxInterpContractTests.swift:208 abs(solver.maxError - 5.3473650477313526e-07) < 1e-12` | ✅ | MATCH |  |
