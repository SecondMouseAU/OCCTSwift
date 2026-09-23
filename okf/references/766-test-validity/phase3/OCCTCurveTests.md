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
| Issue #558: every sampling entry point bounds the count a caller can supply | the ceiling is declared once and the #479 spelling still resolves to it | `none: Sampling.requested / capacity / gridTotal` | ceilval: ceiling 10_000_001 | `Issue558SamplingCountBoundsTests.swift:57 Sampling.maximumSampleCount == 10_000_000` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | a request is honoured exactly or not at all | `none: Sampling.requested / capacity / gridTotal` | reqneg: Sampling.requested answers the minimum for a count below it | `Issue558SamplingCountBoundsTests.swift:66 Sampling.requested(1) == nil  (+2 more)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | Curve3D request samplers reject a count they cannot serve | `none: Sampling.requested / capacity / gridTotal` | reqneg: Sampling.requested answers the minimum for a count below it | `Issue558SamplingCountBoundsTests.swift:112 c.drawUniform(pointCount: n).count == 0  (+5 more)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | Curve2D.drawUniform rejects a count it cannot serve | `none: Sampling.requested / capacity / gridTotal` | reqneg: Sampling.requested answers the minimum for a count below it | `Issue558SamplingCountBoundsTests.swift:122 c.drawUniform(pointCount: n).count == 0  (+2 more)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | Edge request samplers reject a count they cannot serve | `none: Sampling.requested / capacity / gridTotal` | reqneg: Sampling.requested answers the minimum for a count below it | `Issue558SamplingCountBoundsTests.swift:135 e.points(count: n).count == 0  (+5 more)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | Shape.uniformAbscissa rejects a count it cannot serve, both overloads | `none: Sampling.requested / capacity / gridTotal` | reqneg: Sampling.requested answers the minimum for a count below it | `Issue558SamplingCountBoundsTests.swift:150 edge.uniformAbscissa(pointCount: n) == nil  (+5 more)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | Shape iso-curve evaluators reject a count they cannot serve | `none: Sampling.requested / capacity / gridTotal` | reqneg: Sampling.requested answers the minimum for a count below it | `Issue558SamplingCountBoundsTests.swift:166 face.uIsoCurvePoints(u: 0.5, count: n).count == 0  (+3 more)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | BRepGraph.sampleEdgeCurve rejects a count it cannot serve | `none: Sampling.requested / capacity / gridTotal` | reqneg: Sampling.requested answers the minimum for a count below it | `Issue558SamplingCountBoundsTests.swift:179 graph.sampleEdgeCurve(edgeIndex: 0, count: n).count == 0  (+` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | Shape.allEdgePolylines keeps its own lower bound and gains the ceiling | `none: Sampling.requested / capacity / gridTotal` | reqneg: Sampling.requested answers the minimum for a count below it | `Issue558SamplingCountBoundsTests.swift:189 b.allEdgePolylines(maxPointsPerEdge: n).count == 0  (+2 more` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | MedialAxis fills its buffer exactly, so its maxPoints is a request, not a capacity | `none: Sampling.requested / capacity / gridTotal` | reqneg: Sampling.requested answers the minimum for a count below it | `Issue558SamplingCountBoundsTests.swift:206 ma.drawArc(at: 1, maxPoints: n).count == 0  (+2 more)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | a capacity is clamped into 0...ceiling rather than rejected | `none: Sampling.requested / capacity / gridTotal` | capneg: capacity <= 0 answers 2 | `Issue558SamplingCountBoundsTests.swift:82 Sampling.capacity(0) == 0  (+2 more)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | a capacity of zero or less yields the entry point's own empty value | `none: Sampling.requested / capacity / gridTotal` | capneg: capacity <= 0 answers 2 | `Issue558SamplingCountBoundsTests.swift:249 c3.drawAdaptive(maxPoints: n).count == 0  (+26 more)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | an adaptive sampler's capacity is clamped, not rejected: the answer is unchanged | `none: Sampling.requested / capacity / gridTotal` | capzero: over-ceiling capacity answers 0 | `Issue558SamplingCountBoundsTests.swift:230 baseline3D == c3.drawAdaptive(maxPoints: Self.pastInt32).cou` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | Shape's own capacity samplers clamp and still answer | `none: Sampling.requested / capacity / gridTotal` | capzero: over-ceiling capacity answers 0 | `Issue558SamplingCountBoundsTests.swift:267 b.edgePolyline(at: 0, maxPoints: Self.pastInt32) != nil  (+2` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | a grid bounds the product and each factor, and cannot overflow into one | `none: Sampling.requested / capacity / gridTotal` | gridnil: gridTotal always nil | `Issue558SamplingCountBoundsTests.swift:89 Sampling.gridTotal(20, 20) == 400  (+2 more)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | Surface.drawMesh bounds the product, and each factor on its own | `none: Sampling.requested / capacity / gridTotal` | gridnil: gridTotal always nil | `Issue558SamplingCountBoundsTests.swift:296 !s.drawMesh(uCount: 20, vCount: 20).isEmpty` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | Surface.drawGrid bounds the total, and each line count on its own | `none: Sampling.requested / capacity / gridTotal` | gridnil: gridTotal always nil | `Issue558SamplingCountBoundsTests.swift:313 !s.drawGrid(uLineCount: 4, vLineCount: 4, pointsPerLine: 10)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | BRepGraph.sampleFaceUVGrid bounds the product, and each factor on its own | `none: Sampling.requested / capacity / gridTotal` | gridnil: gridTotal always nil | `Issue558SamplingCountBoundsTests.swift:329 graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 5, vSamples:` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | Shape.coonsAlgPatch bounds the product, and each factor on its own | `none: Sampling.requested / capacity / gridTotal` | gridnil: gridTotal always nil | `Issue558SamplingCountBoundsTests.swift:353 grid?.count == 12` | ✅ | N/A | REWRITTEN: every assertion expected nil from a degenerate patch; a real square boundary now has to serve a 3 x 4 grid |
| Issue #558: every sampling entry point bounds the count a caller can supply | Wire.orderedEdgePoints keeps nil for zero and gains it for the ceiling | `none: Sampling.requested / capacity / gridTotal` | oepneg: orderedEdgePoints admits a non-positive maxPoints as 2 | `Issue558SamplingCountBoundsTests.swift:287 w.orderedEdgePoints(at: 0, maxPoints: n) == nil  (+1 more)` | ✅ | N/A |  |
| Issue #558: every sampling entry point bounds the count a caller can supply | QuadricIntersection.coneSpherePoints rejects a count it cannot serve | `OCCTIntAnaConeSpherePoints` | reqneg: Sampling.requested answers the minimum for a count below it | `Issue558SamplingCountBoundsTests.swift:220 served.count == 16` | ✅ | MATCH | REWRITTEN: the fixture sphere met the cone nowhere and curveIndex 0 is below the bridge's 1-based range, so the test could only fail by aborting; now an intersecting pair at curveIndex 1 with a served-count control |
