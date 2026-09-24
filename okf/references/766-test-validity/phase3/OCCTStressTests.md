# Phase 3: OCCTStressTests Injection Matrix

**Target**: `OCCTStressTests` (366 tests) — concurrency, TSan, crash reproduction
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (highest — TSan, concurrency, kernel crash fixes)

---

## Test Inventory by Suite

| Suite | Tests | Lines | Primary Category |
|-------|-------|-------|------------------|
| Stress: Concurrent Read-Only Queries | 5 | 21-88 | TS (thread safety) |
| Stress: Concurrent Curve Evaluation | 3 | 96-140 | TS |
| Stress: Concurrent Shape Creation | 2 | 151-170 | TS |
| Stress: Concurrent Document Creation (#344) | 1 | 188-195 | TS/CR (#344 CDF_Directory) |
| Stress: Sequential Determinism | 4 | 205-252 | WR |
| Stress: Sendable Boundary Crossing | 5 | 264-298 | TS |
| Stress: Nil Propagation | 7 | 13-81 | RF (nil propagation) |
| Stress: Zero-Dimension Shapes | 7 | 89-139 | DG |
| Stress: Empty Containers | 6 | 147-183 | DG/CR |
| Stress: Invalid Parameters | 14 | 191-291 | CR/DG (#345 gp_Dir, #348, evalAndUpdateTol) |
| Stress: Post-Operation State | 5 | 299-355 | WR |
| Stress: Unusual Input Combinations | 10 | 363-444 | DG/WR |
| Stress: UnifySameDomainBuilder Null PCurve | 1 | 458-467 | CR (#348) |
| Stress: evalAndUpdateTolerance Null PCurve | 2 | 484-524 | CR (#348 null pcurve) |
| Stress: Micro Scale Geometry | 7 | 13-55 | DG |
| Stress: Macro Scale Geometry | 6 | 69-110 | DG |
| Stress: Mixed Scale Geometry | 4 | 116-148 | DG |
| Stress: Coincident Geometry | 8 | 156-235 | DG |
| Stress: Degenerate Operations | 11 | 245-320 | DG |
| Stress: Near-Degenerate Geometry | 7 | 338-385 | DG |
| Stress: Curve and Surface Boundaries | 10 | 392-465 | DG/OOB |
| Stress: Round-Trip STEP | 8 | 42-49 | IO |
| Stress: Round-Trip BREP | 8 | 75-82 | IO |
| Stress: Round-Trip BREP String | 8 | 111-118 | IO |
| Stress: Round-Trip STL | 7 | 144-150 | IO |
| Stress: Round-Trip OBJ | 11 | 167-195 | IO |
| Stress: Cross-Format Consistency | 3 | 204-276 | IO/WR |
| Stress: Boolean Chains | 5 | 13-83 | WR/TS |
| Stress: Feature Chains | 4 | 99-146 | WR/TS |
| Stress: Transform Chains | 4 | 181-226 | WR/TS |
| Stress: Wire Construction Chains | 3 | 239-270 | WR/TS |
| Stress: Document Assembly Chains | 3 | 289-318 | TS/IO |
| Stress: Curve Evaluation Depth | 3 | 327-355 | WR |
| Stress: Shape Factories | 12 | 14-52 | WR |
| Stress: Shape Booleans | 6 | 59-84 | WR |
| Stress: Shape Features | 8 | 95-132 | WR |
| Stress: Shape Transforms | 4 | 146-166 | WR |
| Stress: Shape Queries | 24 | 172-256 | WR |
| Stress: Wire API | 10 | 262-300 | WR |
| Stress: Edge API | 2 | 307-324 | WR |
| Stress: Face API | 6 | 330-375 | WR |
| Stress: Curve3D API | 11 | 389-446 | WR |
| Stress: Curve2D API | 6 | 460-487 | WR |
| Stress: Surface API | 11 | 493-551 | WR |
| Stress: Document API | 8 | 558-602 | TS/IO |
| Stress: Math Utilities | 7 | 609-654 | WR |
| Stress: Mesh API | 5 | 659-694 | WR |
| Stress: Feature Recognition | 3 | 701-719 | WR |
| Stress: FilletBuilder Lifecycle | 6 | 14-69 | DG/RL |
| Stress: ChamferBuilder Lifecycle | 6 | 91-145 | DG/RL |
| Stress: PipeShellBuilder Lifecycle | 6 | 173-224 | DG/RL |
| Stress: SewingBuilder Lifecycle | 6 | 234-273 | DG/RL |
| Stress: WireBuilder Lifecycle | 6 | 281-315 | DG/RL |
| Stress: HatchBuilder Lifecycle | 6 | 324-344 | DG/RL |
| Stress: UnifySameDomainBuilder Lifecycle | 5 | 350-381 | DG/CR |
| Stress: ThruSectionsBuilder Lifecycle | 12 | 394-730 | DG/CR (#905, #913) |
| Stress: CellsBuilder Lifecycle | 5 | 758-789 | DG/RL |
| Stress: SectionBuilder Lifecycle | 8 | 796-872 | DG/RL |
| Stress: WireAnalyzer Lifecycle | 3 | 904-942 | DG/RL |
| Stress: WireFixer Lifecycle | 3 | 950-992 | DG/RL |
| Stress: FaceFixer Lifecycle | 3 | 999-1019 | DG/RL |
| Stress: ShapeFixer Lifecycle | 3 | 1027-1056 | DG/RL |

**Total**: 366 tests across 54 suites in 8 files

---

## Injection Matrix: Critical Crash-Related Tests First

### #345: gp_Dir Zero Vector Crash (Stress: Invalid Parameters)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| mirrorAxisZeroDirection | `OCCTMakeMirrorAxis` → `gp_Dir` ctor | Zero direction vector | Remove `try/catch` in bridge | ✅ SIGABRT | ✅ Pass | Uncaught `Standard_ConstructionError` |
| mirrorPlaneZeroNormal | `OCCTMakeMirrorPlane` → `gp_Dir` ctor | Zero normal vector | Remove `try/catch` in bridge | ✅ SIGABRT | ✅ Pass | Uncaught `Standard_ConstructionError` |
| geomDirectionZeroVector | `OCCTGeomDirectionCreate` → `Geom_Direction` ctor | Zero vector handled gracefully | N/A (no crash) | N/A | ✅ Pass | `Geom_Direction` returns NaN, no exception |

### #348: evalAndUpdateTolerance Null PCurve (Bridge Fix)

**Issue**: `OCCTBRepToolsEvalAndUpdateTol` calls `BRep_Tool::CurveOnSurface` which returns null pcurve on non-planar faces → `BRepTools::EvalAndUpdateTol` dereferences unconditionally → SIGSEGV.

**Bridge Fix**: Guard with `if (c3d.IsNull() || c2d.IsNull() || surf.IsNull()) return BRep_Tool::Tolerance(e);`

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| edgePairedWithUnrelatedCylindricalFaceDoesNotCrash | `OCCTBRepToolsEvalAndUpdateTol` → `BRep_Tool::CurveOnSurface` | Null pcurve on non-planar face | Remove null guard | ✅ SIGSEGV | ✅ Pass | SIGSEGV on cylindrical face |
| edgePairedWithAnUnrelatedPlanarFaceDoesNotCrash | `OCCTBRepToolsEvalAndUpdateTol` → `BRep_Tool::CurveOnPlane` | Null pcurve on planar face (OCCT 8.0.1+) | Remove null guard | ✅ SIGSEGV | ✅ Pass | SIGSEGV on planar face (OCCT 8.0.1+) |

**Finding**: Both tests confirmed SIGSEGV when null guard removed. The bridge fix correctly handles null pcurves on both non-planar (cylinder) and planar (OCCT 8.0.1+) faces by returning edge's own tolerance.

### #344: CDF_Directory Race (Stress: Concurrent Document Creation)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| parallelDocumentCreate | `OCCTDocumentCreate` → `CDF_Directory::Add` | Race on `myDocuments` list | Remove mutex in kernel patch `0012` |  |  | TSan race |

### #341: theAutoNaming Race (Stress: Concurrent Document Creation)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| parallelDocumentCreate | `OCCTDocumentCreate` → `XCAFApp_Application::GetApplication` | Race on `theAutoNaming` static bool | Revert to singleton / remove atomic |  |  | TSan race |

### #349/#353: OCAF/CDM Races (Document Assembly Chains)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| hundredShapesInDocument | `Document.addShape` → OCAF/CDM | Race on driver cache / metadata | Remove `ocafStoreMutex` / CDM mutex |  |  | TSan race |
| deepAssemblyTree | Document operations | Same | Same |  |  | |
| manyColorAssignments | Document operations | Same | Same |  |  | |

---

## Injection Matrix: Thread Safety Tests

### Stress: Concurrent Read-Only Queries

| Test | Bridge Function | Defect Category | Injection | Red? | Green? | Notes |
|------|-----------------|-----------------|-----------|------|--------|-------|
| parallelVolumeQuery | `Shape.volume` → `BRepGProp` | TS | Remove `OCCTSerial` lock |  |  | Data race |
| parallelAreaQuery | `Shape.surfaceArea` → `BRepGProp` | TS | Remove `OCCTSerial` lock |  |  | Data race |
| parallelBoundsQuery | `Shape.bounds` → `BRepBndLib` | TS | Remove `OCCTSerial` lock |  |  | Data race |
| parallelFaceCountQuery | `Shape.subShapeCount` → `TopExp` | TS | Remove `OCCTSerial` lock |  |  | Data race |
| parallelIsValidQuery | `Shape.isValid` → `BRepCheck` | TS | Remove `OCCTSerial` lock |  |  | Data race |

### Stress: Concurrent Curve/Surface Evaluation

| Test | Bridge Function | Defect Category | Injection | Red? | Green? | Notes |
|------|-----------------|-----------------|-----------|------|--------|-------|
| parallelCurve3DEval | `Curve3D.point(at:)` → `Geom_Curve::D0` | TS | Remove `OCCTSerial` lock |  |  | Data race |
| parallelCurve2DEval | `Curve2D.point(at:)` → `Geom2d_Curve::D0` | TS | Remove `OCCTSerial` lock |  |  | Data race |
| parallelSurfaceEval | `Surface.point(atU:v:)` → `Geom_Surface::D0` | TS | Remove `OCCTSerial` lock |  |  | Data race |

### Stress: Concurrent Shape Creation

| Test | Bridge Function | Defect Category | Injection | Red? | Green? | Notes |
|------|-----------------|-----------------|-----------|------|--------|-------|
| parallelBoxCreation | `Shape.box` → `BRepPrimAPI_MakeBox` | TS | Remove `OCCTSerial` lock |  |  | Data race |
| parallelBooleanOps | `Shape.union/subtracting` → `BRepAlgoAPI` | TS | Remove `OCCTSerial` lock |  |  | Data race |

---

## Injection Matrix: Degenerate Geometry Tests

### Stress: Zero-Dimension Shapes

| Test | Bridge Function | Defect Category | Injection | Red? | Green? | Notes |
|------|-----------------|-----------------|-----------|------|--------|-------|
| zeroBox | `Shape.box(width:0,height:0,depth:0)` | DG | Remove zero-dimension guard |  |  | Should return nil |
| zeroCylinder | `Shape.cylinder(radius:0,height:0)` | DG | Remove zero-dimension guard |  |  | Should return nil |
| zeroSphere | `Shape.sphere(radius:0)` | DG | Remove zero-dimension guard |  |  | Should return nil |
| zeroCone | `Shape.cone(bottom:0,top:0,height:0)` | DG | Remove zero-dimension guard |  |  | Should return nil |
| zeroTorus | `Shape.torus(major:0,minor:0)` | DG | Remove zero-dimension guard |  |  | Should return nil |
| zeroWidthBox | `Shape.box(width:10,height:10,depth:0)` | DG | Remove zero-dimension guard |  |  | Should return nil |
| queriesOnZeroBox | `Shape.box(0.001,0.001,0.001)` | DG | Remove queries on near-zero |  |  | Should handle gracefully |

### Stress: Empty Containers

| Test | Bridge Function | Defect Category | Injection | Red? | Green? | Notes |
|------|-----------------|-----------------|-----------|------|--------|-------|
| emptyWireBuilder | `WireBuilder().wire` | DG/CR | Remove empty check |  |  | Should not crash |
| thruSectionsNoSections | `ThruSectionsBuilder.build()` | DG/CR | Remove `< 2 sections` guard |  |  | Should SIGSEGV |
| sewingNothing | `SewingBuilder.perform()` | DG/CR | Remove empty check |  |  | Should not crash |
| sectionBuilderEmpty | `SectionBuilder().build()` | DG/CR | Remove empty check |  |  | Should not crash |
| cellsBuilderEmpty | `CellsBuilder(shapes:[])` | DG/CR | Remove empty check |  |  | Should not crash |
| emptyWireRectangle | `Wire.rectangle(1e-15,1e-15)` | DG | Remove tiny check |  |  | Should not crash |

---

## Injection Matrix: Format Round-Trip Tests

### Stress: Round-Trip STEP/BREP/STL/OBJ

| Test | Bridge Function | Defect Category | Injection | Red? | Green? | Notes |
|------|-----------------|-----------------|-----------|------|--------|-------|
| box/cylinder/sphere/... | `Exporter.writeSTEP/readSTEP` | IO | Corrupt temp file / remove cleanup |  |  | Should handle gracefully |
| Cross-Format Consistency | `writeSTEP` vs `writeBREP` | IO/WR | Write invalid shape |  |  | Should reject |

---

## Injection Matrix: Builder Lifecycle Tests

### Stress: FilletBuilder / ChamferBuilder / PipeShellBuilder / SewingBuilder / WireBuilder / HatchBuilder / UnifySameDomainBuilder / ThruSectionsBuilder / CellsBuilder / SectionBuilder / WireAnalyzer / WireFixer / FaceFixer / ShapeFixer

| Test Pattern | Bridge Function | Defect Category | Injection | Red? | Green? | Notes |
|--------------|-----------------|-----------------|-----------|------|--------|-------|
| buildEmpty | Builder init without inputs | DG/RL | Remove empty input guard |  |  | Should return nil/false |
| normalCycle | Full build cycle | WR | Inject invalid params |  |  | Should handle gracefully |
| destroyWithoutBuild/Perform | Deinit without build | RL | Remove deinit cleanup |  |  | Should leak / crash |
| invalidInput | Invalid parameters | DG | Remove validation |  |  | Should return nil |
| doubleBuild | Build twice | DG/RL | Remove state check |  |  | Should handle or return false |

---

## Injection Procedure Per Test

```bash
# 1. Focused compile (3s)
swift build --target OCCTStressTests

# 2. For each test:
#    a. Identify defect and bridge function
#    b. Create injection (remove guard, revert patch, remove try/catch, etc.)
#    c. Run single test: swift test --filter StressConcurrentReadTests
#    d. Confirm FAIL (red) - crash, SIGABRT, TSan race, or wrong result
#    e. Restore fix
#    f. Confirm PASS (green)
#    g. Record in matrix above

# 3. Create PR for OCCTStressTests
# 4. User reviews PR → merge what makes sense
# 5. Proceed to next domain (OCCTModelingTests)
```

---

## Key Bridge Functions to Inject

| Bridge Function | File | Tests Covered |
|-----------------|------|---------------|
| `OCCTShapeVolume` / `OCCTShapeSurfaceArea` | OCCTBridge_Modeling.mm | Concurrent Read-Only |
| `OCCTCurve3DPointAt` | OCCTBridge_Curve3D.mm | Concurrent Curve Eval |
| `OCCTShapeUnion` / `OCCTShapeSubtract` | OCCTBridge_Modeling.mm | Concurrent Booleans |
| `OCCTDocumentCreate` | OCCTBridge_Document.mm | Concurrent Document |
| `OCCTShapeFilleted` | OCCTBridge_Modeling.mm | Invalid Parameters |
| `OCCTTransformFactory3DMirrorAxis` | OCCTBridge_Spatial.mm | #345 gp_Dir |
| `OCCTShapeEvalAndUpdateTolerance` | OCCTBridge_Topology.mm | #348 Null PCurve |
| `OCCTUnifySameDomainBuilderBuild` | OCCTBridge_Healing.mm | #348 Null PCurve |
| `OCCTSerialLock` / `OCCTSerialWithLock` | OCCTBridge_Internal.h | All TS tests |

---

## Notes

- **Run each injection 3×** for flaky tests (especially TSan)
- **If kernel crash**: File upstream issue with reproducer, link to #766, don't fix in bridge
- **Mutation testing**: Run after manual injections; file #767 issues for gaps
- **Evidence format**: Markdown table per test (Test | Defect | Injection | Red? | Green? | Notes)
- **PR after domain complete**: Review before moving to OCCTModelingTests

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| Stress: Concurrent Read-Only Queries | 5 |  |  |  |  |
| Stress: Concurrent Curve Evaluation | 3 |  |  |  |  |
| Stress: Concurrent Shape Creation | 2 |  |  |  |  |
| Stress: Concurrent Document Creation | 1 |  |  |  |  |
| Stress: Sequential Determinism | 4 |  |  |  |  |
| Stress: Sendable Boundary Crossing | 5 |  |  |  |  |
| Stress: Nil Propagation | 7 |  |  |  |  |
| Stress: Zero-Dimension Shapes | 7 |  |  |  |  |
| Stress: Empty Containers | 6 |  |  |  |  |
| Stress: Invalid Parameters | 14 | 3 | 3 | 3 | ✅ |
| Stress: Post-Operation State | 5 |  |  |  |  |
| Stress: Unusual Input Combinations | 10 |  |  |  |  |
| Stress: UnifySameDomain Null PCurve | 1 | 1 | 1 | 1 | ✅ |
| Stress: evalAndUpdateTol Null PCurve | 2 | 2 | 2 | 2 | ✅ |
| Stress: Micro/Macro/Mixed Scale | 17 |  |  |  |  |
| Stress: Coincident Geometry | 8 |  |  |  |  |
| Stress: Degenerate Operations | 11 |  |  |  |  |
| Stress: Near-Degenerate Geometry | 7 |  |  |  |  |
| Stress: Curve/Surface Boundaries | 10 |  |  |  |  |
| Stress: Round-Trip STEP/BREP/STL/OBJ | 42 |  |  |  |  |
| Stress: Cross-Format Consistency | 3 |  |  |  |  |
| Stress: Boolean/Feature/Transform/Wire Chains | 16 |  |  |  |  |
| Stress: Document Assembly Chains | 3 |  |  |  |  |
| Stress: Curve Evaluation Depth | 3 |  |  |  |  |
| Stress: Shape Factories/Booleans/Features/Transforms | 30 |  |  |  |  |
| Stress: Shape Queries | 24 |  |  |  |  |
| Stress: Wire/Edge/Face API | 18 |  |  |  |  |
| Stress: Curve3D/2D/Surface API | 28 |  |  |  |  |
| Stress: Document API | 8 |  |  |  |  |
| Stress: Math/Mesh/Feature Recognition | 15 |  |  |  |  |
| Stress: Builder Lifecycles (8 builders) | 60 |  |  |  |  |

**Total**: 366 tests

## Epic #766 execution, measured: StressBuilderLifecycleTests: FilletBuilder, ChamferBuilder

Appended by the #1974 execution run (2026-09-24). Every row was run, not planned: Red is the failing expectation (or the crash) captured with the named defect injected behind an `OCCT766` environment switch in `Sources/`, Green is the same test passing with `Sources/` reverted and rebuilt. Parity is against `Scripts/repro/766-stress-builder-lifecycle/probe.mm` and its `transcript.txt`. The six records above committed in 96e7cf39 carry no run output and no probe, and are left for the orchestrator to remove.

| Suite | Test | Bridge function | Injection | Red | Green | Parity | Strengthened |
|---|---|---|---|---|---|---|---|
| Stress: FilletBuilder Lifecycle | `buildEmpty` | `OCCTFilletBuilderBuild` | OCCTFilletBuilderBuild: catch returns a wrapper of a null shape instead of nil | RED exit 1: StressBuilderLifecycleTests.swift:26 Expectation failed: result == nil | ✔ | MATCH | yes |
| Stress: FilletBuilder Lifecycle | `normalCycle` | `OCCTFilletBuilderAddEdge, OCCTFilletBuilderBuild, OCCTFilletBuilderNbContours` | EARLY:OCCTFilletBuilderBuild | RED exit 1: StressBuilderLifecycleTests.swift:35 Expectation failed: builder.build() | ✔ | MATCH | yes |
| Stress: FilletBuilder Lifecycle | `destroyWithoutBuild` | `OCCTFilletBuilderRelease` | CRASH:OCCTFilletBuilderRelease | CRASH exit 134: Abort trap: 6 | ✔ | N/A | no |
| Stress: FilletBuilder Lifecycle | `invalidInput` | `OCCTFilletBuilderBuild` | OCCTFilletBuilderBuild: catch returns a wrapper of a null shape instead of nil | RED exit 1: StressBuilderLifecycleTests.swift:65 Expectation failed: result == nil | ✔ | MATCH | yes |
| Stress: FilletBuilder Lifecycle | `doubleBuild` | `OCCTFilletBuilderBuild` | EARLY:OCCTFilletBuilderBuild | RED exit 1: StressBuilderLifecycleTests.swift:77 Expectation failed: builder.build() | ✔ | MATCH | yes |
| Stress: FilletBuilder Lifecycle | `queryContourDetails` | `OCCTFilletBuilderGetRadius, OCCTFilletBuilderGetLength, OCCTFilletBuilderIsConstant` | EARLY:OCCTFilletBuilderGetRadius | RED exit 1: StressBuilderLifecycleTests.swift:95 Expectation failed: builder.radius(contour: 1) == 1 | ✔ | MATCH | yes |
| Stress: ChamferBuilder Lifecycle | `buildEmpty` | `OCCTChamferBuilderBuild` | OCCTChamferBuilderBuild: catch returns a wrapper of a null shape instead of nil | RED exit 1: StressBuilderLifecycleTests.swift:114 Expectation failed: result == nil | ✔ | MATCH | yes |
| Stress: ChamferBuilder Lifecycle | `normalCycleSymmetric` | `OCCTChamferBuilderAddEdge, OCCTChamferBuilderBuild` | EARLY:OCCTChamferBuilderBuild | RED exit 1: StressBuilderLifecycleTests.swift:123 Expectation failed: builder.build() | ✔ | MATCH | yes |
| Stress: ChamferBuilder Lifecycle | `destroyWithoutBuild` | `OCCTChamferBuilderRelease` | CRASH:OCCTChamferBuilderRelease | CRASH exit 134: Abort trap: 6 | ✔ | N/A | no |
| Stress: ChamferBuilder Lifecycle | `invalidInput` | `OCCTChamferBuilderBuild` | OCCTChamferBuilderBuild: catch returns a wrapper of a null shape instead of nil | RED exit 1: StressBuilderLifecycleTests.swift:146 Expectation failed: result == nil | ✔ | MATCH | yes |
| Stress: ChamferBuilder Lifecycle | `doubleBuild` | `OCCTChamferBuilderBuild` | EARLY:OCCTChamferBuilderBuild | RED exit 1: StressBuilderLifecycleTests.swift:157 Expectation failed: builder.build() | ✔ | MATCH | yes |
| Stress: ChamferBuilder Lifecycle | `queryContourDetails` | `OCCTChamferBuilderIsSymmetric, OCCTChamferBuilderIsDistAngle, OCCTChamferBuilderIsTwoDists` | EARLY:OCCTChamferBuilderIsSymmetric | RED exit 1: StressBuilderLifecycleTests.swift:174 Expectation failed: builder.isSymmetric(contour: 1) | ✔ | MATCH | yes |
