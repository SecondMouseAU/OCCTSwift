# Phase 3: OCCTSurfaceTests Injection Matrix

**Target**: `OCCTSurfaceTests` (552 tests) — geometry evaluation, surface operations
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (geometry evaluation, crash fixes #430, #522, #597, #437, #571, #572)

---

## Test Inventory by Suite (Top by Count)

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| Filling Continuity And Support Faces (#430) | 16 | CR/WR |
| BSpline Surface Manipulation Tests | 12 | WR |
| Surface Analytic Primitives | 12 | WR |
| v0.146 Surface finish + GD&T symbols | 11 | WR |
| NLPlate keeps the input surface's position (#1049, #1046) | 10 | WR |
| GeomFill, Gordon Report & Network Surface | 10 | WR |
| Issue #266 follow-up, surface analysis extras | 9 | WR |
| Surface Curve Projection Tests | 9 | WR |
| Surface Operations | 8 | WR |
| BSplineSurface Knot Queries | 8 | WR |
| Plate point constraint G2 domain restriction (#437) | 8 | DG |
| BSplineSurface Completions v121 | 8 | WR |
| Advanced Plate Surface Tests | 8 | WR |
| drawMesh honours its documented minimum (#620) | 8 | DG/WR |
| Surface Continuity Queries v0.120.0 | 8 | WR |
| Bezier Surface Completions | 8 | WR |
| ContinuityClass floor checks (#623) | 7 | WR |
| Surface approximation parity (#491) | 7 | WR |
| Surface measured continuity (#485) | 7 | WR |
| Surface Transform Family Parity (#488) | 7 | WR |
| NLPlate Deformation Tests | 7 | WR |
| BSplineSurface Local Evaluation | 6 | WR |
| Filling Surface Tests | 6 | WR/CR (#430) |
| GeomEval, Circular Helix Curve | 6 | WR |
| Issue #495: surface analysis order | 6 | WR |
| Continuity vocabulary (#398) | 6 | WR |
| Issue 571, plate approximation honours tolerance | 6 | WR/CR (#571) |
| NLPlate G2/G3 parameters are live (#999) | 5 | WR |
| Geom_OffsetSurface Extension Tests | 5 | WR |
| v0.137 Shape.revolutionAxes | 5 | WR |
| Plate_Plate Solver | 5 | WR |
| v0.114.0 - Curve/Surface Type Names | 5 | WR |
| GeomEval, 3D Sine Wave Curve | 5 | WR |
| ... | ... | ... |

**Total**: 552 tests across ~100 suites

---

## Injection Matrix: Critical Crash-Related Tests First

### #430: BRepFill_Filling Untrimmed Pcurve (Bridge Fix)

**Issue**: `BRepFill_Filling::AddConstraints` discards `f`/`l` parameters from `BRep_Tool::CurveOnSurface`, creating untrimmed pcurve → SIGSEGV on non-C0 surfaces (cylinder/sphere/cone).

**Bridge Fix**: `occtFillingSupportFaceFromPCurve` / `occtFillingAddConstraint` synthesize support face from edge's pcurve surface, using `BRepAdaptor_Curve2d` which trims correctly.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Default parameters on a curved boundary return a surface instead of crashing | `Shape.fill` / `FillingSurface` → `BRepFill_Filling` | Untrimmed pcurve on non-C0 | Remove `occtFillingSupportFaceFromPCurve` synthesis | ✅ SIGSEGV | ✅ Pass | SIGSEGV on cylinder/sphere/cone |
| Tangent fill against a support shape is not flat | `Shape.fill` → `BRepFill_Filling` | Support face handling | Remove support face logic |  |  | Wrong surface |
| Explicit per-edge constraint with a support face is tangent | `Shape.fill` → `BRepFill_Filling` | Support face handling | Remove support face logic |  |  | Wrong surface |
| G1 constraints work with a support face | `Shape.fill` → `BRepFill_Filling` | Support face handling | Remove support face logic |  |  | Wrong surface |
| G2 constraints work with a support face | `Shape.fill` → `BRepFill_Filling` | Support face handling | Remove support face logic |  |  | Wrong surface |
| Internal constraint is not a boundary | `Shape.fill` → `BRepFill_Filling` | Support face handling | Remove support face logic |  |  | Wrong surface |
| Explicit support face overrides automatic | `Shape.fill` → `BRepFill_Filling` | Support face handling | Remove support face logic |  |  | Wrong surface |
| wavyEdge() tests (with corrected interpolation) | `FillingSurface` → `BRepFill_Filling` | Support face handling | Remove support face logic |  |  | Wrong surface |

**Finding**: Injection confirmed SIGSEGV on `Default parameters on a curved boundary return a surface instead of crashing` test. The bridge fix correctly synthesizes support faces from pcurves to avoid the face-less overload that causes SIGSEGV on non-C0 surfaces.

### #437: Plate Point Constraint G2 Domain Restriction

**Issue**: `GeomPlate_MakeApprox` rejects G2 point constraints (ordinal 3 > max 2).

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| g0 and g1 are supported for a point constraint; g2 is not | `PlateSurface` → `GeomPlate_MakeApprox` | G2 rejected by kernel | Remove G2 check |  |  | Should still reject (kernel) |
| The mixed-constraint guard's decision depends only on point orders | `PlateSurface` → `GeomPlate_MakeApprox` | Mixed constraint logic | Remove guard |  |  | Wrong decision |
| The shared point-order guard is the one implementation both entry points defer to | `PlateSurface` → `GeomPlate_MakeApprox` | Code sharing | Remove shared guard |  |  | Both paths fail |

### #522: AdvApp2Var U Buffer Overflow (Kernel Patch `0019`)

**Issue**: `AdvApp2Var_ApproxF2var::mma2ce1_` fills U Jacobi-maxima buffer from V slot → degree collapse at C0.

**Kernel Patch**: `0019` — target `ipt4` from U call.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| A full sphere at C0 is not collapsed to a line across its longitude | `Surface.approximated` → `GeomConvert_ApproxSurface` | U buffer from V slot | Revert kernel patch `0019` |  | ✅ Pass | Verified passes |
| The same C0 request through approximated() is not collapsed either | `Surface.approximated` → `GeomConvert_ApproxSurface` | Same | Revert kernel patch `0019` |  | ✅ Pass | Verified passes |
| A V-linear cylinder still fits at degree 1 in V | `Surface.approximated` → `GeomConvert_ApproxSurface` | Control test | No injection |  | ✅ Pass | Verified passes |
| A bicubic Bezier at C0 is reproduced exactly, at every tolerance | `Surface.approximated` → `GeomConvert_ApproxSurface` | C0 branch | Revert kernel patch `0019` |  | ✅ Pass | Verified passes |
| Mixed continuities with C0 in either direction stay within tolerance | `Surface.approximated` → `GeomConvert_ApproxSurface` | C0 branch | Revert kernel patch `0019` |  | ✅ Pass | Verified passes |

**Status**: All 5 tests (11 test cases) pass. Kernel patch `0019` correctly fixes the degree collapse.

### #571: Plate Approximation Honours Tolerance

**Issue**: `GeomPlate_MakeApprox` error not checked; `ApproxError()` measures wrong thing.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| A plate surface lands within the tolerance it was given | `PlateSurface` → `GeomPlate_MakeApprox` | Error not checked | Remove error check |  |  | Wrong fit |
| The approximation is allowed to use more than one Bezier patch | `PlateSurface` → `GeomPlate_MakeApprox` | Control | No injection |  |  | Should pass |
| Asking for a tighter tolerance actually produces a tighter fit | `PlateSurface` → `GeomPlate_MakeApprox` | Error not checked | Remove error check |  |  | Wrong fit |

### #572: Surface Conversion Through #522 Approximator

**Issue**: Offset surfaces converted via `GeomConvert_ApproxSurface` at C0.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| A trimmed offset surface converts to within its own tolerance | `Surface.convertToBSpline` → `GeomConvert_ApproxSurface` | C0 branch | Remove conversion |  |  | Wrong surface |
| The untrimmed offset takes the C0 branch without collapsing | `Surface.withSurfacesAsBSpline` → `GeomConvert_ApproxSurface` | C0 branch | Remove conversion |  |  | Wrong surface |
| Analytic surfaces convert exactly, before and after | Control test | No injection | — |  |  | Should pass |

### #597: GeomFill_Sweep SError Overwrite (Kernel Patch `0025`)

**Issue**: `GeomFill_Sweep::BuildAll` overwrites `SError` with requested tolerance instead of actual error.

**Kernel Patch**: `0025` — `SError = ConvertApprox.MaxError()`.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Rejects a sweep that misses its own tolerance instead of reporting it as done | `PipeShellBuilder` → `GeomFill_Sweep` | SError = tolerance | Revert `SError = ConvertApprox.MaxError()` |  |  | Wrong error (0.0001 vs 2.5+) |

### #438: Divided at Continuity

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| C3 produces a different result from C1, proving the surface criterion is observable | `Face.divided(at:)` / `dividedByContinuity` → `ShapeUpgrade_SplitSurface` | Wrong continuity | Revert continuity logic |  |  | Wrong surface split |

---

## Injection Matrix: Borrowed Handles (Surface *Properties)

**From #965**: 7 `*Properties` views in Surface.swift stored raw handles. Fixed by conforming to `NativeHandleView`.

| Test | Properties Type | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| every Surface *Properties accessor keeps its parent alive | Sphere/Cylindrical/Conical/Toroidal/Plane/BSpline/Bezier | Raw handle storage | Revert to `fileprivate let handle` |  |  | SIGSEGV (use-after-free) |
| a view outliving its parent still reads the right values | Same | Raw handle storage | Revert to raw handle |  |  | SIGSEGV |
| a view outliving its parent survives 400 intervening allocations | Same | Raw handle storage | Revert to raw handle |  |  | SIGSEGV |

---

## Injection Matrix: Null-Handle Guards (Surface Entry Points)

From `check-null-handle-guards.py` ALLOWED table - 14 Surface entry points need `surface.IsNull()` guard.

| Bridge Function | OCCT Call | Test Coverage | Injection Status |
|-----------------|-----------|---------------|------------------|
| `OCCTGeomLibToolParametersSurface` | `GeomLib_Tool::Parameters` | SurfaceTests | |
| `OCCTGeomConvertIsCanonical` | `GeomConvert_SurfToAnaSurf::IsCanonical` | SurfaceTests | |
| `OCCTGeomLibIsPlanarSurface` | `GeomLib_IsPlanarSurface` | SurfaceTests | |
| `OCCTGeomLibPlanarSurfacePlane` | `GeomLib_IsPlanarSurface` | SurfaceTests | |
| `OCCTExtremaExtPS` | `GeomAdaptor_Surface` | AnalysisTests | |
| `OCCTExtremaExtPSPoint` | `GeomAdaptor_Surface` | AnalysisTests | |
| `OCCTExtremaExtSS` | `GeomAdaptor_Surface` (2x) | AnalysisTests | |
| `OCCTExtremaExtSSPoint` | `GeomAdaptor_Surface` (2x) | AnalysisTests | |
| `OCCTGeomFillCoonsAlgPatchEval` | `GeomAdaptor_Curve` (local handle) | StressTests | |
| `OCCTBRepToolsEvalAndUpdateTol` | `BRepTools::EvalAndUpdateTol` (local handle) | StressTests | |

---

## Injection Procedure Per Test

```bash
# 1. Focused compile (3s)
swift build --target OCCTSurfaceTests

# 2. For each test:
#    a. Identify defect and bridge function
#    b. Create injection (revert kernel patch, remove guard, remove support face synthesis, etc.)
#    c. Run single test: swift test --filter <TestStructName>
#    d. Confirm FAIL (red) - crash, wrong result, or timeout
#    e. Restore fix
#    f. Confirm PASS (green)
#    g. Record in matrix above

# 3. Create PR for OCCTSurfaceTests
# 4. User reviews PR → merge what makes sense
# 5. Proceed to next domain (OCCTCurveTests)
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
| Filling Continuity And Support Faces (#430) | 16 |  |  |  |  |
| BSpline Surface Manipulation Tests | 12 |  |  |  |  |
| Surface Analytic Primitives | 12 |  |  |  |  |
| v0.146 Surface finish + GD&T symbols | 11 |  |  |  |  |
| NLPlate keeps the input surface's position | 10 |  |  |  |  |
| GeomFill, Gordon Report & Network Surface | 10 |  |  |  |  |
| Issue #266 follow-up, surface analysis extras | 9 |  |  |  |  |
| Surface Curve Projection Tests | 9 |  |  |  |  |
| Surface Operations | 8 |  |  |  |  |
| BSplineSurface Knot Queries | 8 |  |  |  |  |
| Plate point constraint G2 domain restriction (#437) | 8 |  |  |  |  |
| BSplineSurface Completions v121 | 8 |  |  |  |  |
| Advanced Plate Surface Tests | 8 |  |  |  |  |
| drawMesh honours its documented minimum (#620) | 8 |  |  |  |  |
| Surface Continuity Queries v0.120.0 | 8 |  |  |  |  |
| Bezier Surface Completions | 8 |  |  |  |  |
| ... | ... |  |  |  |  |

**Total**: 552 tests

### Measured: AdvancedPlateSurfaceTests.swift (8 tests), probe Scripts/repro/766-advanced-plate-surface/

| Suite | Test | Bridge function | Injection | Red (failing expectation) | Green | Parity | Notes |
|-------|------|-----------------|-----------|---------------------------|-------|--------|-------|
| Advanced Plate Surface Tests | Plate surface with G0 constraint orders | `OCCTShapePlatePointsAdvanced` | constraint points z + 1 (INJ_PLATE_ZOFF) | AdvancedPlateSurfaceTests.swift:37 maxDistance(from: points, to: s) < 1e-6 | ✅ | MATCH | Rewritten: `area > 0` passed a surface shifted off its points; now pins area and point distance |
| Advanced Plate Surface Tests | Plate surface rejects mixed G0/G1 orders (a bare point cannot carry tangent data) | `OCCTShapePlatePointsAdvanced` | Swift plateRejectsPointOrders returns false (INJ_PLATE_NO_ORDER_REJECT) | AdvancedPlateSurfaceTests.swift:53 shape == nil | ✅ | MATCH |  |
| Advanced Plate Surface Tests | Plate surface with custom degree and iterations | `OCCTShapePlatePointsAdvanced` | degree and iteration count swapped (INJ_PLATE_SWAPPARAMS) | AdvancedPlateSurfaceTests.swift:70 abs((s.surfaceArea ?? 0) - 137.30983411355206) < 1e-6 | ✅ | MATCH | Rewritten: asserted only `shape != nil`; now pins area and point distance |
| Advanced Plate Surface Tests | Plate surface rejects mismatched point/order counts | `OCCTShapePlatePointsAdvanced` | Swift and bridge count guards removed (INJ_PLATE_NO_COUNT_GUARD) | AdvancedPlateSurfaceTests.swift:80 shape == nil | ✅ | N/A | Wrapper precondition, no kernel counterpart |
| Advanced Plate Surface Tests | Plate surface rejects fewer than 3 points | `OCCTShapePlatePointsAdvanced` | count guards removed (INJ_PLATE_NO_COUNT_GUARD): stays GREEN, kernel throws V1==V2 and the bridge catch returns nil; red only with the catch also removed (INJ_PLATE_NOCATCH): uncaught Standard_ConstructionError aborts the run | libc++abi: terminating due to uncaught exception of type Standard_ConstructionError: Geom_RectangularTrimmedSurface::V1==V2 | ✅ | MATCH | Three independent layers refuse two points (Swift guard, bridge guard, kernel throw caught) |
| Advanced Plate Surface Tests | Mixed plate surface with points and curves | `OCCTShapePlateMixed` | curve constraints skipped (INJ_PLATE_NOCURVES) | AdvancedPlateSurfaceTests.swift:118 abs((s.surfaceArea ?? 0) - 266.0526366309989) < 1e-6 | ✅ | MATCH | Rewritten: asserted only `shape != nil`; now pins area and that points and boundary lie on the surface |
| Advanced Plate Surface Tests | Mixed plate surface with points only | `OCCTShapePlateMixed` | constraint points z + 1 (INJ_PLATE_ZOFF) | AdvancedPlateSurfaceTests.swift:145 maxDistance(from: pointConstraints.map(\.point), to: s) < 1e-6 | ✅ | MATCH | Rewritten: asserted only `shape != nil` |
| Advanced Plate Surface Tests | Advanced plate produces face with nonzero area | `OCCTShapePlatePointsAdvanced` | constraint points flattened to z = 0 (INJ_PLATE_ZFLAT) | AdvancedPlateSurfaceTests.swift:160 abs((s.surfaceArea ?? 0) - 161.0299905620775) < 1e-6 | ✅ | MATCH | Rewritten: `area > 50` passed the flattened 100 |
### Measured: AHTBezierCurve3DTests.swift, AHTBezierSurfaceTests.swift, ApproxCurveOnSurfaceTests.swift, BatchSurfaceTests.swift (8 tests), probes Scripts/repro/766-aht-bezier/, 766-approx-curve-on-surface/, 766-batch-surface/
| GeomEval AHTBezier 3D Curve | createAndEval | `OCCTGeomEvalAHTBezierCurveCreate` | pole 3 y + 0.5 (INJ_AHT_POLE) | AHTBezierCurve3DTests.swift:28 simd_length(pt - SIMD3(7.7249540992806089, 1.1276259652063807, 0)) < 1e-9 | ✅ | MATCH | Rewritten: `domain > 0` and a finite x passed wrong poles |
| GeomEval AHTBezier 3D Curve | rationalAHTBezier | `OCCTGeomEvalAHTBezierCurveCreateRational` | weights dropped, non-rational constructor (INJ_AHT_WEIGHTS) | AHTBezierCurve3DTests.swift:46 simd_length(c.point(at: 0.5) - SIMD3(1.9441876464157528, 0.43933290852097595, 0)) < 1e-9 | ✅ | MATCH | Rewritten: asserted only `curve != nil` |
| GeomEval AHTBezier Surface | createSurface | `OCCTGeomEvalAHTBezierSurfaceCreate` | pole grid read transposed (INJ_AHT_TRANSPOSE) | AHTBezierSurfaceTests.swift:28 simd_length(s.point(atU: 0.3, v: 0.7) - expected) < 1e-9 | ✅ | MATCH | Rewritten: asserted only `surf != nil` |
| Approx CurveOnSurface | Approximate curve on surface from edge PCurve | `OCCTApproxCurveOnSurface` | approximation range halved (INJ_APPROXCOS_HALF) | ApproxCurveOnSurfaceTests.swift:29 abs(length - expected[i]) < 1e-6 (x3, one per edge) | ✅ | MATCH | Rewritten: every path ended in `#expect(Bool(true))`, it could not fail |
| Batch Surface Evaluation | Evaluate grid on plane | `OCCTSurfaceEvaluateGrid` | X written into the Z slot (INJ_GRID_COMPONENT) | BatchSurfaceTests.swift:20 abs(grid.at(u: u, v: v).z) < 1e-10 | ✅ | MATCH |  |
| Batch Surface Evaluation | Evaluate grid on sphere | `OCCTSurfaceEvaluateGrid` | X written into the Z slot (INJ_GRID_COMPONENT) | BatchSurfaceTests.swift:38 abs(dist - 5.0) < 1e-6 | ✅ | MATCH |  |
| Batch Surface Evaluation | evaluateGrid indexes each (u, v) at its own parameter, not transposed | `OCCTSurfaceEvaluateGrid` | output index transposed (INJ_GRID_TRANSPOSE) | BatchSurfaceTests.swift:60 simd_length(actual - expected) < 1e-6 | ✅ | MATCH |  |
| Batch Surface Evaluation | drawMesh and evaluateGrid agree at matching parameters | `OCCTSurfaceDrawMesh` | drawMesh output slot transposed (INJ_DRAWMESH_TRANSPOSE) | BatchSurfaceTests.swift:91 simd_length(fromMesh - fromEval) < 1e-6 | ✅ | MATCH | Also reaches OCCTSurfaceEvaluateGrid |
### Measured: BezierSurfaceCompletionTests.swift, BezierSurfaceFillTests.swift, BezierSurfaceResolutionTests.swift (13 tests), probe Scripts/repro/766-bezier-surface-queries/
| Bezier Surface Completions | UIso and VIso return curves | `OCCTSurfaceBezierUIso` | UIso/VIso swapped (INJ_BZ_ISO_SWAP) | BezierSurfaceCompletionTests.swift:29 simd_length(uIso.point(at: 0.3) - s.point(atU: 0.5, v: 0.3)) < 1e-12 | ✅ | MATCH | Rewritten: asserted only non-nil. Also reaches OCCTSurfaceBezierVIso |
| Bezier Surface Completions | IsUClosed and IsVClosed | `OCCTSurfaceBezierIsUClosed` | always false (INJ_BZ_CLOSED_FALSE) | BezierSurfaceCompletionTests.swift:59 uClosed.bezierIsUClosed && !uClosed.bezierIsVClosed | ✅ | MATCH | Rewritten: only the open case, which "always false" passed; added a closed case per direction. Also reaches OCCTSurfaceBezierIsVClosed |
| Bezier Surface Completions | IsUPeriodic and IsVPeriodic always false | `OCCTSurfaceBezierIsUPeriodic` | always true (INJ_BZ_PERIODIC_TRUE) | BezierSurfaceCompletionTests.swift:73 !s.bezierIsUPeriodic | ✅ | MATCH | Also reaches OCCTSurfaceBezierIsVPeriodic |
| Bezier Surface Completions | Continuity is CN | `OCCTSurfaceBezierContinuity` | returns GeomAbs_C2 (INJ_BZ_CONT) | BezierSurfaceCompletionTests.swift:87 s.bezierContinuity == 6 | ✅ | MATCH |  |
| Bezier Surface Completions | IsCNu and IsCNv always true | `OCCTSurfaceBezierIsCNu` | returns n < 2 (INJ_BZ_ISCN_FALSE) | BezierSurfaceCompletionTests.swift:101 s.bezierIsCNu(10) | ✅ | MATCH | Also reaches OCCTSurfaceBezierIsCNv |
| Bezier Surface Completions | GetPoles bulk | `OCCTSurfaceBezierGetPoles` | poles read transposed (INJ_BZ_POLES_TRANSPOSE) | BezierSurfaceCompletionTests.swift:119 p == inputPoles.flatMap { $0 } | ✅ | MATCH | Rewritten: count alone passed a transposed grid |
| Bezier Surface Completions | GetWeights for non-rational returns nil | `OCCTSurfaceBezierGetWeights` | null weights reported as all 1.0 (INJ_BZ_WEIGHTS_ONES) | BezierSurfaceCompletionTests.swift:134 s.bezierWeights == nil | ✅ | MATCH | Rewritten: accepted "nil or all 1.0"; pinned to the documented nil |
| Bezier Surface Completions | Bounds returns [0,1]x[0,1] | `OCCTSurfaceBezierBounds` | Bounds out-arguments in the wrong order (INJ_BZ_BOUNDS_ORDER) | BezierSurfaceCompletionTests.swift:149 abs(b.u2 - 1) < 1e-10 | ✅ | MATCH |  |
| Bezier Surface Fill | Fill 4 bezier curves into surface | `OCCTSurfaceBezierFill4` | style forced to Coons (INJ_BZ_FILL_STYLE) | BezierSurfaceFillTests.swift:27 simd_length(surf.point(atU: 0.3, v: 0.6) - SIMD3(2.808, 6.42, 0)) < 1e-12 | ✅ | MATCH | Rewritten: asserted only non-nil |
| Bezier Surface Fill | Fill 2 bezier curves into surface | `OCCTSurfaceBezierFill2` | style forced to Curved (INJ_BZ_FILL_STYLE) | BezierSurfaceFillTests.swift:36 surf != nil | ✅ | MATCH | Rewritten: asserted only non-nil |
| Bezier Surface Fill | Fill with different styles | `OCCTSurfaceBezierFill2` | style forced to Curved (INJ_BZ_FILL_STYLE) | BezierSurfaceFillTests.swift:53 stretch != nil | ✅ | MATCH | Rewritten: discarded the curved result (`_ = curved`); pinned to nil |
| Bezier Surface Fill | Non-bezier curves return nil | `OCCTSurfaceBezierFill2` | Geom_BezierCurve type check removed (INJ_BZ_FILL_NOTYPECHECK) | process died inside "Non-bezier curves return nil" (null Geom_BezierCurve handle dereferenced), test target reported failure | ✅ | MATCH |  |
| Bezier Surface Resolution v0.120.0 | resolution | `OCCTSurfaceBezierMaxDegree` | MaxDegree() - 1 (INJ_BZ_MAXDEG) | BezierSurfaceResolutionTests.swift:14 md == 25 | ✅ | MATCH | Tightened `>= 25` to `== 25` |
### Measured: GeomConvertApproxSurfaceTests.swift and GeomEval{CircularHelicoid,CircularHelix,Ellipsoid,Hyperboloid,HypParaboloid,Paraboloid,SineWave}Tests.swift (26 tests), probe Scripts/repro/766-geomeval-approx/
| GeomConvert ApproxSurface Tests | approximate sphere as BSpline surface | `OCCTGeomConvertApproxSurface` | tolerance x 1000 (INJ_APPROXSURF_TOL) | GeomConvertApproxSurfaceTests.swift:20 abs(result.maxError - 0.00020644039516730319) < 1e-12 | ✅ | MATCH | Rewritten: sphere behind `if let`, surface discarded, only hasResult checked |
| GeomEval, Circular Helicoid Surface | circularHelicoidD0 | `OCCTGeomEvalCircularHelicoidD0` | u and v swapped (INJ_HELICOID_SWAP) | GeomEvalCircularHelicoidTests.swift:13 abs(p.x - 1.0) < 1e-10 | ✅ | MATCH |  |
| GeomEval, Circular Helicoid Surface | circularHelicoidSurfaceCreate | `OCCTGeomEvalCircularHelicoidCreate` | pitch doubled (INJ_HELICOID_PITCH) | GeomEvalCircularHelicoidTests.swift:23 simd_length(surf.point(atU: .pi / 2, v: 2) - SIMD3(0, 2, 1.25)) < 1e-12 | ✅ | MATCH | Rewritten: asserted only `!= nil`; now pins a point on the created geometry |
| GeomEval, Circular Helix Curve | helixD0AtZero | `OCCTGeomEvalCircularHelixD0` | radius + 1 (INJ_HELIX_R) | GeomEvalCircularHelixTests.swift:14 abs(p.x - 5.0) < 1e-10 | ✅ | MATCH |  |
| GeomEval, Circular Helix Curve | helixD0AtPi | `OCCTGeomEvalCircularHelixD0` | radius + 1 (INJ_HELIX_R) | GeomEvalCircularHelixTests.swift:21 abs(p.x - (-5.0)) < 1e-6 | ✅ | MATCH |  |
| GeomEval, Circular Helix Curve | helixD1 | `OCCTGeomEvalCircularHelixD1` | D1 x and y swapped (INJ_HELIX_D1SWAP) | GeomEvalCircularHelixTests.swift:29 abs(r.d1.x) < 1e-10 | ✅ | MATCH |  |
| GeomEval, Circular Helix Curve | helixD2 | `OCCTGeomEvalCircularHelixD2` | D2.x negated (INJ_HELIX_D2NEG) | GeomEvalCircularHelixTests.swift:37 abs(r.d2.x - (-5.0)) < 1e-10 | ✅ | MATCH |  |
| GeomEval, Circular Helix Curve | helixCurveCreate | `OCCTGeomEvalCircularHelixCurveCreate` | pitch doubled (INJ_HELIX_CREATE_PITCH) | GeomEvalCircularHelixTests.swift:45 simd_length(curve.point(at: .pi) - SIMD3(-3, 0, 3)) < 1e-12 | ✅ | MATCH | Rewritten: asserted only `!= nil`; now pins a point on the created geometry |
| GeomEval, Circular Helix Curve | helixCurveMinDistance | `OCCTExtremaPCMinDistance` | squared distance returned (INJ_EXTPC_SQ) | GeomEvalCircularHelixTests.swift:60 abs(d - 5) < 1e-9 | ✅ | MATCH | Rewritten: nested `if let`s and `d > 0` passed the squared distance 25 |
| GeomEval, Ellipsoid Surface | ellipsoidD0AtZeroZero | `OCCTGeomEvalEllipsoidD0` | a and c swapped (INJ_ELL_SWAP) | GeomEvalEllipsoidTests.swift:12 abs(p.x - 3.0) < 1e-10 | ✅ | MATCH |  |
| GeomEval, Ellipsoid Surface | ellipsoidD0AtPoles | `OCCTGeomEvalEllipsoidD0` | a and c swapped (INJ_ELL_SWAP) | GeomEvalEllipsoidTests.swift:22 abs(p.z - 5.0) < 1e-6 | ✅ | MATCH |  |
| GeomEval, Ellipsoid Surface | ellipsoidSurfaceCreate | `OCCTGeomEvalEllipsoidCreate` | a and c swapped (INJ_ELL_SWAP) | GeomEvalEllipsoidTests.swift:31 simd_length(surf.point(atU: 0.3, v: 0.4) - expected) < 1e-12 | ✅ | MATCH | Rewritten: asserted only `!= nil`; now pins a point on the created geometry |
| GeomEval, Hyperboloid Surface | hyperboloidOneSheetD0 | `OCCTGeomEvalHyperboloidD0` | r1 and r2 swapped (INJ_HYP_R) | GeomEvalHyperboloidTests.swift:14 abs(p.x - 2.0) < 1e-10 | ✅ | MATCH |  |
| GeomEval, Hyperboloid Surface | hyperboloidTwoSheets | `OCCTGeomEvalHyperboloidD0` | sheet mode ignored, always one sheet (INJ_HYP_SHEET) | GeomEvalHyperboloidTests.swift:24 simd_length(p - SIMD3(0, 0, 2)) < 1e-12 | ✅ | MATCH | Rewritten: `p.z != 0 || p.x != 0` passed the one-sheet point (2, 0, 0) |
| GeomEval, Hyperboloid Surface | hyperboloidSurfaceCreate | `OCCTGeomEvalHyperboloidCreate` | r1 and r2 swapped (INJ_HYP_R) | GeomEvalHyperboloidTests.swift:33 simd_length(surf.point(atU: 0.5, v: 0.3) - expected) < 1e-12 | ✅ | MATCH | Rewritten: asserted only `!= nil`; now pins a point on the created geometry |
| GeomEval, Hyperboloid Surface | hyperboloidTwoSheetsCreate | `OCCTGeomEvalHyperboloidCreate` | sheet mode ignored (INJ_HYP_SHEET) | GeomEvalHyperboloidTests.swift:43 simd_length(surf.point(atU: 0.5, v: 0.3) - expected) < 1e-12 | ✅ | MATCH | Rewritten: asserted only `!= nil`; now pins a point on the created geometry |
| GeomEval, Hyperbolic Paraboloid Surface | hypParaboloidD0AtOrigin | `OCCTGeomEvalHypParaboloidD0` | placement moved to z = 1 (INJ_HYPPAR_AX) | GeomEvalHypParaboloidTests.swift:13 abs(p.z) < 1e-10 | ✅ | MATCH |  |
| GeomEval, Hyperbolic Paraboloid Surface | hypParaboloidD0AwayFromOrigin | `OCCTGeomEvalHypParaboloidD0` | a and b swapped (INJ_HYPPAR_SWAP) | GeomEvalHypParaboloidTests.swift:20 abs(p.z - 1.0) < 1e-10 | ✅ | MATCH |  |
| GeomEval, Hyperbolic Paraboloid Surface | hypParaboloidSurfaceCreate | `OCCTGeomEvalHypParaboloidCreate` | a and b swapped (INJ_HYPPAR_SWAP) | GeomEvalHypParaboloidTests.swift:28 simd_length(surf.point(atU: 1, v: 2) - SIMD3(1, 2, -0.19444444444444442)) < 1e-12 | ✅ | MATCH | Rewritten: asserted only `!= nil`; now pins a point on the created geometry |
| GeomEval, Paraboloid Surface | paraboloidD0 | `OCCTGeomEvalParaboloidD0` | focal doubled (INJ_PAR_FOCAL) | GeomEvalParaboloidTests.swift:14 abs(p.z - 0.125) < 1e-10 | ✅ | MATCH |  |
| GeomEval, Paraboloid Surface | paraboloidSurfaceCreate | `OCCTGeomEvalParaboloidCreate` | focal doubled (INJ_PAR_FOCAL) | GeomEvalParaboloidTests.swift:23 simd_length(surf.point(atU: 0.5, v: 2) - expected) < 1e-12 | ✅ | MATCH | Rewritten: asserted only `!= nil`; now pins a point on the created geometry |
| GeomEval, 3D Sine Wave Curve | sineWaveD0AtZero | `OCCTGeomEvalSineWaveD0` | placement moved to y = 1 (INJ_SW_AX) | GeomEvalSineWaveTests.swift:13 abs(p.y) < 1e-10 | ✅ | MATCH |  |
| GeomEval, 3D Sine Wave Curve | sineWaveD0AtPiOver2 | `OCCTGeomEvalSineWaveD0` | omega doubled (INJ_SW_OMEGA) | GeomEvalSineWaveTests.swift:22 abs(p.y - 2.0) < 1e-6 | ✅ | MATCH |  |
| GeomEval, 3D Sine Wave Curve | sineWaveD1 | `OCCTGeomEvalSineWaveD1` | omega doubled (INJ_SW_OMEGA) | GeomEvalSineWaveTests.swift:29 abs(r.d1.y - 6.0) < 1e-6 | ✅ | MATCH |  |
| GeomEval, 3D Sine Wave Curve | sineWaveCurveCreate | `OCCTGeomEvalSineWaveCurveCreate` | omega doubled (INJ_SW_OMEGA) | GeomEvalSineWaveTests.swift:37 simd_length(curve.point(at: 1) - SIMD3(1, 0.90929742682568171, 0)) < 1e-12 | ✅ | MATCH | Rewritten: asserted only `!= nil`; now pins a point on the created geometry |
| GeomEval, 3D Sine Wave Curve | sineWaveWithPhase | `OCCTGeomEvalSineWaveD0` | phase dropped (INJ_SW_PHASE) | GeomEvalSineWaveTests.swift:43 abs(p.y - 1.0) < 1e-6 | ✅ | MATCH |  |
### Measured: Issue1017NLPlateResolutionOrderTests.swift, Issue1049NLPlateBaseSurfaceTests.swift (14 tests), probe Scripts/repro/766-nlplate-order-base/
| NLPlate resolution order is bounded and load-bearing (#1017) | An order outside 2...9 is refused rather than silently ignored | `OCCTSurfaceNLPlateG0` | occtNLPlateResolutionOrderInRange always true, the pre-#1017 behaviour (INJ_NL_NORANGE) | Issue1017NLPlateResolutionOrderTests.swift:46 surface.nlPlateDeformed(...) == nil, all six orders, and :49 for G1 | ✅ | MATCH | Also reaches OCCTSurfaceNLPlateG1 |
| NLPlate resolution order is bounded and load-bearing (#1017) | Every order the kernel accepts still builds and deforms | `OCCTSurfaceNLPlateG0` | G0 constraints not loaded (INJ_NL_NOLOAD) | Issue1017NLPlateResolutionOrderTests.swift:82 maxAbsZ > 1.0, all six orders | ✅ | MATCH |  |
| NLPlate resolution order is bounded and load-bearing (#1017) | Two accepted orders produce different surfaces | `OCCTSurfaceNLPlateG0` | order ignored, Solve2(4, 1) (INJ_NL_ORDER_FIXED) | Issue1017NLPlateResolutionOrderTests.swift:107 abs(lowZ - highZ) > 1.0 | ✅ | MATCH | FINDING: at order 8 the plate meets its (0,0,5) constraint but reaches |z| = 1764 at the edges of the padded working domain, and the 20x20 refit in occtNLPlateFitSolved misses the constraint by 22 (returns (1.25, -10.07, -16.93)). Swift matches the probe copy of the same fit exactly. The `> 1.0` passes because of that miss; now documented with withKnownIssue |
| NLPlate resolution order is bounded and load-bearing (#1017) | The default order moves the surface off the input plane | `OCCTSurfaceNLPlateG0` | G0 constraints not loaded (INJ_NL_NOLOAD) | Issue1017NLPlateResolutionOrderTests.swift:140 maxAbsZ > 1.0 | ✅ | MATCH |  |
| NLPlate keeps the input surface's position and parametrisation (#1049, #1046) | The fixture plane is parametrised as (100 + u, v, 0) | `OCCTSurfacePlaneFromPointNormal` | plane origin x + 1 (INJ_PLANE_ORIGIN) | Issue1049NLPlateBaseSurfaceTests.swift:50 abs(origin.x - 100) < 1e-9 | ✅ | MATCH |  |
| NLPlate keeps the input surface's position and parametrisation (#1049, #1046) | An identity constraint returns the input surface, G0 | `OCCTSurfaceNLPlateG0` | base surface added to NLPlate_NLPlate::Evaluate in the refit, the pre-#1049 doubling (INJ_NL_DOUBLEBASE) | Issue1049NLPlateBaseSurfaceTests.swift deviationFromInput(deformed, plane) < 1e-9 | ✅ | MATCH |  |
| NLPlate keeps the input surface's position and parametrisation (#1049, #1046) | An identity constraint returns the input surface, G1 | `OCCTSurfaceNLPlateG1` | base surface added to NLPlate_NLPlate::Evaluate in the refit, the pre-#1049 doubling (INJ_NL_DOUBLEBASE) | Issue1049NLPlateBaseSurfaceTests.swift deviationFromInput(deformed, plane) < 1e-9 | ✅ | MATCH |  |
| NLPlate keeps the input surface's position and parametrisation (#1049, #1046) | An identity constraint returns the input surface, G2 | `OCCTSurfaceNLPlateG2` | base surface added to NLPlate_NLPlate::Evaluate in the refit, the pre-#1049 doubling (INJ_NL_DOUBLEBASE) | Issue1049NLPlateBaseSurfaceTests.swift deviationFromInput(deformed, plane) < 1e-9 | ✅ | MATCH |  |
| NLPlate keeps the input surface's position and parametrisation (#1049, #1046) | An identity constraint returns the input surface, G3 | `OCCTSurfaceNLPlateG3` | base surface added to NLPlate_NLPlate::Evaluate in the refit, the pre-#1049 doubling (INJ_NL_DOUBLEBASE) | Issue1049NLPlateBaseSurfaceTests.swift deviationFromInput(deformed, plane) < 1e-9 | ✅ | MATCH |  |
| NLPlate keeps the input surface's position and parametrisation (#1049, #1046) | An identity constraint returns the input surface, incremental | `OCCTSurfaceNLPlateIncrementalG0` | base surface added to NLPlate_NLPlate::Evaluate in the refit, the pre-#1049 doubling (INJ_NL_DOUBLEBASE) | Issue1049NLPlateBaseSurfaceTests.swift deviationFromInput(deformed, plane) < 1e-9 | ✅ | MATCH |  |
| NLPlate keeps the input surface's position and parametrisation (#1049, #1046) | A pure-Z constraint moves z and leaves x and y alone | `OCCTSurfaceNLPlateG0` | base surface added in the refit (INJ_NL_DOUBLEBASE) | Issue1049NLPlateBaseSurfaceTests.swift:220 worstInPlane < 1e-9 | ✅ | MATCH |  |
| NLPlate keeps the input surface's position and parametrisation (#1049, #1046) | The constrained point is where the caller asked for it | `OCCTSurfaceNLPlateG0` | base surface added in the refit (INJ_NL_DOUBLEBASE) | Issue1049NLPlateBaseSurfaceTests.swift:242 abs(p.x - 100) < 1e-6 | ✅ | MATCH |  |
| NLPlate keeps the input surface's position and parametrisation (#1049, #1046) | The output carries the working domain, not [0, 1] | `OCCTSurfaceNLPlateG0` | knot reparametrisation skipped, the pre-#1046 [0, 1] output (INJ_NL_NOREPARAM) | Issue1049NLPlateBaseSurfaceTests.swift:249 abs(domain.uMin - Self.workingDomain.uMin) < 1e-9 | ✅ | MATCH | All five entry points (G0, G1, G2, G3, incremental) |
| NLPlate keeps the input surface's position and parametrisation (#1049, #1046) | A bounded direction keeps the input surface's own range | `OCCTSurfaceNLPlateG0` | u treated as unbounded, derived from the constraints (INJ_NL_DERIVE_ALL) | Issue1049NLPlateBaseSurfaceTests.swift:354 abs(domain.uMin) < 1e-9 | ✅ | MATCH |  |
### Measured: Issue1433GPropFaceKnotSizingTests.swift, Issue1460PlatePointG1Tests.swift, Issue1502DarbouxTrihedronTests.swift, Issue1515CoonsPatchUParameterTests.swift (13 tests), probe Scripts/repro/766-issue1433-1502-1515/
| Issue #1433, BRepGProp_Face knot-array sizing | V-direction integration knots are not truncated on a planar face | `OCCTBRepGPropFaceVKnots` | last knot dropped on read-back, the #1433 symptom without the heap overrun (INJ_1433_DROPLAST) | Issue1433GPropFaceKnotSizingTests.swift:41 knots.count == 2 | ✅ | MATCH | Re-introducing the undersized array itself would be an unguarded heap overflow, so the read-back symptom was injected instead |
| Issue #1433, BRepGProp_Face knot-array sizing | Boundary integration knots are not truncated on a straight face edge | `OCCTBRepGPropFaceBoundaryIntegration` | last knot dropped on read-back (INJ_1433_DROPLAST) | Issue1433GPropFaceKnotSizingTests.swift:60 bi.knots.count == 2 | ✅ | MATCH |  |
| Issue #1433, BRepGProp_Face knot-array sizing | V knots and boundary knots agree with their own already-correct subinterval counts | `OCCTBRepGPropFaceVKnots` | last knot dropped on read-back (INJ_1433_DROPLAST) | Issue1433GPropFaceKnotSizingTests.swift:78 face.faceIntegrationKnotsV().count == si.vSubs + 1 | ✅ | MATCH | Also reaches OCCTBRepGPropFaceSurfaceIntegration |
| Plate point constraint G1 domain restriction (#1460) | All-g1 orders are rejected for a point constraint | `OCCTShapePlatePointsAdvanced` | point-order guard reverted to the pre-#1460 `== .g2` (INJ_1460_G2ONLY) | Issue1460PlatePointG1Tests.swift:76 Shape.plateSurface(through: pentagon, orders: orders) == nil | ✅ | N/A |  |
| Plate point constraint G1 domain restriction (#1460) | A single g1 among otherwise-g0 orders poisons the whole call | `OCCTShapePlatePointsAdvanced` | point-order guard reverted to the pre-#1460 `== .g2` (INJ_1460_G2ONLY) | Issue1460PlatePointG1Tests.swift:83 Shape.plateSurface(through: pentagon, orders: orders) == nil | ✅ | N/A |  |
| Plate point constraint G1 domain restriction (#1460) | A g1 point constraint is rejected even alongside otherwise-valid curve constraints | `OCCTShapePlateMixed` | point-order guard reverted to the pre-#1460 `== .g2` (INJ_1460_G2ONLY) | Issue1460PlatePointG1Tests.swift:94 shape == nil | ✅ | N/A |  |
| Plate point constraint G1 domain restriction (#1460) | g1 alone, and g1 alongside g2, are both rejected for a point constraint | `OCCTShapePlatePointsAdvanced` | point-order guard reverted to the pre-#1460 `== .g2` (INJ_1460_G2ONLY) | Issue1460PlatePointG1Tests.swift:101 g1Only == nil | ✅ | N/A | The g1+g2 half stays green under this injection (g2 still refused), as the test file says |
| Plate point constraint G1 domain restriction (#1460) | The point-order guard's decision is unaffected by an accompanying g1 curve order | `(Swift) Shape.plateMixedRejectsPointOrders` | point-order guard reverted to the pre-#1460 `== .g2` (INJ_1460_G2ONLY) | Issue1460PlatePointG1Tests.swift:131 Shape.plateMixedRejectsPointOrders([(point: SIMD3(5, 5, 3), order: .g1)]) | ✅ | N/A |  |
| Issue #1502: Darboux trihedron on a real curve-on-surface | darbouxOnCircleEdgeOnFace | `OCCTGeomFillDarbouxTrihedron` | normal and binormal swapped (INJ_DARB_SWAP_NB) | Issue1502DarbouxTrihedronTests.swift:37 abs(abs(frame.binormal.z) - 1.0) < 1e-6 | ✅ | MATCH | Added: T and N pinned to the kernel frame; unit length and orthogonality alone passed a frame turned the wrong way |
| Issue #1502: Darboux trihedron on a real curve-on-surface | darbouxOnMultipleParameters | `OCCTGeomFillDarbouxTrihedron` | tangent written into the normal (INJ_DARB_T_EQ_N) | Issue1502DarbouxTrihedronTests.swift:56 abs(simd_dot(frame.tangent, frame.normal)) < 1e-6 (all five parameters) | ✅ | MATCH |  |
| Issue1515 Coons patch samples the U boundaries at U | every sample is the bilinear point, not its diagonal collapse | `OCCTGeomFillCoonsAlgPatchEval` | patch.Value(v, v): the #1515 U-collapse emulated at the bridge (INJ_1515_IGNORE_U); the fix is kernel patch 0034, which cannot be reverted without a kernel rebuild | Issue1515CoonsPatchUParameterTests.swift:66 simd_distance(got, want) < 1e-9 | ✅ | MATCH |  |
| Issue1515 Coons patch samples the U boundaries at U | the off-diagonal corners are not the diagonal's corners | `OCCTGeomFillCoonsAlgPatchEval` | patch.Value(v, v): the #1515 U-collapse emulated at the bridge (INJ_1515_IGNORE_U); the fix is kernel patch 0034, which cannot be reverted without a kernel rebuild | Issue1515CoonsPatchUParameterTests.swift:90 simd_distance(u1v0, SIMD3(Self.side, 0, 0)) < 1e-9 | ✅ | MATCH |  |
| Issue1515 Coons patch samples the U boundaries at U | holding v fixed and varying u moves the point | `OCCTGeomFillCoonsAlgPatchEval` | patch.Value(v, v): the #1515 U-collapse emulated at the bridge (INJ_1515_IGNORE_U); the fix is kernel patch 0034, which cannot be reverted without a kernel rebuild | Issue1515CoonsPatchUParameterTests.swift:111 spread > 1e-6 | ✅ | MATCH |  |
### Measured: BSplineSurfaceCompletionsV121Tests.swift, BSplineSurfaceCompletionsV129Tests.swift (12 tests), probe Scripts/repro/766-bspline-surface-completions/
| BSplineSurface Completions v121 | SetUNotPeriodic / SetVNotPeriodic | `OCCTSurfaceBSplineSetUNotPeriodic` | SetUPeriodic/SetVPeriodic called instead (INJ_BS_NOTPERIODIC_WRONG) | BSplineSurfaceCompletionsV121Tests.swift:34 !surf.isUPeriodic && !surf.isVPeriodic | ✅ | MATCH | Rewritten: asserted only the two Bools; also reaches OCCTSurfaceBSplineSetVNotPeriodic |
| BSplineSurface Completions v121 | IncreaseUMultiplicity / IncreaseVMultiplicity | `OCCTSurfaceBSplineIncreaseUMultiplicity` | IncreaseU/VMultiplicity skipped (INJ_BS_INCMULT_NOOP) | BSplineSurfaceCompletionsV121Tests.swift:50 surf.bsplineUMultiplicities == [4, 2, 4] | ✅ | MATCH | Rewritten: asserted only the Bool; also reaches OCCTSurfaceBSplineInsertUKnots |
| BSplineSurface Completions v121 | IncreaseVMultiplicity | `OCCTSurfaceBSplineIncreaseVMultiplicity` | IncreaseU/VMultiplicity skipped (INJ_BS_INCMULT_NOOP) | BSplineSurfaceCompletionsV121Tests.swift:63 surf.bsplineVMultiplicities == [4, 2, 4] | ✅ | MATCH | Rewritten: asserted only the Bool |
| BSplineSurface Completions v121 | SetUKnot / SetVKnot single index | `OCCTSurfaceBSplineSetUKnot` | SetUKnot/SetVKnot skipped (INJ_BS_SETKNOT_NOOP) | BSplineSurfaceCompletionsV121Tests.swift:79 abs((uKnots.first ?? 0) - (-1.0)) < 1e-9 | ✅ | MATCH | Caught as written; only the fixture `if let` made unconditional. Also reaches OCCTSurfaceBSplineSetVKnot |
| BSplineSurface Completions v121 | InsertUKnots / InsertVKnots batch | `OCCTSurfaceBSplineInsertUKnots` | InsertU/VKnots skipped (INJ_BS_INSERTKNOTS_NOOP) | BSplineSurfaceCompletionsV121Tests.swift:90 nuk == 4 | ✅ | MATCH | Caught as written; knot values added. Also reaches OCCTSurfaceBSplineInsertVKnots |
| BSplineSurface Completions v121 | MovePoint on BSpline surface | `OCCTSurfaceBSplineMovePoint` | target z + 0.5 (INJ_BS_MOVE_OFF) | BSplineSurfaceCompletionsV121Tests.swift:112 simd_length(p - target) < 1e-9 | ✅ | MATCH | Rewritten: checked x and y within 1.0 and never z, so a point moved to the wrong height passed |
| BSplineSurface Completions v121 | SetPoleCol and SetPoleRow | `OCCTSurfaceBSplineSetPoleCol` | SetPoleCol/Row skipped (INJ_BS_SETPOLE_NOOP) | BSplineSurfaceCompletionsV121Tests.swift:136 (1...4).map { bs.pole(uIndex: $0, vIndex: 1) } == [newRow[0]] + newCol.dropFirst() | ✅ | MATCH | Rewritten: asserted only the Bools; also reaches OCCTSurfaceBSplineSetPoleRow |
| BSplineSurface Completions v121 | SetUOrigin / SetVOrigin fail on non-periodic | `OCCTSurfaceBSplineSetUOrigin` | SetU/VOrigin skipped, so no refusal (INJ_BS_ORIGIN_NOOP) | BSplineSurfaceCompletionsV121Tests.swift:147 !r1 | ✅ | MATCH | Caught as written. Also reaches OCCTSurfaceBSplineSetVOrigin |
| BSplineSurface Completions v129 | SetWeightCol and SetWeightRow | `OCCTSurfaceBSplineSetWeightCol` | SetWeightCol/Row skipped (INJ_BS_SETWEIGHT_NOOP) | BSplineSurfaceCompletionsV129Tests.swift:34 (1...nbU).allSatisfy { bs.bsplineWeight(uIndex: $0, vIndex: 1) == 1 } | ✅ | MATCH | Rewritten: asserted only the Bools inside two `if`s; also reaches OCCTSurfaceBSplineSetWeightRow |
| BSplineSurface Completions v129 | IncrementUMultiplicity and IncrementVMultiplicity range | `OCCTSurfaceBSplineIncrementUMultiplicity` | IncrementU/VMultiplicity skipped (INJ_BS_INCREMENT_NOOP) | BSplineSurfaceCompletionsV129Tests.swift:63 cubic.bsplineUMultiplicities == [4, 2, 4] | ✅ | MATCH | Rewritten: on the sphere the increment is a kernel no-op (all knots at max multiplicity) so no assertion could see it; added a cubic case where it lands. Also reaches OCCTSurfaceBSplineIncrementVMultiplicity |
| BSplineSurface Completions v129 | First/Last U/V KnotIndex | `OCCTSurfaceBSplineFirstUKnotIndex` | all four indices + 1 (INJ_BS_KNOTINDEX_OFF) | BSplineSurfaceCompletionsV129Tests.swift:77 firstU == 1 | ✅ | MATCH | Rewritten: `>= 1` / `last >= first` passed an off-by-one; also reaches Last U, First/Last V |
| BSplineSurface Completions v129 | CheckAndSegment | `OCCTSurfaceBSplineCheckAndSegment` | CheckAndSegment skipped (INJ_BS_SEGMENT_NOOP) | BSplineSurfaceCompletionsV129Tests.swift:91 b.u1 == 0 && b.u2 == 1 && b.v1 == 0 && b.v2 == 1 | ✅ | MATCH | Rewritten: asserted only the Bool |
### Measured: BSplineSurfaceExtrasTests.swift, BSplineSurfaceFillTests.swift, BSplineSurfaceIsoTests.swift, BSplineSurfaceKnotSplitTests.swift (10 tests), probe Scripts/repro/766-bspline-extras-fill-iso/
| BSplineSurface_Extras | resolution | `OCCTSurfaceBSplineResolution` | u and v resolutions swapped (INJ_BS_RES_SWAP) | BSplineSurfaceExtrasTests.swift:23 abs(ur - 7.0494451571408934e-05) < 1e-15 | ✅ | MATCH | Rewritten: `> 0` passed swapped values |
| BSplineSurface_Extras | getWeight | `OCCTSurfaceBSplineGetWeight` | returns the 0 fallback (INJ_BS_WEIGHT_ZERO) | BSplineSurfaceExtrasTests.swift:31 abs(w - 1.0) < 1e-10 | ✅ | MATCH | Caught as written |
| BSplineSurface_Extras | setUPeriodic | `OCCTSurfaceBSplineSetUPeriodic` | periodic flag inverted (INJ_BS_PERIODIC_INVERT) | BSplineSurfaceExtrasTests.swift:42 !s.isUPeriodic | ✅ | MATCH | Rewritten: was `#expect(true)`, could not fail |
| BSplineSurface_Extras | setVPeriodic | `OCCTSurfaceBSplineSetVPeriodic` | periodic flag inverted (INJ_BS_PERIODIC_INVERT) | BSplineSurfaceExtrasTests.swift:52 !s.isVPeriodic | ✅ | MATCH | Rewritten: was `#expect(true)`, could not fail |
| BSpline Surface Fill | Fill from 2 boundary curves | `OCCTSurfaceFillBSpline2Curves` | style forced to Curved (INJ_BSFILL_STYLE) | BSplineSurfaceFillTests.swift:28 surface != nil | ✅ | MATCH | Rewritten: asserted only non-nil |
| BSpline Surface Fill | Fill from 4 boundary curves (Coons) | `OCCTSurfaceFillBSpline4Curves` | fourth curve replaced by the first (INJ_BSFILL_ORDER) | process died inside "Fill from 4 boundary curves (Coons)": GeomFill_BSplineCurves faults (SIGSEGV) on a boundary that does not close, reproduced in the probe | ✅ | MATCH | Rewritten: asserted only non-nil. KERNEL FINDING: four curves that do not close SIGSEGV in GeomFill_BSplineCurves, uncatchable, reachable from Surface.bsplineFill(curves:). A first injection, swapping curves 2 and 3, stayed GREEN: the kernel reorders the curves itself |
| BSpline Surface Fill | Stretch fill style | `OCCTSurfaceFillBSpline2Curves` | style forced to Curved (INJ_BSFILL_STYLE) | BSplineSurfaceFillTests.swift:85 surface != nil | ✅ | MATCH | Rewritten: inputs behind `if let`, only non-nil; now also pins that curved is refused |
| BSplineSurface Iso Curves | UIso returns curve | `OCCTSurfaceBSplineUIso` | UIso/VIso swapped (INJ_BS_ISO_SWAP) | BSplineSurfaceIsoTests.swift:25 simd_length(iso.point(at: 0.3) - bs.point(atU: uMid, v: 0.3)) < 1e-12 | ✅ | MATCH | Rewritten: asserted only non-nil |
| BSplineSurface Iso Curves | VIso returns curve | `OCCTSurfaceBSplineVIso` | UIso/VIso swapped (INJ_BS_ISO_SWAP) | BSplineSurfaceIsoTests.swift:42 simd_length(iso.point(at: 1.0) - bs.point(atU: 1.0, v: vMid)) < 1e-12 | ✅ | MATCH | Rewritten: asserted only non-nil |
| BSplineSurface KnotSplitting Tests | knotSplitsU | `OCCTSurfaceKnotSplitting` | requested continuity + 1 (INJ_KS_CONT) | BSplineSurfaceKnotSplitTests.swift:20 c0.uSplitCount == 2 | ✅ | MATCH | Rewritten: `n >= 0` held for any Int |
