# Phase 3: OCCTModelingTests Injection Matrix

**Target**: `OCCTModelingTests` (654 tests) — boolean ops, fillets, holes (most OCCT surface)
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (largest domain, most OCCT surface, key crash fixes)

---

## Test Inventory by Suite (Top by Count)

| Suite | Tests | Lines | Primary Category |
|-------|-------|-------|------------------|
| Advanced Modeling Tests | 28 | — | WR |
| Fillet Edge-Index And Radius-Law Contracts (#520) | 15 | — | WR/CR |
| Sub-Shape Index Skipping (#568) | 13 | — | OOB/RF |
| Issue496 cylindrical hole contracts | 13 | — | WR/DG |
| Oriented Primitives | 13 | — | WR |
| Fillet Edge-List Radius Validation (#489) | 13 | — | DG/RF |
| Transform / pattern *WithFullHistory (#331) | 10 | — | WR/TS |
| Boolean Pre-Validation | 10 | — | WR/RF |
| AAG.detectHoles() (#747) | 9 | — | WR |
| Sewing / Quilting / Healing with Full History | 9 | — | WR/TS |
| Issue 497: BRepAlgoAPI_Defeaturing family | 8 | — | WR/RF |
| AAG builds nodes from orientedFaces() (#642) | 8 | — | WR |
| Fillet radius laws go to edge's own slot (#612) | 8 | — | WR |
| FeatureReconstructor inputBody (#87) | 8 | — | WR |
| Pipe shell unification (#503) | 7 | — | WR |
| Issue532 cylindrical hole part selection | 7 | — | WR/CR (#532) |
| v0.142 FeatureReconstructor | 7 | — | WR |
| Issue 578: which faces defeating will accept | 7 | — | WR/RF |
| AAG restricts adjacency to one solid (#699) | 7 | — | WR |
| Fillet family reports declined edges (#639) | 7 | — | WR |
| Shape, Torus, Chamfer, Offset, Scale, Mirror | 7 | — | WR/DG |
| Issue #1068, self-intersection detailed API | 7 | — | TO/CR (#319) |
| FilletBuilder radius laws keyed by edge (#505) | 6 | — | WR |
| Issue #1067, boolean timeout not failure | 6 | — | TO |
| FilletBuilder Completions v124 | 6 | — | WR |
| ChamferBuilder Completions v124 | 6 | — | WR |
| FeatureReconstructor BuildResult.histories | 6 | — | WR |
| v0.114.0 - Boolean Tolerance | 6 | — | WR |
| FilletBuilder v121 | 6 | — | WR |
| Feature Recognition, AAG | 6 | — | WR |
| blendedEdges reports overwritten duplicates (#633) | 6 | — | WR |
| Partial Oriented Primitives | 6 | — | WR |
| Issue #397, faceAddHole accepts circular hole wires | 6 | — | DG/CR |
| ... | ... | ... | ... |

**Total**: 654 tests across ~100 suites in multiple files

---

## Injection Matrix: Critical Crash-Related Tests First

### #532: Cylindrical Hole Part Selection (kernel patch `0020`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| untilEnd and a stack-spanning range drill every body on the axis | `Shape.cylindricalHole` → `BRepFeat_MakeCylindricalHole` | Wrong part selection (SetOperation Fuse) | Revert kernel patch `0020` |  |  | Zero volume removed |
| blind drills its depth into the first body of a stack | `Shape.cylindricalHole` → `BRepFeat_MakeCylindricalHole` | Wrong part selection | Revert kernel patch `0020` |  |  | Zero volume removed |
| A three-plate stack drills as many bodies as the extent names | `Shape.cylindricalHole` → `BRepFeat_MakeCylindricalHole` | Wrong part selection | Revert kernel patch `0020` |  |  | Zero volume removed |
| A single solid the bore severs is drilled, not merely imprinted | `Shape.cylindricalHole` → `BRepFeat_MakeCylindricalHole` | Wrong part selection | Revert kernel patch `0020` |  |  | Zero volume removed |
| A single plate is unaffected by the part-selection fix | `Shape.cylindricalHole` → `BRepFeat_MakeCylindricalHole` | Control test | No injection needed |  |  | Should pass |
| A hollow box drills both walls, before and after the fix | `Shape.cylindricalHole` → `BRepFeat_MakeCylindricalHole` | Wrong part selection | Revert kernel patch `0020` |  |  | Zero volume removed |
| A range naming no face pair is still invalidPlacement | `Shape.cylindricalHole` → `BRepFeat_MakeCylindricalHole` | Input validation | No injection needed |  |  | Should pass |

### #430: BRepFill_Filling Untrimmed Pcurve (bridge fix)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| (Find filling tests) | `Shape.fill` / `FillingSurface` → `BRepFill_Filling::AddConstraints` | Untrimmed pcurve on non-C0 surface | Remove `occtFillingSupportFaceFromPCurve` synthesis |  |  | SIGSEGV on cylinder/sphere/cone |

### #522: AdvApp2Var U Buffer Overflow (kernel patch `0019`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| (Find approx C0 tests) | `GeomConvert_ApproxSurface` → `AdvApp2Var_ApproxF2var` | U Jacobi-maxima buffer from V slot | Revert kernel patch `0019` |  |  | Wrong surface, wrong MaxError |

### #597: GeomFill_Sweep SError Overwrite (kernel patch `0025`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| (Find sweep/pipe tests) | `GeomFill_Sweep::BuildAll` → `GeomConvert_ApproxSurface` | SError = requested tolerance | Revert `SError = ConvertApprox.MaxError()` |  |  | Wrong error reported (0.0001 vs actual 2.5+) |

### #905/#913: ThruSections Capping/Count Mismatch (kernel patches `0026`/`0027`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| (Find ThruSections tests) | `BRepOffsetAPI_ThruSections::MakeSolid` | Missing end-cap faces | Revert kernel patch `0026` |  |  | SIGSEGV/SIGBUS on count mismatch |
| (Find ThruSections tests) | `BRepOffsetAPI_ThruSections::CreateSmoothed` | Edge count mismatch | Revert kernel patch `0027` |  |  | Heap corruption / wrong geometry |

### #319: Self-Intersection Timeout (kernel patch `0010`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| isSelfIntersectingDetailed reports indeterminateBreakerTripped on very short timeout | `Shape.isSelfIntersecting` → `BOPAlgo_ArgumentAnalyzer` | Timeout not honored | Revert kernel patch `0010` |  |  | Runs past deadline |

---

## Injection Matrix: Thread Safety / TSan Tests

### Transform / pattern *WithFullHistory (#331)

| Test | Bridge Function | Defect Category | Injection | Red? | Green? | Notes |
|------|-----------------|-----------------|-----------|------|--------|-------|
| Translate: every input face is Modified exactly once | `Shape.translated` → `BRepBuilderAPI_Transform` | TS | Remove `OCCTSerial` lock |  |  | Data race |
| Rotate: every input face is Modified exactly once | `Shape.rotated` → `BRepBuilderAPI_Transform` | TS | Remove `OCCTSerial` lock |  |  | Data race |
| Scale: every input face Modified exactly once; volume scales by factor^3 | `Shape.scaled` → `BRepBuilderAPI_Transform` | TS | Remove `OCCTSerial` lock |  |  | Data race |
| Mirror: every input face Modified exactly once | `Shape.mirrored` → `BRepBuilderAPI_Transform` | TS | Remove `OCCTSerial` lock |  |  | Data race |

---

## Injection Matrix: Degenerate Geometry Tests

### #489: Fillet Radius Validation (Bridge-level validation)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Blend rejects a zero radius | `Shape.blendedEdges` → `OCCTShapeBlendEdges` | Invalid radius passed to OCCT | Remove `radius > 0` guard | ❌ Still GREEN | ✅ Pass | OCCT kernel rejects (IsDone=false) |
| Blend rejects a negative radius | `Shape.blendedEdges` → `OCCTShapeBlendEdges` | Invalid radius passed to OCCT | Remove `radius > 0` guard | ❌ Still GREEN | ✅ Pass | OCCT kernel rejects (IsDone=false) |
| Blend rejects a NaN radius | `Shape.blendedEdges` → `OCCTShapeBlendEdges` | Invalid radius passed to OCCT | Remove `radius > 0` guard | ❌ Still GREEN | ✅ Pass | OCCT kernel rejects (IsDone=false) |
| Uniform fillet rejects a non-positive radius | `Shape.filleted(edges:radius:)` → `OCCTShapeFilletEdges` | Invalid radius passed to OCCT | Remove `radius > 0` guard | ❌ Still GREEN | ✅ Pass | OCCT kernel rejects (IsDone=false) |
| Linear fillet rejects a non-positive radius | `Shape.filleted(edges:startRadius:endRadius:)` | Invalid radius passed to OCCT | Remove `radius > 0` guard | ❌ Still GREEN | ✅ Pass | OCCT kernel rejects (IsDone=false) |
| History fillet rejects a non-positive radius | `Shape.filletedWithFullHistory` | Invalid radius passed to OCCT | Remove `radius > 0` guard | ❌ Still GREEN | ✅ Pass | OCCT kernel rejects (IsDone=false) |

**Finding**: The bridge-level radius validation guards are **redundant defensive code**. OCCT's `BRepFilletAPI_MakeFillet` itself rejects non-positive radii by failing `IsDone()`, which the bridge correctly converts to `nil`. Removing the bridge guards does not change test outcomes — OCCT kernel handles the validation. The tests exercise OCCT behavior, not bridge validation.

### Issue #397: faceAddHole accepts circular hole wires

| Test | Bridge Function | Defect Category | Injection | Red? | Green? | Notes |
|------|-----------------|-----------------|-----------|------|--------|-------|
| Wire.circle hole is accepted (was nil for every radius) | `Shape.face(withBoundary:innerWires:)` → `BRepBuilderAPI_MakeFace` | DG/CR | Remove circular wire acceptance |  |  | Was SIGSEGV |

### Issue #234: faceAddHole rejects degenerate hole wires

| Test | Bridge Function | Defect Category | Injection | Red? | Green? | Notes |
|------|-----------------|-----------------|-----------|------|--------|-------|
| Degenerate 2-vertex hole wire is rejected (was healed() SIGSEGV) | `Shape.face(withBoundary:innerWires:)` → `ShapeFix_Face` | DG/CR | Revert degenerate wire check |  |  | Was SIGSEGV |

---

## Injection Matrix: Key Bridge Functions

| Bridge Function | File | Crash Fix | Tests Covered |
|-----------------|------|-----------|---------------|
| `OCCTShapeCylindricalHole` | OCCTBridge_Modeling.mm | #532 | Issue532 (7 tests) |
| `OCCTShapeFill` / `OCCTShapeFillWithSupport` / `OCCTShapeFillConstraints` | OCCTBridge_Healing.mm | #430 | Filling tests |
| `OCCTGeomFillSweep` | OCCTBridge_Surface.mm | #597 | Pipe/sweep tests |
| `OCCTThruSectionsBuilderBuild` | OCCTBridge_AdvancedModeling.mm | #905, #913 | ThruSections tests |
| `OCCTShapeIsSelfIntersecting` | OCCTBridge_Analysis.mm | #319 | Self-intersection tests |
| `OCCTShapeFilleted` / `OCCTFilletBuilderBuild` | OCCTBridge_Modeling_Fillet.mm | #489, #520, #612, #639 | Fillet tests |
| `OCCTShapeChamfered` / `OCCTChamferBuilderBuild` | OCCTBridge_Modeling_Chamfer.mm | Chamfer tests | Chamfer tests |
| `OCCTShapeTransformed` | OCCTBridge_Modeling_Transform.mm | #331 | Transform history tests |
| `OCCTBOPAlgoArgumentAnalyzer` | OCCTBridge_Analysis.mm | #319, #206 | Timeout tests |
| `OCCTBRepFeatMakeCylindricalHole` | OCCTBridge_Modeling.mm | #532 | Cylindrical hole tests |
| `OCCTFeatureReconstructor` | OCCTBridge_AdvancedModeling.mm | #87, #88 | FeatureReconstructor tests |
| `OCCTDraftBuilder` | OCCTBridge_Modeling_Draft.mm | Draft tests | Draft tests |
| `OCCTBRepFillSweep` | OCCTBridge_Surface.mm | Pipe/sweep tests | Sweep tests |

---

## Injection Procedure Per Test

```bash
# 1. Focused compile (3s)
swift build --target OCCTModelingTests

# 2. For each test:
#    a. Identify defect and bridge function
#    b. Create injection (revert kernel patch, remove guard, remove try/catch, etc.)
#    c. Run single test: swift test --filter <TestStructName>
#    d. Confirm FAIL (red) - crash, wrong result, or timeout
#    e. Restore fix
#    f. Confirm PASS (green)
#    g. Record in matrix above

# 3. Create PR for OCCTModelingTests
# 4. User reviews PR → merge what makes sense
# 5. Proceed to next domain (OCCTShapeHealingTests)
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
| Advanced Modeling Tests | 28 |  |  |  |  |
| Fillet Edge-Index And Radius-Law Contracts (#520) | 15 |  |  |  |  |
| Sub-Shape Index Skipping (#568) | 13 |  |  |  |  |
| Issue496 cylindrical hole contracts | 13 |  |  |  |  |
| Oriented Primitives | 13 |  |  |  |  |
| Fillet Edge-List Radius Validation (#489) | 13 |  |  |  |  |
| Transform / pattern *WithFullHistory (#331) | 10 |  |  |  |  |
| Boolean Pre-Validation | 10 |  |  |  |  |
| AAG.detectHoles() (#747) | 9 |  |  |  |  |
| Sewing / Quilting / Healing with Full History | 9 |  |  |  |  |
| Issue 497: BRepAlgoAPI_Defeaturing family | 8 |  |  |  |  |
| AAG builds nodes from orientedFaces() (#642) | 8 |  |  |  |  |
| Fillet radius laws go to edge's own slot (#612) | 8 |  |  |  |  |
| FeatureReconstructor inputBody (#87) | 8 |  |  |  |  |
| Pipe shell unification (#503) | 7 |  |  |  |  |
| **Issue532 cylindrical hole part selection** | **7** |  |  |  |  |
| v0.142 FeatureReconstructor | 7 |  |  |  |  |
| Issue 578: which faces defeating will accept | 7 |  |  |  |  |
| AAG restricts adjacency to one solid (#699) | 7 |  |  |  |  |
| Fillet family reports declined edges (#639) | 7 |  |  |  |  |
| Shape, Torus, Chamfer, Offset, Scale, Mirror | 7 |  |  |  |  |
| Issue #1068, self-intersection detailed API | 7 |  |  |  |  |
| ... | ... |  |  |  |  |

**Total**: 654 tests

---

## Measured Red→Green and kernel parity (#766 re-execution, appended per file)

Every row below was run: the injection applied through an environment switch in one build, the named test run red, then the whole suite run green with the switch off. Parity comes from the probe named in each section, whose transcript is committed beside it.

### `FilletBuilderV121Tests.swift` (6 tests)

Probe: `Scripts/repro/766-modeling-fillet-builder-v121/`.

| Test | Injection | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| filletBuilderConstantRadius | `OCCTFilletBuilderGetRadius` returns twice `Radius(IC)` | `:27 Expectation failed: abs(builder.radius(contour: 1) - 2.0) < 1e-10` | pass | `OCCTFilletBuilderGetRadius` | PASS |
| filletBuilderEvolvingRadius | `OCCTFilletBuilderIsConstant` inverts `IsConstant(IC)` | `:38 Expectation failed: !builder.isConstant(contour: 1)` | pass | `OCCTFilletBuilderIsConstant` | PASS |
| filletBuilderMultipleEdges | `OCCTFilletBuilderNbContours` returns -1 | `:51 Expectation failed: builder.contourCount == 3` | pass | `OCCTFilletBuilderNbContours` | PASS |
| filletBuilderDiagnostics | `OCCTFilletBuilderGetLength` returns half `Length(IC)` | `:62 Expectation failed: abs(builder.length(contour: 1) - 20.0) < 1e-9` | pass | `OCCTFilletBuilderGetLength` | PASS |
| filletBuilderReset | `OCCTFilletBuilderReset` also removes every contour | `:77 Expectation failed: builder.contourCount == 1`, `:78 Expectation failed: builder.build()?.isValid == true` | pass | `OCCTFilletBuilderReset` | PASS |
| filletBuilderRemoveEdge | `OCCTFilletBuilderRemoveEdge` returns false without removing | `:88 Expectation failed: builder.removeEdge(edge)`, `:89 Expectation failed: builder.contourCount == 0` | pass | `OCCTFilletBuilderRemoveEdge` | PASS |
