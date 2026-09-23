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

### Measured: ProjectCurveOnSurface, ProjectionOnSurface, RectangularTrimmedSurface, RevolutionFeature, RevolutionForm, RevolutionFromCurve, SectionPlane, ShapeRevolutionAxes, ShellFromSurface (21 tests), probe Scripts/repro/766-projection-trim-revolution-section/

| Suite | Test | Bridge function | Injection | Red (failing expectation) | Green | Parity | Notes |
|-------|------|-----------------|-----------|---------------------------|-------|--------|-------|
| ProjectCurveOnSurface Tests | project line onto plane | `OCCTProjectCurveOnSurface` | 2D result translated by (0, 1) (INJ_PCOS_SHIFT) | ProjectCurveOnSurfaceTests.swift:21 simd_length(curve2d.point(at: 0) - SIMD2(1, 2)) < 1e-9 | ✅ | MATCH | Rewritten: only non-nil, inside `if let`; now names the Curve2D overload explicitly |
| v0.113.0 - ProjectionOnSurface | multiResultProjection | `OCCTProjOnSurfPoint` | index + 1 (INJ_POS_INDEX) | ProjectionOnSurfaceTests.swift:19 simd_length(proj.point(at: 0) - SIMD3(5, 0, 0)) < 1e-9 | ✅ | MATCH | Rewritten: two `u >= 0 || u < 0` expectations could not fail. Also reaches OCCTProjOnSurfCreate, OCCTProjOnSurfParameters, OCCTProjOnSurfDistance |
| Geom_RectangularTrimmedSurface Tests | trimPlane | `OCCTSurfaceCreateRectangularTrimmed` | u and v ranges swapped (INJ_TRIM_SWAP) | RectangularTrimmedSurfaceTests.swift:21 d.uMin == -5 && d.uMax == 5 && d.vMin == -3 && d.vMax == 3 | ✅ | MATCH | Rewritten: only non-nil |
| Geom_RectangularTrimmedSurface Tests | trimInU | `OCCTSurfaceCreateTrimmedInU` | UTrim flag inverted (INJ_TRIM_SWAP) | RectangularTrimmedSurfaceTests.swift:32 d.uMin == -2 && d.uMax == 2 | ✅ | MATCH | Rewritten: only non-nil |
| Geom_RectangularTrimmedSurface Tests | trimInV | `OCCTSurfaceCreateTrimmedInV` | UTrim flag inverted (INJ_TRIM_SWAP) | RectangularTrimmedSurfaceTests.swift:44 d.vMin == -3 && d.vMax == 3 | ✅ | MATCH | Rewritten: only non-nil |
| Revolution Feature | Revolved boss on box | `OCCTShapeRevolFeature` | fuse flag inverted (INJ_REVOLF_FUSE) | RevolutionFeatureTests.swift:31 abs((result.volume ?? 0) - 8392699.0816987269) < 1e-3 | ✅ | MATCH | Rewritten: `_ = result`, and its off-face profile made the kernel return the unchanged box |
| Revolution Feature | Revolved feature thru all (360) | `OCCTShapeRevolFeatureThruAll` | fuse flag inverted (INJ_REVOLF_FUSE) | RevolutionFeatureTests.swift:48 abs((result.volume ?? 0) - 8882194.4784009419) < 1e-3 | ✅ | MATCH | Rewritten: `_ = result`, same off-face profile |
| Revolution Form Feature | Add revolution form to shape | `OCCTShapeAddRevolutionForm` | XZ plane substituted when FindSurface fails (INJ_RF_PLANE) | RevolutionFormTests.swift:26 result == nil | ✅ | MATCH | Rewritten: `_ = result`; the result is always nil for this profile, now pinned |
| Revolution from Curve | Revolve segment into cylinder | `OCCTShapeCreateRevolutionFromCurve` | angle halved (INJ_REVCURVE_ANGLE) | RevolutionFromCurveTests.swift:20 abs((solid?.volume ?? 0) - 785.39816339744823) < 1e-6 | ✅ | MATCH | Rewritten: only non-nil |
| Revolution from Curve | Revolve circle into torus-like shape | `OCCTShapeCreateRevolutionFromCurve` | angle halved (INJ_REVCURVE_ANGLE) | RevolutionFromCurveTests.swift:30 abs((solid?.surfaceArea ?? 0) - 1184.3525281307232) < 1e-6 | ✅ | MATCH | Rewritten: only non-nil. FINDING: the kernel solid is inside out (volume -1776.53) and Shape.volume turns the negative value into nil |
| Revolution from Curve | Partial revolution | `OCCTShapeCreateRevolutionFromCurve` | angle halved (INJ_REVCURVE_ANGLE) | RevolutionFromCurveTests.swift:39 abs((solid?.volume ?? 0) - 196.34954084936206) < 1e-6 | ✅ | MATCH | Rewritten: only non-nil |
| v0.127.0, Section with Plane/Surface | Section shape with plane produces edges | `OCCTShapeSectionWithPlane` | plane moved 1 along its normal (INJ_SECTION_SHIFT) | SectionPlaneTests.swift:21 edges.count == 4 | ✅ | MATCH | `> 0` behind `if let` pinned to 4, unconditional |
| v0.127.0, Section with Plane/Surface | Section shape with cylindrical surface | `OCCTShapeSectionWithSurface` | surface translated (10, 10, 0) (INJ_SECTION_SHIFT) | SectionPlaneTests.swift:35 section.subShapes(ofType: .edge).count == 4 | ✅ | MATCH | `> 0` behind two `if let`s pinned to 4 |
| v0.137 Shape.revolutionAxes | Cylinder yields exactly one axis | `OCCTShapeRevolutionAxes` | every axis recorded twice (INJ_AXES_DUP) | ShapeRevolutionAxesTests.swift:14 axes.count == 1 | ✅ | MATCH | Caught as written |
| v0.137 Shape.revolutionAxes | Box yields no revolution axes | `OCCTShapeRevolutionAxes` | planar faces reported as axes (INJ_AXES_PLANE) | ShapeRevolutionAxesTests.swift:27 box.revolutionAxes().isEmpty | ✅ | MATCH | Caught as written |
| v0.137 Shape.revolutionAxes | Torus yields one deduplicated axis | `OCCTShapeRevolutionAxes` | kind reported as cylinder (INJ_AXES_KIND); axis duplicated (INJ_AXES_DUP) | ShapeRevolutionAxesTests.swift:39 axes.contains { $0.kind == .torus } | ✅ | MATCH | `count >= 1` tightened to `== 1` |
| v0.137 Shape.revolutionAxes | Coaxial cylinder + torus collapse to one axis | `OCCTShapeRevolutionAxes` | every axis recorded twice (INJ_AXES_DUP) | ShapeRevolutionAxesTests.swift:64 axes.count == 1 | ✅ | N/A | Caught as written |
| v0.137 Shape.revolutionAxes | Cylinder's revolution axis reports a real, non-nil extent matching its height | `OCCTShapeRevolutionAxes` | every axis recorded twice (INJ_AXES_DUP) | ShapeRevolutionAxesTests.swift:81 axes.count == 1 | ✅ | N/A | Caught as written |
| v0.137 Shape.revolutionAxes | More than 256 distinct revolution axes: reported count never exceeds the buffer capacity | `OCCTShapeRevolutionAxes` | uncapped count returned, the #1576 defect (INJ_AXES_UNCAPPED) | Swift/ContiguousArrayBuffer.swift:695: Fatal error: Index out of range (process trapped inside the test) | ✅ | N/A | Caught as written |
| Shell from Surface | Shell from cylinder surface | `OCCTShapeMakeShell` | v range halved (INJ_SHELL_VHALF) | ShellFromSurfaceTests.swift:15 abs((s.surfaceArea ?? 0) - 314.15926535897933) < 1e-9 | ✅ | MATCH | Rewritten: `surfaceArea! > 0` (force unwrap in #expect, any area) |
| Shell from Surface | Shell from plane surface | `OCCTShapeMakeShell` | v range halved (INJ_SHELL_VHALF) | ShellFromSurfaceTests.swift:25 abs((shell?.surfaceArea ?? 0) - 100) < 1e-9 | ✅ | MATCH | Rewritten: only non-nil |
