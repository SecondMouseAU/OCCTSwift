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
