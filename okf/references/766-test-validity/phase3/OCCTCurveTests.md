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
| Curve3D measured continuity (#485) | knotMultiplicityDrivesMeasuredClass | `OCCTCurve3DGetContinuity` | contold: the retired hand-mapped encoding | `Issue485Curve3DContinuityTests.swift:58 c2.continuity == 4` | ✅ | MATCH | Three silent if-let skips now record an issue |
| Curve3D measured continuity (#485) | analyticCurvesReportCN | `OCCTCurve3DGetContinuity` | contold | `Issue485Curve3DContinuityTests.swift:81 line.continuity == 6` | ✅ | MATCH | Two silent if-let skips now record an issue |
| Curve3D measured continuity (#485) | g1CurveReportsOrdinalOne | `OCCTCurve3DGetContinuity` | contold | `Issue485Curve3DContinuityTests.swift:101 g1.continuity == 1` | ✅ | MATCH |  |
| Curve3D measured continuity (#485) | bothPropertiesAgree | `OCCTCurve3DGetContinuity` | contold | `Issue485Curve3DContinuityTests.swift:125 continuity == continuityClass.rawValue` | ✅ | MATCH |  |
| Curve3D measured continuity (#485) | retiredSentinelValuesAreGone | `OCCTCurve3DGetContinuity` | contold | `Issue485Curve3DContinuityTests.swift:139 continuity != 99` | ✅ | MATCH |  |
| Issue 486: Curve3D batch-eval spellings agree | emptyParametersGiveEmptyResult | `none: Swift early return` | gridpad: empty input answers one zero point | `Issue486Curve3DBatchTests.swift:26 evaluateGrid([]).isEmpty` | ✅ | N/A | A silent `guard ... else { return }` now records an issue |
| Issue #490: continuity vocabulary domains (curves) | approximationDomain | `OCCTCurve3DApproximate` | approxc3: continuity clamped to 2 | `Issue490ContinuityDecoderTests.swift:33 approximated(continuity: 3) == nil` | ✅ | MATCH |  |
| Issue #490: continuity vocabulary domains (curves) | pointFittingDomain | `OCCTPointsToBSplineWithParams` | fitfail: continuity 3 answers nil | `Issue490ContinuityDecoderTests.swift:56 approximate(points:, continuity: 3) != nil` | ✅ | N/A |  |
| Issue #490: continuity vocabulary domains (curves) | splitCriterionLadder | `OCCTSplitCurve3dContinuity` | splitcrit: criterion - 1 | `Issue490ContinuityDecoderTests.swift:71 atC3 > 1` | ✅ | MATCH | REWRITTEN: > 1 and >= atC3 now also pin 5 |
| Issue #490: continuity vocabulary domains (curves) | analysisOrderSaturates | `OCCTLocalAnalysisCurveContinuity` | aord: requested order echoed unsaturated | `Issue490ContinuityDecoderTests.swift:106 atC2.order == beyond.order` | ✅ | N/A | A silent return now records an issue |
| Issue #490: continuity vocabulary domains (curves) | analysisOrderIsObservable | `OCCTLocalAnalysisCurveContinuity` | aecho: order always reported as .c2 | `Issue490ContinuityDecoderTests.swift:128 analysis.order == order` | ✅ | N/A | A silent return now records an issue |
