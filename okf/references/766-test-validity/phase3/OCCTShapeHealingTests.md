# Phase 3: OCCTShapeHealingTests Injection Matrix

**Target**: `OCCTShapeHealingTests` (320 tests) — fix/heal operations, degenerate geometry
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (fix/heal operations, degenerate geometry, crash fixes #317, #318, #263)

---

## Test Inventory by Suite (Top by Count)

| Suite | Tests | Lines | Primary Category |
|-------|-------|-------|------------------|
| Issue 443: solid(from:) and upgraded() cover every body | 22 | — | WR/CR (#442) |
| Issue 442: fixSolid/solidFromShellFixed cover every body | 16 | — | WR/CR |
| ShapeAnalysis_Edge Tests | 14 | — | WR |
| Issue 702: solid demotion is reported accurately | 12 | — | WR/CR |
| ShapeBuild Edge | 9 | — | WR |
| ShapeAnalysis_Wire Tests | 9 | — | WR |
| ShapeAnalysis_ShapeTolerance | 8 | — | WR |
| Advanced Healing Tests | 8 | — | WR |
| SAWireAnalysis.checkOuterBound (#1058) | 7 | — | RF/OOB |
| ShapeAnalysis FreeBoundsProperties Tests | 7 | — | WR |
| Issue #446, unify does not mutate its input | 6 | — | WR |
| ShapeAnalysis_Curve Static Method Tests | 6 | — | WR |
| Issue 570: healing approximations accepted on a zeroed error | 6 | — | WR/CR (#522) |
| v0.123.0, UnifySameDomain builder | 5 | — | WR |
| Issue #484, Shape.connectedFaces coverage | 5 | — | WR |
| Free Boundary Analysis | 5 | — | WR |
| v0.122.0, Sewing Extended | 5 | — | WR |
| Issue 772: analyze() self-intersection is opt-in | 5 | — | TO/CR (#319) |
| Issue #266 follow-up, face healing control & checks | 4 | — | WR |
| Issue #490: one continuity vocabulary per operation | 4 | — | WR |
| ShapeConstruct Curve Tests | 4 | — | WR |
| ShapeAnalysis_Surface Tests | 4 | — | WR |
| ShapeExtend Explorer | 4 | — | WR |
| v0.122.0, ShapeFix_Edge Extended | 4 | — | WR |
| #849 - ShapeFixStatus real OCCT ordinals | 4 | — | WR |
| ShapeAnalysis_FreeBounds Simplified Tests | 4 | — | WR |
| Issue #484, Face.fixed(tolerance:) gets a ReShape context | 4 | — | CR (#317, #318) |
| ShapeUpgrade ConvertSurfacesToBezier | 3 | — | WR |
| ShapeUpgrade SplitCurve Tests | 3 | — | WR |
| Issue #870: OCCTShapeExtendShapeType failure fallback | 3 | — | WR |
| ShapeAnalysis Surface ValueOfUV Tests | 3 | — | WR |
| Sewing Tests | 3 | — | WR |
| Shape Analysis Tests | 3 | — | WR |
| Shape Fixing Tests | 3 | — | WR |
| Self-Intersecting Profile Crash Guard (#263) | 3 | — | CR |
| Sewing_Extras | 3 | — | WR |
| #837: fixed() mode-flag wiring | 3 | — | WR/CR |
| ShapeUpgrade_SplitSurface | 3 | — | WR |
| ShapeFix_Wireframe Extension Tests | 3 | — | WR |
| DetectPocketsAAG tolerance (#733) | 3 | — | WR |
| PocketFeature.isOpen (#753) | 2 | — | WR |
| Off-center enclosed pocket (#777) | 2 | — | WR |
| Prism Until Face | 2 | — | WR |
| Vertical corner-blend fillet (#762) | 2 | — | WR |
| Filleted through-slot (#762) | 2 | — | WR |
| Filleted box exterior edges (#762) | 2 | — | WR |
| LocOpe_Spliter v71 Tests | 2 | — | WR |
| PocketFeature.isOpen on compound (#1089) | 2 | — | WR |
| BiTgte Blend Tests | 2 | — | WR |
| Issue 572: forced-C1 sweep approximation | 2 | — | WR/CR (#597) |
| Prismatic Feature Tests | 2 | — | WR |
| Split Shape by Wire | 2 | — | WR |
| Boolean with History | 2 | — | WR |
| BRepOffset Offset Face | 2 | — | WR |
| Edge.split bounded by edge's own range (#1020) | 2 | — | WR/OOB |
| SEGV Guards, CellsBuilder empty inputs | 2 | — | CR/DG |
| Extended Extrusion | 2 | — | WR |
| BOPAlgo Splitter | 2 | — | WR |
| BRepFeat Builder | 2 | — | WR |
| Evolved Advanced | 2 | — | WR |
| BRepFill OffsetWire Tests | 2 | — | WR |
| BRepAlgo Image Tests | 2 | — | WR |
| BOPAlgo_Tools Tests | 2 | — | WR |
| BOPAlgo_BuilderSolid Tests | 1 | — | WR |
| LocOpe_Gluer Tests | 1 | — | WR |
| BRepFill Draft Tests | 1 | — | WR |
| BOPAlgo_WireSplitter MakeWire Tests | 1 | — | WR |
| BRepOffset SimpleOffset | 1 | — | WR |
| LocOpe Spliter | 1 | — | WR |
| Loft polar-method SIGSEGV regression (#176) | 1 | — | CR |
| BOPTools_AlgoTools Tests | 1 | — | WR |
| LocOpe BuildShape Tests | 1 | — | WR |
| BRepAlgoAPI_Defeaturing | 1 | — | WR |
| LocOpe SplitShape Tests | 1 | — | WR |
| BRepAlgo FaceRestrictor Tests | 1 | — | WR |
| Make Connected | 1 | — | WR |
| Linear Rib Feature | 1 | — | WR |
| Glue Tests | 1 | — | WR |
| Integration: Thickness Analysis | 1 | — | WR |
| Issue818 middlePath ground truth (#811) | 1 | — | WR |
| Simple Offset | 1 | — | WR |
| BRepFill CompatibleWires Tests | 1 | — | WR |
| BRepFill AdvancedEvolved Tests | 1 | — | WR |
| Integration: Draft Analysis | 1 | — | WR |
| BRepAlgo Loop Tests | 1 | — | WR |
| BOPAlgo_BuilderFace Tests | 1 | — | WR |
| LocOpe BuildWires | 1 | — | WR |
| LocOpe FindEdges Tests | 1 | — | WR |
| FilletSurf_Builder Tests | 1 | — | WR |
| Integration: Boolean Chain Stress | 1 | — | WR |
| Draft Modification Tests | 1 | — | WR |
| BRepFill_Evolved | 1 | — | WR |

**Total**: 320 tests across ~80 suites

---

## Injection Matrix: Critical Crash-Related Tests First

### #317: ShapeFix_Face::FixPeriodicDegenerated SIGSEGV (v1.12.7 bridge fix)

**Issue**: `ShapeFix_Face::FixPeriodicDegenerated` SIGSEGV on null-Context dereference when a face's sole boundary wire is a single closed edge belting a `Surface.cone`'s full period.

**Bridge Fix**: Bridge now calls `fixer.SetContext(new ShapeBuild_ReShape)` before `Perform()` at all three `ShapeFix_Face` call sites.

**Kernel Patch**: `0005` (retired at OCCT 8.0.1)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Face.fixed on a periodic conical single-wire face survives and stays valid | `Shape.face.fixed` → `ShapeFix_Face` | Null Context deref | Remove `SetContext` call in bridge |  |  | SIGSEGV on cone face |
| Face.fixed on an unhealed full-period conical UV face returns a face | `Shape.face.fixed` → `ShapeFix_Face` | Null Context deref | Remove `SetContext` call in bridge |  |  | SIGSEGV on cone face |
| Face.fixed leaves well-formed box faces valid | `Shape.face.fixed` → `ShapeFix_Face` | Control test | No injection needed |  |  | Should pass |

### #318: BRepGProp_EdgeTool::IntegrationOrder SIGSEGV (v1.12.8 bridge fix)

**Issue**: `IntegrationOrder` SIGSEGV on edge whose sole geometry is a Bezier/BSpline-type curve-on-surface pcurve (no 3D curve).

**Bridge Fix**: Bridge's small-edge scan now skips degenerate edges outright (`OCCTShapeAnalyze`).

**Kernel Patch**: `0006` (retired at OCCT 8.0.1)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| (Find analyze tests) | `Shape.analyze` → `BRepGProp_EdgeTool` | Null 3D curve deref | Remove degenerate edge skip in bridge |  |  | SIGSEGV on degenerate edge |

### #263: Self-Intersecting Profile Crash Guard

**Issue**: Extrude/heal would crash on self-intersecting profiles (uncatchable SIGSEGV).

**Bridge Fix**: Bridge checks for self-intersection and returns `nil` before calling OCCT.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| extrude refuses a self-intersecting profile (returns nil, never crashes) | `Shape.extrude` → `BRepPrimAPI_MakePrism` | No self-intersection check | Remove self-intersection guard in bridge |  |  | Should SIGSEGV |
| heal refuses a self-intersecting shape (returns nil, never crashes) | `Shape.heal` → `ShapeFix_Shape` | No self-intersection check | Remove self-intersection guard in bridge |  |  | Should SIGSEGV |
| a clean convex profile still extrudes and heals | Control test | No injection needed | — |  |  | Should pass |

### #319: Self-Intersection Timeout (kernel patch `0010`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| a non-nil selfIntersectionTimeout on a self-intersecting shape populates true | `Shape.analyze` → `BOPAlgo_ArgumentAnalyzer` | Timeout not honored | Revert kernel patch `0010` |  |  | Runs past deadline |
| a non-nil selfIntersectionTimeout on a clean shape populates false | `Shape.analyze` → `BOPAlgo_ArgumentAnalyzer` | Control test | No injection needed |  |  | Should pass |
| default analyze() does not check self-intersection: hasSelfIntersection is nil | `Shape.analyze` → `BOPAlgo_ArgumentAnalyzer` | Control test | No injection needed |  |  | Should pass |

### #522: AdvApp2Var U Buffer Overflow (kernel patch `0019`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| convertedToBSpline keeps the offset sphere's shape instead of collapsing it to a line | `Shape.convertToBSpline` → `GeomConvert_ApproxSurface` | U Jacobi-maxima buffer from V slot | Revert kernel patch `0019` |  |  | Wrong surface (degree collapse) |
| withSurfacesAsBSpline takes the same forced-C0 branch and keeps the same shape | `Shape.withSurfacesAsBSpline` → `GeomConvert_ApproxSurface` | U Jacobi-maxima buffer from V slot | Revert kernel patch `0019` |  |  | Wrong surface (degree collapse) |
| convertToBSplineAdvanced with offsetMode reaches the same branch | `Shape.convertToBSplineAdvanced` → `GeomConvert_ApproxSurface` | U Jacobi-maxima buffer from V slot | Revert kernel patch `0019` |  |  | Wrong surface (degree collapse) |

### #597: GeomFill_Sweep SError Overwrite (kernel patch `0025`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| The forced-C1 surface covers the surface it is approximating | `Shape.sweep` / `PipeShellBuilder` → `GeomFill_Sweep` | SError = requested tolerance | Revert `SError = ConvertApprox.MaxError()` |  |  | Wrong error reported (0.0001 vs actual 2.5+) |
| The un-forced sweep is untouched by the approximation fix | Control test | No injection needed | — |  |  | Should pass |

---

## Injection Matrix: Degenerate Geometry Tests

### Issue #484: Face.fixed on Periodic Conical Face (ReShape Context)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Face.fixed on a periodic conical single-wire face survives and stays valid | `Face.fixed(tolerance:)` → `ShapeFix_Face` | Null Context | Remove `SetContext(new ShapeBuild_ReShape)` |  |  | SIGSEGV (same as #317) |
| Face.fixed on an unhealed full-period conical UV face returns a face | `Face.fixed(tolerance:)` → `ShapeFix_Face` | Null Context | Remove `SetContext(new ShapeBuild_ReShape)` |  |  | SIGSEGV (same as #317) |
| Face.fixed leaves well-formed box faces valid | Control test | No injection needed | — |  |  | Should pass |

### Issue #438: Divided at Continuity

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| C3 produces a different result from C1, proving the surface criterion is observable | `Face.divided(at:)` / `dividedByContinuity` → `ShapeUpgrade_SplitSurface` | Wrong continuity handling | Revert continuity logic |  |  | Wrong surface split |

### #837: fixed() Mode-Flag Wiring (bridge fix)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Fixture actually has the wire-orientation defect it claims to | `OCCTShapeFixDetailed` → `ShapeFix_Shape` | Control test | No injection needed | N/A | ✅ Pass | Verifies fixture validity |
| fixFace: false leaves a free face's wire-orientation defect uncorrected | `OCCTShapeFixDetailed` → `ShapeFix_Shape` | fixFace parameter ignored | Remove `FixFreeFaceMode()` assignment | ✅ FAIL | ✅ Pass | ShapeFix_Shape default fixed it |
| fixFace: true corrects a free face's wire-orientation defect | `OCCTShapeFixDetailed` → `ShapeFix_Shape` | fixFace parameter ignored | Remove `FixFreeFaceMode()` assignment | ✅ PASS (always worked) | ✅ Pass | Both branches ran fix before fix |

**Finding**: The test's own "Prove-the-test-fails record" documented exactly this behavior. The pre-fix bridge had `FixFreeFaceMode` defaulting to on (always), so `fixFace: false` was ignored. The injection confirmed this by reproducing the failure.

### #570: Healing Approximations Accepted on Zeroed Error

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| convertedToBSpline keeps the offset sphere's shape instead of collapsing it to a line | `Shape.convertToBSpline` → `GeomConvert_ApproxSurface` | Error not checked | Remove error check |  |  | Wrong surface (degree collapse) |
| withSurfacesAsBSpline takes the same forced-C0 branch and keeps the same shape | `Shape.withSurfacesAsBSpline` → `GeomConvert_ApproxSurface` | Error not checked | Remove error check |  |  | Wrong surface (degree collapse) |
| convertToBSplineAdvanced with offsetMode reaches the same branch | `Shape.convertToBSplineAdvanced` → `GeomConvert_ApproxSurface` | Error not checked | Remove error check |  |  | Wrong surface (degree collapse) |

### SAWireAnalysis.checkOuterBound (#1058)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| The cylinder's own wire answers false, so the fixture is not refused for being curved | `SAWireAnalysis.checkOuterBound` → `ShapeAnalysis_Wire` | Wrong wire check | Remove wire-boundary check |  |  | Wrong verdict |
| A wire with no pcurve on the face is refused, not reported as the outer bound | `SAWireAnalysis.checkOuterBound` → `ShapeAnalysis_Wire` | No pcurve check | Remove pcurve check |  |  | Wrong verdict |
| A Shape that is not a wire is refused, and so is one that is not a face | `SAWireAnalysis.checkOuterBound` → `ShapeAnalysis_Wire` | Type validation | Remove type checks |  |  | Should not refuse |
| A null shape is refused rather than crashing | `SAWireAnalysis.checkOuterBound` → `ShapeAnalysis_Wire` | Null check | Remove null check |  |  | SIGSEGV |
| A wire with no edges is refused | `SAWireAnalysis.checkOuterBound` → `ShapeAnalysis_Wire` | Empty wire check | Remove empty check |  |  | Wrong verdict |
| A wire whose edges do not assemble is refused rather than taking the process down | `SAWireAnalysis.checkOuterBound` → `ShapeAnalysis_Wire` | Assembly check | Remove assembly check |  |  | SIGSEGV |
| A wire whose projected area cancels to rounding is refused (#1073) | `SAWireAnalysis.checkOuterBound` → `ShapeAnalysis_Wire` | Area check | Remove area check |  |  | Wrong verdict |

### ShapeAnalysis_FreeBounds (#655, #310)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| An embedded INTERNAL loop is absent from both closed and open free bounds | `Shape.freeBounds` → `ShapeAnalysis_FreeBounds` | INTERNAL orientation handling | Remove INTERNAL check |  |  | Wrong free bounds count |
| The same loop, left FORWARD, IS counted (contrast fixture) | `Shape.freeBounds` → `ShapeAnalysis_FreeBounds` | Control test | No injection needed |  |  | Should pass |
| Closed solid has no free boundaries | `Shape.freeBounds` → `ShapeAnalysis_FreeBounds` | Control test | No injection needed |  |  | Should pass |
| Compound of adjacent faces has free boundaries | `Shape.freeBounds` → `ShapeAnalysis_FreeBounds` | Control test | No injection needed |  |  | Should pass |

---

## Injection Matrix: Thread Safety / TSan Tests

### UnifySameDomainBuilder (#348, #348 Null PCurve)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| unifySameDomainOnMeshSewnSolidWithMissingPCurve | `UnifySameDomainBuilder.build` → `ShapeUpgrade_UnifySameDomain` | Missing pcurve on edge | Revert kernel patch `0013` |  |  | SIGSEGV |

### evalAndUpdateTolerance Null PCurve

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| edgePairedWithUnrelatedCylindricalFaceDoesNotCrash | `Shape.evalAndUpdateTolerance` → `BRep_Tool::CurveOnSurface` | Null pcurve on non-planar face | Remove null guard in bridge |  |  | SIGSEGV |
| edgePairedWithAnUnrelatedPlanarFaceDoesNotCrash | `Shape.evalAndUpdateTolerance` → `BRep_Tool::CurveOnPlane` | Null pcurve on planar face | Remove null guard in bridge |  |  | SIGSEGV |

---

## Injection Procedure Per Test

```bash
# 1. Focused compile (3s)
swift build --target OCCTShapeHealingTests

# 2. For each test:
#    a. Identify defect and bridge function
#    b. Create injection (revert kernel patch, remove guard, remove SetContext, etc.)
#    c. Run single test: swift test --filter <TestStructName>
#    d. Confirm FAIL (red) - crash, wrong result, or timeout
#    e. Restore fix
#    f. Confirm PASS (green)
#    g. Record in matrix above

# 3. Create PR for OCCTShapeHealingTests
# 4. User reviews PR → merge what makes sense
# 5. Proceed to next domain (OCCTSurfaceTests)
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
| Issue 443: solid(from:) and upgraded() | 22 |  |  |  |  |
| Issue 442: fixSolid/solidFromShellFixed | 16 |  |  |  |  |
| ShapeAnalysis_Edge Tests | 14 |  |  |  |  |
| Issue 702: solid demotion is reported accurately | 12 |  |  |  |  |
| ShapeBuild Edge | 9 |  |  |  |  |
| ShapeAnalysis_Wire Tests | 9 |  |  |  |  |
| ShapeAnalysis_ShapeTolerance | 8 |  |  |  |  |
| Advanced Healing Tests | 8 |  |  |  |  |
| SAWireAnalysis.checkOuterBound (#1058) | 7 |  |  |  |  |
| ShapeAnalysis FreeBoundsProperties Tests | 7 |  |  |  |  |
| Issue #446, unify does not mutate its input | 6 |  |  |  |  |
| ShapeAnalysis_Curve Static Method Tests | 6 |  |  |  |  |
| Issue 570: healing approximations accepted on a zeroed error | 6 |  |  |  |  |
| v0.123.0, UnifySameDomain builder | 5 |  |  |  |  |
| Issue #484, Shape.connectedFaces coverage | 5 |  |  |  |  |
| Free Boundary Analysis | 5 |  |  |  |  |
| v0.122.0, Sewing Extended | 5 |  |  |  |  |
| Issue 772: analyze() self-intersection is opt-in | 5 |  |  |  |  |
| Issue #266 follow-up, face healing control & checks | 4 |  |  |  |  |
| Issue #490: one continuity vocabulary per operation | 4 |  |  |  |  |
| ShapeConstruct Curve Tests | 4 |  |  |  |  |
| ShapeAnalysis_Surface Tests | 4 |  |  |  |  |
| ShapeExtend Explorer | 4 |  |  |  |  |
| v0.122.0, ShapeFix_Edge Extended | 4 |  |  |  |  |
| #849 - ShapeFixStatus real OCCT ordinals | 4 |  |  |  |  |
| ShapeAnalysis_FreeBounds Simplified Tests | 4 |  |  |  |  |
| **Issue #484, Face.fixed(tolerance:) gets a ReShape context** | **4** |  |  |  |  |
| ShapeUpgrade ConvertSurfacesToBezier | 3 |  |  |  |  |
| ShapeUpgrade SplitCurve Tests | 3 |  |  |  |  |
| Issue #870: OCCTShapeExtendShapeType failure fallback | 3 |  |  |  |  |
| ShapeAnalysis Surface ValueOfUV Tests | 3 |  |  |  |  |
| Sewing Tests | 3 |  |  |  |  |
| Shape Analysis Tests | 3 |  |  |  |  |
| Shape Fixing Tests | 3 |  |  |  |  |
| Self-Intersecting Profile Crash Guard (#263) | 3 |  |  |  |  |
| Sewing_Extras | 3 |  |  |  |  |
| **#837: fixed() mode-flag wiring** | **3** |  |  |  |  |
| ShapeUpgrade_SplitSurface | 3 |  |  |  |  |
| ShapeFix_Wireframe Extension Tests | 3 |  |  |  |  |
| DetectPocketsAAG tolerance (#733) | 3 |  |  |  |  |
| ... | ... |  |  |  |  |

**Total**: 320 tests

## #766 measured: BSplineRestrictionAdvanced, ConvertToBSplineAdvanced, Curve* (10 tests)

Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-curve-custom/transcript.txt`.

| Test | File | Bridge function | Injection | Red | Green | Parity |
|------|------|-----------------|-----------|-----|-------|--------|
| `restrictBox` | BSplineRestrictionAdvancedTests.swift | `OCCTShapeBSplineRestrictionAdvanced` | BSPRESTRADV: treat the modifier as not done | BSplineRestrictionAdvancedTests.swift:16 `#require(Shape.bsplineRestrictionAdvanced(...))` | pass | PASS |
| `convertCylinder` | ConvertToBSplineAdvancedTests.swift | `OCCTShapeConvertToBSplineAdvanced` | CONVBSPADV: planeMode forced true | ConvertToBSplineAdvancedTests.swift:26 `kinds.filter { $0 == .plane }.count == 2` | pass | PASS |
| `convertToPeriodic` | CurveConvertToPeriodicTests.swift | `OCCTCurve3DConvertToPeriodic` | PERIODIC: return the input curve unconverted | CurveConvertToPeriodicTests.swift:24 `periodic.isPeriodic` | pass | PASS |
| `projectOntoLine` | CurveProjectTests.swift | `OCCTCurve3DProjectPoint` | PROJECT: report the squared distance | CurveProjectTests.swift:15 `abs(proj.distance - 3.0) < 1e-9` | pass | PASS |
| `projectOntoCircle` | CurveProjectTests.swift | `OCCTCurve3DProjectPoint` | PROJECT: report the squared distance | CurveProjectTests.swift:25 `abs(proj.distance - 5.0) < 1e-9` | pass | PASS |
| `sampleCircle` | CurveSamplePointsTests.swift | `OCCTCurve3DGetSamplePoints3D` | SAMPLES: drop the last point (off by one) | CurveSamplePointsTests.swift:17 `points.count == 360` | pass | PASS |
| `sampleLine` | CurveSamplePointsTests.swift | `OCCTCurve3DGetSamplePoints3D` | SAMPLES: drop the last point (off by one) | CurveSamplePointsTests.swift:31 `points == [SIMD3(0, 0, 0), SIMD3(10, 0, 0)]` | pass | PASS |
| `splitCurve` | CurveSplitTests.swift | `OCCTCurve3DSplitAt` | SPLIT: hand the two pieces back swapped | CurveSplitTests.swift:24 `abs(result.first.domain.lowerBound - dom.lowerBound) < 1e-9` | pass | PASS |
| `validateInBounds` | CurveValidateRangeTests.swift | `OCCTCurve3DValidateRange` | VALIDRANGE: ignore the kernel, echo the inputs with wasAdjusted false | CurveValidateRangeTests.swift:20 `result.wasAdjusted` | pass | PASS: wasAdjusted is ValidateRange's 'OK or corrected' flag, true for an untouched range |
| `validateOutOfBounds` | CurveValidateRangeTests.swift | `OCCTCurve3DValidateRange` | VALIDRANGE: ignore the kernel, echo the inputs with wasAdjusted false | CurveValidateRangeTests.swift:28 `abs(result.first) < 1e-12` | pass | PASS |
## #766 measured: DivideByNumber, EncodeRegularity, FastSewing (11 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-divide-encode-fastsew/transcript.txt`.
| `divideBox` | DivideByNumberTests.swift | `OCCTShapeDivideByNumber` | DIVNUM: leave MaxArea() at its default (the pre-#1491 defect) | DivideByNumberTests.swift:24 `result?.faces().count == 24` | pass | PASS |
| `divideOnePart` | DivideByNumberTests.swift | `OCCTShapeDivideByNumber` | DIVNUM1: bypass the Swift parts>1 guard and return the input when Perform() is false | DivideByNumberTests.swift:34 `result == nil` | pass | PASS: kernel Perform false at (1,1); Swift guard refuses first |
| `divideCylinder` | DivideByNumberTests.swift | `OCCTShapeDivideByNumber` | DIVNUM: leave MaxArea() at its default | DivideByNumberTests.swift:45 `result?.faces().count == 6` | pass | PASS |
| `encodeRegularityBox` | EncodeRegularityTests.swift | `OCCTShapeEncodeRegularity` | ENCODE: copy the shape and skip BRepLib::EncodeRegularity | EncodeRegularityTests.swift:36 `sharedEdgeCodes(r) == [c0 x 12]` | pass | PASS |
| `encodeRegularityFilleted` | EncodeRegularityTests.swift | `OCCTShapeEncodeRegularity` | ENCNULL: return nullptr (ENCODE alone leaves it green: the fillet already encoded every edge) | EncodeRegularityTests.swift:45 `#require(box.encodingRegularity(toleranceDegrees: 1.0))` | pass | PASS |
| `fixtureStartsUnencoded` | EncodeRegularityTests.swift | `OCCTMakeShell` | SHELLENC: OCCTMakeShell encodes regularity on the shell it builds | EncodeRegularityTests.swift:152 `!Shape.hasContinuity(edge:face1:face2:)` | pass | PASS |
| `defaultToleranceMarksNearTangentEdgeRegular` | EncodeRegularityTests.swift | `OCCTShapeEncodeRegularity` | ENCODE: skip BRepLib::EncodeRegularity | EncodeRegularityTests.swift:170 `Shape.hasContinuity(edge:face1:face2:)` | pass | PASS |
| `oldBuggyDefaultStillDoesNotMarkRegular` | EncodeRegularityTests.swift | `OCCTShapeEncodeRegularity` | ENCUNITS: pass the degree value to BRepLib as radians | EncodeRegularityTests.swift:190 `continuity == ContinuityClass.c0.rawValue` | pass | PASS |
| `fastSewValid` | FastSewingTests.swift | `OCCTShapeFastSewn` | FASTSEWNULL: return nullptr | FastSewingTests.swift:21 `sewn != nil` | pass | PASS |
| `fastSewTolerance` | FastSewingTests.swift | `OCCTShapeFastSewn` | FASTSEWNULL: return nullptr | FastSewingTests.swift:42 `#require(sphere.fastSewn(tolerance: 0.01))` | pass | PASS |
| `fastSewBoxReturnsNil` | FastSewingTests.swift | `OCCTShapeFastSewn` | FASTSEWPASS: hand back the input when GetResult() is null (the #1475 shape) | FastSewingTests.swift:61 `sewn == nil` | pass | PASS |
## #766 measured: FreeBoundsTests, GeometryConversionTests (8 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-freebounds-geomconv/transcript.txt`.
| `closedSolidNoFreeBounds` | FreeBoundsTests.swift | `OCCTShapeFreeBounds` | FBEMPTYOK: return the empty compound instead of nil when nothing is free | FreeBoundsTests.swift:14 `result == nil` | pass | PASS |
| `compoundFacesHasFreeBounds` | FreeBoundsTests.swift | `OCCTShapeFreeBounds` | FBSWAP: closed and open counts written to each other's out-param | FreeBoundsTests.swift:29 `result.closedCount == 1` | pass | PASS |
| `freeBoundsSphere` | FreeBoundsTests.swift | `OCCTShapeFreeBounds` | FBEMPTYOK | FreeBoundsTests.swift:39 `result == nil` | pass | PASS |
| `fixFreeBoundsCallable` | FreeBoundsTests.swift | `OCCTShapeFixFreeBounds` | FIXFBWIRES: return the closed-wire compound instead of GetShape() (the #1636 defect) | FreeBoundsTests.swift:49 `repair.shape.subShapes(ofType: .face).count == 1` | pass | PASS |
| `issue310DisjointFacesFreeBounds` | FreeBoundsTests.swift | `OCCTShapeFreeBoundsClosedCount` | FBOPENCLOSED: count GetOpenWires() in the closed-count function | FreeBoundsTests.swift:72 `freeBoundsClosedCount(tolerance: 0.01) == 2` | pass | PASS |
| `cylinderToBSpline` | GeometryConversionTests.swift | `OCCTShapeCustomConvertToBSpline` | CUSTBSPFLAG: pass !plane | GeometryConversionTests.swift:31 `kinds(result) == [.plane: 2, .cylinder: 1]` | pass | PASS |
| `toRevolution` | GeometryConversionTests.swift | `OCCTShapeCustomConvertToRevolution` | CUSTREV: return the input unconverted | GeometryConversionTests.swift:40 `kinds(result) == [.plane: 2, .surfaceOfRevolution: 1]` | pass | PASS |
| `bsplinePreservesVolume` | GeometryConversionTests.swift | `OCCTShapeCustomConvertToBSpline` | CUSTBSPFLAG: pass !plane | GeometryConversionTests.swift:50 `kinds(result) == [.cylinder: 1, .bsplineSurface: 2]` | pass | PASS |
## #766 measured: FreeBoundsPropertiesTests, FreeBoundsSimplifiedTests (11 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-freebounds-props/transcript.txt`.
| `freeBoundsOnFaces` | FreeBoundsPropertiesTests.swift | `OCCTFreeBoundsPropsCounts` | FBCOUNTS: closed and open counts swapped | FreeBoundsPropertiesTests.swift:17 `analysis.closedCount == 2` | pass | PASS |
| `closedBoundInfo` | FreeBoundsPropertiesTests.swift | `OCCTFreeBoundsPropsInfo` | FBINDEX: 0-based index handed to OCCT's 1-based accessor | FreeBoundsPropertiesTests.swift:26 `#require(closedFreeBoundInfo(index: 0))` | pass | PASS |
| `freeBoundWire` | FreeBoundsPropertiesTests.swift | `OCCTFreeBoundsPropsWire` | FBINDEX | FreeBoundsPropertiesTests.swift:36 `#require(closedFreeBoundWire(index: 0))` | pass | PASS |
| `freeBoundIndexOutOfRange` | FreeBoundsPropertiesTests.swift | `OCCTFreeBoundsPropsInfo` | FBINDEX (also red under FBCOUNTS at :62 and a Swift index+1 shift at :65) | FreeBoundsPropertiesTests.swift:69 `closedFreeBoundInfo(index: bad) == nil` | pass | PASS |
| `openFreeBoundsAbsent` | FreeBoundsPropertiesTests.swift | `OCCTFreeBoundsPropsCounts` | FBCOUNTS | FreeBoundsPropertiesTests.swift:80 `openCount == 0` | pass | PASS |
| `loneFaceHasNoFreeBounds` | FreeBoundsPropertiesTests.swift | `OCCTFreeBoundsPropsCreate` | FBWRAP: wrap a lone face in a compound before Init | FreeBoundsPropertiesTests.swift:94 `analysis.totalCount == 0` | pass | PASS |
| `shapeAndPropertiesAgree` | FreeBoundsPropertiesTests.swift | `OCCTFreeBoundsPropsInfo` | Swift closedFreeBoundInfo reading index+1 (the #504 index-base drift); also red under FBINDEX | FreeBoundsPropertiesTests.swift:110 `#require(compound.closedFreeBoundInfo(index: i))` | pass | PASS |
| `closedCountOnBox` | FreeBoundsSimplifiedTests.swift | `OCCTShapeFreeBoundsClosedCount` | FBCOUNTSRC: count wires in the input shape instead of the result compound | FreeBoundsSimplifiedTests.swift:17 `freeBoundsClosedCount == 0` | pass | PASS |
| `closedWiresOnBox` | FreeBoundsSimplifiedTests.swift | `OCCTShapeFreeBoundsClosed` | FBSIMPLENULL: report an empty compound as nil | FreeBoundsSimplifiedTests.swift:23 `#require(box.freeBoundsClosedWires(...))` | pass | PASS |
| `openWiresOnBox` | FreeBoundsSimplifiedTests.swift | `OCCTShapeFreeBoundsOpen` | FBSIMPLENULL | FreeBoundsSimplifiedTests.swift:29 `#require(box.freeBoundsOpenWires(...))` | pass | PASS |
| `freeBoundsOnOpenShell` | FreeBoundsSimplifiedTests.swift | `OCCTShapeFreeBoundsClosedCount` | FBNOSEW: the non-sewing ShapeAnalysis_FreeBounds constructor | FreeBoundsSimplifiedTests.swift:39 `freeBoundsClosedCount == 0` | pass | PASS |
## #766 measured: Issue1058OuterBoundRefusalTests (7 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-1058-outer-bound/transcript.txt`.
| `cylinderAnswersForItsOwnWire` | Issue1058OuterBoundRefusalTests.swift | `OCCTWireCheckOuterBound` | OBINVERT: the pcurve guard refuses unconditionally | Issue1058OuterBoundRefusalTests.swift:77 `checkOuterBound(wire: own, face: lateral) == false` | pass | PASS |
| `wireNotOnTheFaceIsRefused` | Issue1058OuterBoundRefusalTests.swift | `OCCTWireCheckOuterBound` | OBZERO: every refusal returns 0 (the pre-#1058 contract). Removing the pcurve guard alone stays green: the #1073 area guard refuses the same wire (area 0) | Issue1058OuterBoundRefusalTests.swift:93 `== nil` | pass | N/A: refusal is a bridge guard; raw kernel answers false off a zero area |
| `wrongTypedShapeIsRefused` | Issue1058OuterBoundRefusalTests.swift | `OCCTWireCheckOuterBound` | OBZERO | Issue1058OuterBoundRefusalTests.swift:109 `checkOuterBound(wire: box, face: panel) == nil` | pass | N/A: type guard in the bridge; no kernel call is made |
| `nullShapeIsRefused` | Issue1058OuterBoundRefusalTests.swift | `OCCTWireCheckOuterBound` | OBZERO | Issue1058OuterBoundRefusalTests.swift:124 `checkOuterBound(wire: empty, face: panel) == nil` | pass | N/A: null-shape guard in the bridge; no kernel call is made |
| `edgelessWireIsRefused` | Issue1058OuterBoundRefusalTests.swift | `OCCTWireCheckOuterBound` | OBREADY: !IsReady() returns 0 instead of -1 | Issue1058OuterBoundRefusalTests.swift:139 `== nil` | pass | PASS: kernel cannot run the check; bridge refuses |
| `disconnectedEdgeWireIsRefused` | Issue1058OuterBoundRefusalTests.swift | `OCCTWireCheckOuterBound` | OBZERO | Issue1058OuterBoundRefusalTests.swift:166 `== nil` | pass | N/A: not probed: without the null-WireAPIMake guard the kernel SIGSEGVs in BRep_Builder::Add |
| `cylinderWireOnPlanarFaceIsRefused` | Issue1058OuterBoundRefusalTests.swift | `OCCTWireCheckOuterBound` | OBAREA: drop the #1073 area-magnitude guard | Issue1058OuterBoundRefusalTests.swift:191 `== nil` | pass | N/A: raw kernel says true off an area of -1.8e-15; the bridge refuses by design |
## #766 measured: Issue1479 null guards, Issue1491 divide-by-number axes and fixSmallEdges (10 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-1479-1491/transcript.txt`.
| `composeShellOnNullifiedShapeReturnsNil` | Issue1479HealingFixNullGuardsTests.swift | `OCCTShapeFixComposeShell` | CSGUARD: drop the occtShapeIsPresent guard | process killed, signal 11 (SIGSEGV) inside the test | pass | N/A: the kernel dereferences a null TopoDS_Face; the guard is the bridge's |
| `composeShellNullRawPointerReturnsNil` | Issue1479HealingFixNullGuardsTests.swift | `OCCTShapeFixComposeShell` | CSGUARD | process killed, signal 11 (SIGSEGV) | pass | N/A: null C pointer; no kernel call |
| `composeShellOrdinaryFaceUnaffected` | Issue1479HealingFixNullGuardsTests.swift | `OCCTShapeFixComposeShell` | CSNULL: return nullptr | Issue1479HealingFixNullGuardsTests.swift:59 `#require(face.composeShell())` | pass | PASS |
| `edgeConnectNullRawPointerReturnsNil` | Issue1479HealingFixNullGuardsTests.swift | `OCCTShapeFixEdgeConnect` | ECGUARD: drop the `if (!shape)` guard | process killed, signal 11 (SIGSEGV) | pass | N/A: null C pointer; no kernel call |
| `edgeConnectOrdinaryShapeUnaffected` | Issue1479HealingFixNullGuardsTests.swift | `OCCTShapeFixEdgeConnect` | ECNULL: return nullptr | Issue1479HealingFixNullGuardsTests.swift:77 `#require(box.fixEdgeConnect())` | pass (1 known issue: result invalid) | PASS: FINDING: EdgeConnect leaves the valid box invalid, in place |
| `exactSplitCountUOnly` | Issue1491DivideByNumberUVAxesTests.swift | `OCCTShapeDivideByNumber` | DIVUV: skip SetNumbersUVSplits (the #1491 defect) | Issue1491DivideByNumberUVAxesTests.swift:56 `faces().count == 5` | pass | PASS |
| `exactSplitCountVOnly` | Issue1491DivideByNumberUVAxesTests.swift | `OCCTShapeDivideByNumber` | DIVUV | Issue1491DivideByNumberUVAxesTests.swift:72 `faces().count == 5` | pass | PASS |
| `exactSplitCountAsymmetric` | Issue1491DivideByNumberUVAxesTests.swift | `OCCTShapeDivideByNumber` | DIVUV | Issue1491DivideByNumberUVAxesTests.swift:86 `faces().count == 6` | pass | PASS |
| `smallEdgeIsActuallyMerged` | Issue1491FixSmallCurvesRemovalTests.swift | `OCCTShapeFixSmallEdges` | SMALLNOOP: return the input unchanged (the removed functions' no-op) | Issue1491FixSmallCurvesRemovalTests.swift:74 `fixed.edges().count < 6` | pass | PASS |
| `largeEdgeIsUntouched` | Issue1491FixSmallCurvesRemovalTests.swift | `OCCTShapeFixSmallEdges` | SMALLTOLFIXED: SetPrecision(1.0) instead of the caller's tolerance | Issue1491FixSmallCurvesRemovalTests.swift:89 `fixed.edges().count == 6` | pass | PASS |
## #766 measured: Issue1505 bare-wire guard, Issue1507 sewing null guards, Issue1634 revolution direction (11 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-1505-1507-1634/transcript.txt`.
| `bareWireRefusesExtrusion` | Issue1505BareWireSelfIntersectionGuardTests.swift | `OCCTShapeCreateExtrusionShape (guard occtHasSelfIntersectingWire)` | BAREWIRE: skip the synthesized-face check for face-less input (the pre-#1505 gap) | Issue1505BareWireSelfIntersectionGuardTests.swift:47 `extruded == nil` | pass | PASS: kernel flags it only with a face context, which the guard synthesizes |
| `bareWireRefusesHeal` | Issue1505BareWireSelfIntersectionGuardTests.swift | `OCCTShapeHeal (guard occtHasSelfIntersectingWire)` | BAREWIRE | Issue1505BareWireSelfIntersectionGuardTests.swift:58 `healed == nil` | pass | PASS |
| `bareWireRefusesHealWithHistory` | Issue1505BareWireSelfIntersectionGuardTests.swift | `OCCTShapeHealWithHistory (guard occtHasSelfIntersectingWire)` | BAREWIRE | Issue1505BareWireSelfIntersectionGuardTests.swift:69 `healedWithHistory == nil` | pass | PASS |
| `cleanBareWireStillWorks` | Issue1505BareWireSelfIntersectionGuardTests.swift | `occtHasSelfIntersectingWire` | SIALWAYS: the guard reports every shape self-intersecting | Issue1505BareWireSelfIntersectionGuardTests.swift:80 `extruded != nil` | pass | PASS |
| `faceInputStillRefuses` | Issue1505BareWireSelfIntersectionGuardTests.swift | `occtHasSelfIntersectingWire` | SIFACE: skip the face-context walk | Issue1505BareWireSelfIntersectionGuardTests.swift:94 `extruded == nil` | pass | PASS |
| `nbMultipleEdgesNullRawPointerReturnsZero` | Issue1507SewingNullGuardTests.swift | `OCCTSewingNbMultipleEdges` | NULLSEW: drop the `if (!sewing)` guard | process killed, signal 11 (SIGSEGV) | pass | N/A: null C pointer; no kernel call |
| `isMultipleEdgeNullRawPointerReturnsFalse` | Issue1507SewingNullGuardTests.swift | `OCCTSewingIsMultipleEdge` | NULLSEW | process killed, signal 11 (SIGSEGV) | pass | N/A: null C pointer; no kernel call |
| `ordinarySewingUnaffected` | Issue1507SewingNullGuardTests.swift | `OCCTSewingPerform / OCCTSewingResult / OCCTSewingNbFreeEdges` | SEWNOPERFORM: skip BRepBuilderAPI_Sewing::Perform | Issue1507SewingNullGuardTests.swift:49 `#require(sewing.result)` | pass | PASS |
| `directionIsElementaryToRevolution` | Issue1634ConvertToRevolutionDirectionTests.swift | `OCCTShapeCustomConvertToRevolution` | CUSTREV: return the input unconverted | Issue1634ConvertToRevolutionDirectionTests.swift:37 `revolutionFaceCount(converted) == 1` | pass | PASS |
| `sweptToElementaryReversesIt` | Issue1634ConvertToRevolutionDirectionTests.swift | `OCCTShapeSweptToElementary` | SWEPTNOOP: return the input unconverted | Issue1634ConvertToRevolutionDirectionTests.swift:49 `revolutionFaceCount(back) == 0` | pass | PASS |
| `volumeIsPreserved` | Issue1634ConvertToRevolutionDirectionTests.swift | `OCCTShapeCustomConvertToRevolution` | CUSTREVNULL: return nullptr (an unconverted input keeps the volume too, so only a lost result turns it red) | Issue1634ConvertToRevolutionDirectionTests.swift:59 `#require(cylinder.withSurfacesAsRevolution())` | pass | PASS |
## #766 measured: Issue1636 fixedFreeBounds shape, Issue1637 restriction parameters (9 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-1636-1637/transcript.txt`.
| `resultIsTheModifiedSourceShape` | Issue1636FixedFreeBoundsShapeTests.swift | `OCCTShapeFixFreeBounds` | FIXFBWIRES: return the closed-wire compound instead of GetShape() (the #1636 defect) | Issue1636FixedFreeBoundsShapeTests.swift:37 `faces == 2` | pass | PASS |
| `openShellKeepsItsFaces` | Issue1636FixedFreeBoundsShapeTests.swift | `OCCTShapeFixFreeBounds` | FIXFBWIRES (and closedWireCount reported 0: `:52`) | Issue1636FixedFreeBoundsShapeTests.swift:51 `faces == 5` | pass | PASS |
| `wiresAreStillAvailable` | Issue1636FixedFreeBoundsShapeTests.swift | `OCCTShapeFixFreeBounds` | FIXFBCOUNT: closed-wire count reported as 0 | Issue1636FixedFreeBoundsShapeTests.swift:60 `closedWireCount == 1` | pass | PASS |
| `gapWiderThanTheSewingToleranceIsNotSewn` | Issue1636FixedFreeBoundsShapeTests.swift | `OCCTShapeFixFreeBounds` | FIXFBTOL: sewing and closing tolerances passed swapped | Issue1636FixedFreeBoundsShapeTests.swift:79 `closedWireCount == 2` | pass | PASS |
| `defaultsMatchTheKernel` | Issue1637BSplineRestrictionParametersTests.swift | `occtDefaultBSplineRestrictionParameters` | RDEFREPORT: convertPlane reported inverted | Issue1637BSplineRestrictionParametersTests.swift:31 `swift.convertPlane == kernel.convertPlane` | pass | PASS |
| `occtDefaultsConvertNothingOnACylinder` | Issue1637BSplineRestrictionParametersTests.swift | `OCCTShapeCustomBSplineRestriction` | RCYL: ConvertCylindricalSurf forced on | Issue1637BSplineRestrictionParametersTests.swift:53 `bsplineFaceCount == 0` | pass | PASS |
| `allSurfaceTypesConvertsEverything` | Issue1637BSplineRestrictionParametersTests.swift | `OCCTShapeCustomBSplineRestriction` | RPARAMS: caller's parameters ignored, class defaults used (the #1637 defect) | Issue1637BSplineRestrictionParametersTests.swift:71 `bsplineFaceCount == faceCount` | pass | PASS |
| `perKindSwitchesActIndependently` | Issue1637BSplineRestrictionParametersTests.swift | `OCCTShapeCustomBSplineRestriction` | RPARAMS | Issue1637BSplineRestrictionParametersTests.swift:84 `bsplineFaceCount(wall) == 1` | pass | PASS |
| `conversionPreservesTheSolid` | Issue1637BSplineRestrictionParametersTests.swift | `OCCTShapeCustomBSplineRestriction` | RTOL: both tolerances scaled x1000 (a unit slip); tol3d alone left it green | Issue1637BSplineRestrictionParametersTests.swift:104 `abs(after - before) / before < 0.01` | pass | PASS |
## #766 measured: Issue490 continuity decoding, Issue570 healing approximations, Issue655 free-bound orientation (16 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-490-570-655/transcript.txt`.
| `restrictionEntryPointsAgree` | Issue490ContinuityDecoderTests.swift | `OCCTShapeBSplineRestrictionAdvanced` | ADVORD: advanced entry point reads the continuity integer as a raw GeomAbs_Shape ordinal (the pre-#490 defect) | `Issue490ContinuityDecoderTests.swift:65:9: Expectation failed: abs(plainVolume - advancedVolume) < 1e-9 [1 argument continuity → .c2]` | pass | PASS: kernel plain == advanced at each level |
| `restrictionRejectsC3` | Issue490ContinuityDecoderTests.swift | `OCCTShapeCustomBSplineRestriction` | C3CLAMP: continuity above C2 silently clamped to C2 instead of reaching the kernel | `Issue490ContinuityDecoderTests.swift:75:9: Expectation failed: cyl.bsplineRestriction(continuity3d: .c3, continuity2d: .c3) == nil` | pass | PASS |
| `restrictionContinuityIsObservable` | Issue490ContinuityDecoderTests.swift | `OCCTShapeCustomBSplineRestriction` | RCONTIGNORE: requested continuity ignored, C1 always | `Issue490ContinuityDecoderTests.swift:94:9: Expectation failed: abs(atC0 - atC2) > 1e-9` | pass | PASS |
| `surfaceSplitEntryPointsAgree` | Issue490ContinuityDecoderTests.swift | `OCCTSurfaceSplitByContinuity / OCCTSplitSurfaceContinuity` | SPLITORD: surface split reads the criterion as a raw GeomAbs_Shape ordinal | `Issue490ContinuityDecoderTests.swift:111:9: Expectation failed: viaSurface.uSplitCount == viaShapeUpgrade.uSplitCount [1 argument criterion → 3]` | pass | PASS |
| `surfaceSplitCriterionIsObservable` | Issue490ContinuityDecoderTests.swift | `OCCTSurfaceSplitByContinuity` | SPLITORD: surface split reads the criterion as a raw GeomAbs_Shape ordinal | `Issue490ContinuityDecoderTests.swift:124:9: Expectation failed: atC2.uSplitCount == 3` | pass | PASS |
| `outOfRangeCriterionSaturates` | Issue490ContinuityDecoderTests.swift | `OCCTSurfaceSplitByContinuity` | SPLITSAT: an out-of-range criterion falls to C0 instead of saturating at CN | `Issue490ContinuityDecoderTests.swift:144:9: Expectation failed: outOfRange.uSplitCount >= atC3.uSplitCount` | pass | PASS |
| `convertedToBSplineDoesNotCollapse` | Issue570HealingApproxTests.swift | `OCCTShapeConvertToBSpline` | OFFSETBASIS: offset surface replaced by its basis before conversion | `Issue570HealingApproxTests.swift:78:9: Expectation failed: fitted.uDegree > 1` | pass | PASS |
| `withSurfacesAsBSplineDoesNotCollapse` | Issue570HealingApproxTests.swift | `OCCTShapeCustomConvertToBSpline` | OFFSETBASIS: offset surface replaced by its basis before conversion | `Issue570HealingApproxTests.swift:92:9: Expectation failed: deviation < 1e-5` | pass | PASS |
| `convertToBSplineAdvancedDoesNotCollapse` | Issue570HealingApproxTests.swift | `OCCTShapeConvertToBSplineAdvanced` | OFFSETBASIS: offset surface replaced by its basis before conversion | `Issue570HealingApproxTests.swift:100:9: Expectation failed: deviation < 1e-5` | pass | PASS |
| `bsplineRestrictionHonoursTolerance` | Issue570HealingApproxTests.swift | `OCCTShapeBSplineRestriction` | RTOL: both approximation tolerances scaled x1000 | `Issue570HealingApproxTests.swift:122:9: Expectation failed: deviation <= tolerance` | pass | PASS |
| `bsplineRestrictionAtEachContinuity` | Issue570HealingApproxTests.swift | `OCCTShapeCustomBSplineRestriction` | RTOL: both approximation tolerances scaled x1000 | `Issue570HealingApproxTests.swift:142:9: Expectation failed: deviation <= tolerance [1 argument continuity → .c0]` | pass | PASS |
| `bsplineRestrictionAdvancedHonoursTolerance` | Issue570HealingApproxTests.swift | `OCCTShapeBSplineRestrictionAdvanced` | RTOL: both approximation tolerances scaled x1000 | `Issue570HealingApproxTests.swift:151:30: Expectation failed: Shape.bsplineRestrictionAdvanced(face, tol3d: tolerance, tol2d: tolerance, maxDegree: 9, maxSegments: 10000)` | pass | PASS |
| `trimmedOffsetSphereWasNeverAffected` | Issue570HealingApproxTests.swift | `OCCTShapeConvertToBSpline` | OFFSETBASIS: offset surface replaced by its basis before conversion | `Issue570HealingApproxTests.swift:174:9: Expectation failed: deviation < 1e-5` | pass | N/A: the pole-trimmed variant is not probed; the full-domain one is |
| `freeBoundsUnaffectedByInternalOrientation` | Issue655FreeBoundsInternalOrientationTests.swift | `OCCTShapeFreeBoundsClosedCount / OCCTShapeFreeBoundsClosed / OCCTShapeFreeBounds` | FBCOUNTSRC: count wires of the input instead of the result | `Issue655FreeBoundsInternalOrientationTests.swift:96:9: Expectation failed: shape.freeBoundsClosedCount(tolerance: 1e-6) == 2` | pass | PASS |
| `forwardLoopIsCounted` | Issue655FreeBoundsInternalOrientationTests.swift | `OCCTShapeFreeBoundsClosedCount / OCCTShapeFreeBoundsClosed / OCCTShapeFreeBounds` | FBOPENCLOSED: count GetOpenWires() in the closed-count function | `Issue655FreeBoundsInternalOrientationTests.swift:126:9: Expectation failed: shape.freeBoundsClosedCount(tolerance: 1e-6) == 3` | pass | PASS |
| `sharedTopologyBranchMeasuredDirectly` | Issue655FreeBoundsInternalOrientationTests.swift | `OCCTFreeBoundsPropsCounts` | FBCOUNTS: closed/open counts swapped | `Issue655FreeBoundsInternalOrientationTests.swift:180:9: Expectation failed: analysis.closedCount == expectedClosed [4 arguments loopOrientation → .forward, tolerance → -1.0, expectedClosed → 2, expectedOpen → 4]` | pass | PASS |
## #766 measured: ShapeAnalysis curve/surface statics, analyze(), TransferParametersProj (16 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-shapeanalysis/transcript.txt`.
| `isClosedWithPrecision` | ShapeAnalysisCurveStaticTests.swift | `OCCTCurve3DIsClosedWithPreci / OCCTCurve3DIsPeriodicSA / OCCTCurve3DIsPlanar` | CURVECLOSEDINV: IsClosed answer inverted | `ShapeAnalysisCurveStaticTests.swift:21:9: Expectation failed: try circle().isClosedWithPrecision(1e-6)` | pass | PASS |
| `lineIsNotClosed` | ShapeAnalysisCurveStaticTests.swift | `OCCTCurve3DIsClosedWithPreci / OCCTCurve3DIsPeriodicSA / OCCTCurve3DIsPlanar` | CURVECLOSEDINV: IsClosed answer inverted | `ShapeAnalysisCurveStaticTests.swift:25:9: Expectation failed: !(try line().isClosedWithPrecision(1e-6))` | pass | PASS |
| `isPeriodicSA` | ShapeAnalysisCurveStaticTests.swift | `OCCTCurve3DIsClosedWithPreci / OCCTCurve3DIsPeriodicSA / OCCTCurve3DIsPlanar` | PERIODICSAINV: IsPeriodic answer inverted | `ShapeAnalysisCurveStaticTests.swift:29:9: Expectation failed: try circle().isPeriodicSA` | pass | PASS |
| `lineIsNotPeriodic` | ShapeAnalysisCurveStaticTests.swift | `OCCTCurve3DIsClosedWithPreci / OCCTCurve3DIsPeriodicSA / OCCTCurve3DIsPlanar` | PERIODICSAINV: IsPeriodic answer inverted | `ShapeAnalysisCurveStaticTests.swift:33:9: Expectation failed: !(try line().isPeriodicSA)` | pass | PASS |
| `circleIsPlanar` | ShapeAnalysisCurveStaticTests.swift | `OCCTCurve3DIsClosedWithPreci / OCCTCurve3DIsPeriodicSA / OCCTCurve3DIsPlanar` | PLANARNORMAL: IsPlanar normal reported with x and z swapped | `ShapeAnalysisCurveStaticTests.swift:39:9: Expectation failed: simd_distance(normal, SIMD3(0, 0, 1)) < 1e-12` | pass | PASS |
| `lineIsPlanar` | ShapeAnalysisCurveStaticTests.swift | `OCCTCurve3DIsClosedWithPreci / OCCTCurve3DIsPeriodicSA / OCCTCurve3DIsPlanar` | PLANARNORMAL: IsPlanar normal reported with x and z swapped | `ShapeAnalysisCurveStaticTests.swift:46:9: Expectation failed: simd_distance(normal, SIMD3(0, 0, 1)) < 1e-12` | pass | PASS |
| `projectPointOnPlane` | ShapeAnalysisSurfaceTests.swift | `OCCTSurfaceProjectPointUV / OCCTSurfaceHasSingularities / OCCTSurfaceIsUClosedSA` | SASPROJ: projected u and v swapped | `ShapeAnalysisSurfaceTests.swift:18:9: Expectation failed: abs(result.u - 5.0) < 1e-9` | pass | PASS |
| `projectPointOffPlane` | ShapeAnalysisSurfaceTests.swift | `OCCTSurfaceProjectPointUV / OCCTSurfaceHasSingularities / OCCTSurfaceIsUClosedSA` | SASGAP: projection gap doubled | `ShapeAnalysisSurfaceTests.swift:25:9: Expectation failed: abs(result.gap - 10.0) < 1e-9` | pass | PASS |
| `planeHasNoSingularities` | ShapeAnalysisSurfaceTests.swift | `OCCTSurfaceProjectPointUV / OCCTSurfaceHasSingularities / OCCTSurfaceIsUClosedSA` | SASSING: singularity answer inverted, count +1 | `ShapeAnalysisSurfaceTests.swift:31:9: Expectation failed: !s.hasSingularitiesSA()` | pass | PASS |
| `planeIsNotClosed` | ShapeAnalysisSurfaceTests.swift | `OCCTSurfaceProjectPointUV / OCCTSurfaceHasSingularities / OCCTSurfaceIsUClosedSA` | SASCLOSED: IsUClosed/IsVClosed inverted | `ShapeAnalysisSurfaceTests.swift:37:9: Expectation failed: !s.isUClosedSA()` | pass | PASS |
| `analyzeValidBox` | ShapeAnalysisTests.swift | `OCCTShapeAnalyze` | INVALIDTOPO: hasInvalidTopology forced true | `ShapeAnalysisTests.swift:22:9: Expectation failed: analysis.hasInvalidTopology == false` | pass | PASS |
| `analyzeForSmallFeatures` | ShapeAnalysisTests.swift | `OCCTShapeAnalyze` | SMALLALL: every edge counted small | `ShapeAnalysisTests.swift:31:9: Expectation failed: analysis.smallEdgeCount == 0` | pass | PASS |
| `analysisResultProperties` | ShapeAnalysisTests.swift | `OCCTShapeAnalyze` | GAPDOUBLE: each gap counted twice | `ShapeAnalysisTests.swift:47:9: Expectation failed: analysis.gapCount == 24` | pass | PASS |
| `gapCountCountsEachGap` | ShapeAnalysisTests.swift | `OCCTShapeAnalyze` | GAPWIRE: count wires with a gap instead of gaps (the #1438 defect) | `ShapeAnalysisTests.swift:94:9: Expectation failed: analysis?.gapCount == 2` | pass | PASS |
| `transferToFace` | ShapeAnalysisTransferParametersProjTests.swift | `OCCTShapeAnalysisTransferParam` | TRANSFERZERO: transfer returns 0 instead of the kernel's parameter | `ShapeAnalysisTransferParametersProjTests.swift:24:9: Expectation failed: abs(edge.transferParameterToFace(1.0, face: face) - 1.0) < 1e-9` | pass | PASS |
| `transferFromFace` | ShapeAnalysisTransferParametersProjTests.swift | `OCCTShapeAnalysisTransferParam` | TRANSFERZERO: transfer returns 0 instead of the kernel's parameter | `ShapeAnalysisTransferParametersProjTests.swift:30:9: Expectation failed: abs(edge.transferParameterFromFace(1.0, face: face) - 1.0) < 1e-9` | pass | PASS |
## #766 measured: ShapeBuild Edge and Vertex (12 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-shapebuild/transcript.txt`.
| `copyEdge` | ShapeBuildEdgeTests.swift | `OCCTShapeBuildEdge*` | SBECOPYSAME: Copy hands back the original edge | `ShapeBuildEdgeTests.swift:42:9: Expectation failed: !copied.isSame(as: edges[0])` | pass | PASS |
| `copyEdgeNoShare` | ShapeBuildEdgeTests.swift | `OCCTShapeBuildEdge*` | SBECOPYSAME: Copy hands back the original edge | `ShapeBuildEdgeTests.swift:51:9: Expectation failed: !copied.isSame(as: edges[0])` | pass | PASS |
| `copyEdgeReplaceVertices` | ShapeBuildEdgeTests.swift | `OCCTShapeBuildEdge*` | SBEREPLSWAP: replacement vertices swapped | `ShapeBuildEdgeTests.swift:66:9: Expectation failed: EdgeAnalysis.firstVertex(result) == SIMD3(-5, -5, 5)` | pass | PASS |
| `setRange3d` | ShapeBuildEdgeTests.swift | `OCCTShapeBuildEdge*` | SBERANGE: SetRange3d skipped | `ShapeBuildEdgeTests.swift:76:9: Expectation failed: b.first == 0 && b.last == 5` | pass | PASS |
| `buildCurve3d` | ShapeBuildEdgeTests.swift | `OCCTShapeBuildEdge*` | SBEBUILDINV: BuildCurve3d answer inverted | `ShapeBuildEdgeTests.swift:83:9: Expectation failed: edges[0].buildEdgeCurve3d()` | pass | PASS |
| `removeCurve3d` | ShapeBuildEdgeTests.swift | `OCCTShapeBuildEdge*` | SBEREMOVENOOP: RemoveCurve3d skipped | `ShapeBuildEdgeTests.swift:92:9: Expectation failed: !EdgeAnalysis.hasCurve3d(copied)` | pass | PASS |
| `copyRanges` | ShapeBuildEdgeTests.swift | `OCCTShapeBuildEdge*` | SBECOPYRANGESNOOP: CopyRanges skipped | `ShapeBuildEdgeTests.swift:104:9: Expectation failed: b.first == 0 && b.last == 10` | pass | PASS |
| `copyPCurves` | ShapeBuildEdgeTests.swift | `OCCTShapeBuildEdge*` | SBEREMOVEPCNOOP (the removal it starts with is skipped, `:112`); CopyPCurves skipped also turns it red at `:114` (run B2) | `ShapeBuildEdgeTests.swift:112:9: Expectation failed: !EdgeAnalysis.hasPCurve(copied, face: face)` | pass | PASS |
| `removePCurve` | ShapeBuildEdgeTests.swift | `OCCTShapeBuildEdge*` | SBEREMOVEPCNOOP: RemovePCurve skipped | `ShapeBuildEdgeTests.swift:123:9: Expectation failed: !EdgeAnalysis.hasPCurve(copied, face: face)` | pass | PASS |
| `combineVertices` | ShapeBuildVertexTests.swift | `OCCTShapeBuildVertexCombine / OCCTShapeBuildVertexCombineFromPoints` | SBVFACTOR: tolFactor ignored (1.0) | `ShapeBuildVertexTests.swift:28:9: Expectation failed: abs(combined.vertexTolerance - 5.0005001) < 1e-6` | pass | PASS |
| `combineFromPoints` | ShapeBuildVertexTests.swift | `OCCTShapeBuildVertexCombine / OCCTShapeBuildVertexCombineFromPoints` | SBVFACTOR: tolFactor ignored (1.0) | `ShapeBuildVertexTests.swift:38:9: Expectation failed: abs(combined.vertexTolerance - 0.0150015) < 1e-9` | pass | PASS |
| `combineWithTolFactor` | ShapeBuildVertexTests.swift | `OCCTShapeBuildVertexCombine / OCCTShapeBuildVertexCombineFromPoints` | SBVFACTOR: tolFactor ignored (1.0) | `ShapeBuildVertexTests.swift:46:9: Expectation failed: abs(combined.vertexTolerance - 7.50000015) < 1e-6` | pass | PASS |
## #766 measured: LocationPurge, NearestPlane, NURBSConversion, RemoveLocations, SameParameter (11 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-locations-nurbs-sameparam/transcript.txt`.
| `cleanShapePurge` | LocationPurgeTests.swift | `OCCTShapePurgeLocations` | PURGENULL: treat a done purge as failed (nil) | `LocationPurgeTests.swift:18:26: Expectation failed: box.purgedLocations` | pass | PASS |
| `mirroredShapePurge` | LocationPurgeTests.swift | `OCCTShapePurgeLocations` | PURGENULL: treat a done purge as failed (nil) | `LocationPurgeTests.swift:30:26: Expectation failed: mirrored.purgedLocations` | pass | PASS |
| `nearestPlane` | NearestPlaneTests.swift | `OCCTShapeNearestPlane` | NPNORMAL: normal's z component reported from x | `NearestPlaneTests.swift:22:9: Expectation failed: simd_distance(result.normal, SIMD3(0.002500313, 0.007500938, 0.999968742)) < 1e-8` | pass | PASS |
| `convertBox` | NURBSConversionTests.swift | `OCCTShapeConvertToNURBS` | NURBSNOOP: return the input instead of the NURBS conversion | `NURBSConversionTests.swift:22:9: Expectation failed: bsplineFaceCount(nurbs) == 6` | pass | PASS |
| `convertSphere` | NURBSConversionTests.swift | `OCCTShapeConvertToNURBS` | NURBSNOOP: return the input instead of the NURBS conversion | `NURBSConversionTests.swift:32:9: Expectation failed: bsplineFaceCount(nurbs) == 1` | pass | PASS |
| `convertFilleted` | NURBSConversionTests.swift | `OCCTShapeConvertToNURBS` | NURBSNOOP: return the input instead of the NURBS conversion | `NURBSConversionTests.swift:41:9: Expectation failed: bsplineFaceCount(nurbs) == 26` | pass | PASS |
| `removeFromTranslated` | RemoveLocationsTests.swift | `OCCTShapeRemoveLocations` | REMLOCDROP: drop the location instead of folding it into the geometry | `RemoveLocationsTests.swift:24:9: Expectation failed: simd_distance(b.min, SIMD3(95, 195, 295)) < 1e-6` | pass | PASS |
| `removeFromRotated` | RemoveLocationsTests.swift | `OCCTShapeRemoveLocations` | REMLOCDROP: drop the location instead of folding it into the geometry | `RemoveLocationsTests.swift:39:9: Expectation failed: simd_distance(b.min, SIMD3(45, -10.6066, -3.5355)) < 1e-3` | pass | PASS |
| `sameParameterBox` | SameParameterTests.swift | `OCCTShapeSameParameter` | SAMEPARAMNULL: return nil before BRepLib::SameParameter | `SameParameterTests.swift:16:21: Expectation failed: box.sameParameter()` | pass | PASS |
| `sameParameterCylinder` | SameParameterTests.swift | `OCCTShapeSameParameter` | SAMEPARAMNULL: return nil before BRepLib::SameParameter | `SameParameterTests.swift:24:21: Expectation failed: cyl.sameParameter()` | pass | PASS |
| `sameParameterPreservesVolume` | SameParameterTests.swift | `OCCTShapeSameParameter` | SAMEPARAMNULL: return nil before BRepLib::SameParameter | `SameParameterTests.swift:32:26: Expectation failed: box.sameParameter()` | pass | PASS |
## #766 measured: Issue442 fixSolid/solidFromShellFixed, Issue443 solid(from:)/upgraded() multi-body (38 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-442-443/transcript.txt`.
| `fixSolidMultiBody` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | FIXSOLIDFIRST: fixSolid heals only the first solid (the pre-#442 first-of-N) | `Issue442FixSolidMultiBodyTests.swift:42:9: Expectation failed: healed.solids.count == 2` | pass | PASS |
| `fixSolidSingleBody` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | SINGLECOMP: a single body returned wrapped in a compound | `Issue442FixSolidMultiBodyTests.swift:57:9: Expectation failed: healed.shapeType == .solid` | pass | PASS |
| `fixSolidHollow` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | CAVITYDROP: fixSolid rebuilds from the outer shell only, filling the cavity | `Issue442FixSolidMultiBodyTests.swift:74:21: Expectation failed: abs(volume - expected) < 1e-6` | pass | PASS |
| `fixSolidMulticonnex` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | FIXCOMPFIRST: only the first solid of ShapeFix_Solid's compound kept | `Issue442FixSolidMultiBodyTests.swift:92:9: Expectation failed: healed.solids.count == 2` | pass | PASS |
| `fixSolidNoSolid` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | FIXSOLIDPASS: fixSolid hands back the input when it holds no solid | `Issue442FixSolidMultiBodyTests.swift:108:9: Expectation failed: face.fixSolid() == nil` | pass | PASS |
| `solidFromShellMultiBody` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue442FixSolidMultiBodyTests.swift:124:9: Expectation failed: solids.solids.count == 2` | pass | PASS |
| `solidFromShellSingleBody` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | BODYALL: every shell selected as a body, no enclosure parity | `Issue442FixSolidMultiBodyTests.swift:139:9: Expectation failed: solid.shapeType == .solid` | pass | PASS |
| `solidFromShellSkipsCavity` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | BODYALL: every shell selected as a body, no enclosure parity | `Issue442FixSolidMultiBodyTests.swift:159:9: Expectation failed: solid.shapeType == .solid` | pass | PASS |
| `solidFromShellMulticonnex` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue442FixSolidMultiBodyTests.swift:178:9: Expectation failed: solids.solids.count == 2` | pass | PASS |
| `solidFromShellCavityWithWiderSibling` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue442FixSolidMultiBodyTests.swift:210:9: Expectation failed: bodies.solids.count == 2` | pass | PASS |
| `solidFromShellFreeShells` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue442FixSolidMultiBodyTests.swift:232:9: Expectation failed: solids.solids.count == 2` | pass | PASS |
| `solidFromShellDeduplicates` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | DEDUP: no de-duplication of a repeated free shell | `Issue442FixSolidMultiBodyTests.swift:255:9: Expectation failed: solid.solids.count == 1` | pass | PASS |
| `solidFromShellNoShell` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | SHELLFROMFACES: a shell-less input's faces wrapped into a shell instead of refusing | `Issue442FixSolidMultiBodyTests.swift:271:9: Expectation failed: face.solidFromShellFixed() == nil` | pass | PASS |
| `documentedUnclosedCheck` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | FIXSOLIDFIRST: fixSolid heals only the first solid (the pre-#442 first-of-N) | `Issue442FixSolidMultiBodyTests.swift:290:9: Expectation failed: bodies.count == 2` | pass | PASS |
| `openShellDoesNotPerturbParity` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | BODYFIRST and OPENREF in one run; BODYALL alone also turns it red, at :354 (the cavity emitted as a body) | `Issue442FixSolidMultiBodyTests.swift:351:9: Expectation failed: volumes.contains { abs($0 - 8000.0) < 1e-6 }` | pass | N/A: the open-shell reference rule is bridge logic; no single kernel call answers it |
| `reproducerTable` | Issue442FixSolidMultiBodyTests.swift | `OCCTShapeSolidFromShell (occtBodyBoundingShells)` | FIXSOLIDFIRST and BODYFIRST in one run (the table walks both fixSolid and solidFromShellFixed) | `Issue442FixSolidMultiBodyTests.swift:381:13: Expectation failed: shape.solids.count == 2` | pass | PASS |
| `solidFromSewnMultiBody` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:61:9: Expectation failed: solid.solids.count == 2` | pass | PASS |
| `solidFromAgreesWithSibling` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:81:9: Expectation failed: viaMakeSolid.solids.count == 2` | pass | PASS |
| `solidFromSingleShell` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | SINGLECOMP: a single body returned wrapped in a compound | `Issue443FirstOfNTests.swift:98:9: Expectation failed: solid.shapeType == .solid` | pass | PASS |
| `solidFromKeepsOpenBody` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:124:9: Expectation failed: solid.solids.count == 2` | pass | PASS |
| `solidFromSkipsCavity` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYALL: every shell selected as a body, no enclosure parity | `Issue443FirstOfNTests.swift:142:9: Expectation failed: solid.shapeType == .solid` | pass | PASS |
| `solidFromMulticonnex` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:163:9: Expectation failed: bodies.solids.count == 2` | pass | PASS |
| `solidFromNoShell` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | SHELLFROMFACES: a shell-less input's faces wrapped into a shell instead of refusing | `Issue443FirstOfNTests.swift:175:9: Expectation failed: Shape.solid(from: face) == nil` | pass | PASS |
| `sewnHollowIsOneBody` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYALL: every shell selected as a body, no enclosure parity | `Issue443FirstOfNTests.swift:205:13: Expectation failed: result.solids.count == 1` | pass | PASS |
| `sewnAndUnsewnHollowAgree` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYALL: every shell selected as a body, no enclosure parity | `Issue443FirstOfNTests.swift:220:9: Expectation failed: fromSolid.solids.count == fromShells.solids.count` | pass | PASS |
| `manyFreeShells` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:253:9: Expectation failed: solids.solids.count == count` | pass | PASS |
| `touchingBodiesNotPruned` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:274:9: Expectation failed: solids.solids.count == 2` | pass | PASS |
| `solidWithHistoryMultiBody` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:292:9: Expectation failed: result.solids.count == 2` | pass | PASS |
| `solidWithHistoryQueryableForEveryBody` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:328:9: Expectation failed: result.solids.count == 2` | pass | PASS |
| `solidWithHistorySingleShell` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | SINGLECOMP: a single body returned wrapped in a compound | `Issue443FirstOfNTests.swift:352:9: Expectation failed: result.shapeType == .solid` | pass | PASS |
| `solidWithHistoryKeepsOpenBody` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:368:9: Expectation failed: result.solids.count == 2` | pass | PASS |
| `upgradedMultiBody` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:387:9: Expectation failed: upgraded.solids.count == 2` | pass | PASS |
| `upgradedFromLooseFaces` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:417:9: Expectation failed: upgraded.solids.count == 2` | pass | PASS |
| `upgradedSingleBody` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | UPGRADE: upgraded() skips the per-body MakeSolid step | `Issue443FirstOfNTests.swift:431:9: Expectation failed: upgraded.solids.count == 1` | pass | PASS |
| `upgradedHollow` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYALL: every shell selected as a body, no enclosure parity | `Issue443FirstOfNTests.swift:454:9: Expectation failed: upgraded.solids.count == 1` | pass | PASS |
| `upgradedNestedBody` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:478:9: Expectation failed: upgraded.solids.count == 2` | pass | PASS |
| `upgradedKeepsOpenBody` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | BODYFIRST: occtBodyBoundingShells keeps only the first body shell (the pre-#443 first-of-N) | `Issue443FirstOfNTests.swift:505:9: Expectation failed: upgraded.subShapeCount(ofType: .face) == 11` | pass | PASS |
| `upgradedNoShell` | Issue443FirstOfNTests.swift | `occtBodyBoundingShells via OCCTShapeCreateSolidFromShell / OCCTShapeUpgrade` | UPGRADEDROPLOOSE: upgraded() returns nil when the healed result holds no solid | `Issue443FirstOfNTests.swift:519:25: Issue recorded` | pass | PASS |
## #766 measured: Issue1638 compose-shell grid, Issue266 face healing control, Issue318, Issue438 (13 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-1638-266-318-438/transcript.txt`.
| `planarFaceSplitsIntoTheRequestedGrid` | Issue1638ComposeShellGridTests.swift | `OCCTShapeFixComposeShell` | CSGRID1: grid forced to 1 x 1 (the pre-#1638 defect) | `Issue1638ComposeShellGridTests.swift:36:13: Expectation failed: composed.subShapes(ofType: .face).count == u * v` | pass | PASS |
| `defaultGridIsStillAWireRebuild` | Issue1638ComposeShellGridTests.swift | `OCCTShapeFixComposeShell` | CSGRIDPLUS: one extra patch along U | `Issue1638ComposeShellGridTests.swift:46:9: Expectation failed: composed.subShapes(ofType: .face).count == 1` | pass | PASS |
| `piecesTileTheOriginalArea` | Issue1638ComposeShellGridTests.swift | `OCCTShapeFixComposeShell` | CSGRID1: grid forced to 1 x 1 (the pre-#1638 defect) | `Issue1638ComposeShellGridTests.swift:58:9: Expectation failed: areas.count == 4` | pass | PASS |
| `cylinderWallSplits` | Issue1638ComposeShellGridTests.swift | `OCCTShapeFixComposeShell` | CSGRID1: grid forced to 1 x 1 (the pre-#1638 defect) | `Issue1638ComposeShellGridTests.swift:71:9: Expectation failed: alongU.subShapes(ofType: .face).count == 4` | pass | PASS |
| `patchCountsBelowOneAreRefused` | Issue1638ComposeShellGridTests.swift | `OCCTShapeFixComposeShell` | SWIFTPATCH + CSPATCH: drop both the Swift and the bridge `< 1` guard (run P1). Either guard alone is enough: dropping only one stays green (runs Y1, P2) | `the test process dies on signal 11 (SIGSEGV) once `composeShell(uPatches: 0)` reaches the bridge's patch-grid build with a zero extent; nothing is thrown, so no catch can refuse it. The guards are what keep a Swift caller alive` | pass | PASS |
| `nonFaceInputIsRefused` | Issue1638ComposeShellGridTests.swift | `OCCTShapeFixComposeShell` | CSFIRSTFACE: a non-face input's first face composed instead of refusing | `Issue1638ComposeShellGridTests.swift:92:9: Expectation failed: box.composeShell(uPatches: 2) == nil` | pass | PASS: the type refusal is TopoDS::Face throwing into the catch |
| `faceFixerControl` | Issue266FaceHealingControlTests.swift | `OCCTFaceFixer*` | FFSTATUS: Status() reports true for every flag | `Issue266FaceHealingControlTests.swift:39:9: Expectation failed: !fixer.status(.done)` | pass | PASS |
| `faceFixerIndividualPasses` | Issue266FaceHealingControlTests.swift | `OCCTFaceFixer*` | FFPASSES: each individual pass reports it did something | `Issue266FaceHealingControlTests.swift:58:9: Expectation failed: fixer.fixIntersectingWires() == false` | pass | PASS |
| `checkCleanFace` | Issue266FaceHealingControlTests.swift | `OCCTFaceFixer*` | FACEGUARDINV: type guard inverted: a face is refused (CheckFail) | `Issue266FaceHealingControlTests.swift:71:9: Expectation failed: face.checkFaceIntersectingWires() == .noError` | pass | PASS |
| `checkNonFace` | Issue266FaceHealingControlTests.swift | `OCCTFaceFixer*` | FACECHECKFIRST: a non-face input's first face checked instead of refusing | `Issue266FaceHealingControlTests.swift:82:9: Expectation failed: box.checkFaceIntersectingWires() == .checkFail` | pass | PASS: dropping the type guard alone stays green: TopoDS::Face throws into the catch |
| `analyzeSurvivesDegenerateCurveOnSurfaceEdge` | Issue318DegenerateCurveOnSurfaceEdgeTests.swift | `OCCTShapeAnalyze` | DEGENSKIP: degenerate edges no longer skipped by the small-edge count (the #318 guard) | `Issue318DegenerateCurveOnSurfaceEdgeTests.swift:46:9: Expectation failed: result.smallEdgeCount == 0` | pass | PASS |
| `dividedVariesWithContinuity` | Issue438DivideContinuityUnificationTests.swift | `OCCTShapeDivide` | DIVBOUNDONLY: only the boundary criterion set (the pre-#438 defect) | `Issue438DivideContinuityUnificationTests.swift:77:9: Expectation failed: result?.faceCount == expectedFaces [2 arguments level → .c0, expectedFaces → nil]` | pass | PASS |
| `dividedContinuityIsObservable` | Issue438DivideContinuityUnificationTests.swift | `OCCTShapeDivide` | DIVBOUNDONLY: only the boundary criterion set (the pre-#438 defect) | `Issue438DivideContinuityUnificationTests.swift:84:9: Expectation failed: atC1.faceCount != atC3.faceCount` | pass | PASS |
## #766 measured: ShapeConstruct Curve + Triangulation, ShapeCustom BSplineRestriction / DirectModification / SurfacePeriodic / TrsfModification, ShapeExtend Explorer (16 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-construct-custom-extend/transcript.txt`.
| `convert3DLine` | ShapeConstructCurveTests.swift | `OCCTCurve3DConvertSegmentToBSpline / OCCTCurve2DConvertSegmentToBSpline / OCCTCurve3DAdjustEndpoints` | SCCONV: segment converted only to its midpoint parameter | `ShapeConstructCurveTests.swift:19:9: Expectation failed: simd_distance(bsp.point(at: bsp.domain.upperBound), SIMD3(10, 0, 0)) < 1e-9` | pass | PASS |
| `convert3DCircle` | ShapeConstructCurveTests.swift | `OCCTCurve3DConvertSegmentToBSpline / OCCTCurve2DConvertSegmentToBSpline / OCCTCurve3DAdjustEndpoints` | SCCONV: segment converted only to its midpoint parameter | `ShapeConstructCurveTests.swift:29:9: Expectation failed: simd_distance(bsp.point(at: bsp.domain.upperBound), SIMD3(-5, 0, 0)) < 1e-9` | pass | PASS |
| `convert2DLine` | ShapeConstructCurveTests.swift | `OCCTCurve3DConvertSegmentToBSpline / OCCTCurve2DConvertSegmentToBSpline / OCCTCurve3DAdjustEndpoints` | SCCONV: segment converted only to its midpoint parameter | `ShapeConstructCurveTests.swift:39:9: Expectation failed: simd_distance(bsp.point(at: bsp.domain.upperBound), SIMD2(5, 0)) < 1e-9` | pass | PASS |
| `adjust3D` | ShapeConstructCurveTests.swift | `OCCTCurve3DConvertSegmentToBSpline / OCCTCurve2DConvertSegmentToBSpline / OCCTCurve3DAdjustEndpoints` | SCADJUST: AdjustCurve verdict inverted | `ShapeConstructCurveTests.swift:46:9: Expectation failed: line.adjustEndpoints(start: SIMD3(0, 0, 0), end: SIMD3(10, 0, 0))` | pass | PASS |
| `fromPoints` | ShapeConstructTriangulationTests.swift | `OCCTShapeTriangulationFromPoints / FromWire` | TRIPTS: last point dropped | `ShapeConstructTriangulationTests.swift:20:9: Expectation failed: abs((shape.surfaceArea ?? 0) - 100) < 1e-9` | pass | PASS |
| `fromWire` | ShapeConstructTriangulationTests.swift | `OCCTShapeTriangulationFromPoints / FromWire` | TRIWIRENULL: wire triangulation returns nil | `ShapeConstructTriangulationTests.swift:27:25: Expectation failed: Shape.triangulationFromWire(w)` | pass | PASS |
| `bsplineRestrictionBox` | ShapeCustomBSplineRestrictionTests.swift | `OCCTShapeCustomBSplineRestriction` | CUSTRESTRNULL: BSplineRestriction returns nil | `ShapeCustomBSplineRestrictionTests.swift:17:26: Expectation failed: box.bsplineRestriction(tol3d: 0.01, tol2d: 0.01)` | pass | PASS |
| `bsplineRestrictionCustom` | ShapeCustomBSplineRestrictionTests.swift | `OCCTShapeCustomBSplineRestriction` | CUSTRESTRNULL: BSplineRestriction returns nil | `ShapeCustomBSplineRestrictionTests.swift:26:26: Expectation failed: box.bsplineRestriction(tol3d: 0.001, tol2d: 0.001, maxDegree: 4, maxSegments: 50, continuity3d: .c2, continuity2d: .c2)` | pass | PASS |
| `directModification` | ShapeCustomDirectModificationTests.swift | `OCCTShapeCustomDirectModification` | DIRECTMODNULL: DirectModification returns nil | `ShapeCustomDirectModificationTests.swift:16:26: Expectation failed: box.directModification()` | pass | PASS |
| `convertToPeriodic` | ShapeCustomSurfacePeriodicTests.swift | `OCCTSurfaceConvertToPeriodic / OCCTSurfaceConversionGap` | PERIODICSURFPASS: a null ConvertToPeriodic result replaced by the input surface | `ShapeCustomSurfacePeriodicTests.swift:15:9: Expectation failed: surf.convertToPeriodic() == nil` | pass | PASS |
| `conversionGapIsDeprecatedSentinel` | ShapeCustomSurfacePeriodicTests.swift | `OCCTSurfaceConvertToPeriodic / OCCTSurfaceConversionGap` | GAPSENTINEL: deprecated gap reported as 0.0 instead of the -1.0 sentinel | `ShapeCustomSurfacePeriodicTests.swift:37:9: Expectation failed: bsp.conversionGap == -1.0` | pass | PASS |
| `trsfModificationScale` | ShapeCustomTrsfModificationTests.swift | `OCCTShapeCustomTrsfModification` | TRSFFACTOR: scale factor ignored (1.0) | `ShapeCustomTrsfModificationTests.swift:17:9: Expectation failed: abs((result.volume ?? 0) - 8000) < 1e-6` | pass | PASS |
| `sortedCompoundSolids` | ShapeExtendExplorerTests.swift | `OCCTShapeExtendSortedCompound / OCCTShapeExtendPredominantType` | SORTEDTYPEOFF: sorted-compound type shifted by one | `ShapeExtendExplorerTests.swift:24:9: Expectation failed: solids.subShapes(ofType: .solid).count == 2` | pass | PASS |
| `sortedCompoundFaces` | ShapeExtendExplorerTests.swift | `OCCTShapeExtendSortedCompound / OCCTShapeExtendPredominantType` | SORTEDTYPEOFF: sorted-compound type shifted by one | `ShapeExtendExplorerTests.swift:30:9: Expectation failed: faces.subShapes(ofType: .face).count == 12` | pass | PASS |
| `sortedCompoundEdges` | ShapeExtendExplorerTests.swift | `OCCTShapeExtendSortedCompound / OCCTShapeExtendPredominantType` | SORTEDTYPEOFF: sorted-compound type shifted by one | `ShapeExtendExplorerTests.swift:38:9: Expectation failed: edges.subShapes(ofType: .edge).count == 12` | pass | PASS |
| `predominantType` | ShapeExtendExplorerTests.swift | `OCCTShapeExtendSortedCompound / OCCTShapeExtendPredominantType` | TYPEPLUS1: predominant type shifted by one | `ShapeExtendExplorerTests.swift:43:9: Expectation failed: try twoBoxes().predominantShapeType() == .solid` | pass | PASS |
## #766 measured: SewingBuilder, SewingExtended, SewingExtras, Sewing (14 tests)
Red = the failing expectation under the named injection (env-gated `INJ766` token in the bridge, one build); Green = same build, no token. Parity against `Scripts/repro/766-healing-sewing/transcript.txt`.
| `createSewing` | SewingBuilderTests.swift | `OCCTSewing*` | SEWCREATENULL: builder construction returns nil | `SewingBuilderTests.swift:14:26: Expectation failed: SewingBuilder(tolerance: 1e-6)` | pass | PASS |
| `sewBoxFaces` | SewingBuilderTests.swift | `OCCTSewing*` | SEWNOPERFORM: Perform() skipped | `SewingBuilderTests.swift:24:26: Expectation failed: sewing.result` | pass | PASS |
| `sewingStatistics` | SewingBuilderTests.swift | `OCCTSewing*` | SEWFREECOUNT: free-edge count answered with the contiguous-edge count | `SewingBuilderTests.swift:36:9: Expectation failed: sewing.nbFreeEdges == 4` | pass | PASS |
| `sewingDeletedFacesAndQueries` | SewingExtendedTests.swift | `OCCTSewing*` | SEWNOPERFORM: Perform() skipped | `SewingExtendedTests.swift:23:26: Expectation failed: s.result` | pass | PASS |
| `sewingIsModified` | SewingExtendedTests.swift | `OCCTSewing*` | SEWISMODINV: IsModified inverted | `SewingExtendedTests.swift:39:9: Expectation failed: s.isModified(faces[0]) == false` | pass | PASS |
| `sewingIsDegenerated` | SewingExtendedTests.swift | `OCCTSewing*` | DEGENINV: IsDegenerated inverted | `SewingExtendedTests.swift:48:9: Expectation failed: !s.isDegenerated(b)` | pass | PASS |
| `sewingLoadAndModes` | SewingExtendedTests.swift | `OCCTSewing*` | SEWLOADNOOP: Load() skipped | `SewingExtendedTests.swift:64:26: Expectation failed: s.result` | pass | PASS |
| `sewingSectionBoundAndWhichFace` | SewingExtendedTests.swift | `OCCTSewing*` | WHICHFACEANY: a null WhichFace answered with the sewn shape's first face | `SewingExtendedTests.swift:79:9: Expectation failed: s.whichFace(edge) == nil` | pass | PASS |
| `multipleEdgeCount` | SewingExtrasTests.swift | `OCCTSewingNbMultipleEdges / OCCTSewingMultipleEdge` | MULTICOUNTPLUS: NbMultipleEdges reported one too many | `SewingExtrasTests.swift:31:9: Expectation failed: s.multipleEdgeCount == 1` | pass | PASS |
| `noMultipleEdgesForBox` | SewingExtrasTests.swift | `OCCTSewingNbMultipleEdges / OCCTSewingMultipleEdge` | MULTICOUNTPLUS: NbMultipleEdges reported one too many | `SewingExtrasTests.swift:40:9: Expectation failed: s.multipleEdgeCount == 0` | pass | PASS |
| `multipleEdgeAtInvalidIndex` | SewingExtrasTests.swift | `OCCTSewingNbMultipleEdges / OCCTSewingMultipleEdge` | MULTIIDXOFF: multiple-edge index off by one | `SewingExtrasTests.swift:46:9: Expectation failed: s.multipleEdge(at: 1) != nil` | pass | PASS |
| `sewTwoShapes` | SewingTests.swift | `OCCTShapeSew / OCCTShapeSewMultiple` | SEWFIRSTONLY: only the first shape of a multi-shape sew is added | `SewingTests.swift:25:9: Expectation failed: sewn.faces().count == 2` | pass | PASS |
| `sewMultipleFaces` | SewingTests.swift | `OCCTShapeSew / OCCTShapeSewMultiple` | SEWFIRSTONLY: only the first shape of a multi-shape sew is added | `SewingTests.swift:37:9: Expectation failed: sewn.faces().count == 3` | pass | PASS |
| `instanceMethodSewn` | SewingTests.swift | `OCCTShapeSew / OCCTShapeSewMultiple` | SEWFIRSTONLY: only the first shape of a multi-shape sew is added | `SewingTests.swift:46:9: Expectation failed: sewn.faces().count == 2` | pass | PASS |
