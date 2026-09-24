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

## Epic #766 execution, measured: StressConcurrencyTests (all six suites)

Appended by the #1974 execution run (2026-09-24). Every row was run, not planned: Red is the failing expectation (or the crash) captured with the named defect injected behind an `OCCT766` environment switch in `Sources/`, Green is the same test passing with `Sources/` reverted and rebuilt. Parity is against `Scripts/repro/766-stress-concurrency/probe.mm` and its `transcript.txt`. The six records above committed in 96e7cf39 carry no run output and no probe, and are left for the orchestrator to remove.

| Suite | Test | Bridge function | Injection | Red | Green | Parity | Strengthened |
|---|---|---|---|---|---|---|---|
| Stress: Concurrent Read-Only Queries | `parallelVolumeQuery` | `OCCTShapeGetVolume` | OCCTShapeGetVolume reports Mass() × 1.5 | StressConcurrencyTests.swift:35 Expectation failed: abs(first - 1000.0) < 1e-9 | ✔ | MATCH | yes |
| Stress: Concurrent Read-Only Queries | `parallelAreaQuery` | `OCCTShapeGetSurfaceArea` | OCCTShapeGetSurfaceArea × 1.5 | StressConcurrencyTests.swift:52 Expectation failed: abs(first - 100.0 * .pi) < 1e-6 | ✔ | MATCH | yes |
| Stress: Concurrent Read-Only Queries | `parallelBoundsQuery` | `OCCTShapeGetBounds` | OCCTShapeGetBounds max.x + 100 | StressConcurrencyTests.swift:69 Expectation failed: abs(m.x - 5) < 1e-6 | ✔ | MATCH | yes |
| Stress: Concurrent Read-Only Queries | `parallelFaceCountQuery` | `OCCTShapeGetSubShapeCount` | OCCTShapeGetSubShapeCount + 1 | StressConcurrencyTests.swift:85 Expectation failed: c == 6 | ✔ | MATCH | no |
| Stress: Concurrent Read-Only Queries | `parallelIsValidQuery` | `OCCTShapeIsValid` | OCCTShapeIsValid always false | StressConcurrencyTests.swift:98 Expectation failed: r == true | ✔ | MATCH | no |
| Stress: Concurrent Curve Evaluation | `parallelCurve3DEval` | `OCCTCurve3DGetPoint` | OCCTCurve3DGetPoint: x coordinate set to NaN | StressConcurrencyTests.swift:120 Expectation failed: p.x.isFinite | ✔ | MATCH | no |
| Stress: Concurrent Curve Evaluation | `parallelCurve2DEval` | `OCCTCurve2DGetPoint` | OCCTCurve2DGetPoint x + 1 | StressConcurrencyTests.swift:137 Expectation failed: abs((p.x * p.x + p.y * p.y).squareRoot() - 5) < 1e-9 | ✔ | MATCH | yes |
| Stress: Concurrent Curve Evaluation | `parallelSurfaceEval` | `OCCTSurfaceGetPoint` | OCCTSurfaceGetPoint: x coordinate set to NaN | StressConcurrencyTests.swift:155 Expectation failed: p.x.isFinite | ✔ | MATCH | no |
| Stress: Concurrent Shape Creation | `parallelBoxCreation` | `OCCTShapeCreateBox` | OCCTShapeCreateBox returns nil | StressConcurrencyTests.swift:172 Expectation failed: shapes.count == 4 | ✔ | MATCH | no |
| Stress: Concurrent Shape Creation | `parallelBooleanOps` | `OCCTShapeUnionEx, OCCTShapeSubtractEx, OCCTShapeIntersectEx` | runBooleanEx returns nil after a successful build | StressConcurrencyTests.swift:189 Expectation failed: volumes.count == 3 | ✔ | MATCH | yes |
| Stress: Concurrent Document Creation (#344) | `parallelDocumentCreate` | `OCCTDocumentCreate` | OCCTDocumentCreate returns nil | StressConcurrencyTests.swift:217 Expectation failed: documents.count == 40 | ✔ | N/A | no |
| Stress: Sequential Determinism | `booleanDeterministic` | `OCCTShapeSubtractEx` | runBooleanEx returns nil after a successful build | StressConcurrencyTests.swift:236 Expectation failed: volumes.count == 10 | ✔ | MATCH | no |
| Stress: Sequential Determinism | `filletDeterministic` | `OCCTShapeFillet` | OCCTShapeFillet returns nil | StressConcurrencyTests.swift:252 Expectation failed: volumes.count == 10 | ✔ | MATCH | yes |
| Stress: Sequential Determinism | `meshDeterministic` | `OCCTShapeCreateMesh` | OCCTShapeCreateMesh returns nil | StressConcurrencyTests.swift:268 Expectation failed: vertexCounts.count == 10 | ✔ | MATCH | yes |
| Stress: Sequential Determinism | `volumeQueryDeterministic` | `OCCTShapeGetVolume` | OCCTShapeGetVolume reports Mass() × 1.5 | StressConcurrencyTests.swift:285 Expectation failed: abs(first - 2 * .pi * .pi * 10 * 9) < 1e-6 | ✔ | MATCH | yes |
| Stress: Sendable Boundary Crossing | `shapeAcrossTaskBoundary` | `OCCTShapeGetVolume` | OCCTShapeGetVolume reports Mass() × 1.5 | StressConcurrencyTests.swift:299 Expectation failed: abs(v - 1000.0) < 0.01 | ✔ | MATCH | no |
| Stress: Sendable Boundary Crossing | `curveAcrossTaskBoundary` | `OCCTCurve3DGetPoint` | OCCTCurve3DGetPoint: x coordinate set to NaN | StressConcurrencyTests.swift:307 Expectation failed: pt.x.isFinite | ✔ | MATCH | no |
| Stress: Sendable Boundary Crossing | `surfaceAcrossTaskBoundary` | `OCCTSurfaceGetPoint` | OCCTSurfaceGetPoint: x coordinate set to NaN | StressConcurrencyTests.swift:313 Expectation failed: pt.x.isFinite | ✔ | MATCH | no |
| Stress: Sendable Boundary Crossing | `documentAcrossTaskBoundary` | `OCCTDocumentGetShapeCount` | OCCTDocumentGetShapeCount - 1 | StressConcurrencyTests.swift:320 Expectation failed: count == 1 | ✔ | N/A | yes |
| Stress: Sendable Boundary Crossing | `wireAcrossTaskBoundary` | `OCCTWireGetLength` | OCCTWireGetLength × 1.5 | StressConcurrencyTests.swift:328 Expectation failed: abs(l - 40) < 1e-9 | ✔ | MATCH | yes |
## Epic #766 execution, measured: StressChainDepthTests (all six suites)
Appended by the #1974 execution run (2026-09-24). Every row was run, not planned: Red is the failing expectation (or the crash) captured with the named defect injected behind an `OCCT766` environment switch in `Sources/`, Green is the same test passing with `Sources/` reverted and rebuilt. Parity is against `Scripts/repro/766-stress-chain-depth/probe.mm` and its `transcript.txt`. The six records above committed in 96e7cf39 carry no run output and no probe, and are left for the orchestrator to remove.
| Stress: Boolean Chains | `fiftySubtractions` | `OCCTShapeSubtractEx, OCCTShapeTranslate` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressChainDepthTests.swift:28 Expectation failed: vol < origVol | ✔ | MATCH | yes |
| Stress: Boolean Chains | `hundredSubtractions` | `OCCTShapeSubtractEx, OCCTShapeTranslate` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressChainDepthTests.swift:50 Expectation failed: vol < origVol | ✔ | MATCH | yes |
| Stress: Boolean Chains | `fiftyUnions` | `OCCTShapeUnionEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressChainDepthTests.swift:69 Expectation failed: abs((shape.volume ?? 0) - 6359.375) < 1e-6 | ✔ | MATCH | yes |
| Stress: Boolean Chains | `fiftyIntersections` | `OCCTShapeIntersectEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressChainDepthTests.swift:85 Expectation failed: abs((shape.volume ?? 0) - 75.5 * 75.5 * 75.5) < 1e-4 | ✔ | MATCH | yes |
| Stress: Boolean Chains | `mixedBooleans` | `OCCTShapeUnionEx, OCCTShapeSubtractEx, OCCTShapeIntersectEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressChainDepthTests.swift:104 Expectation failed: shape.volume == nil | ✔ | MATCH | yes |
| Stress: Feature Chains | `filletDrillChamferChain` | `OCCTShapeFillet, OCCTShapeDrillHole, OCCTShapeChamfer, OCCTShapeShell` | OCCTShapeSubtract (the cut behind drilled) returns nil | StressChainDepthTests.swift:140 Expectation failed: abs((shape.volume ?? 0) - 30905.43876) < 1e-3 | ✔ | MATCH | yes |
| Stress: Feature Chains | `tenSuccessiveFillets` | `OCCTShapeFillet` | OCCTShapeFillet returns nil | StressChainDepthTests.swift:158 Expectation failed: succeeded == 1 | ✔ | MATCH | yes |
| Stress: Feature Chains | `tenDrillsGrid` | `OCCTShapeDrillHole` | OCCTShapeSubtract (the cut behind drilled) returns nil | StressChainDepthTests.swift:178 Expectation failed: abs((shape.volume ?? 0) - (1e5 - 400 * .pi)) < 1e-3 | ✔ | MATCH | yes |
| Stress: Feature Chains | `deepFeatureChain` | `OCCTShapeFillet, OCCTShapeDrillHole` | OCCTShapeFillet returns nil | StressChainDepthTests.swift:201 Expectation failed: stepCount == 20 | ✔ | MATCH | yes |
| Stress: Transform Chains | `thousandTranslations` | `OCCTShapeTranslate` | OCCTShapeTranslate moves by dx + 1 | StressChainDepthTests.swift:223 Expectation failed: abs(b.max.x - 6) < 1e-6 | ✔ | MATCH | yes |
| Stress: Transform Chains | `thousandRotations` | `OCCTShapeRotate` | OCCTShapeRotate turns by angle + 0.1 | StressChainDepthTests.swift:241 Expectation failed: abs(b.max.x - 5) < 1e-6 | ✔ | MATCH | yes |
| Stress: Transform Chains | `hundredScales` | `OCCTShapeScale` | OCCTShapeScale scales by factor × 1.1 | StressChainDepthTests.swift:256 Expectation failed: abs(vol - 1000.0) / 1000.0 < 0.1 | ✔ | MATCH | no |
| Stress: Transform Chains | `mixedTransforms` | `OCCTShapeTranslate, OCCTShapeRotate, OCCTShapeScale` | OCCTShapeScale scales by factor × 1.1 | StressChainDepthTests.swift:271 Expectation failed: abs((shape.volume ?? 0) - 1104.01168603) < 1e-6 | ✔ | MATCH | yes |
| Stress: Wire Construction Chains | `hundredEdgeWire` | `OCCTWireBuilderAddEdge, OCCTWireBuilderWire, OCCTWireBuilderIsDone` | OCCTWireBuilderAddEdge ignores its edge | RED exit 1: StressChainDepthTests.swift:290 Expectation failed: builder.isDone | ✔ | MATCH | yes |
| Stress: Wire Construction Chains | `largePolygonWire` | `OCCTWireCreateFastPolygon, OCCTWireGetLength` | OCCTWireGetLength × 1.5 | StressChainDepthTests.swift:304 Expectation failed: abs((w.length ?? 0) - 2000 * sin(.pi / 100)) < 1e-9 | ✔ | MATCH | yes |
| Stress: Wire Construction Chains | `manyPointInterpolation` | `OCCTCurve3DGetPoint` | OCCTCurve3DGetPoint: x coordinate set to NaN | StressChainDepthTests.swift:321 Expectation failed: pt.x.isFinite | ✔ | MATCH | no |
| Stress: Document Assembly Chains | `hundredShapesInDocument` | `OCCTDocumentCreate, OCCTDocumentGetShapeCount` | OCCTDocumentGetShapeCount - 1 | StressChainDepthTests.swift:341 Expectation failed: doc.shapeCount == 100 | ✔ | N/A | yes |
| Stress: Document Assembly Chains | `deepAssemblyTree` | `OCCTDocumentCreate, OCCTDocumentGetShapeCount` | OCCTDocumentGetShapeCount - 1 | StressChainDepthTests.swift:355 Expectation failed: doc.shapeCount == 6 | ✔ | N/A | yes |
| Stress: Document Assembly Chains | `manyColorAssignments` | `OCCTDocumentColorToolAddColor, OCCTDocumentColorToolGetColorCount` | OCCTDocumentColorToolGetColorCount - 1 | RED exit 1: StressChainDepthTests.swift:365 Expectation failed: doc.colorToolColorCount == 50 | ✔ | N/A | yes |
| Stress: Curve Evaluation Depth | `tenThousandPointEval` | `OCCTCurve3DGetPoint` | OCCTCurve3DGetPoint: x coordinate set to NaN | StressChainDepthTests.swift:380 Expectation failed: pt.x.isFinite | ✔ | MATCH | no |
| Stress: Curve Evaluation Depth | `surfaceGridEval10x10` | `OCCTSurfaceGetPoint` | OCCTSurfaceGetPoint: x coordinate set to NaN | StressChainDepthTests.swift:392 Expectation failed: pt.x.isFinite | ✔ | MATCH | no |
| Stress: Curve Evaluation Depth | `curve2DThousandPoints` | `OCCTCurve2DGetPoint` | OCCTCurve2DGetPoint: x coordinate set to NaN | StressChainDepthTests.swift:403 Expectation failed: pt.x.isFinite | ✔ | MATCH | no |
## Epic #766 execution, measured: StressBoundaryConditionTests: Micro, Macro and Mixed Scale
Appended by the #1974 execution run (2026-09-24). Every row was run, not planned: Red is the failing expectation (or the crash) captured with the named defect injected behind an `OCCT766` environment switch in `Sources/`, Green is the same test passing with `Sources/` reverted and rebuilt. Parity is against `Scripts/repro/766-stress-boundary/probe.mm` and its `transcript.txt`. The six records above committed in 96e7cf39 carry no run output and no probe, and are left for the orchestrator to remove.
| Stress: Micro Scale Geometry | `microBox1e6` | `OCCTShapeCreateBox, OCCTShapeGetVolume` | OCCTShapeGetVolume reports Mass() × 1.5 | StressBoundaryConditionTests.swift:27 Expectation failed: near(box.volume, 1e-18) | ✔ | MATCH | yes |
| Stress: Micro Scale Geometry | `microBox1e9` | `OCCTShapeCreateBox` | OCCTShapeCreateBox: catch returns a wrapper of a null shape instead of nil | StressBoundaryConditionTests.swift:32 Expectation failed: Shape.box(width: 1e-9, height: 1e-9, depth: 1e-9) == nil | ✔ | MATCH | yes |
| Stress: Micro Scale Geometry | `microCylinder` | `OCCTShapeCreateCylinder` | OCCTShapeGetVolume reports Mass() × 1.5 | StressBoundaryConditionTests.swift:38 Expectation failed: near(cyl.volume, .pi * 1e-18) | ✔ | MATCH | yes |
| Stress: Micro Scale Geometry | `microSphere` | `OCCTShapeCreateSphere` | OCCTShapeGetVolume reports Mass() × 1.5 | StressBoundaryConditionTests.swift:44 Expectation failed: near(sph.volume, 4.0 / 3.0 * .pi * 1e-18) | ✔ | MATCH | yes |
| Stress: Micro Scale Geometry | `microBoolean` | `OCCTShapeSubtractEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressBoundaryConditionTests.swift:52 Expectation failed: near(r.volume, 8.75e-13) | ✔ | MATCH | yes |
| Stress: Micro Scale Geometry | `microFillet` | `OCCTShapeFillet` | OCCTShapeFillet returns nil | StressBoundaryConditionTests.swift:58 Expectation failed: box.filleted(radius: 1e-4) | ✔ | MATCH | yes |
| Stress: Micro Scale Geometry | `microMesh` | `OCCTShapeCreateMesh` | OCCTShapeCreateMesh returns nil | StressBoundaryConditionTests.swift:65 Expectation failed: box.mesh(linearDeflection: 1e-5) | ✔ | MATCH | yes |
| Stress: Macro Scale Geometry | `macroBox1e6` | `OCCTShapeCreateBox, OCCTShapeGetVolume` | OCCTShapeGetVolume reports Mass() × 1.5 | StressBoundaryConditionTests.swift:78 Expectation failed: near(box.volume, 1e18) | ✔ | MATCH | yes |
| Stress: Macro Scale Geometry | `macroBox1e9` | `OCCTShapeCreateBox, OCCTShapeGetVolume` | OCCTShapeGetVolume reports Mass() × 1.5 | StressBoundaryConditionTests.swift:84 Expectation failed: near(box.volume, 1e27) | ✔ | MATCH | yes |
| Stress: Macro Scale Geometry | `macroCylinder` | `OCCTShapeCreateCylinder` | OCCTShapeGetVolume reports Mass() × 1.5 | StressBoundaryConditionTests.swift:90 Expectation failed: near(cyl.volume, .pi * 1e18) | ✔ | MATCH | yes |
| Stress: Macro Scale Geometry | `macroSphere` | `OCCTShapeCreateSphere` | OCCTShapeGetVolume reports Mass() × 1.5 | StressBoundaryConditionTests.swift:96 Expectation failed: near(sph.volume, 4.0 / 3.0 * .pi * 1e18) | ✔ | MATCH | yes |
| Stress: Macro Scale Geometry | `macroBoolean` | `OCCTShapeSubtractEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressBoundaryConditionTests.swift:104 Expectation failed: near(r.volume, 8.75e17) | ✔ | MATCH | yes |
| Stress: Macro Scale Geometry | `macroFillet` | `OCCTShapeFillet` | OCCTShapeFillet returns nil | StressBoundaryConditionTests.swift:109 Expectation failed: box.filleted(radius: 100) | ✔ | MATCH | yes |
| Stress: Mixed Scale Geometry | `largeBoxTinyHole` | `OCCTShapeDrillHole` | OCCTShapeSubtract returns its first argument unchanged | StressBoundaryConditionTests.swift:126 Expectation failed: abs((r.volume ?? 0) - 999999999.686) < 1e-3 | ✔ | MATCH | yes |
| Stress: Mixed Scale Geometry | `largeBoxMicroFillet` | `OCCTShapeFillet` | OCCTShapeFillet returns nil | StressBoundaryConditionTests.swift:132 Expectation failed: box.filleted(radius: 0.001) | ✔ | MATCH | yes |
| Stress: Mixed Scale Geometry | `tinyBoxLargeOffset` | `OCCTShapeTranslate, OCCTShapeGetBounds` | OCCTShapeTranslate moves by dx + 1 | StressBoundaryConditionTests.swift:146 Expectation failed: abs(bounds.max.x - 1000000.5) < 1e-6 | ✔ | MATCH | yes |
| Stress: Mixed Scale Geometry | `largeBoxSmallSubtract` | `OCCTShapeSubtractEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressBoundaryConditionTests.swift:159 Expectation failed: abs((r.volume ?? 0) - 999999.999) < 1e-6 | ✔ | MATCH | yes |
## Epic #766 execution, measured: StressBoundaryConditionTests: Coincident Geometry, Degenerate Operations
| Stress: Coincident Geometry | `identicalBoxUnion` | `OCCTShapeUnionEx` | runBooleanEx returns nil after a successful build | StressBoundaryConditionTests.swift:170 Expectation failed: b1.union(b2) | ✔ | MATCH | yes |
| Stress: Coincident Geometry | `identicalBoxSubtract` | `OCCTShapeSubtractEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressBoundaryConditionTests.swift:181 Expectation failed: r.subShapeCount(ofType: .face) == 0 | ✔ | MATCH | yes |
| Stress: Coincident Geometry | `identicalBoxIntersect` | `OCCTShapeIntersectEx` | runBooleanEx returns nil after a successful build | StressBoundaryConditionTests.swift:188 Expectation failed: b1.intersection(b2) | ✔ | MATCH | yes |
| Stress: Coincident Geometry | `touchingFaceUnion` | `OCCTShapeUnionEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressBoundaryConditionTests.swift:199 Expectation failed: abs((r.volume ?? 0) - 2000) < 1e-6 | ✔ | MATCH | yes |
| Stress: Coincident Geometry | `touchingFaceSubtract` | `OCCTShapeSubtractEx` | runBooleanEx returns nil after a successful build | StressBoundaryConditionTests.swift:206 Expectation failed: b1.subtracting(b2) | ✔ | MATCH | yes |
| Stress: Coincident Geometry | `overlappingBoxes` | `OCCTShapeUnionEx, OCCTShapeSubtractEx, OCCTShapeIntersectEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressBoundaryConditionTests.swift:222 Expectation failed: abs((uni?.volume ?? 0) - 2000) < 1e-6 | ✔ | MATCH | yes |
| Stress: Coincident Geometry | `nestedSpheres` | `OCCTShapeSubtractEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressBoundaryConditionTests.swift:235 Expectation failed: abs((r.volume ?? 0) - expected) < 1e-6 | ✔ | MATCH | yes |
| Stress: Coincident Geometry | `concentricCylinders` | `OCCTShapeSubtractEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressBoundaryConditionTests.swift:243 Expectation failed: abs((t.volume ?? 0) - .pi * 75 * 20) < 1e-6 | ✔ | MATCH | yes |
| Stress: Degenerate Operations | `filletRadiusEqualsHalfEdge` | `OCCTShapeFillet` | OCCTShapeFillet returns the input unchanged when not done or on a throw | StressBoundaryConditionTests.swift:256 Expectation failed: box.filleted(radius: 5.0) == nil | ✔ | MATCH | yes |
| Stress: Degenerate Operations | `filletRadiusExceedsEdge` | `OCCTShapeFillet` | OCCTShapeFillet returns nil | StressBoundaryConditionTests.swift:263 Expectation failed: box.filleted(radius: 6.0) | ✔ | MATCH | yes |
| Stress: Degenerate Operations | `shellThicknessEqualsHalf` | `OCCTShapeShell` | OCCTShapeShell returns the input unchanged when not done or on a throw | StressBoundaryConditionTests.swift:271 Expectation failed: box.shelled(thickness: -5.0) == nil | ✔ | MATCH | yes |
| Stress: Degenerate Operations | `shellThicknessExceedsHalf` | `OCCTShapeShell` | OCCTShapeShell returns the input unchanged when not done or on a throw | StressBoundaryConditionTests.swift:276 Expectation failed: box.shelled(thickness: -6.0) == nil | ✔ | MATCH | yes |
| Stress: Degenerate Operations | `offsetByZero` | `OCCTShapeTranslate` | OCCTShapeTranslate returns nil | StressBoundaryConditionTests.swift:284 Expectation failed: box.translated(by: SIMD3(0, 0, 0)) | ✔ | MATCH | yes |
| Stress: Degenerate Operations | `rotateByTwoPi` | `OCCTShapeRotate, OCCTShapeGetBounds` | OCCTShapeRotate turns by angle + 0.1 | StressBoundaryConditionTests.swift:296 Expectation failed: abs(b.max.x - 5) < 1e-6 | ✔ | MATCH | yes |
| Stress: Degenerate Operations | `rotateByLargeAngle` | `OCCTShapeRotate, OCCTShapeGetBounds` | OCCTShapeRotate turns by angle + 0.1 | StressBoundaryConditionTests.swift:306 Expectation failed: abs(b.max.x - 5) < 1e-6 | ✔ | MATCH | yes |
| Stress: Degenerate Operations | `scaleByVerySmall` | `OCCTShapeScale` | OCCTShapeScale scales by factor × 1.1 | StressBoundaryConditionTests.swift:314 Expectation failed: near(r.volume, 1e-27) | ✔ | MATCH | yes |
| Stress: Degenerate Operations | `scaleByVeryLarge` | `OCCTShapeScale` | OCCTShapeScale scales by factor × 1.1 | StressBoundaryConditionTests.swift:321 Expectation failed: near(r.volume, 1e33) | ✔ | MATCH | yes |
| Stress: Degenerate Operations | `drillRadiusLargerThanBox` | `OCCTShapeDrillHole` | OCCTShapeSubtract returns its first argument unchanged | StressBoundaryConditionTests.swift:331 Expectation failed: r.subShapeCount(ofType: .face) == 0 | ✔ | MATCH | yes |
| Stress: Degenerate Operations | `drillOutsideBox` | `OCCTShapeDrillHole` | OCCTShapeDrillHole returns nil | StressBoundaryConditionTests.swift:340 Expectation failed: result | ✔ | MATCH | yes |
## Epic #766 execution, measured: StressBoundaryConditionTests: Near-Degenerate Geometry, Curve and Surface Boundaries
| Stress: Near-Degenerate Geometry | `veryThinBox` | `OCCTShapeCreateBox, OCCTShapeGetVolume` | OCCTShapeGetVolume reports Mass() × 1.5 | StressBoundaryConditionTests.swift:352 Expectation failed: near(thin.volume, 10) | ✔ | MATCH | yes |
| Stress: Near-Degenerate Geometry | `verySmallFillet` | `OCCTShapeFillet` | OCCTShapeFillet returns nil | StressBoundaryConditionTests.swift:357 Expectation failed: box.filleted(radius: 1e-5) | ✔ | MATCH | yes |
| Stress: Near-Degenerate Geometry | `verySmallChamfer` | `OCCTShapeChamfer` | OCCTShapeChamfer returns nil | StressBoundaryConditionTests.swift:365 Expectation failed: box.chamfered(distance: 1e-5) | ✔ | MATCH | yes |
| Stress: Near-Degenerate Geometry | `nearlyTouchingBoxes` | `OCCTShapeUnionEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressBoundaryConditionTests.swift:378 Expectation failed: abs((r.volume ?? 0) - 2000) < 1e-6 | ✔ | MATCH | yes |
| Stress: Near-Degenerate Geometry | `nearlyCoincidentSubtract` | `OCCTShapeSubtractEx` | runBooleanEx returns its first argument unchanged (a no-op boolean) | StressBoundaryConditionTests.swift:390 Expectation failed: abs((r.volume ?? 0) - 875.00000075) < 1e-6 | ✔ | MATCH | yes |
| Stress: Near-Degenerate Geometry | `veryThinShell` | `OCCTShapeShell` | OCCTShapeShell returns the input unchanged when not done or on a throw | StressBoundaryConditionTests.swift:397 Expectation failed: box.shelled(thickness: -0.001) == nil | ✔ | MATCH | yes |
| Stress: Near-Degenerate Geometry | `verySmallDrill` | `OCCTShapeDrillHole` | OCCTShapeSubtract returns its first argument unchanged | StressBoundaryConditionTests.swift:406 Expectation failed: r.subShapeCount(ofType: .face) == 7 | ✔ | MATCH | yes |
| Stress: Curve and Surface Boundaries | `curveEvalAtDomainBounds` | `OCCTCurve3DGetPoint` | OCCTCurve3DGetPoint: x coordinate set to NaN | StressBoundaryConditionTests.swift:421 Expectation failed: p1.x.isFinite | ✔ | MATCH | no |
| Stress: Curve and Surface Boundaries | `curveEvalSlightlyOutside` | `OCCTCurve3DGetPoint` | OCCTCurve3DGetPoint clamps u into [First, Last] | StressBoundaryConditionTests.swift:432 Expectation failed: abs(p1.x - 4.9999975000002088) < 1e-12 | ✔ | MATCH | yes |
| Stress: Curve and Surface Boundaries | `surfaceEvalAtDomainCorners` | `OCCTSurfaceGetPoint` | OCCTSurfaceGetPoint: x coordinate set to NaN | StressBoundaryConditionTests.swift:445 Expectation failed: p1.x.isFinite | ✔ | MATCH | no |
| Stress: Curve and Surface Boundaries | `curve2DEvalAtDomainBounds` | `OCCTCurve2DGetPoint` | OCCTCurve2DGetPoint: x coordinate set to NaN | StressBoundaryConditionTests.swift:456 Expectation failed: p1.x.isFinite | ✔ | MATCH | no |
| Stress: Curve and Surface Boundaries | `bezierSurfaceEvalGrid` | `OCCTSurfaceGetPoint` | OCCTSurfaceGetPoint: x coordinate set to NaN | StressBoundaryConditionTests.swift:469 Expectation failed: pt.x.isFinite | ✔ | MATCH | no |
| Stress: Curve and Surface Boundaries | `curveCurvatureAtBounds` | `OCCTCurve3DGetCurvature` | OCCTCurve3DGetCurvature × 1.5 | StressBoundaryConditionTests.swift:483 Expectation failed: abs((k1 ?? 0) - 0.0674635578751) < 1e-9 | ✔ | MATCH | yes |
| Stress: Curve and Surface Boundaries | `surfaceCurvatureAtBounds` | `OCCTSurfaceGetGaussianCurvature, OCCTSurfaceGetMeanCurvature` | OCCTSurfaceGetGaussianCurvature + 0.01 | StressBoundaryConditionTests.swift:495 Expectation failed: abs((g ?? 0) - -0.0064) < 1e-9 | ✔ | MATCH | yes |
| Stress: Curve and Surface Boundaries | `periodicCurveAtPeriodBoundary` | `OCCTCurve3DGetPoint` | OCCTCurve3DGetPoint: x coordinate set to NaN | StressBoundaryConditionTests.swift:508 Expectation failed: dist < 0.01 | ✔ | MATCH | no |
## Epic #766 execution, measured: StressFormatRoundTripTests: STEP, BREP and BREP-string round trips
Appended by the #1974 execution run (2026-09-24). Every row was run, not planned: Red is the failing expectation (or the crash) captured with the named defect injected behind an `OCCT766` environment switch in `Sources/`, Green is the same test passing with `Sources/` reverted and rebuilt. Parity is against `Scripts/repro/766-stress-format-round-trip/probe.mm` and its `transcript.txt`. The six records above committed in 96e7cf39 carry no run output and no probe, and are left for the orchestrator to remove.
| Stress: Round-Trip STEP | `box` | `OCCTExportSTEPWithMode, OCCTImportSTEPProgress` | OCCTImportSTEPProgress: import returns only the first face | StressFormatRoundTripTests.swift:31 Expectation failed: abs(rArea - origArea) / origArea < 0.01 | ✔ | MATCH | no |
| Stress: Round-Trip STEP | `cylinder` | `OCCTExportSTEPWithMode, OCCTImportSTEPProgress` | OCCTImportSTEPProgress: import returns only the first face | StressFormatRoundTripTests.swift:31 Expectation failed: abs(rArea - origArea) / origArea < 0.01 | ✔ | MATCH | no |
| Stress: Round-Trip STEP | `sphere` | `OCCTExportSTEPWithMode, OCCTImportSTEPProgress` | OCCTImportSTEPProgress returns nil | StressFormatRoundTripTests.swift:44 Caught error: .readFailed(path: "/var/folders/qg/vl7hjxld1dj2z8lvcrjp_klm0000gn/T/occt-stress-0749DAF... | ✔ | MATCH | no |
| Stress: Round-Trip STEP | `cone` | `OCCTExportSTEPWithMode, OCCTImportSTEPProgress` | OCCTImportSTEPProgress: import returns only the first face | StressFormatRoundTripTests.swift:31 Expectation failed: abs(rArea - origArea) / origArea < 0.01 | ✔ | MATCH | no |
| Stress: Round-Trip STEP | `torus` | `OCCTExportSTEPWithMode, OCCTImportSTEPProgress` | OCCTImportSTEPProgress returns nil | StressFormatRoundTripTests.swift:46 Caught error: .readFailed(path: "/var/folders/qg/vl7hjxld1dj2z8lvcrjp_klm0000gn/T/occt-stress-120CA9A... | ✔ | MATCH | no |
| Stress: Round-Trip STEP | `filletedBoxShape` | `OCCTExportSTEPWithMode, OCCTImportSTEPProgress` | OCCTImportSTEPProgress: import returns only the first face | StressFormatRoundTripTests.swift:31 Expectation failed: abs(rArea - origArea) / origArea < 0.01 | ✔ | MATCH | no |
| Stress: Round-Trip STEP | `drilledPlateShape` | `OCCTExportSTEPWithMode, OCCTImportSTEPProgress` | OCCTImportSTEPProgress: import returns only the first face | StressFormatRoundTripTests.swift:31 Expectation failed: abs(rArea - origArea) / origArea < 0.01 | ✔ | MATCH | no |
| Stress: Round-Trip STEP | `compound` | `OCCTExportSTEPWithMode, OCCTImportSTEPProgress` | OCCTImportSTEPProgress: import returns only the first face | StressFormatRoundTripTests.swift:31 Expectation failed: abs(rArea - origArea) / origArea < 0.01 | ✔ | MATCH | no |
| Stress: Round-Trip BREP | `box` | `OCCTExportBREPWithTriangles, OCCTImportBREP` | OCCTImportBREP: import returns only the first face | StressFormatRoundTripTests.swift:71 Expectation failed: reimported.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
| Stress: Round-Trip BREP | `cylinder` | `OCCTExportBREPWithTriangles, OCCTImportBREP` | OCCTImportBREP: import returns only the first face | StressFormatRoundTripTests.swift:71 Expectation failed: reimported.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
| Stress: Round-Trip BREP | `sphere` | `OCCTExportBREPWithTriangles, OCCTImportBREP` | OCCTImportBREP returns nil | StressFormatRoundTripTests.swift:77 Caught error: .importFailed("Failed to import BREP file: occt-stress-8A001FFA-DA3F-41F5-B73F-E6FA50F0... | ✔ | MATCH | no |
| Stress: Round-Trip BREP | `cone` | `OCCTExportBREPWithTriangles, OCCTImportBREP` | OCCTImportBREP: import returns only the first face | StressFormatRoundTripTests.swift:71 Expectation failed: reimported.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
| Stress: Round-Trip BREP | `torus` | `OCCTExportBREPWithTriangles, OCCTImportBREP` | OCCTImportBREP returns nil | StressFormatRoundTripTests.swift:79 Caught error: .importFailed("Failed to import BREP file: occt-stress-E9215F4D-9D15-4AED-AF35-EF113708... | ✔ | MATCH | no |
| Stress: Round-Trip BREP | `filletedBoxShape` | `OCCTExportBREPWithTriangles, OCCTImportBREP` | OCCTImportBREP: import returns only the first face | StressFormatRoundTripTests.swift:71 Expectation failed: reimported.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
| Stress: Round-Trip BREP | `drilledPlateShape` | `OCCTExportBREPWithTriangles, OCCTImportBREP` | OCCTImportBREP: import returns only the first face | StressFormatRoundTripTests.swift:71 Expectation failed: reimported.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
| Stress: Round-Trip BREP | `compound` | `OCCTExportBREPWithTriangles, OCCTImportBREP` | OCCTImportBREP: import returns only the first face | StressFormatRoundTripTests.swift:71 Expectation failed: reimported.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
| Stress: Round-Trip BREP String | `box` | `OCCTShapeToBREPString, OCCTShapeFromBREPString` | OCCTShapeFromBREPString: import returns only the first face | StressFormatRoundTripTests.swift:108 Expectation failed: restored.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
| Stress: Round-Trip BREP String | `cylinder` | `OCCTShapeToBREPString, OCCTShapeFromBREPString` | OCCTShapeFromBREPString: import returns only the first face | StressFormatRoundTripTests.swift:108 Expectation failed: restored.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
| Stress: Round-Trip BREP String | `sphere` | `OCCTShapeToBREPString, OCCTShapeFromBREPString` | OCCTShapeFromBREPString returns nil | StressFormatRoundTripTests.swift:101 Expectation failed: Bool(false) | ✔ | MATCH | no |
| Stress: Round-Trip BREP String | `cone` | `OCCTShapeToBREPString, OCCTShapeFromBREPString` | OCCTShapeFromBREPString: import returns only the first face | StressFormatRoundTripTests.swift:108 Expectation failed: restored.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
| Stress: Round-Trip BREP String | `torus` | `OCCTShapeToBREPString, OCCTShapeFromBREPString` | OCCTShapeFromBREPString returns nil | StressFormatRoundTripTests.swift:101 Expectation failed: Bool(false) | ✔ | MATCH | no |
| Stress: Round-Trip BREP String | `filletedBoxShape` | `OCCTShapeToBREPString, OCCTShapeFromBREPString` | OCCTShapeFromBREPString: import returns only the first face | StressFormatRoundTripTests.swift:108 Expectation failed: restored.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
| Stress: Round-Trip BREP String | `drilledPlateShape` | `OCCTShapeToBREPString, OCCTShapeFromBREPString` | OCCTShapeFromBREPString: import returns only the first face | StressFormatRoundTripTests.swift:108 Expectation failed: restored.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
| Stress: Round-Trip BREP String | `compound` | `OCCTShapeToBREPString, OCCTShapeFromBREPString` | OCCTShapeFromBREPString: import returns only the first face | StressFormatRoundTripTests.swift:108 Expectation failed: restored.subShapeCount(ofType: .face) == origFaces | ✔ | MATCH | no |
## Epic #766 execution, measured: StressFormatRoundTripTests: STL, OBJ, IGES round trips, Cross-Format Consistency
| Stress: Round-Trip STL | `box` | `OCCTExportSTLWithMode, OCCTImportSTL` | OCCTImportSTL returns nil | StressFormatRoundTripTests.swift:144 Caught error: .importFailed("Failed to import STL file: occt-stress-12EECDD7-AEEB-47C0-A4D2-1731518C... | ✔ | MATCH | no |
| Stress: Round-Trip STL | `cylinder` | `OCCTExportSTLWithMode, OCCTImportSTL` | OCCTImportSTL returns nil | StressFormatRoundTripTests.swift:145 Caught error: .importFailed("Failed to import STL file: occt-stress-9AA60B35-0025-4B8B-A610-8F9CCC15... | ✔ | MATCH | no |
| Stress: Round-Trip STL | `sphere` | `OCCTExportSTLWithMode, OCCTImportSTL` | OCCTImportSTL returns nil | StressFormatRoundTripTests.swift:146 Caught error: .importFailed("Failed to import STL file: occt-stress-3C2D71B4-5345-4D7F-88F4-98584774... | ✔ | MATCH | no |
| Stress: Round-Trip STL | `cone` | `OCCTExportSTLWithMode, OCCTImportSTL` | OCCTImportSTL returns nil | StressFormatRoundTripTests.swift:147 Caught error: .importFailed("Failed to import STL file: occt-stress-62804DF2-B0EF-4BF2-B632-6C202B02... | ✔ | MATCH | no |
| Stress: Round-Trip STL | `torus` | `OCCTExportSTLWithMode, OCCTImportSTL` | OCCTImportSTL returns nil | StressFormatRoundTripTests.swift:148 Caught error: .importFailed("Failed to import STL file: occt-stress-C3B660CB-EDF7-42B5-8019-604FB6F0... | ✔ | MATCH | no |
| Stress: Round-Trip STL | `filletedBoxShape` | `OCCTExportSTLWithMode, OCCTImportSTL` | OCCTImportSTL returns nil | StressFormatRoundTripTests.swift:149 Caught error: .importFailed("Failed to import STL file: occt-stress-CD30EE27-230D-4116-BB62-6DE1F873... | ✔ | MATCH | no |
| Stress: Round-Trip OBJ | `box` | `OCCTExportOBJ, OCCTImportOBJ` | OCCTImportOBJ returns nil | StressFormatRoundTripTests.swift:175 Caught error: .importFailed("Failed to import OBJ file: occt-stress-1B7092A0-1AF1-4049-8A6C-2131B56A... | ✔ | MATCH | yes |
| Stress: Round-Trip OBJ | `cylinder` | `OCCTExportOBJ, OCCTImportOBJ` | OCCTImportOBJ returns nil | StressFormatRoundTripTests.swift:178 Caught error: .importFailed("Failed to import OBJ file: occt-stress-B1EC3B1D-6653-4721-BF00-97356118... | ✔ | MATCH | yes |
| Stress: Round-Trip OBJ | `sphere` | `OCCTExportOBJ, OCCTImportOBJ` | OCCTImportOBJ returns nil | StressFormatRoundTripTests.swift:181 Caught error: .importFailed("Failed to import OBJ file: occt-stress-07C5D802-5BE0-46F0-BEE9-34BDE9E2... | ✔ | MATCH | yes |
| Stress: Round-Trip OBJ | `filletedBoxShape` | `OCCTExportOBJ, OCCTImportOBJ` | OCCTImportOBJ returns nil | StressFormatRoundTripTests.swift:184 Caught error: .importFailed("Failed to import OBJ file: occt-stress-7A077629-A41A-46A0-A4A9-D74C9D44... | ✔ | MATCH | yes |
| Stress: Round-Trip IGES | `box` | `OCCTExportIGES, OCCTImportIGESProgress` | OCCTExportIGES returns false | StressFormatRoundTripTests.swift:211 Caught error: .exportFailed("IGES export to occt-stress-F290632F-1B46-47CF-A05E-E541AF2FA898.iges fa... | ✔ | MATCH | yes |
| Stress: Round-Trip IGES | `cylinder` | `OCCTExportIGES, OCCTImportIGESProgress` | OCCTExportIGES returns false | StressFormatRoundTripTests.swift:212 Caught error: .exportFailed("IGES export to occt-stress-0D69672B-8C65-4EB1-B2EB-70E2479A4009.iges fa... | ✔ | MATCH | yes |
| Stress: Round-Trip IGES | `sphere` | `OCCTExportIGES, OCCTImportIGESProgress` | OCCTExportIGES returns false | StressFormatRoundTripTests.swift:213 Caught error: .exportFailed("IGES export to occt-stress-FEC2DEA2-6D6A-4E96-A788-845324514659.iges fa... | ✔ | MATCH | yes |
| Stress: Round-Trip IGES | `cone` | `OCCTExportIGES, OCCTImportIGESProgress` | OCCTExportIGES returns false | StressFormatRoundTripTests.swift:214 Caught error: .exportFailed("IGES export to occt-stress-443669D8-2EC5-4AFF-BAC8-21516D8F74E8.iges fa... | ✔ | MATCH | yes |
| Stress: Round-Trip IGES | `torus` | `OCCTExportIGES, OCCTImportIGESProgress` | OCCTExportIGES returns false | StressFormatRoundTripTests.swift:215 Caught error: .exportFailed("IGES export to occt-stress-A8980DFD-812A-41CB-BD13-E71A83707583.iges fa... | ✔ | MATCH | yes |
| Stress: Cross-Format Consistency | `boxAllBRepFormats` | `OCCTExportSTEPWithMode, OCCTExportBREPWithTriangles, OCCTExportIGES, OCCTImportIGESProgress` | OCCTImportBREP: import returns only the first face | StressFormatRoundTripTests.swift:259 Expectation failed: abs(vBREP - origVol) / origVol < 0.001 | ✔ | MATCH | no |
| Stress: Cross-Format Consistency | `cylinderSTEPvsBREP` | `OCCTExportSTEPWithMode, OCCTImportSTEPProgress, OCCTImportBREP` | OCCTImportSTEPProgress: import returns only the first face | StressFormatRoundTripTests.swift:283 Expectation failed: abs(vSTEP - origVol) / origVol < 0.01 | ✔ | MATCH | no |
| Stress: Cross-Format Consistency | `allShapesBREPString` | `OCCTShapeToBREPString, OCCTShapeFromBREPString` | OCCTShapeFromBREPString returns nil | StressFormatRoundTripTests.swift:293 Expectation failed: Bool(false) | ✔ | MATCH | no |
## Epic #766 execution, measured: StressExhaustiveAPITests: Shape Factories, Shape Booleans
Appended by the #1974 execution run (2026-09-24). Every row was run, not planned: Red is the failing expectation (or the crash) captured with the named defect injected behind an `OCCT766` environment switch in `Sources/`, Green is the same test passing with `Sources/` reverted and rebuilt. Parity is against `Scripts/repro/766-stress-exhaustive-api/probe.mm` and its `transcript.txt`. The six records above committed in 96e7cf39 carry no run output and no probe, and are left for the orchestrator to remove.
| Stress: Shape Factories | `box` | `OCCTShapeCreateBox` | OCCTShapeCreateBox returns nil | RED exit 1: StressExhaustiveAPITests.swift:19 Expectation failed: Shape.box(width: 10, height: 20, depth: 30) != nil | ✔ | MATCH | no |
| Stress: Shape Factories | `boxWithOrigin` | `OCCTShapeCreateBoxAt` | OCCTShapeCreateBoxAt returns nil | RED exit 1: StressExhaustiveAPITests.swift:21 Expectation failed: Shape.box(origin: SIMD3<Double>(1, 2, 3), width: 10, height: 20, depth:... | ✔ | MATCH | no |
| Stress: Shape Factories | `cylinder` | `OCCTShapeCreateCylinder` | OCCTShapeCreateCylinder returns nil | RED exit 1: StressExhaustiveAPITests.swift:23 Expectation failed: Shape.cylinder(radius: 5, height: 10) != nil | ✔ | MATCH | no |
| Stress: Shape Factories | `cylinderAtPosition` | `OCCTShapeCreateCylinderAt` | EARLY:OCCTShapeCreateCylinderAt | RED exit 1: StressExhaustiveAPITests.swift:25 Expectation failed: Shape.cylinder(at: SIMD2(0, 0), bottomZ: 0, radius: 5, height: 10) != nil | ✔ | MATCH | no |
| Stress: Shape Factories | `sphere` | `OCCTShapeCreateSphere` | OCCTShapeCreateSphere returns nil | RED exit 1: StressExhaustiveAPITests.swift:27 Expectation failed: Shape.sphere(radius: 5) != nil | ✔ | MATCH | no |
| Stress: Shape Factories | `cone` | `OCCTShapeCreateCone` | OCCTShapeCreateCone returns nil | RED exit 1: StressExhaustiveAPITests.swift:28 Expectation failed: Shape.cone(bottomRadius: 5, topRadius: 2, height: 10) != nil | ✔ | MATCH | no |
| Stress: Shape Factories | `torus` | `OCCTShapeCreateTorus` | OCCTShapeCreateTorus returns nil | RED exit 1: StressExhaustiveAPITests.swift:29 Expectation failed: Shape.torus(majorRadius: 10, minorRadius: 3) != nil | ✔ | MATCH | no |
| Stress: Shape Factories | `wedge` | `OCCTShapeCreateWedge` | EARLY:OCCTShapeCreateWedge | RED exit 1: StressExhaustiveAPITests.swift:30 Expectation failed: Shape.wedge(dx: 10, dy: 10, dz: 10, ltx: 5) != nil | ✔ | MATCH | no |
| Stress: Shape Factories | `fromWire` | `OCCTShapeFromWire` | EARLY:OCCTShapeFromWire | RED exit 1: StressExhaustiveAPITests.swift:35 Expectation failed: shape != nil | ✔ | MATCH | no |
| Stress: Shape Factories | `face` | `OCCTShapeCreateFaceFromWire` | EARLY:OCCTShapeCreateFaceFromWire | RED exit 1: StressExhaustiveAPITests.swift:41 Expectation failed: face != nil | ✔ | MATCH | no |
| Stress: Shape Factories | `extrude` | `OCCTShapeCreateExtrusion` | EARLY:OCCTShapeCreateExtrusion | RED exit 1: StressExhaustiveAPITests.swift:46 Expectation failed: Shape.extrude(profile: wire, direction: SIMD3(0, 0, 1), length: 10) | ✔ | MATCH | yes |
| Stress: Shape Factories | `revolve` | `OCCTShapeCreateRevolution` | EARLY:OCCTShapeCreateRevolution | RED exit 1: StressExhaustiveAPITests.swift:55 Expectation failed: Shape.revolve(profile: wire, axisOrigin: .zero, axisDirection: SIMD3(0,... | ✔ | MATCH | yes |
| Stress: Shape Booleans | `union` | `OCCTShapeUnionEx` | runBooleanEx returns nil after a successful build | RED exit 1: StressExhaustiveAPITests.swift:72 Expectation failed: standardBox().union(standardSphere()) | ✔ | MATCH | yes |
| Stress: Shape Booleans | `subtract` | `OCCTShapeSubtractEx` | runBooleanEx returns nil after a successful build | RED exit 1: StressExhaustiveAPITests.swift:78 Expectation failed: standardBox().subtracting(standardSphere()) | ✔ | MATCH | yes |
| Stress: Shape Booleans | `intersect` | `OCCTShapeIntersectEx` | runBooleanEx returns nil after a successful build | RED exit 1: StressExhaustiveAPITests.swift:84 Expectation failed: standardBox().intersection(standardSphere()) | ✔ | MATCH | yes |
| Stress: Shape Booleans | `section` | `OCCTShapeSection` | EARLY:OCCTShapeSection | RED exit 1: StressExhaustiveAPITests.swift:91 Expectation failed: standardBox().section(standardSphere()) | ✔ | MATCH | yes |
| Stress: Shape Booleans | `split` | `OCCTShapeSplit` | EARLY:OCCTShapeSplit | RED exit 1: StressExhaustiveAPITests.swift:98 Expectation failed: standardBox().split(by: standardSphere()) | ✔ | MATCH | yes |
| Stress: Shape Booleans | `splitAtPlane` | `OCCTShapeSplitByPlane` | EARLY:OCCTShapeSplitByPlane | RED exit 1: StressExhaustiveAPITests.swift:109 Expectation failed: standardBox().split(atPlane: .zero, normal: SIMD3(0, 0, 1)) | ✔ | MATCH | yes |
## Epic #766 execution, measured: StressExhaustiveAPITests: Shape Queries
| Stress: Shape Queries | `isValid` | `OCCTShapeIsValid` | OCCTShapeIsValid always false | RED exit 1: StressExhaustiveAPITests.swift:177 Expectation failed: standardBox().isValid | ✔ | MATCH | no |
| Stress: Shape Queries | `volume` | `OCCTShapeGetVolume` | OCCTShapeGetVolume reports Mass() × 1.5 | RED exit 1: StressExhaustiveAPITests.swift:178 Expectation failed: abs((standardBox().volume ?? 0) - 1000) < 1e-9 | ✔ | MATCH | yes |
| Stress: Shape Queries | `surfaceArea` | `OCCTShapeGetSurfaceArea` | OCCTShapeGetSurfaceArea × 1.5 | RED exit 1: StressExhaustiveAPITests.swift:179 Expectation failed: abs((standardBox().surfaceArea ?? 0) - 600) < 1e-9 | ✔ | MATCH | yes |
| Stress: Shape Queries | `bounds` | `OCCTShapeGetBounds` | OCCTShapeGetBounds max.x + 100 | RED exit 1: StressExhaustiveAPITests.swift:184 Expectation failed: abs(b.max.x - 5) < 1e-6 | ✔ | MATCH | yes |
| Stress: Shape Queries | `faceCount` | `OCCTShapeGetSubShapeCount` | OCCTShapeGetSubShapeCount + 1 | RED exit 1: StressExhaustiveAPITests.swift:186 Expectation failed: standardBox().subShapeCount(ofType: .face) == 6 | ✔ | MATCH | no |
| Stress: Shape Queries | `edgeCount` | `OCCTShapeGetSubShapeCount` | OCCTShapeGetSubShapeCount + 1 | RED exit 1: StressExhaustiveAPITests.swift:187 Expectation failed: standardBox().subShapeCount(ofType: .edge) == 12 | ✔ | MATCH | no |
| Stress: Shape Queries | `vertexCount` | `OCCTShapeGetSubShapeCount` | OCCTShapeGetSubShapeCount + 1 | RED exit 1: StressExhaustiveAPITests.swift:188 Expectation failed: standardBox().subShapeCount(ofType: .vertex) == 8 | ✔ | MATCH | no |
| Stress: Shape Queries | `subShapes` | `OCCTShapeGetSubShapes` | EARLY:OCCTShapeGetSubShapes | RED exit 1: StressExhaustiveAPITests.swift:192 Expectation failed: faces.count == 6 | ✔ | MATCH | no |
| Stress: Shape Queries | `mesh` | `OCCTShapeCreateMesh` | OCCTShapeCreateMesh returns nil | RED exit 1: StressExhaustiveAPITests.swift:197 Expectation failed: m != nil | ✔ | MATCH | yes |
| Stress: Shape Queries | `edgePolyline` | `OCCTShapeGetEdgePolyline` | EARLY:OCCTShapeGetEdgePolyline | RED exit 1: StressExhaustiveAPITests.swift:206 Expectation failed: box.edgePolyline(at: 0, deflection: 0.1) | ✔ | MATCH | yes |
| Stress: Shape Queries | `faces` | `OCCTShapeGetFaces` | EARLY:OCCTShapeGetFaces | RED exit 1: StressExhaustiveAPITests.swift:213 Expectation failed: faces.count == 6 | ✔ | MATCH | no |
| Stress: Shape Queries | `edges` | `OCCTShapeGetTotalEdgeCount` | EARLY:OCCTShapeGetTotalEdgeCount | RED exit 1: StressExhaustiveAPITests.swift:218 Expectation failed: edges.count == 12 | ✔ | MATCH | no |
| Stress: Shape Queries | `distance` | `OCCTShapeDistance` | EARLY:OCCTShapeDistance | RED exit 1: StressExhaustiveAPITests.swift:225 Expectation failed: b1.distance(to: b2) | ✔ | MATCH | yes |
| Stress: Shape Queries | `boundingBoxOptimal` | `OCCTShapeBoundingBoxOptimal` | EARLY:OCCTShapeBoundingBoxOptimal | RED exit 1: StressExhaustiveAPITests.swift:232 Expectation failed: box.boundingBoxOptimal() | ✔ | MATCH | yes |
| Stress: Shape Queries | `orientedBoundingBox` | `OCCTShapeOrientedBoundingBox` | EARLY:OCCTShapeOrientedBoundingBox | RED exit 1: StressExhaustiveAPITests.swift:240 Expectation failed: box.orientedBoundingBox(optimal: false) | ✔ | MATCH | yes |
| Stress: Shape Queries | `toleranceValue` | `OCCTShapeToleranceValue` | EARLY:OCCTShapeToleranceValue | RED exit 1: StressExhaustiveAPITests.swift:248 Expectation failed: tol >= 0 | ✔ | MATCH | yes |
| Stress: Shape Queries | `isBooleanValid` | `OCCTShapeBooleanCheckSingle` | EARLY:OCCTShapeBooleanCheckSingle | RED exit 1: StressExhaustiveAPITests.swift:256 Expectation failed: valid | ✔ | MATCH | no |
| Stress: Shape Queries | `brepString` | `OCCTShapeToBREPString` | OCCTShapeToBREPString returns nil | RED exit 1: StressExhaustiveAPITests.swift:261 Expectation failed: box.toBREPString() | ✔ | MATCH | yes |
| Stress: Shape Queries | `typeName` | `OCCTShapeTypeName` | EARLY:OCCTShapeTypeName | RED exit 1: StressExhaustiveAPITests.swift:268 Expectation failed: name != nil | ✔ | MATCH | yes |
## Epic #766 execution, measured: StressExhaustiveAPITests: Surface API, Document API
| Stress: Surface API | `plane` | `OCCTSurfacePlaneFromPointNormal` | EARLY:OCCTSurfacePlaneFromPointNormal | RED exit 1: StressExhaustiveAPITests.swift:500 Expectation failed: s != nil | ✔ | MATCH | no |
| Stress: Surface API | `cylinder` | `OCCTSurfaceCreateCylinder` | EARLY:OCCTSurfaceCreateCylinder | RED exit 1: StressExhaustiveAPITests.swift:505 Expectation failed: s != nil | ✔ | MATCH | no |
| Stress: Surface API | `sphere` | `OCCTSurfaceCreateSphere` | EARLY:OCCTSurfaceCreateSphere | RED exit 1: StressExhaustiveAPITests.swift:510 Expectation failed: s != nil | ✔ | MATCH | no |
| Stress: Surface API | `cone` | `OCCTSurfaceCreateCone` | EARLY:OCCTSurfaceCreateCone | RED exit 1: StressExhaustiveAPITests.swift:515 Expectation failed: s != nil | ✔ | MATCH | no |
| Stress: Surface API | `torus` | `OCCTSurfaceCreateTorus` | EARLY:OCCTSurfaceCreateTorus | RED exit 1: StressExhaustiveAPITests.swift:520 Expectation failed: s != nil | ✔ | MATCH | no |
| Stress: Surface API | `bezier` | `OCCTSurfaceGetDomain` | EARLY:OCCTSurfaceGetDomain | RED exit 1: StressExhaustiveAPITests.swift:526 Expectation failed: dom.uMax > dom.uMin | ✔ | MATCH | yes |
| Stress: Surface API | `pointEval` | `OCCTSurfaceGetPoint` | OFFSET:OCCTSurfaceGetPoint | RED exit 1: StressExhaustiveAPITests.swift:535 Expectation failed: abs(pt.x - 7.5) < 1e-12 | ✔ | MATCH | yes |
| Stress: Surface API | `gaussianCurvature` | `OCCTSurfaceGetGaussianCurvature` | OCCTSurfaceGetGaussianCurvature + 0.01 | RED exit 1: StressExhaustiveAPITests.swift:543 Expectation failed: abs(k - 0.01) < 0.001 | ✔ | MATCH | no |
| Stress: Surface API | `meanCurvature` | `OCCTSurfaceGetMeanCurvature` | OFFSET:OCCTSurfaceGetMeanCurvature | RED exit 1: StressExhaustiveAPITests.swift:550 Expectation failed: abs(abs(h) - 0.1) < 0.001 | ✔ | MATCH | no |
| Stress: Surface API | `continuity` | `OCCTSurfaceIsCNu, OCCTSurfaceIsCNv` | EARLY:OCCTSurfaceIsCNu | RED exit 1: StressExhaustiveAPITests.swift:556 Expectation failed: s.isCNu(2) | ✔ | MATCH | no |
| Stress: Document API | `create` | `OCCTDocumentCreate` | OCCTDocumentCreate returns nil | RED exit 1: StressExhaustiveAPITests.swift:569 Expectation failed: doc != nil | ✔ | N/A | no |
| Stress: Document API | `addShape` | `OCCTDocumentAddShape` | EARLY:OCCTDocumentAddShape | RED exit 1: StressExhaustiveAPITests.swift:577 Expectation failed: label >= 0 | ✔ | N/A | yes |
| Stress: Document API | `shapeCount` | `OCCTDocumentGetShapeCount` | OCCTDocumentGetShapeCount - 1 | RED exit 1: StressExhaustiveAPITests.swift:582 Expectation failed: doc.shapeCount >= 1 | ✔ | N/A | yes |
| Stress: Document API | `colorToolAdd` | `OCCTDocumentColorToolAddColor, OCCTDocumentColorToolGetColorCount` | EARLY:OCCTDocumentColorToolAddColor | RED exit 1: StressExhaustiveAPITests.swift:590 Expectation failed: doc.colorToolColorCount == 1 | ✔ | N/A | yes |
| Stress: Document API | `colorToolFind` | `OCCTDocumentColorToolAddColor, OCCTDocumentColorToolFindColor` | EARLY:OCCTDocumentColorToolFindColor | RED exit 1: StressExhaustiveAPITests.swift:602 Expectation failed: found == added | ✔ | N/A | yes |
| Stress: Document API | `shapeToolQueries` | `OCCTDocumentShapeToolIsFree, OCCTDocumentShapeToolIsSimpleShape, OCCTDocumentShapeToolIsComponent` | EARLY:OCCTDocumentShapeToolIsFree | RED exit 1: StressExhaustiveAPITests.swift:610 Expectation failed: doc.shapeToolIsFree(labelId: label) | ✔ | N/A | yes |
| Stress: Document API | `stepExport` | `OCCTDocumentWriteSTEPWithModes` | EARLY:OCCTDocumentWriteSTEPWithModes | RED exit 1: StressExhaustiveAPITests.swift:623 Expectation failed: doc.writeSTEP(to: url) | ✔ | N/A | yes |
## Epic #766 execution, measured: StressBuilderLifecycleTests: PipeShell, Sewing, WireBuilder, HatchBuilder
Appended by the #1974 execution run (2026-09-24). Every row was run, not planned: Red is the failing expectation (or the crash) captured with the named defect injected behind an `OCCT766` environment switch in `Sources/`, Green is the same test passing with `Sources/` reverted and rebuilt. Parity is against `Scripts/repro/766-stress-builder-lifecycle/probe.mm` and its `transcript.txt`. The six records above committed in 96e7cf39 carry no run output and no probe, and are left for the orchestrator to remove.
| Stress: PipeShellBuilder Lifecycle | `buildEmpty` | `OCCTPipeShellBuild` | TRUE:OCCTPipeShellBuild | RED exit 1: StressBuilderLifecycleTests.swift:184 Expectation failed: !ok | ✔ | MATCH | yes |
| Stress: PipeShellBuilder Lifecycle | `normalCycle` | `OCCTPipeShellAdd, OCCTPipeShellBuild, OCCTPipeShellShape` | EARLY:OCCTPipeShellShape | RED exit 1: StressBuilderLifecycleTests.swift:195 Expectation failed: builder.shape | ✔ | MATCH | yes |
| Stress: PipeShellBuilder Lifecycle | `destroyWithoutBuild` | `OCCTPipeShellRelease` | CRASH:OCCTPipeShellRelease | CRASH exit 134: Abort trap: 6 | ✔ | N/A | no |
| Stress: PipeShellBuilder Lifecycle | `simulateBeforeBuild` | `OCCTPipeShellSimulate` | EARLY:OCCTPipeShellSimulate | RED exit 1: StressBuilderLifecycleTests.swift:218 Expectation failed: sections.count == 5 | ✔ | MATCH | yes |
| Stress: PipeShellBuilder Lifecycle | `doubleBuild` | `OCCTPipeShellBuild` | EARLY:OCCTPipeShellBuild | RED exit 1: StressBuilderLifecycleTests.swift:230 Expectation failed: builder.build() | ✔ | MATCH | yes |
| Stress: SewingBuilder Lifecycle | `buildEmpty` | `OCCTSewingResult` | OCCTSewingResult returns a null sewn shape as non-nil | RED exit 1: StressBuilderLifecycleTests.swift:245 Expectation failed: sewing.result == nil | ✔ | MATCH | yes |
| Stress: SewingBuilder Lifecycle | `normalCycle` | `OCCTSewingAdd, OCCTSewingPerform, OCCTSewingResult` | OCCTShapeGetVolume reports Mass() × 1.5 | RED exit 1: StressBuilderLifecycleTests.swift:257 Expectation failed: abs((result.volume ?? 0) - 1000) < 1e-6 | ✔ | MATCH | yes |
| Stress: SewingBuilder Lifecycle | `twoShapes` | `OCCTSewingResult` | OCCTShapeGetSubShapeCount + 1 | RED exit 1: StressBuilderLifecycleTests.swift:269 Expectation failed: result.subShapeCount(ofType: .face) == 12 | ✔ | MATCH | yes |
| Stress: SewingBuilder Lifecycle | `destroyWithoutPerform` | `OCCTSewingRelease` | CRASH:OCCTSewingRelease | CRASH exit 134: Abort trap: 6 | ✔ | N/A | no |
| Stress: SewingBuilder Lifecycle | `extendedQueries` | `OCCTSewingNbDeletedFaces, OCCTSewingRelease` | CRASH:OCCTSewingRelease | CRASH exit 134: Abort trap: 6 | ✔ | MATCH | yes |
| Stress: WireBuilder Lifecycle | `buildEmpty` | `OCCTWireBuilderWire, OCCTWireBuilderIsDone` | OCCTWireBuilderIsDone always true | RED exit 1: StressBuilderLifecycleTests.swift:296 Expectation failed: !builder.isDone | ✔ | MATCH | yes |
| Stress: WireBuilder Lifecycle | `normalCycle` | `OCCTWireBuilderAddEdge, OCCTWireBuilderWire` | OCCTWireBuilderAddEdge ignores its edge | RED exit 1: StressBuilderLifecycleTests.swift:307 Expectation failed: builder.wire | ✔ | MATCH | yes |
| Stress: WireBuilder Lifecycle | `destroyWithoutGettingWire` | `OCCTWireBuilderRelease` | CRASH:OCCTWireBuilderRelease | CRASH exit 134: Abort trap: 6 | ✔ | N/A | no |
| Stress: WireBuilder Lifecycle | `addWireShape` | `OCCTWireBuilderAddWire` | EARLY:OCCTWireBuilderAddWire | RED exit 1: StressBuilderLifecycleTests.swift:329 Expectation failed: builder.isDone | ✔ | MATCH | yes |
| Stress: HatchBuilder Lifecycle | `buildEmpty` | `OCCTHatcherNbLines, OCCTHatcherRelease` | CRASH:OCCTHatcherRelease | CRASH exit 134: Abort trap: 6 | ✔ | N/A | no |
| Stress: HatchBuilder Lifecycle | `normalCycle` | `OCCTHatcherAddXLine, OCCTHatcherNbLines` | EARLY:OCCTHatcherNbLines | RED exit 1: StressBuilderLifecycleTests.swift:352 Expectation failed: hatcher.nbLines == 4 | ✔ | N/A | yes |
| Stress: HatchBuilder Lifecycle | `destroyWithoutQuery` | `OCCTHatcherRelease` | CRASH:OCCTHatcherRelease | CRASH exit 134: Abort trap: 6 | ✔ | N/A | no |
## Epic #766 execution, measured: StressBuilderLifecycleTests: WireAnalyzer, WireFixer, FaceFixer, ShapeFixer
| Stress: WireAnalyzer Lifecycle | `normalCycle` | `OCCTWireAnalyzerPerform, OCCTWireAnalyzerNbEdges, OCCTWireAnalyzerMinDistance3d` | EARLY:OCCTWireAnalyzerNbEdges | RED exit 1: StressBuilderLifecycleTests.swift:922 Expectation failed: analyzer.edgeCount == 4 | ✔ | N/A | yes |
| Stress: WireAnalyzer Lifecycle | `checkMethods` | `OCCTWireAnalyzerCheckOrder, OCCTWireAnalyzerCheckClosed, OCCTWireAnalyzerNbEdges` | EARLY:OCCTWireAnalyzerNbEdges | RED exit 1: StressBuilderLifecycleTests.swift:944 Expectation failed: analyzer.edgeCount == 4 | ✔ | N/A | yes |
| Stress: WireAnalyzer Lifecycle | `destroyWithoutPerform` | `OCCTWireAnalyzerRelease` | CRASH:OCCTWireAnalyzerRelease | CRASH exit 134: Abort trap: 6 | ✔ | N/A | no |
| Stress: WireFixer Lifecycle | `normalCycle` | `OCCTWireFixerFix*, OCCTWireFixerWire` | EARLY:OCCTWireFixerWire | RED exit 1: StressBuilderLifecycleTests.swift:976 Expectation failed: fixer.wire | ✔ | N/A | yes |
| Stress: WireFixer Lifecycle | `extendedFixMethods` | `OCCTWireFixerFixTails, OCCTWireFixerWire` | EARLY:OCCTWireFixerWire | RED exit 1: StressBuilderLifecycleTests.swift:995 Expectation failed: fixer.wire?.subShapeCount(ofType: .edge) == 4 | ✔ | N/A | yes |
| Stress: WireFixer Lifecycle | `destroyWithoutGettingResult` | `OCCTWireFixerRelease` | CRASH:OCCTWireFixerRelease | CRASH exit 134: Abort trap: 6 | ✔ | N/A | no |
| Stress: FaceFixer Lifecycle | `normalCycle` | `OCCTFaceFixerPerform, OCCTFaceFixerFace` | EARLY:OCCTFaceFixerFace | RED exit 1: StressBuilderLifecycleTests.swift:1021 Expectation failed: fixer.face | ✔ | N/A | yes |
| Stress: FaceFixer Lifecycle | `destroyWithoutPerform` | `OCCTFaceFixerRelease` | CRASH:OCCTFaceFixerRelease | CRASH exit 134: Abort trap: 6 | ✔ | N/A | no |
| Stress: ShapeFixer Lifecycle | `normalCycle` | `OCCTShapeFixerPerform, OCCTShapeFixerShape` | EARLY:OCCTShapeFixerShape | RED exit 1: StressBuilderLifecycleTests.swift:1045 Expectation failed: fixer.shape | ✔ | MATCH | yes |
| Stress: ShapeFixer Lifecycle | `fixAlreadyGoodShape` | `OCCTShapeFixerShape` | EARLY:OCCTShapeFixerShape | RED exit 1: StressBuilderLifecycleTests.swift:1053 Expectation failed: fixer.shape | ✔ | MATCH | yes |
| Stress: ShapeFixer Lifecycle | `destroyWithoutPerform` | `OCCTShapeFixerRelease` | CRASH:OCCTShapeFixerRelease | CRASH exit 134: Abort trap: 6 | ✔ | N/A | no |
## Epic #766 execution, measured: StressExhaustiveAPITests: Math Utilities, Mesh API, Feature Recognition
| Stress: Math Utilities | `polynomialSolverQuadratic` | `OCCTMathPolyQuadratic` | EARLY:OCCTMathPolyQuadratic | RED exit 1: StressExhaustiveAPITests.swift:619 Expectation failed: sorted.count == 2 | ✔ | MATCH | yes |
| Stress: Math Utilities | `polynomialSolverCubic` | `OCCTMathPolyCubic` | EARLY:OCCTMathPolyCubic | RED exit 1: StressExhaustiveAPITests.swift:630 Expectation failed: (roots ?? []).sorted() == [-1, 0, 1] | ✔ | MATCH | yes |
| Stress: Math Utilities | `gaussIntegration` | `OCCTMathIntegGauss` | EARLY:OCCTMathIntegGauss | RED exit 1: StressExhaustiveAPITests.swift:635 Expectation failed: result != nil | ✔ | MATCH | no |
| Stress: Math Utilities | `planeGeometry` | `OCCTPlaneDistanceToPoint` | EARLY:OCCTPlaneDistanceToPoint | RED exit 1: StressExhaustiveAPITests.swift:642 Expectation failed: abs(dist - 5.0) < 0.001 | ✔ | MATCH | no |
| Stress: Math Utilities | `lineGeometry` | `OCCTLineDistanceToPoint` | EARLY:OCCTLineDistanceToPoint | RED exit 1: StressExhaustiveAPITests.swift:648 Expectation failed: abs(dist - 3.0) < 0.001 | ✔ | MATCH | no |
| Stress: Math Utilities | `vectorCrossMagnitude` | `OCCTVecCrossMagnitude` | EARLY:OCCTVecCrossMagnitude | RED exit 1: StressExhaustiveAPITests.swift:653 Expectation failed: abs(mag - 1.0) < 0.001 | ✔ | MATCH | no |
| Stress: Math Utilities | `dirIsOpposite` | `OCCTDirIsOpposite` | EARLY:OCCTDirIsOpposite | RED exit 1: StressExhaustiveAPITests.swift:657 Expectation failed: Shape.dirIsOpposite(SIMD3(1, 0, 0), SIMD3(-1, 0, 0)) | ✔ | MATCH | no |
| Stress: Math Utilities | `dirIsNormal` | `OCCTDirIsNormal` | EARLY:OCCTDirIsNormal | RED exit 1: StressExhaustiveAPITests.swift:662 Expectation failed: Shape.dirIsNormal(SIMD3(1, 0, 0), SIMD3(0, 1, 0)) | ✔ | MATCH | no |
| Stress: Mesh API | `meshGeneration` | `OCCTShapeCreateMesh, OCCTMeshGetVertexCount, OCCTMeshGetTriangleCount` | EARLY:OCCTMeshGetTriangleCount | RED exit 1: StressExhaustiveAPITests.swift:677 Expectation failed: m.triangleCount > 0 | ✔ | MATCH | no |
| Stress: Mesh API | `meshVertices` | `OCCTMeshGetVertices` | EARLY:OCCTMeshGetVertices | RED exit 1: StressExhaustiveAPITests.swift:690 Expectation failed: abs(rad - 5) < 1e-4 | ✔ | MATCH | yes |
| Stress: Mesh API | `meshNormals` | `OCCTMeshGetNormals` | EARLY:OCCTMeshGetNormals | RED exit 1: StressExhaustiveAPITests.swift:703 Expectation failed: abs(len - 1) < 1e-5 | ✔ | MATCH | yes |
| Stress: Mesh API | `meshTriangles` | `OCCTMeshGetTriangleCount` | EARLY:OCCTMeshGetTriangleCount | RED exit 1: StressExhaustiveAPITests.swift:709 Expectation failed: m.triangleCount > 0 | ✔ | MATCH | yes |
| Stress: Mesh API | `meshOnAllShapes` | `OCCTShapeCreateMesh` | OCCTShapeCreateMesh returns nil | RED exit 1: StressExhaustiveAPITests.swift:716 Expectation failed: m != nil | ✔ | MATCH | no |
| Stress: Feature Recognition | `aagOnBox` | `OCCTShapeGetOrientedFaces` | EARLY:OCCTShapeGetOrientedFaces | RED exit 1: StressExhaustiveAPITests.swift:729 Expectation failed: aag.nodes.count == 6 | ✔ | MATCH | no |
| Stress: Feature Recognition | `aagOnFilletedBox` | `OCCTShapeGetOrientedFaces` | EARLY:OCCTShapeGetOrientedFaces | RED exit 1: StressExhaustiveAPITests.swift:735 Expectation failed: aag.nodes.count > 6 | ✔ | MATCH | yes |
| Stress: Feature Recognition | `aagOnDrilledPlate` | `OCCTShapeGetOrientedFaces` | EARLY:OCCTShapeGetOrientedFaces | RED exit 1: StressExhaustiveAPITests.swift:743 Expectation failed: aag.nodes.count > 6 | ✔ | MATCH | yes |
## Epic #766 execution, measured: StressExhaustiveAPITests: Shape Features, Shape Transforms
| Stress: Shape Features | `fillet` | `OCCTShapeFillet` | OCCTShapeFillet returns nil | RED exit 1: StressExhaustiveAPITests.swift:101 Expectation failed: standardBox().filleted(radius: 1.0) | ✔ | MATCH | yes |
| Stress: Shape Features | `chamfer` | `OCCTShapeChamfer` | OCCTShapeChamfer returns nil | RED exit 1: StressExhaustiveAPITests.swift:107 Expectation failed: standardBox().chamfered(distance: 1.0) | ✔ | MATCH | yes |
| Stress: Shape Features | `shell` | `OCCTShapeShell` | OCCTShapeShell returns the input unchanged when not done or on a throw | RED exit 1: StressExhaustiveAPITests.swift:115 Expectation failed: r == nil | ✔ | MATCH | yes |
| Stress: Shape Features | `drill` | `OCCTShapeDrillHole` | OCCTShapeDrillHole returns nil | RED exit 1: StressExhaustiveAPITests.swift:119 Expectation failed: standardBox().drilled(at: SIMD3(0, 0, 5), direction: SIMD3(0, 0, -1), ... | ✔ | MATCH | yes |
| Stress: Shape Features | `offset` | `OCCTShapeOffset` | EARLY:OCCTShapeOffset | RED exit 1: StressExhaustiveAPITests.swift:128 Expectation failed: standardBox().offset(by: 1.0) | ✔ | MATCH | yes |
| Stress: Shape Features | `linearPattern` | `OCCTShapeLinearPattern` | EARLY:OCCTShapeLinearPattern | RED exit 1: StressExhaustiveAPITests.swift:135 Expectation failed: standardBox().linearPattern(direction: SIMD3(15, 0, 0), spacing: 15, c... | ✔ | MATCH | yes |
| Stress: Shape Features | `circularPattern` | `OCCTShapeCircularPattern` | EARLY:OCCTShapeCircularPattern | RED exit 1: StressExhaustiveAPITests.swift:144 Expectation failed: standardBox().circularPattern(axisPoint: .zero, axisDirection: SIMD3(0... | ✔ | MATCH | yes |
| Stress: Shape Features | `sectionWires` | `OCCTShapeSectionWiresAtZ` | EARLY:OCCTShapeSectionWiresAtZ | RED exit 1: StressExhaustiveAPITests.swift:153 Expectation failed: !wires.isEmpty | ✔ | MATCH | no |
| Stress: Shape Transforms | `translate` | `OCCTShapeTranslate` | OCCTShapeTranslate moves by dx + 1 | RED exit 1: StressExhaustiveAPITests.swift:172 Expectation failed: abs(b.min.x - 5) < 1e-6 | ✔ | MATCH | yes |
| Stress: Shape Transforms | `rotate` | `OCCTShapeRotate` | OCCTShapeRotate turns by angle + 0.1 | RED exit 1: StressExhaustiveAPITests.swift:182 Expectation failed: abs(b.max.x - 5 * 2.0.squareRoot()) < 1e-6 | ✔ | MATCH | yes |
| Stress: Shape Transforms | `scale` | `OCCTShapeScale` | OCCTShapeScale scales by factor × 1.1 | RED exit 1: StressExhaustiveAPITests.swift:188 Expectation failed: abs((r.volume ?? 0) - 8000) < 1e-6 | ✔ | MATCH | yes |
| Stress: Shape Transforms | `mirror` | `OCCTShapeMirror` | EARLY:OCCTShapeMirror | RED exit 1: StressExhaustiveAPITests.swift:192 Expectation failed: standardBox().mirrored(planeNormal: SIMD3(1, 0, 0)) | ✔ | MATCH | yes |
## Epic #766 execution, measured: StressBuilderLifecycleTests: FilletBuilder, ChamferBuilder
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
