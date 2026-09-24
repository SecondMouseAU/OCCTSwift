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
