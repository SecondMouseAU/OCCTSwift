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
| BSpline Curve 3D Manipulation Tests | knotCount | `OCCTCurve3DBSplineKnotCount` | NbKnots() + 1 | `BSplineCurve3DManipulationTests.swift:38 bsp.bspline.knotCount == 5` | ✅ | MATCH | Rewritten: knotCount > 0 |
| BSpline Curve 3D Manipulation Tests | poleCount | `OCCTCurve3DBSplinePoleCount` | NbPoles() + 1 | `BSplineCurve3DManipulationTests.swift:43 bsp.bspline.poleCount == 7` | ✅ | MATCH | Rewritten: poleCount >= 5 |
| BSpline Curve 3D Manipulation Tests | degree | `OCCTCurve3DBSplineDegree` | Degree() + 1 | `BSplineCurve3DManipulationTests.swift:48 bsp.bspline.degree == 3` | ✅ | MATCH | Rewritten: degree >= 1 |
| BSpline Curve 3D Manipulation Tests | isRational | `OCCTCurve3DBSplineIsRational` | IsRational() negated | `BSplineCurve3DManipulationTests.swift:54 !bsp.bspline.isRational` | ✅ | MATCH | Rewritten: asserted nothing |
| BSpline Curve 3D Manipulation Tests | knotsArray | `OCCTCurve3DBSplineGetKnots` | knots doubled | `BSplineCurve3DManipulationTests.swift:59 Self.near(bsp.bspline.knots, Self.knots)` | ✅ | MATCH | Rewritten: count > 0 and last > first |
| BSpline Curve 3D Manipulation Tests | multiplicities | `OCCTCurve3DBSplineGetMults` | multiplicities + 1 | `BSplineCurve3DManipulationTests.swift:64 bsp.bspline.multiplicities == [4, 1, 1, 1, 4]` | ✅ | MATCH | Rewritten: count > 0 and first > 0 |
| BSpline Curve 3D Manipulation Tests | getPole | `OCCTCurve3DBSplineGetPole` | index + 1 read | `BSplineCurve3DManipulationTests.swift:69 Self.near(bsp.bspline.pole(at: 1), SIMD3(0, 0, 0))` | ✅ | MATCH | Rewritten: \|x\| < 1.0 on pole 1 |
| BSpline Curve 3D Manipulation Tests | setPole | `OCCTCurve3DBSplineSetPole` | SetPole skipped | `BSplineCurve3DManipulationTests.swift:78 Self.near(bsp.bspline.pole(at: 3), SIMD3(5, 7, 0))` | ✅ | MATCH |  |
| BSpline Curve 3D Manipulation Tests | getAndSetWeight | `OCCTCurve3DBSplineGetWeight` | Weight() + 0.5 | `BSplineCurve3DManipulationTests.swift:83 bsp.bspline.weight(at: 1) == 1.0` | ✅ | MATCH |  |
| BSpline Curve 3D Manipulation Tests | insertKnot | `OCCTCurve3DBSplineInsertKnot` | InsertKnot skipped | `BSplineCurve3DManipulationTests.swift:93 bsp.bspline.multiplicities == [4, 1, 2, 1, 4]` | ✅ | MATCH | Rewritten: knotCount >= before passed a skipped insert |
| BSpline Curve 3D Manipulation Tests | segment | `OCCTCurve3DBSplineSegment` | Segment skipped | `BSplineCurve3DManipulationTests.swift:103 abs(bsp.domain.lowerBound - 3.6055512754639891) < 1e-12` | ✅ | MATCH | Rewritten: checked only the returned Bool |
| BSpline Curve 3D Manipulation Tests | increaseDegree | `OCCTCurve3DBSplineIncreaseDegree` | IncreaseDegree skipped | `BSplineCurve3DManipulationTests.swift:114 bsp.bspline.degree == 4` | ✅ | MATCH |  |
| BSpline Curve 3D Manipulation Tests | resolution | `OCCTCurve3DBSplineResolution` | resolution doubled | `BSplineCurve3DManipulationTests.swift:122 abs(res - 0.00059678090076645284) < 1e-15` | ✅ | MATCH | Rewritten: res > 0 |
| BSpline Curve 3D Manipulation Tests | setPeriodic | `OCCTCurve3DBSplineSetPeriodic` | periodic flag inverted | `BSplineCurve3DManipulationTests.swift:129 !bsp.isPeriodic` | ✅ | MATCH | Rewritten: checked only the returned Bool |
| BSpline Curve 3D Manipulation Tests | removeKnot | `OCCTCurve3DBSplineRemoveKnot` | report success without removing | `BSplineCurve3DManipulationTests.swift:141 bsp.bspline.knotCount == 4` | ✅ | MATCH | Rewritten: asserted nothing |
| v0.143 Circle property extraction | Cylindrical face exposes revolutionProperties with correct radius | `OCCTFaceGetPrimaryAxis (radius computed in Swift, Face.revolutionProperties)` | Swift: radius scaled by 1.01 | `CirclePropertyTests.swift:19 abs(rp.radius - 5.0) < 1e-6` | ✅ | MATCH |  |
| v0.143 Circle property extraction | Circle through three points recovers correct centre and radius | `none: pure Swift circleThroughThreePoints` | Swift: centre offset by (0.01, 0, 0) | `CirclePropertyTests.swift:36 abs(simd_length(circle.center - SIMD3<Double>(0, 0, 0))) < 1e-9` | ✅ | MATCH | Swift-side geometry; the kernel counterpart is gce_MakeCirc |
| v0.143 Circle property extraction | Three collinear points → nil circle | `none: pure Swift circleThroughThreePoints` | Swift: collinearity guard skipped | `CirclePropertyTests.swift:45 circleThroughThreePoints(p1, p2, p3) == nil` | ✅ | MATCH | Swift-side geometry; the kernel counterpart is gce_MakeCirc |
| v0.143 Circle property extraction | Edge.circleProperties recovers a full-circle cap edge (#378) | `OCCTEdgeGetParameterBounds + OCCTEdgeGetPointAtParam (circle recovered in Swift)` | Swift: isFullCircle inverted (and, separately, centre offset) | `CirclePropertyTests.swift:63 Issue recorded (isFullCircle false for the full cap circle)` | ✅ | MATCH |  |
| Convert_CompBezierCurvesToBSplineCurve Tests | singleCubicSegment3D | `OCCTConvertCompBezierToBSpline` | pole x + 1 | `CompBezierToBSplineTests.swift:24 result.poles == seg` | ✅ | MATCH | Strengthened: all poles, knots and multiplicities; the old last-pole check force-unwrapped inside #expect |
| Convert_CompBezierCurvesToBSplineCurve Tests | twoCubicSegments3D | `OCCTConvertCompBezierToBSpline` | pole x + 1 | `CompBezierToBSplineTests.swift:44 result.poles == [...]` | ✅ | MATCH | Rewritten: poles.count >= 4 and knots.count >= 2 inside `if let` |
| Convert_CompBezierCurvesToBSplineCurve Tests | emptySegmentsReturnsNil | `none: Swift guard in CompBezierConverter.toBSpline` | Swift: empty input returns an empty result instead of nil | `CompBezierToBSplineTests.swift:55 result == nil` | ✅ | N/A | No kernel counterpart: the Swift guard rejects the input |
| Convert_CompBezierCurvesToBSplineCurve Tests | mismatchedSegmentSizesReturnsNil | `none: Swift guard in CompBezierConverter.toBSpline` | Swift: segment-size check skipped | `CompBezierToBSplineTests.swift:62 result == nil` | ✅ | N/A | No kernel counterpart: the Swift guard rejects the input |
| Convert_CompBezierCurvesToBSplineCurve Tests | manySegmentsExceedingCapacityReturnsNil | `OCCTConvertCompBezierToBSpline` | over-capacity result reported as success (empty) | `CompBezierToBSplineTests.swift:80 result == nil` | ✅ | MATCH |  |
| CompCurve Tests | concatenate3DCurves | `OCCTConcatenateCurves3D` | second curve not added | `CompCurveTests.swift:26 simd_distance(combined.endPoint, SIMD3(2, 1, 0)) < 1e-12` | ✅ | MATCH | Rewritten: checked only != nil |
| CompCurve Tests | concatenate2DCurves | `OCCTConcatenateCurves2D` | second curve not added | `CompCurveTests.swift:42 simd_distance(combined.endPoint, SIMD2(2, 1)) < 1e-12` | ✅ | MATCH | Rewritten: checked only != nil |
| Conical Projection | Project wire onto box from eye point | `OCCTShapeProjectWireConical` | eye z + 5 | `ConicalProjectionTests.swift:34 abs(b.min.x + 4.65) < 1e-6` | ✅ | MATCH | Rewritten: `_ = result` could not fail |
| Convert Circle Tests | circleArcToBSpline | `OCCTConvertCircleToBSpline2D` | every pole shifted 0.5 in x | `ConvertCircleTests.swift:18 simd_distance(curve.startPoint, SIMD2(10, 0)) < 1e-12` | ✅ | MATCH | Rewritten: checked only != nil |
| Convert Conic Curves Tests | ellipseArc | `OCCTConvertEllipseToBSpline2D` | every pole shifted 0.5 in x | `ConvertConicCurvesTests.swift:27 simd_distance(curve.startPoint, SIMD2(20, 0)) < 1e-12` | ✅ | MATCH | Rewritten: checked only != nil |
| Convert Conic Curves Tests | hyperbolaArc | `OCCTConvertHyperbolaToBSpline2D` | every pole shifted 0.5 in x | `ConvertConicCurvesTests.swift:43 simd_distance(curve.startPoint, SIMD2(10 * cosh(-1.0), 5 * sinh(-1.0))) < 1e-9` | ✅ | MATCH | Rewritten: checked only != nil |
| Convert Conic Curves Tests | parabolaArc | `OCCTConvertParabolaToBSpline2D` | every pole shifted 0.5 in x | `ConvertConicCurvesTests.swift:57 simd_distance(curve.startPoint, SIMD2(0.2, -2)) < 1e-12` | ✅ | MATCH | Rewritten: checked only != nil |
| CPnts UniformDeflection | Uniform deflection on circle edge | `OCCTCPntsUniformDeflection` | deflection x4 | `CPntsUniformDeflectionTests.swift:30 result.points.count == 24` | ✅ | MATCH | Rewritten: any count above 4 passed |
| CPnts UniformDeflection | Uniform deflection with range | `OCCTCPntsUniformDeflectionRange` | deflection x4 | `CPntsUniformDeflectionTests.swift:43 Issue recorded (full sampling not 24 points)` | ✅ | MATCH | Rewritten: any ranged count below the full one passed |
| Curve3D conic factory families agree (#399) | Circle: both families reject zero and negative radius | `OCCTGceMakeCircFromCenterNormal` | radius precondition skipped in the gce family | `Curve3DConicFactoryParityTests.swift:26 Curve3D.circleFromCenterNormal(...) == nil` | ✅ | MATCH |  |
| Curve3D conic factory families agree (#399) | Ellipse: both families reject zero radii and inverted radii | `OCCTGceMakeElips` | radii precondition skipped in the gce family | `Curve3DConicFactoryParityTests.swift:41 Curve3D.ellipseFromCenterNormal(...) == nil` | ✅ | MATCH |  |
| Curve3D conic factory families agree (#399) | Hyperbola: both families reject a zero or negative radius | `OCCTGceMakeHypr` | radii precondition skipped in the gce family | `Curve3DConicFactoryParityTests.swift:56 Curve3D.hyperbolaFromCenterNormal(...) == nil` | ✅ | MATCH |  |
| Curve3D conic factory families agree (#399) | Parabola: both families reject zero and negative focal length | `OCCTGceMakeParab` | focal precondition skipped in the gce family | `Curve3DConicFactoryParityTests.swift:68 Curve3D.parabolaFromCenterNormal(...) == nil` | ✅ | MATCH |  |
| Curve3D conic factory families agree (#399) | Valid inputs still build the identical curve in both families | `OCCTGceMakeElips` | gce ellipse moved 0.5 in x | `Curve3DConicFactoryParityTests.swift:101 simd_distance(a.point(at: t), b.point(at: t)) < 1e-9` | ✅ | MATCH |  |
| Curve3D Continuity Tests | lineContinuity | `OCCTCurve3DGetContinuity` | Continuity() - 1 | `Curve3DContinuityTests.swift:18 line.continuity == 6` | ✅ | MATCH | Rewritten: c >= 0 held for every value |
| Curve3D Continuity Tests | bsplineContinuity | `OCCTCurve3DGetContinuity` | Continuity() - 1 | `Curve3DContinuityTests.swift:32 bsp.continuity == 4` | ✅ | MATCH | Rewritten: c >= 0 held for every value |
| Curve3D Continuity Queries v0.120.0 | lineContinuityClass | `OCCTCurve3DGetContinuity` | Continuity() - 1 | `Curve3DContinuityQueriesTests.swift:24 c.continuityClass == .cN` | ✅ | MATCH |  |
| Curve3D Continuity Queries v0.120.0 | isCN | `OCCTCurve3DIsCN` | IsCN() negated | `Curve3DContinuityQueriesTests.swift:33 c.isCN(0)` | ✅ | MATCH |  |
| Curve3D Continuity Queries v0.120.0 | reversedParameter | `OCCTCurve3DReversedParameter` | ReversedParameter + 1 | `Curve3DContinuityQueriesTests.swift:45 abs(rp + u) < 1e-10` | ✅ | MATCH |  |
| Curve3D Continuity Queries v0.120.0 | parametricTransformation | `OCCTCurve3DParametricTransformation` | result x 2 | `Curve3DContinuityQueriesTests.swift:56 abs(scale - 1.0) < 1e-10` | ✅ | MATCH |  |
| Curve3D Continuity Queries v0.120.0 | bezierResolution | `OCCTCurve3DBezierResolution` | resolution x 2 | `Curve3DContinuityQueriesTests.swift:68 abs(c.bezierResolution(tolerance3d: 0.01) - 0.0025) < 1e-15` | ✅ | MATCH | Rewritten: r > 0 |
| Curve3D Continuity Queries v0.120.0 | bezierMaxDegree | `OCCTCurve3DBezierMaxDegree` | report 8 | `Curve3DContinuityQueriesTests.swift:73 md == 25` | ✅ | MATCH | Rewritten: md >= 25 |
| Curve3D Continuity Queries v0.120.0 | bsplineMaxDegree | `OCCTCurve3DBSplineMaxDegree` | report 8 | `Curve3DContinuityQueriesTests.swift:78 md == 25` | ✅ | MATCH | Rewritten: md >= 25 |
| Curve3D Conversion Tests | Circle to BSpline | `OCCTCurve3DToBSpline` | degree raised by one after conversion | `Curve3DConversionTests.swift:28 b.poleCount == 6` | ✅ | MATCH | Rewritten: poleCount > 0 and degree > 0 |
| Curve3D Conversion Tests | BSpline to Bezier segments | `OCCTCurve3DBSplineToBeziers` | one arc fewer | `Curve3DConversionTests.swift:40 segs.count == 3` | ✅ | MATCH | Rewritten: count >= 2 |
| Curve3D Conversion Tests | Join two segments into BSpline | `OCCTCurve3DJoinToBSpline` | later curves not added | `Curve3DConversionTests.swift:56 simd_distance(j.endPoint, SIMD3(10, 5, 0)) < 1e-12` | ✅ | MATCH | Rewritten: end points to 0.1 |
| Curve3D Conversion Tests | Join returns nil rather than silently dropping a disconnected curve | `OCCTCurve3DJoinToBSpline` | Add() failure ignored | `Curve3DConversionTests.swift:71 Curve3D.join([seg1, seg2]) == nil` | ✅ | MATCH |  |
| Curve3D Conversion Tests | Approximate curve | `OCCTCurve3DApproximate` | tolerance x 1000 | `Curve3DConversionTests.swift:90 abs(simd_length(p) - 5) < 0.01` | ✅ | MATCH | Rewritten: checked only != nil |
| Curve3D Draw Tests | Adaptive draw on circle produces points | `OCCTCurve3DDrawAdaptive` | deflections x 4 (and, separately, one point fewer) | `Curve3DDrawTests.swift:23 points.count == 64` | ✅ | MATCH | Rewritten: count >= 10, radius to 0.1 |
| Curve3D Draw Tests | Uniform draw produces exact count | `OCCTCurve3DDrawUniform` | one point fewer | `Curve3DDrawTests.swift:33 points.count == 32` | ✅ | MATCH |  |
| Curve3D Draw Tests | Deflection draw produces points | `OCCTCurve3DDrawDeflection` | deflection x 4 | `Curve3DDrawTests.swift:44 points.count == 17` | ✅ | MATCH | Rewritten: count >= 4 |
| Curve3D Draw Tests | Adaptive draw on segment produces at least 2 points | `OCCTCurve3DDrawAdaptive` | one point fewer | `Curve3DDrawTests.swift:55 points.count == 2` | ✅ | MATCH | Rewritten: count >= 2. The first rewrite compared the last point with == and failed green by 4e-16; it now uses a distance |
| Curve3D Evaluation v0.110 | evalD0BSpline | `OCCTCurve3DEvalD0` | x + 0.5 | `Curve3DEvalTests.swift:30 simd_length(p) < 1e-12` | ✅ | MATCH | Rewritten: tolerance 1e-3 inside `if let` |
| Curve3D Evaluation v0.110 | evalD1BSpline | `OCCTCurve3DEvalD1` | D1.y + 0.5 | `Curve3DEvalTests.swift:43 simd_distance(r.d1, Self.d1) < 1e-12` | ✅ | MATCH | Rewritten: \|d1\| > 0.1 |
| Curve3D Evaluation v0.110 | evalD2BSpline | `OCCTCurve3DEvalD2` | D2.y + 0.5 | `Curve3DEvalTests.swift:51 simd_distance(r.d2, Self.d2) < 1e-12` | ✅ | MATCH | Rewritten: ended in #expect(true) |
| Curve3D Evaluation v0.110 | evalD3BSpline | `OCCTCurve3DEvalD3` | D3.y + 0.5 | `Curve3DEvalTests.swift:59 simd_distance(r.d3, Self.d3) < 1e-12` | ✅ | MATCH | Rewritten: ended in #expect(true) |
| Curve3D Evaluation v0.110 | evalD0Circle | `OCCTCurve3DEvalD0` | x + 0.5 | `Curve3DEvalTests.swift:68 curve.evalD0(at: 0) == SIMD3(5, 0, 0)` | ✅ | MATCH |  |
| Curve3D Extras v0.109 | reverseCurve | `OCCTCurve3DReverse` | Reverse skipped | `Curve3DExtrasTests.swift:20 simd_distance(c.startPoint, SIMD3(10, 0, 0)) < 1e-12` | ✅ | MATCH | Rewritten: discarded both points, could not fail. Fixture is now a segment so its start point is finite |
| Curve3D Extras v0.109 | copyCurve | `OCCTCurve3DCopy` | copy moved 0.5 in y | `Curve3DExtrasTests.swift:32 simd_distance(c.point(at: u), copy.point(at: u)) < 1e-12` | ✅ | MATCH | Rewritten: one sample inside `if let` |
| Curve3D Extras v0.109 | copiedCurveIndependent | `OCCTCurve3DCopy` | copy moved 0.5 in y (and, separately, Reverse skipped) | `Curve3DExtrasTests.swift:43 copy.startPoint == c.startPoint` | ✅ | MATCH | Rewritten: checked only isClosed; now checks independence, which the title claims |
| Curve3D extras v0.112 | curveType | `OCCTCurve3DCurveType` | type + 1 | `Curve3DExtrasV112Tests.swift:19 line.curveType == 0` | ✅ | MATCH |  |
| Curve3D extras v0.112 | nearestParameterOnLine | `OCCTCurve3DNearestParameter` | parameter + 1 | `Curve3DExtrasV112Tests.swift:32 abs(param - 5.0) < 1e-9` | ✅ | MATCH | Rewritten: 0.1 of slack inside `if let` |
| Curve3D.interpolate tangent-tolerance reachability (#400) | Bare 3-arg call matches an explicit default-tolerance call exactly | `OCCTCurve3DInterpolateWithTangents` | end tangent loaded as the start tangent | `Curve3DInterpolateTangentToleranceParityTests.swift:53 simd_distance(t0, simd_normalize(Self.startTangent)) < 1e-9` | ✅ | MATCH | Strengthened: the comparison of two calls to one function cannot differ at runtime; tangent directions pinned |
| Curve3D.interpolate tangent-tolerance reachability (#400) | tolerance: is reachable and actually governs the minimum inter-point distance | `OCCTCurve3DInterpolateWithTangents` | tolerance argument ignored (1e-6 always) | `Curve3DInterpolateTangentToleranceParityTests.swift:73 tighter != nil` | ✅ | MATCH |  |
| Curve3D Plane Projection Tests | Project segment onto XY plane along Z direction | `OCCTCurve3DProjectOnPlane` | result moved 0.5 in x (and, separately, plane moved 1 in z) | `Curve3DPlaneProjectionTests.swift:30 abs(start.x - 0.0) < 1e-6` | ✅ | MATCH |  |
| Curve3D Plane Projection Tests | Project circle onto XY plane preserves shape | `OCCTCurve3DProjectOnPlane` | result moved 0.5 in x | `Curve3DPlaneProjectionTests.swift:54 simd_distance(pt, SIMD3(5, 0, 0)) < 1e-9` | ✅ | MATCH | Rewritten: radius to 0.1 |
| Curve3D Plane Projection Tests | Project arc onto tilted plane | `OCCTCurve3DProjectOnPlane` | result moved 0.5 in x | `Curve3DPlaneProjectionTests.swift:79 simd_distance(mid, SIMD3(0, 0, 0)) < 1e-9` | ✅ | MATCH | Rewritten: checked only the midpoint's y |
| Curve3D Plane Projection Tests | Project BSpline onto plane | `OCCTCurve3DProjectOnPlane` | plane moved 1 in z (and, separately, result moved in x) | `Curve3DPlaneProjectionTests.swift:105 abs(pt.z) < 1e-6` | ✅ | MATCH | Strengthened: end points and sample count |
| Curve3D Plane Projection Tests | Projected curve preserves parametric consistency | `OCCTCurve3DProjectOnPlane` | result moved 0.5 in x | `Curve3DPlaneProjectionTests.swift:126 simd_distance(start, SIMD3(2, 3, 0)) < 1e-9` | ✅ | MATCH | Strengthened: whole points |
| Curve3D Plane Projection Tests | Project segment along oblique direction | `OCCTCurve3DProjectOnPlane` | projection direction replaced by the plane normal | `Curve3DPlaneProjectionTests.swift:148 abs(start.x - (-10.0)) < 1e-9` | ✅ | MATCH | Strengthened: tolerance 1e-3 to 1e-9, end point added |
| Curve3D Plane Projection Tests | Project onto plane with near-parallel direction returns nil or valid curve | `OCCTCurve3DProjectOnPlane` | result moved 0.5 in x | `Curve3DPlaneProjectionTests.swift:169 simd_distance(c.point(at: c.domain.lowerBound), SIMD3(0, 0, 0)) < 1e-9` | ✅ | MATCH | Rewritten: discarded the result, could not fail |
| Curve3D Primitive Tests | Create segment and verify endpoints | `OCCTCurve3DCreateSegment` | end point moved 0.5 in z | `Curve3DPrimitiveTests.swift:28 abs(end.z - 3) < 1e-10` | ✅ | MATCH |  |
| Curve3D Primitive Tests | Degenerate segment returns nil | `OCCTCurve3DCreateSegment` | coincident end nudged 1 in x instead of rejected | `Curve3DPrimitiveTests.swift:35 seg == nil` | ✅ | MATCH | Finding: the bridge's pre-check guards a kernel crash |
| Curve3D Primitive Tests | Create circle and verify closed/periodic | `OCCTCurve3DIsClosed` | IsClosed negated (and, separately, IsPeriodic negated, Period + 1) | `Curve3DPrimitiveTests.swift:43 circle.isClosed` | ✅ | MATCH | Strengthened: period pinned, was != nil |
| Curve3D Primitive Tests | Circle zero radius returns nil | `OCCTCurve3DCreateCircle` | radius check skipped (radius clamped to 1e-7) | `Curve3DPrimitiveTests.swift:52 circle == nil` | ✅ | MATCH |  |
| Curve3D Primitive Tests | Circle point at 0 and pi/2 | `OCCTCurve3DGetPoint` | value moved 0.5 in y | `Curve3DPrimitiveTests.swift:61 abs(p0.y) < 1e-10` | ✅ | MATCH |  |
| Curve3D Primitive Tests | Arc through three points | `OCCTCurve3DCreateArcOfCircle` | start point moved 0.1 in x | `Curve3DPrimitiveTests.swift:75 simd_distance(arc.startPoint, SIMD3(5, 0, 0)) < 1e-12` | ✅ | MATCH | Strengthened: start x to 0.01 before |
| Curve3D Primitive Tests | Create ellipse | `OCCTCurve3DCreateEllipse` | IsClosed negated (and IsPeriodic, Period, point) | `Curve3DPrimitiveTests.swift:87 e.isClosed` | ✅ | MATCH | Strengthened: shape pinned |
| Curve3D Primitive Tests | Invalid ellipse returns nil | `OCCTCurve3DCreateEllipse` | inverted radii swapped into order instead of rejected | `Curve3DPrimitiveTests.swift:100 e == nil` | ✅ | MATCH |  |
| Curve3D Primitive Tests | Create line and verify infinite domain | `OCCTCurve3DGetDomain` | infinite last parameter reported as 1e10 | `Curve3DPrimitiveTests.swift:111 d.upperBound == 2e100` | ✅ | MATCH | Rewritten: span > 1e10 passed a finite 1e10 bound |
| Curve3D Primitive Tests | Evaluate segment midpoint | `OCCTCurve3DGetPoint` | value moved 0.5 in y | `Curve3DPrimitiveTests.swift:122 abs(p.y) < 1e-10` | ✅ | MATCH |  |
| Curve3D Primitive Tests | D1 returns non-zero tangent | `OCCTCurve3DD1` | D1.y + 1 | `Curve3DPrimitiveTests.swift:130 simd_distance(result.tangent, simd_normalize(SIMD3(10, 5, 3))) < 1e-12` | ✅ | MATCH | Rewritten: any non-zero tangent passed |
| Curve3D Primitive Tests | D2 second derivative of a circle points from the curve back to its own center | `OCCTCurve3DD2` | D2 reversed | `Curve3DPrimitiveTests.swift:143 abs(result.d2.x - (-result.point.x)) < 1e-9` | ✅ | MATCH |  |
| v0.123.0, Curve3D queries | Period of circle | `OCCTCurve3DGetPeriod` | Period + 1 | `Curve3DQueriesV123Tests.swift:21 abs((c.period ?? -1) - 2.0 * .pi) < 1e-10` | ✅ | MATCH | Rewritten: nested `if let` skipped the check on nil |
| v0.123.0, Curve3D queries | FirstParameter and LastParameter | `OCCTCurve3DFirstParameter` | both + 0.5 | `Curve3DQueriesV123Tests.swift:27 abs(c.firstParameter) < 1e-10` | ✅ | MATCH |  |
| v0.123.0, Curve3D queries | Line first/last parameters | `OCCTCurve3DFirstParameter` | infinite first parameter reported as -1e10 | `Curve3DQueriesV123Tests.swift:38 l.firstParameter == -2e100` | ✅ | MATCH | Rewritten: bounds past 1e10 passed a finite 1e10 |
| Curve3D Transform Family Parity | translate vs translated | `OCCTCurve3DTransform` | in-place transform composed with a 0.25 x translation | `Curve3DTransformFamilyParityTests.swift:30 abs(p.x - q.x) < tolerance` | ✅ | MATCH | Strengthened: absolute start point added |
| Curve3D Transform Family Parity | rotate vs rotated | `OCCTCurve3DTransform` | in-place transform composed with a 0.25 x translation | `Curve3DTransformFamilyParityTests.swift:30 abs(p.x - q.x) < tolerance` | ✅ | MATCH | Strengthened: absolute start point added |
| Curve3D Transform Family Parity | scale vs scaled | `OCCTCurve3DTransform` | in-place transform composed with a 0.25 x translation | `Curve3DTransformFamilyParityTests.swift:30 abs(p.x - q.x) < tolerance` | ✅ | MATCH |  |
| Curve3D Transform Family Parity | mirrorPoint vs mirrored(acrossPoint:) | `OCCTCurve3DTransform` | in-place transform composed with a 0.25 x translation | `Curve3DTransformFamilyParityTests.swift:30 abs(p.x - q.x) < tolerance` | ✅ | MATCH |  |
| Curve3D Transform Family Parity | mirrorAxis vs mirrored(acrossAxis:direction:) | `OCCTCurve3DTransform` | in-place transform composed with a 0.25 x translation | `Curve3DTransformFamilyParityTests.swift:30 abs(p.x - q.x) < tolerance` | ✅ | MATCH |  |
| Curve3D Transform Family Parity | mirrorPlane vs mirrored(acrossPlane:normal:) | `OCCTCurve3DTransform` | in-place transform composed with a 0.25 x translation | `Curve3DTransformFamilyParityTests.swift:30 abs(p.x - q.x) < tolerance` | ✅ | MATCH |  |
| Curve Approximation Tests | Approximate circle edge to BSpline | `OCCTEdgeApproxCurve` | result moved 0.01 in x and z | `CurveApproximationTests.swift:32 abs(simd_length(SIMD2(p.x, p.y)) - 5) < 1e-3` | ✅ | MATCH | Rewritten: checked only != nil |
| Curve Approximation Tests | Approximation info returns valid data | `OCCTEdgeApproxCurveInfo` | MaxError x 2, poles + 1 | `CurveApproximationTests.swift:54 abs(info.maxError - 0.00033800541390782121) < 1e-12` | ✅ | MATCH | Rewritten: maxError < 0.01, degree >= 2, poles > 0 |
| Curve Approximation Tests | Approximate straight edge | `OCCTEdgeApproxCurve` | result moved 0.01 in x and z | `CurveApproximationTests.swift:72 simd_distance(bspline.startPoint, SIMD3(-5, -5, -5)) < 1e-9` | ✅ | MATCH | Rewritten: checked only != nil |
| v0.114.0 - Curve DN | curve3dFirstDerivative | `OCCTCurve3DDN` | DN y + 0.5 | `CurveDNTests.swift:19 line.dn(at: 0, order: 1) == SIMD3(1, 0, 0)` | ✅ | MATCH | Rewritten: \|d1.x\| > 0.5 |
| v0.114.0 - Curve DN | curve3dSecondDerivative | `OCCTCurve3DDN` | DN y + 0.5 | `CurveDNTests.swift:28 line.dn(at: 0, order: 2) == SIMD3(0, 0, 0)` | ✅ | MATCH |  |
| v0.114.0 - Curve DN | curve2dFirstDerivative | `OCCTCurve2DDN` | DN y negated | `CurveDNTests.swift:37 simd_distance(d1, SIMD2(1, 1) / 2.0.squareRoot()) < 1e-15` | ✅ | MATCH | Rewritten: \|x\|, \|y\| > 0.1 |
| v0.114.0 - Curve DN | surfaceDN | `OCCTSurfaceDN` | DN z + 0.5 | `CurveDNTests.swift:47 simd_distance(du, SIMD3(0, 3.5355339059327378, 0)) < 1e-12` | ✅ | MATCH | Rewritten: \|du\| > 0.1 |
| v0.114.0 - Curve isBounded | lineIsNotBounded | `OCCTCurve3DIsBounded` | answer inverted | `CurveIsBoundedTests.swift:17 !line.isBounded` | ✅ | MATCH | `if let` removed |
| v0.114.0 - Curve isBounded | bsplineIsBounded | `OCCTCurve3DIsBounded` | answer inverted | `CurveIsBoundedTests.swift:26 curve.isBounded` | ✅ | MATCH | `if let` removed |
| v0.114.0 - Curve isBounded | line2dIsNotBounded | `OCCTCurve2DIsBounded` | answer inverted | `CurveIsBoundedTests.swift:34 !line.isBounded` | ✅ | MATCH | `if let` removed |
| v0.114.0 - Curve isBounded | bspline2dIsBounded | `OCCTCurve2DIsBounded` | answer inverted | `CurveIsBoundedTests.swift:43 curve.isBounded` | ✅ | MATCH | `if let` removed |
| Curve Interpolation Tests | Interpolate through 2 points | `OCCTWireGetLength` | length x 1.01 | `CurveInterpolationTests.swift:24 abs((wire.length ?? 0) - 200.0.squareRoot()) < 1e-9` | ✅ | MATCH | Rewritten: 0.5 of slack, force-unwrapped wire |
| Curve Interpolation Tests | Interpolate through multiple points | `OCCTWireGetCurveInfo` | isClosed inverted (and, separately, closed flag flipped, length x 1.01) | `CurveInterpolationTests.swift:40 !info.isClosed` | ✅ | MATCH | Rewritten: force-unwraps inside #expect |
| Curve Interpolation Tests | Interpolate closed curve | `OCCTWireGetCurveInfo` | isClosed inverted (and, separately, closed flag flipped) | `CurveInterpolationTests.swift:61 info.isClosed` | ✅ | MATCH | Rewritten: force-unwraps inside #expect |
| Curve Interpolation Tests | Interpolate with tangent constraints | `OCCTWireInterpolateWithTangents` | tangent y components swapped | `CurveInterpolationTests.swift:84 simd_distance(midPoint, SIMD3(5, 1.25, 0)) < 1e-9` | ✅ | MATCH | Rewritten: y > 0 with a force-unwrap in #expect |
| Curve Interpolation Tests | Interpolate 3D curve | `OCCTWireGetPointAt` | point moved 0.5 in z (and, separately, closed flag flipped) | `CurveInterpolationTests.swift:102 simd_distance(midPoint, SIMD3(20, 0, 10)) < 1e-9` | ✅ | MATCH | Rewritten: z > 5 with a force-unwrap in #expect |
| Curve Interpolation Tests | Interpolate too few points returns nil | `none: Swift guard in Wire.interpolate` | Swift: a lone point is padded to two | `CurveInterpolationTests.swift:111 wire == nil` | ✅ | N/A | No kernel counterpart: the Swift guard rejects the input |
| GeomConvert_CurveToAnaCurve | recognize line from BSpline | `OCCTGeomConvertCurveToAnalytical` | conversion reports failure (and, separately, newLast = newFirst) | `CurveToAnaCurveTests.swift:29 Issue recorded (line not recognized)` | ✅ | MATCH | Rewritten: `if let result` skipped the check on failure |
| GeomConvert_CurveToAnaCurve | recognize circle from BSpline | `OCCTGeomConvertCurveToAnalytical` | conversion reports failure (and, separately, newLast = newFirst) | `CurveToAnaCurveTests.swift:54 Issue recorded (circle not recognized)` | ✅ | MATCH | Rewritten: `if let result` skipped the check on failure |
| GeomConvert_CurveToAnaCurve | check points are linear | `OCCTGeomConvertIsLinear` | IsLinear answer inverted | `CurveToAnaCurveTests.swift:66 isLinear` | ✅ | MATCH | Strengthened: deviation pinned to 0 |
| v0.147 DrawingAnnotation.cuttingPlaneLine | addCuttingPlaneLine stores a cutting-plane annotation | `none: Swift Drawing.addCuttingPlaneLine` | Swift: trace length halved (and, separately, arrow taken along the trace) | `CuttingPlaneLineTests.swift:34 abs(simd_length(trace) - 60) < 1e-9` | ✅ | N/A | Rewritten: checked only the label |
| v0.147 DrawingAnnotation.cuttingPlaneLine | Cutting plane parallel to view plane returns nil | `none: Swift Drawing.addCuttingPlaneLine` | Swift: parallel-trace guard skipped | `CuttingPlaneLineTests.swift:53 ann == nil` | ✅ | N/A |  |
| v0.147 DrawingAnnotation.cuttingPlaneLine | Zero-length cuttingPlaneNormal returns nil | `none: Swift Drawing.addCuttingPlaneLine` | Swift: zero-length guard skipped (#1581 path) | `CuttingPlaneLineTests.swift:77 ann == nil` | ✅ | N/A |  |
| v0.147 DrawingAnnotation.cuttingPlaneLine | Zero-length viewDirection returns nil | `none: Swift Drawing.addCuttingPlaneLine` | Swift: zero-length guard skipped (#1581 path) | `CuttingPlaneLineTests.swift:94 ann == nil` | ✅ | N/A |  |
| v0.147 DrawingAnnotation.cuttingPlaneLine | DXFWriter emits cutting plane line geometry | `none: Swift DXF emitter` | Swift: middle chain segment not emitted | `CuttingPlaneLineTests.swift:119 counts.lines - before.entityCounts.lines == 9` | ✅ | N/A | Rewritten: `lines >= 9` was met by the view's own edges |
| v0.147 Edge.curve3D accessor | Linear edge returns a Curve3D | `OCCTEdgeGetCurve3D` | raw curve trimmed to the edge range | `EdgeCurve3DTests.swift:24 c.domain == -2e100...2e100` | ✅ | MATCH | Rewritten: lowerBound <= upperBound held for any range |
| v0.147 Edge.curve3D accessor | Cylindrical face's circular edge yields circleProperties | `OCCTEdgeGetCurve3D` | raw curve scaled 1.01 about the origin (and, separately, trimmed) | `EdgeCurve3DTests.swift:40 abs(props.radius - 5.0) < 1e-6` | ✅ | MATCH |  |
| v0.147 Edge.curve3D accessor | Straight edge's curve3D domain is the underlying Geom_Line's unbounded range, not the edge's own finite span | `OCCTEdgeGetCurve3D` | raw curve trimmed to the edge range | `EdgeCurve3DTests.swift:65 curve.domain.upperBound > 1e100` | ✅ | MATCH | Comment corrected: the range is +-2e100, not +-1.8e308 as it said |
| v0.147 Edge.curve3D accessor | Circular edge's curve3D domain is the underlying circle's full period, not the arc's own sweep | `OCCTEdgeGetCurve3D` | raw curve trimmed to the edge range | `EdgeCurve3DTests.swift:96 curve.domain.upperBound - curve.domain.lowerBound > 6.0` | ✅ | MATCH |  |
| Ellipse Arc Tests | Arc of ellipse from angles | `OCCTCurve3DArcOfEllipse` | end angle x 0.9 | `EllipseArcTests.swift:30 simd_distance(arc.endPoint, SIMD3(0, 5, 0)) < 1e-12` | ✅ | MATCH | Rewritten: 0.1 of slack inside `if let` |
| Ellipse Arc Tests | Arc of ellipse between two points | `OCCTCurve3DArcOfEllipsePoints` | sense inverted | `EllipseArcTests.swift:47 simd_distance(arc.startPoint, SIMD3(10, 0, 0)) < 1e-12` | ✅ | MATCH | Rewritten: end x only, to 0.1; the midpoint now fixes the direction |
| Ellipse Arc Tests | Full semi-ellipse arc | `OCCTCurve3DArcOfEllipse` | end angle x 0.9 | `EllipseArcTests.swift:70 simd_distance(arc.endPoint, SIMD3(-10, 0, 0)) < 1e-12` | ✅ | MATCH | Rewritten: x only, to 0.1 |
| Ellipse Arc Tests | Ellipse arc properties | `OCCTCurve3DArcOfEllipse` | end angle x 0.9 | `EllipseArcTests.swift:88 arc.domain == 0...(Double.pi / 2)` | ✅ | MATCH | Rewritten: start.x > 9, end.y > 4 |
| v0.162 EditorView geometric, location, PCurve setters | Per-(edge, face1, face2) regularity setter reports failure on the pinned kernel | `OCCTBRepGraphSetEdgeRegularity` | stub reports success | `EditorViewV162Tests.swift:34 graph.setEdgeRegularity(0, face1: 0, face2: 1, continuity: 1) == false` | ✅ | N/A | Strengthened: nested `if let` let a nil box or graph pass unchecked |
| v0.162 EditorView geometric, location, PCurve setters | coEdgeSetPCurve binds and clears the PCurve that the UV endpoints derive from | `OCCTBRepGraphCoEdgeSetPCurve` | SetPCurve skipped | `EditorViewV162Tests.swift:63 graph.coedgeHasPCurve(0) == false` | ✅ | NOT RUN |  |
| v0.162 EditorView geometric, location, PCurve setters | coEdgeAddPCurve appends a coedge carrying the requested parameter range | `OCCTBRepGraphCoEdgeAddPCurve` | last parameter halved | `EditorViewV162Tests.swift:92 abs(range.last - 4.0) < 1e-9` | ✅ | NOT RUN |  |
| v0.162 EditorView geometric, location, PCurve setters | Face triangulation rep binding | `OCCTBRepGraphSetFaceTriangulationRep` | SetCachedTriangulation skipped | `EditorViewV162Tests.swift:121 graph.meshFaceActiveTriangulationRepId(0) != nil` | ✅ | NOT RUN |  |
| Edge Polyline Consistency Tests | Lofted shape edge polylines match edge count | `OCCTShapeComputeAllEdgePolylines` | Swift: polyline 0 dropped | `EdgePolylineConsistencyTests.swift:27 polylines.count == edgeCount` | ✅ | NOT RUN | Unchanged. A second injection (skipping BuildCurves3d) stayed green: the loft's edges already carry 3D curves |
| Edge Polyline Consistency Tests | Extruded rectangle all 12 edges recovered | `OCCTShapeComputeAllEdgePolylines` | Swift: polyline 0 dropped | `EdgePolylineConsistencyTests.swift:53 polylines.count == 12` | ✅ | MATCH | Unchanged |
| Edge Polyline Consistency Tests | Extruded circle seam edges handled | `OCCTShapeComputeAllEdgePolylines` | Swift: polyline 0 dropped | `EdgePolylineConsistencyTests.swift:70 polylines.count == edgeCount` | ✅ | MATCH | Unchanged |
| Edge Polyline Consistency Tests | allEdgePolylines count matches edgeCount for various shapes | `OCCTShapeComputeAllEdgePolylines` | Swift: polyline 0 dropped | `EdgePolylineConsistencyTests.swift:91 polylines.count == edgeCount` | ✅ | MATCH | Unchanged |
| FairCurve Batten Tests | basicBatten | `OCCTFairCurveBatten` | second point moved 1 in y | `FairCurveBattenTests.swift:23 simd_distance(result.curve.endPoint, SIMD2(10, 0)) < 1e-9` | ✅ | MATCH | Rewritten: `if let` let a failed batten pass |
| FairCurve Batten Tests | battenWithSlope | `OCCTFairCurveBatten` | second point moved 1 in y | `FairCurveBattenTests.swift:23 simd_distance(result.curve.endPoint, SIMD2(10, 0)) < 1e-9` | ✅ | MATCH | Rewritten |
| FairCurve Batten Tests | battenWithAngles | `OCCTFairCurveBatten` | second point moved 1 in y | `FairCurveBattenTests.swift:23 simd_distance(result.curve.endPoint, SIMD2(10, 0)) < 1e-9` | ✅ | MATCH | Rewritten |
| FairCurve Batten Tests | battenConstraintOrders | `OCCTFairCurveBatten` | second point moved 1 in y | `FairCurveBattenTests.swift:23 simd_distance(result.curve.endPoint, SIMD2(10, 0)) < 1e-9` | ✅ | MATCH | Rewritten |
| FairCurve Batten Tests | battenCurveProperties | `OCCTFairCurveBatten` | second point moved 1 in y | `FairCurveBattenTests.swift:61 simd_distance(result.curve.point(at: 0.5), SIMD2(5, 0)) < 1e-9` | ✅ | MATCH | Rewritten: domain non-empty only |
| FairCurve MinimalVariation Tests | basicMinimalVariation | `OCCTFairCurveMinimalVariation` | second point moved 1 in y | `FairCurveMinimalVariationTests.swift:22 simd_distance(result.curve.endPoint, SIMD2(10, 0)) < 1e-9` | ✅ | MATCH | Rewritten |
| FairCurve MinimalVariation Tests | withCurvatureConstraints | `OCCTFairCurveMinimalVariation` | curvature1 not applied | `FairCurveMinimalVariationTests.swift:40 simd_distance(result.curve.point(at: 0.5), SIMD2(5, 0.29798933520658766)) < 1e-6` | ✅ | MATCH | Rewritten: asserted nothing ('should not crash') |
| FairCurve MinimalVariation Tests | withPhysicalRatio | `OCCTFairCurveMinimalVariation` | second point moved 1 in y | `FairCurveMinimalVariationTests.swift:55 simd_distance(result.curve.endPoint, SIMD2(10, 0)) < 1e-9` | ✅ | MATCH | Rewritten |
| v0.115.0 - GCPnts Expansion | edgeArcLength | `OCCTEdgeArcLength` | length x 1.0001 | `GCPntsExpansionTests.swift:24 abs(e.edgeArcLength - 10) < 1e-12` | ✅ | MATCH | Rewritten: len > 0 |
| v0.115.0 - GCPnts Expansion | edgeArcLengthBetween | `OCCTEdgeArcLengthBetween` | length x 1.0001 | `GCPntsExpansionTests.swift:33 abs(halfLen - 5) < 1e-12` | ✅ | MATCH | Rewritten: halfLen > 0 |
| v0.115.0 - GCPnts Expansion | edgeParameterAtFraction | `OCCTEdgeParameterAtFraction` | parameter + 0.5 | `GCPntsExpansionTests.swift:38 abs(e.edgeParameterAtFraction(0.5) - 5) < 1e-9` | ✅ | MATCH | Rewritten: within the domain |
| v0.115.0 - GCPnts Expansion | edgeParameterAtArcLength | `OCCTEdgeParameterAtArcLength` | parameter + 0.5 (and, separately, total length x 1.0001) | `GCPntsExpansionTests.swift:45 abs(param - 5) < 1e-9` | ✅ | MATCH | Rewritten: >= domain start |
| GCPnts QuasiUniform Tests | quasi-uniform on edge | `OCCTGCPntsQuasiUniform` | parameter i shifted by 0.01 i | `GCPntsQuasiUniformTests.swift:22 abs(p - 10 * Double(i) / 9) < 1e-9` | ✅ | MATCH | Rewritten: increasing only, inside `if let` |
| GCPnts TangentialDeflection Tests | tangential deflection on edge | `OCCTGCPntsTangentialDeflection` | angular deflection x 4 | `GCPntsTangentialDeflectionTests.swift:29 pts.count == 33` | ✅ | MATCH | Rewritten: sampled a degenerated pole edge (2 points at any deflection); now the seam |
| GCPnts TangentialDeflection Tests | tighter deflection gives more points | `OCCTGCPntsTangentialDeflection` | angular deflection x 4 | `GCPntsTangentialDeflectionTests.swift:39 coarse.count == 8` | ✅ | MATCH | Rewritten: 2 >= 2 on the degenerated edge could not fail |
| GeomConvert ApproxCurve Tests | approximate circle as BSpline | `OCCTGeomConvertApproxCurve` | isDone false, maxError x 2 | `GeomConvertApproxCurveTests.swift:22 result.isDone` | ✅ | MATCH | Rewritten: error check gated on isDone |
| GeomConvert ApproxCurve Tests | approximate line as BSpline | `OCCTGeomConvertApproxCurve` | isDone false, maxError x 2 | `GeomConvertApproxCurveTests.swift:35 result.isDone` | ✅ | MATCH | Strengthened: error and end point pinned |
| v0.115.0 - GeomConvert Utilities | curveSplitAndJoin | `OCCTCurve3DConcatenateG1` | split returns no pieces (and, separately, rejoined curve moved 0.5 in z) | `GeomConvertUtilTests.swift:19 segs.count == 1` | ✅ | MATCH | Rewritten: an empty split skipped every check |
| Geom_OffsetCurve Tests | createFromLine | `OCCTCurve3DOffsetValue` | Offset() + 0.5 | `GeomOffsetCurveTests.swift:24 abs(offset.offsetValue - 5.0) < 1e-10` | ✅ | MATCH | Strengthened: `if let` removed, a point pinned |
| Geom_OffsetCurve Tests | offsetDirection | `OCCTCurve3DOffsetDirection` | direction reversed | `GeomOffsetCurveTests.swift:35 simd_distance(SIMD3(dir.x, dir.y, dir.z), SIMD3(0, 0, 1)) < 1e-10` | ✅ | MATCH | Rewritten: nested `if let`s |
| GeomTools_CurveSet Tests | serializeDeserialize3D | `OCCTGeomToolsCurveSetRead` | one curve fewer reported | `GeomToolsCurveSetTests.swift:29 curves.count == 2` | ✅ | MATCH | Rewritten: nested `if let`s |
| GeomTools_CurveSet Tests | roundtripPreservesGeometry | `OCCTGeomToolsCurveSetRead` | one curve fewer reported | `GeomToolsCurveSetTests.swift:38 Issue recorded (round trip failed)` | ✅ | MATCH | Rewritten: checked only the count |
| GeomTools_CurveSet Tests | duplicateHandleRefusesTheBatch | `OCCTGeomToolsCurveSetWrite` | dedup refusal skipped | `GeomToolsCurveSetTests.swift:55 Curve3D.serializeCurves([line, line]) == nil` | ✅ | MATCH | `if let` removed |
| Geom_TrimmedCurve Tests | trimLineCreatesSubset | `OCCTCurve3DTrimmed` | u2 + 1 | `GeomTrimmedCurveTests.swift:23 simd_distance(trimmed.endPoint, SIMD3(8, 0, 0)) < 1e-12` | ✅ | MATCH | Strengthened: whole points |
| Geom_TrimmedCurve Tests | trimmedBasisReturnsOriginal | `OCCTCurve3DTrimmedBasis` | trimmed curve returned as its own basis | `GeomTrimmedCurveTests.swift:34 basis.domain == -2e100...2e100` | ✅ | MATCH | Rewritten: checked only != nil |
| Geom_TrimmedCurve Tests | nonTrimmedHasNilBasis | `OCCTCurve3DTrimmedBasis` | untrimmed curve returned as its own basis | `GeomTrimmedCurveTests.swift:39 line.trimmedBasis == nil` | ✅ | MATCH | `if let` removed |
| Geom_TrimmedCurve Tests | setTrimUpdatesRange | `OCCTCurve3DSetTrim` | SetTrim skipped | `GeomTrimmedCurveTests.swift:45 simd_distance(trimmed.startPoint, SIMD3(3, 0, 0)) < 1e-12` | ✅ | MATCH | Strengthened: end point added |
| v0.127.0, BSpline Curve Completions | BSpline periodic normalization | `OCCTCurve3DBSplinePeriodicNormalization` | period added after PeriodicNormalization | `BSplineCurveCompletionsTests.swift:29 abs(normalized - 3.8334777586295301) < 1e-12` | ✅ | MATCH | Rewritten: any value inside the domain passed, and `if let` hid a nil |
| v0.127.0, BSpline Curve Completions | BSpline periodic normalization returns nil for non-periodic | `OCCTCurve3DBSplinePeriodicNormalization` | IsPeriodic() guard skipped | `BSplineCurveCompletionsTests.swift:43 curve.bsplinePeriodicNormalization(0.5) == nil` | ✅ | MATCH |  |
| v0.127.0, BSpline Curve Completions | BSpline IsG1 returns true for smooth curve | `OCCTCurve3DBSplineIsG1` | IsG1() negated | `BSplineCurveCompletionsTests.swift:57 curve.bsplineIsG1(tFirst: domain.lowerBound, tLast: domain.upperBound)` | ✅ | MATCH |  |
| BSpline Knot Splitting | BSpline curve continuity breaks | `OCCTCurve3DBSplineKnotSplits` | continuity order + 3 | `BSplineKnotSplittingTests.swift:37 c0Breaks.count == 2` | ✅ | MATCH | Rewritten: count >= 2 passed every interior knot |
| BSpline Knot Splitting | Non-BSpline returns nil | `OCCTCurve3DBSplineKnotSplits` | return 0 splits instead of -1 for a non-BSpline | `BSplineKnotSplittingTests.swift:49 line.continuityBreaks() == nil` | ✅ | MATCH |  |
| v0.113.0 - BSpline Mutations | curveKnotSequenceAndWeights | `OCCTCurve3DBSplineGetKnotSequence` | one knot short (and, separately, weights doubled) | `BSplineMutationsTests.swift:22 curve.bsplineKnotSequence() == [0, 0, 0, 0, 1, 1, 1, 1]` | ✅ | MATCH | Rewritten: count > 0 passed a short sequence |
| v0.113.0 - BSpline Mutations | periodicKnotSequenceLength | `OCCTCurve3DBSplineGetKnotSequence` | one knot short | `BSplineMutationsTests.swift:50 curve.bsplineKnotSequence().count == 10` | ✅ | MATCH |  |
| v0.113.0 - BSpline Mutations | knotSequenceOverflowGuard | `OCCTCurve3DBSplineGetKnotSequence` | one knot short | `BSplineMutationsTests.swift:102 seq.count == realLength` | ✅ | MATCH |  |
| v0.113.0 - BSpline Mutations | curveMaxDegree | `OCCTCurve3DBSplineMaxDegree` | report 8 | `BSplineMutationsTests.swift:110 maxDeg == 25` | ✅ | MATCH | Rewritten: >= 10 |
| v0.113.0 - BSpline Mutations | curveLocateU | `OCCTCurve3DBSplineLocateU` | span forced to 0 | `BSplineMutationsTests.swift:124 span >= 1` | ✅ | MATCH | Finding: the bridge passes one variable as both LocateU outputs, so it returns the upper index |
| v0.113.0 - BSpline Mutations | surfaceUVKnots | `OCCTSurfaceBSplineGetWeights` | cols + 1 | `BSplineMutationsTests.swift:145 cols == 5` | ✅ | MATCH | Rewritten: counts > 0, and weights.count == rows * cols holds by construction |
| Curve3D.arc(through:_:_:) is a true alias of arcOfCircle (#415) | arc(through:_:_:) produces a valid arc | `OCCTCurve3DCreateArcOfCircle` | start point moved 0.1 in x (and, separately, Swift arc(through:) swaps its ends) | `Curve3DArcAliasParityTests.swift:33 simd_distance(arc.startPoint, Self.start) < 1e-12` | ✅ | MATCH | Rewritten: start point only, to 0.01, inside `if let` |
| Curve3D.arc(through:_:_:) is a true alias of arcOfCircle (#415) | arc(through:_:_:) and arcOfCircle(start:interior:end:) produce identical geometry | `OCCTCurve3DCreateArcOfCircle` | Swift: arc(through:) passes its end points swapped | `Curve3DArcAliasParityTests.swift:55 abs(pa.x - pb.x) < 1e-9` | ✅ | MATCH |  |
| Curve3D.arc(through:_:_:) is a true alias of arcOfCircle (#415) | Both entry points reject collinear points | `OCCTCurve3DCreateArcOfCircle` | failed construction returns a segment instead of nil | `Curve3DArcAliasParityTests.swift:66 a == nil` | ✅ | MATCH |  |
| Curve3D.arc(through:_:_:) is a true alias of arcOfCircle (#415) | Both entry points reject coincident points | `OCCTCurve3DCreateArcOfCircle` | three coincident points short-circuit to a unit circle | `Curve3DArcAliasParityTests.swift:75 a == nil` | ✅ | MATCH | The first injection (return a curve when not done) stayed green here: GC_MakeArcOfCircle throws on coincident points, and the catch already returns nil |
| Curve3D Arc Length | totalArcLength | `OCCTCurve3DGetLength` | length x 1.0001 | `Curve3DArcLengthTests.swift:21 abs(line.totalArcLength - 10.0) < 1e-12` | ✅ | MATCH | Rewritten: tolerance 0.01 passed a 0.01% error, and `if let` |
| Curve3D Arc Length | arcLengthBetween | `OCCTCurve3DGetLengthBetween` | length x 1.0001 | `Curve3DArcLengthTests.swift:28 abs(half - 5.0) < 1e-12` | ✅ | MATCH | Rewritten: tolerance 0.01 |
| Curve3D Arc Length | parameterAtLength | `OCCTCurve3DParameterAtLength` | parameter x 1.0001 | `Curve3DArcLengthTests.swift:34 abs(midParam - 5.0) < 1e-9` | ✅ | MATCH | Rewritten: tolerance 0.01 |
| Curve3D Arc Length | parameterAtLengthCircle | `OCCTCurve3DParameterAtLength` | parameter x 1.0001 (and, separately, length x 1.0001) | `Curve3DArcLengthTests.swift:48 abs(param - Double.pi / 2) < 1e-9` | ✅ | MATCH | Rewritten: tolerance 0.1 |
| Curve3D arc-length failure vs. zero-length distinguishability (#408) | A genuine zero-width interval reports exactly 0.0, not a failure sentinel | `OCCTCurve3DGetLengthBetween` | zero-width interval reported as failure (-1) | `Curve3DArcLengthFailureParityTests.swift:23 line.arcLength(from: mid, to: mid) == 0.0` | ✅ | MATCH | Strengthened: `if let` removed, totalArcLength pinned to 10 |
| Curve3D arc-length failure vs. zero-length distinguishability (#408) | A genuinely failing computation is distinguishable from a real zero-length result | `OCCTCurve3DGetLengthBetween` | Swift: arcLength(from:to:) falls back to 0.0 instead of -1.0 | `Curve3DArcLengthFailureParityTests.swift:44 arcLen == -1.0` | ✅ | MATCH |  |
| Curve3D arc-length failure vs. zero-length distinguishability (#408) | totalArcLength and length agree on a valid curve (single source of truth) | `OCCTCurve3DGetLength` | Swift: totalArcLength scaled by 1.0001 | `Curve3DArcLengthFailureParityTests.swift:54 line.totalArcLength == line.length` | ✅ | MATCH | Strengthened: `if let` hid a nil length |
| Curve3D arc-length failure vs. zero-length distinguishability (#408) | arcLength(from:to:) and length(from:to:) agree on a valid curve | `OCCTCurve3DGetLengthBetween` | Swift: arcLength(from:to:) scaled by 1.0001 | `Curve3DArcLengthFailureParityTests.swift:64 line.arcLength(from: d.lowerBound, to: quarter) == 2.5` | ✅ | MATCH | Strengthened: nested `if let` hid a nil |
