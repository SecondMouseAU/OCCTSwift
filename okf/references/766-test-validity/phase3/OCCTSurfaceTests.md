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

### Measured: SurfaceAnalyticTests.swift, SurfaceApproximateDefaultsParityTests.swift, SurfaceAxisAccessorsTests.swift (19 tests), probes Scripts/repro/766-surface-analytic/ and 766-surface-approx-defaults/

| Suite | Test | Bridge function | Injection | Red (failing expectation) | Green | Parity | Notes |
|-------|------|-----------------|-----------|---------------------------|-------|--------|-------|
| Surface Analytic Primitives | Create plane and evaluate point | `OCCTSurfaceGetPoint` | u and v swapped in D0 (INJ_SA_POINT_UV) | SurfaceAnalyticTests.swift:28 plane.point(atU: 3, v: 4) == SIMD3(3, 4, 0) | ✅ | MATCH | Rewritten: (0, 0) maps to the origin under any parameterisation; added (3, 4). Also reaches OCCTSurfaceCreatePlane, OCCTSurfaceGetDomain |
| Surface Analytic Primitives | Plane normal is consistent | `OCCTSurfaceGetNormal` | normal reversed (INJ_SA_NORMAL_NEG) | SurfaceAnalyticTests.swift:39 n == SIMD3(0, 0, 1) | ✅ | MATCH | Rewritten: `abs(n.z)` passed a flipped normal |
| Surface Analytic Primitives | Create sphere and check properties | `OCCTSurfaceGetUPeriod` | period doubled (INJ_SA_UPERIOD) | SurfaceAnalyticTests.swift:57 abs(period - 2 * .pi) < 1e-10 | ✅ | MATCH | Caught as written |
| Surface Analytic Primitives | Closure flags (isUClosed/isVClosed) match each analytic surface's own documented answer | `OCCTSurfaceIsUClosed` | U and V swapped (INJ_SA_CLOSED_SWAP) | SurfaceAnalyticTests.swift:76 cyl.isUClosed == true | ✅ | MATCH | Caught as written; cylinder and torus `if let`s made unconditional. Also reaches OCCTSurfaceIsVClosed |
| Surface Analytic Primitives | Sphere point evaluation | `OCCTSurfaceCreateSphere` | sphere axis X instead of Z (INJ_SA_SPHERE_AXIS) | SurfaceAnalyticTests.swift:102 simd_length(p - SIMD3(r, 0, 0)) < 1e-12 | ✅ | MATCH | Rewritten: radius alone passed a sphere on the wrong axis |
| Surface Analytic Primitives | Create cylinder | `OCCTSurfaceCreateCylinder` | radius + 1 (INJ_SA_CYL_R) | SurfaceAnalyticTests.swift:114 abs(rDist - 3.0) < 1e-10 | ✅ | MATCH | Caught as written; point pinned |
| Surface Analytic Primitives | Create cone | `OCCTSurfaceCreateCone` | reference radius + 1 (INJ_SA_CONE_R) | SurfaceAnalyticTests.swift:128 simd_length(cone.point(atU: 0, v: 0) - SIMD3(5, 0, 0)) < 1e-12 | ✅ | MATCH | Rewritten: asserted only non-nil |
| Surface Analytic Primitives | Create torus | `OCCTSurfaceCreateTorus` | major radius + 1 (INJ_SA_TORUS_R) | SurfaceAnalyticTests.swift:142 simd_length(torus.point(atU: 0, v: 0) - SIMD3(13, 0, 0)) < 1e-12 | ✅ | MATCH | Rewritten: periodicity alone passed wrong radii |
| Surface Analytic Primitives | Sphere Gaussian curvature = 1/r² | `OCCTSurfaceGetGaussianCurvature` | +0.1 on the reported curvature (INJ_SA_CURV_OFF) | SurfaceAnalyticTests.swift:152 abs(gc - expected) < 1e-10 | ✅ | MATCH | Caught as written |
| Surface Analytic Primitives | Sphere mean curvature = 1/r | `OCCTSurfaceGetMeanCurvature` | +0.1 on the reported curvature (INJ_SA_CURV_OFF) | SurfaceAnalyticTests.swift:163 abs(abs(mc) - expected) < 1e-10 | ✅ | MATCH | Caught as written; the kernel sign (-1/r) pinned too |
| Surface Analytic Primitives | Plane Gaussian curvature = 0 | `OCCTSurfaceGetGaussianCurvature` | +0.1 on the reported curvature (INJ_SA_CURV_OFF) | SurfaceAnalyticTests.swift:176 abs(gc) < 1e-10 | ✅ | MATCH | Caught as written |
| Surface Analytic Primitives | Cylinder principal curvatures = (0, 1/r) | `OCCTSurfaceGetPrincipalCurvatures` | kMin + 0.1 (INJ_SA_PC_KOFF) | SurfaceAnalyticTests.swift:192 abs(maxK - 1.0 / r) < 1e-10 | ✅ | MATCH | Caught as written |
| Surface Analytic Primitives | Cylinder principal curvature directions are not transposed | `OCCTSurfaceGetPrincipalCurvatures` | min/max directions swapped, the #1437 defect (INJ_SA_PC_SWAPDIR) | SurfaceAnalyticTests.swift:227 abs(abs(axialDir.z) - 1.0) < 1e-10 | ✅ | MATCH | Caught as written |
| Surface.approximated defaults match Curve3D/Curve2D (#406) | Default call succeeds and respects the shared maxDegree cap | `OCCTSurfaceApproximate` | Swift defaults back to 1e-2 / 10, the pre-#406 values (INJ_APPROX_OLD_DEFAULTS) | SurfaceApproximateDefaultsParityTests.swift:28 approx.uDegree <= 8 | ✅ | MATCH | Caught as written; pole counts pinned |
| Surface.approximated defaults match Curve3D/Curve2D (#406) | Default call is equivalent to an explicit tolerance: 1e-3, maxDegree: 8 call | `OCCTSurfaceApproximate` | Swift defaults back to 1e-2 / 10 (INJ_APPROX_OLD_DEFAULTS) | SurfaceApproximateDefaultsParityTests.swift:43 a.uDegree == b.uDegree | ✅ | MATCH | Caught as written |
| Surface.approximated defaults match Curve3D/Curve2D (#406) | Tighter shared defaults still succeed on every primitive the old looser defaults handled | `OCCTSurfaceApproximate` | periodic input refused (INJ_APPROX_NOPERIODIC) | SurfaceApproximateDefaultsParityTests.swift:52 sphere.approximated() != nil | ✅ | MATCH | Three `if let` primitives made unconditional; pole counts pinned |
| Surface.approximated defaults match Curve3D/Curve2D (#406) | Non-analytic surface (offset of a BSpline base) still approximates at the new default | `OCCTSurfaceApproximate` | offset surface approximated from its un-offset base, the regression the test names (INJ_APPROX_BASE) | SurfaceApproximateDefaultsParityTests.swift:149 abs(maxDeviation - 0.026897065170123618) < 1e-6 | ✅ | MATCH | Rewritten: `maxDeviation < 0.5` passed the named regression (0.300) |
| v0.137 Surface.torusAxis / revolutionAxis | Torus surface exposes axis | `OCCTSurfaceTorusAxis` | location not written, fallback origin kept (INJ_AX_ORIGIN) | SurfaceAxisAccessorsTests.swift:21 abs(axis.origin.x - 1) < 1e-6 | ✅ | MATCH | Caught as written |
| v0.137 Surface.torusAxis / revolutionAxis | Cylinder surface returns nil for torusAxis | `OCCTSurfaceGetType` | kind guard skipped in axis(ifKind:) (INJ_AX_NOKIND) | SurfaceAxisAccessorsTests.swift:40 surf.torusAxis == nil | ✅ | MATCH | Caught as written |
