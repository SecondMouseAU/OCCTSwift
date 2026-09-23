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

### Measured: BSplineSurfaceCompletionsV121Tests.swift, BSplineSurfaceCompletionsV129Tests.swift (12 tests), probe Scripts/repro/766-bspline-surface-completions/

| Suite | Test | Bridge function | Injection | Red (failing expectation) | Green | Parity | Notes |
|-------|------|-----------------|-----------|---------------------------|-------|--------|-------|
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
