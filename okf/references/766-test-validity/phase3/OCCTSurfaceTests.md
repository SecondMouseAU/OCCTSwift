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

### Measured: FillingSupportFaceTests.swift (19 tests), probe Scripts/repro/766-filling-support-face/

| Suite | Test | Bridge function | Injection | Red (failing expectation) | Green | Parity | Notes |
|-------|------|-----------------|-----------|---------------------------|-------|--------|-------|
| Filling Continuity And Support Faces (#430) | Default parameters on a curved boundary return a surface instead of crashing | `OCCTShapeFill` | face-less Add for every order, the #430 path (INJ_FSF_FACELESS); also every order forced to C0 (INJ_FSF_C0) | FACELESS: process died inside the test (the #430 SIGSEGV); C0: FillingSupportFaceTests.swift:62 (capped.size?.z ?? .nan) > 0.5 | ✅ | MATCH | Strengthened: it asserted only non-nil; now also requires the tangent cap |
| Filling Continuity And Support Faces (#430) | Tangent fill against a support shape is not flat | `OCCTShapeFillWithSupport` | every order forced to C0 (INJ_FSF_C0) | FillingSupportFaceTests.swift:90 (tangent.size?.z ?? .nan) > 0.5 | ✅ | MATCH | Caught as written; `size!` removed from #expect |
| Filling Continuity And Support Faces (#430) | Explicit per-edge constraint with a support face is tangent | `OCCTShapeFillConstraints` | every order forced to C0 (INJ_FSF_C0) | FillingSupportFaceTests.swift:113 (capped.size?.z ?? .nan) > 0.5 | ✅ | MATCH | Caught as written |
| Filling Continuity And Support Faces (#430) | Curvature continuity is accepted and differs from tangency | `OCCTShapeFillWithSupport` | .g2 mapped to tangency (INJ_FSF_G2_AS_G1) | FillingSupportFaceTests.swift:144 (curvature.size?.z ?? .nan) > (tangent.size?.z ?? .nan) + 0.5 | ✅ | MATCH | Caught as written |
| Filling Continuity And Support Faces (#430) | maxDegree caps the degree of the resulting surface (#431) | `OCCTShapeFillWithSupport` | maxDegree ignored, MaxDeg 8 (INJ_FSF_MAXDEG) | surface.uDegree <= 3 and vDegree <= 3 (2 issues) | ✅ | MATCH | Caught as written |
| Filling Continuity And Support Faces (#430) | A boundary edge absent from the support shape falls back rather than failing | `OCCTShapeFillWithSupport` | edge absent from the support fails the fill (INJ_FSF_NO_FALLBACK) | FillingSupportFaceTests.swift: fill returned nil, Issue.record("Fill should fall back per edge, not fail outright") | ✅ | MATCH | Caught as written |
| Filling Continuity And Support Faces (#430) | A free-standing boundary with an unrelated support still degrades instead of failing (#1503) | `OCCTShapeFillWithSupport` | pcurve-less edge keeps .g1, the pre-#1503 path (INJ_FSF_NO_DEGRADE) | fill returned nil (Issue.record) | ✅ | MATCH | Caught as written |
| Filling Continuity And Support Faces (#430) | Free-standing constraint edges degrade instead of failing the whole build (#1503) | `OCCTShapeFillConstraints` | pcurve-less edge keeps .g1 (INJ_FSF_NO_DEGRADE) | fill returned nil (Issue.record) | ✅ | MATCH | Caught as written |
| Filling Continuity And Support Faces (#430) | An internal constraint pulls the surface without bounding it | `OCCTShapeFillConstraints` | non-bounding constraints dropped (INJ_FSF_DROP_INTERNAL); forcing them bound (INJ_FSF_BOUND) stayed GREEN | FillingSupportFaceTests.swift:291 (withInterior.size?.z ?? .nan) > 0.5 | ✅ | MATCH | Caught as written. Marking the interior edge bound still builds a raised surface, so that injection cannot see the bound/free distinction |
| Filling Continuity And Support Faces (#430) | Free-standing boundary degrades to position-only continuity instead of failing (#1503) | `OCCTShapeFill` | pcurve-less edge keeps .g1 (INJ_FSF_NO_DEGRADE) | fill returned nil (Issue.record) | ✅ | MATCH | Caught as written |
| Filling Continuity And Support Faces (#430) | Constraints fill rejects an empty constraint list | `OCCTShapeFillConstraints` | none turns it red: the Swift wrapper, the bridge count check and the added == 0 check each refuse it | not red | ✅ | N/A | NOT PROVEN RED |
| Filling Continuity And Support Faces (#430) | A nominated support face that cannot serve is a failure, not a substitution | `OCCTShapeFillConstraints` | Nominated refusal skipped, falls back to a derived face (INJ_FSF_NOMINATED) | FillingSupportFaceTests.swift:356 substituted == nil | ✅ | MATCH | Caught as written |
| Filling Continuity And Support Faces (#430) | FillingSurface honours maxDegree instead of retargeting the iteration count (#431) | `OCCTFillingAddEdge` | maxDegree ignored, MaxDeg 8 (INJ_FSF_MAXDEG) | surface.uDegree <= 3 and vDegree <= 3 (2 issues) | ✅ | MATCH | Caught as written |
| Filling Continuity And Support Faces (#430) | FillingSurface survives a curved boundary above positional continuity (#432) | `OCCTFillingAddEdge` | face-less Add (INJ_FSF_FACELESS); also C0 forced (INJ_FSF_C0) | FACELESS: process died inside the test; C0: FillingSupportFaceTests.swift:408 (face.size?.z ?? .nan) > 0.5 | ✅ | MATCH | Strengthened: it asserted only non-nil; now also requires the tangent cap |
| Filling Continuity And Support Faces (#430) | FillingSurface maps .g1 to tangency and .g2 to curvature, not the reverse (#433) | `OCCTFillingAddEdgeWithSupport` | .g2 mapped to tangency (INJ_FSF_G2_AS_G1) | FillingSupportFaceTests.swift:445 (curvatureFace.size?.z ?? .nan) > (tangentFace.size?.z ?? .nan) + 0.5 | ✅ | MATCH | Caught as written |
| Filling Continuity And Support Faces (#430) | add(edge:support:continuity:) rejects a support face that cannot serve (#434) | `OCCTFillingAddEdgeWithSupport` | Nominated refusal skipped (INJ_FSF_NOMINATED) | !filling.add(edge: rim, support: strangerFace, continuity: .g1) | ✅ | N/A | Caught as written |
| Filling Continuity And Support Faces (#430) | add(edge:support:continuity:) defaults to .g1, not .g0, so its default call validates support (#434 review) | `OCCTFillingAddEdgeWithSupport` | Nominated refusal skipped (INJ_FSF_NOMINATED) | !rejecting.add(edge: rim, support: strangerFace) | ✅ | MATCH | Caught as written |
| Filling Continuity And Support Faces (#430) | A refused add poisons build(), matching Shape.fill(constraints:) (#482) | `OCCTFillingBuild` | refusal count ignored by build (INJ_FSF_POISON_OFF) | poisoned.build() == nil (3 issues) | ✅ | N/A | Caught as written |
| Filling Continuity And Support Faces (#430) | Refusals accumulate and stay sticky across later successful adds (#482) | `OCCTFillingBuild` | refusal count ignored by build (INJ_FSF_POISON_OFF) | filling.build() == nil | ✅ | N/A | Caught as written |
