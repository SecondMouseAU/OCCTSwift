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

### `OffsetByJoinTests.swift` (4 tests)

Probe: `Scripts/repro/766-modeling-offset-by-join/`.

| Test | Injection | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| offsetArc | `OCCTShapeOffsetByJoin` offsets by -distance | `:15 Expectation failed: o.volume! > box.volume!` | pass | `OCCTShapeOffsetByJoin` | PASS |
| offsetInward | `OCCTShapeOffsetByJoin` offsets by -distance | `:26 Expectation failed: o.volume! < box.volume!` | pass | `OCCTShapeOffsetByJoin` | PASS |
| offsetIntersection | `OCCTShapeOffsetByJoin` returns nullptr | `:34 Expectation failed: offset != nil` | pass | `OCCTShapeOffsetByJoin` | PASS |
| offsetCylinder | `OCCTShapeOffsetByJoin` returns nullptr | `:44 Expectation failed: offset != nil` | pass | `OCCTShapeOffsetByJoin` | PASS |

### `OffsetWireFaceTests.swift` (3 tests)

Probe: `Scripts/repro/766-modeling-offset-wire-face/`.

| Test | Injection | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| offsetWire | `OCCTOffsetWireOnPlane` returns nullptr | `:14 Expectation failed: offset != nil` | pass | `OCCTOffsetWireOnPlane` | PASS |
| offsetWireIntersection | `OCCTOffsetWireOnPlane` returns nullptr | `:23 Expectation failed: offset != nil` | pass | `OCCTOffsetWireOnPlane` | PASS |
| offsetFace | `OCCTBRepOffsetOffsetFace` returns nullptr | `:32 Expectation failed: offset != nil` | pass | `OCCTBRepOffsetOffsetFace` | PASS |

### `MultiEdgeBlendTests.swift` (3 tests)

Probe: `Scripts/repro/766-modeling-multi-edge-blend/`.

| Test | Injection | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| blendMultipleEdges | `OCCTShapeBlendEdges` returns nullptr | `:20 Expectation failed: blended != nil` | pass | `OCCTShapeBlendEdges` | PASS |
| blendSingleEdge | `OCCTShapeBlendEdges` returns nullptr | `:32 Expectation failed: blended != nil` | pass | `OCCTShapeBlendEdges` | PASS |
| blendEmptyArray | `Shape.blendedEdges` returns the input shape for an empty list instead of nil | `:44 Expectation failed: blended == nil` | pass | `OCCTShapeBlendEdges` | N/A: refused in Swift and in occtShapeFilletEdgeList before any kernel call |

### `MultiFuseTests.swift` (4 tests)

Probe: `Scripts/repro/766-modeling-multi-fuse/`.

| Test | Injection | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| fuseThreeBoxes | `OCCTShapeFuseMulti` returns nullptr | `:14 Expectation failed: result != nil` | pass | `OCCTShapeFuseMulti` | PASS |
| fuseFourSpheres | `OCCTShapeFuseMulti` returns nullptr | `:30 Expectation failed: result != nil` | pass | `OCCTShapeFuseMulti` | PASS |
| fuseTooFew | `Shape.commonAll` / `Shape.fuseAll` return the lone operand for a one-element list instead of nil | `:40 Expectation failed: result == nil` | pass | `OCCTShapeFuseMulti` | N/A: the guard is in Swift (and again in the bridge) before any kernel call |
| fuseNonOverlapping | `OCCTShapeFuseMulti` returns nullptr | `:48 Expectation failed: result != nil` | pass | `OCCTShapeFuseMulti` | PASS |

### `MultiOffsetWireTests.swift` (3 tests)

Probe: `Scripts/repro/766-modeling-multi-offset-wire/`.

| Test | Injection | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| multipleInwardOffsets | `OCCTWireMultiOffset` returns 0 wires | `:15 Expectation failed: wires.count >= 3` | pass | `OCCTWireMultiOffset` | PASS |
| outwardOffset | `OCCTWireMultiOffset` returns 0 wires | `:32 Expectation failed: wires.count >= 2` | pass | `OCCTWireMultiOffset` | PASS |
| emptyOffsets | `Shape.multiOffsetWires` treats an empty offset list as a single 0 offset | `:39 Expectation failed: wires.isEmpty` | pass | `OCCTWireMultiOffset` | N/A: an empty list is refused in Swift and in the bridge before any kernel call |

### `AdvancedModelingTests.swift` (28 tests)

Probe: `Scripts/repro/766-modeling-advanced/`. Two passes under #766 changed the tests in the rows marked "rewritten" or "tightened". The first rewrote the three pipe-shell tests (silent pass: the fixtures gave a degenerate or invalid sweep and the tests accepted any non-nil result). The second tightened the tests that asserted only non-nil, or a positive volume, or a force-unwrapped volume against a loose tolerance: the three fillet tests, `draftVerticalFaces`, `removeFeatures`, `pipeShellCreatesShell` (whose circle also lay in the plane of its spine) and the three multi-section tests each assert validity, the face count and the kernel's volume now. That pass moved every later line, so every line cited below is re-measured or moved with its line (an unchanged line moves to the same place in the new file). Injections for the tightened rows, each reverted: the bridge function returns nullptr (the `#require` lines); returns its input shape (fillet, draft, defeature: the face-count and volume lines); scales the sweep by 0.5 (the pipe-shell volume and area lines); and, for `pipeShellCreatesShell`, `OCCTShapeCreatePipeShellMultiSection` forcing `solid = true` (`:231`, `:233`, `:235`).

| Test | Injection | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| filletSpecificEdges | `OCCTShapeFilletEdges` returns nullptr; or returns its input box unfilleted | `:26 Expectation failed: box.filleted(edges: edgesToFillet, radius: 2.0)`; input returned: `:30 Expectation failed: filleted.subShapes(ofType: .face).count == 10`, `:32 Expectation failed: abs(volume - 3951.5634099876793) < 1e-6` | pass | `OCCTShapeFilletEdges` | PASS: tightened under #766 (it asserted non-nil and valid, which the input box passes): valid, 10 faces and the volume |
| filletSingleEdge | `OCCTShapeFilletEdges` returns nullptr; or returns its input box unfilleted | `:40 Expectation failed: box.filleted(edges: [edge], radius: 1.0)`; input returned: `:43 Expectation failed: filleted.subShapes(ofType: .face).count == 7`, `:45 Expectation failed: abs(volume - 1997.8539816339744) < 1e-6` | pass | `OCCTShapeFilletEdges` | PASS: tightened under #766 (asserted only non-nil): valid, 7 faces and the volume |
| filletVariableRadius | `OCCTShapeFilletEdgesLinear` returns nullptr; or returns its input box unfilleted | `:53 Expectation failed: box.filleted(edges: [edge], startRadius: 1.0, endRadius: 3.0)`; input returned: `:56 Expectation failed: filleted.subShapes(ofType: .face).count == 7`, `:58 Expectation failed: abs(volume - 2990.5237334555886) < 1e-6` | pass | `OCCTShapeFilletEdgesLinear` | PASS: tightened under #766 (asserted only non-nil): valid, 7 faces and the volume |
| edgeHasIndex | `Shape.edge(at:)` stamps `index + 1` on the Edge it returns | `:67 Expectation failed: edge?.index == 5` | pass | `OCCTShapeGetEdgeAtIndex` | N/A: the index is stamped by Swift's `edge(at:)`; the kernel only confirms index 5 is in range (12 edges) |
| faceHasIndex | `Shape.face(at:)` stamps `index + 1` on the Face it returns | `:76 Expectation failed: face?.index == 3` | pass | `OCCTShapeGetFaceAtIndex` | N/A: the index is stamped by Swift's `face(at:)`; the kernel only confirms index 3 is in range (6 faces) |
| draftVerticalFaces | `OCCTShapeDraft` returns nullptr; or returns its input box undrafted | `:101 Expectation failed: drafted`; input returned: `:105 Expectation failed: abs(volume - 12024.71917796442) < 1e-6` (the input is valid and has the same 6 faces, so the volume is what tells it) | pass | `OCCTShapeDraft` | PASS: tightened under #766 (asserted the 4 vertical faces and non-nil): valid, 6 faces and the volume |
| removeFeatures | `OCCTShapeRemoveFeatures` returns nullptr; or returns the holed box unchanged | `:133 Expectation failed: boxWithHole.withoutFeatures(faces: cylindricalFaces)`; input returned: `:135 Expectation failed: defeatured.subShapes(ofType: .face).count == 6`, `:138 Expectation failed: abs(volume - 8000.0) < 1e-6` | pass | `OCCTShapeRemoveFeatures` | PASS: tightened under #766 (read `defeatured.volume!` inside `#expect` against a tolerance of 100 mm3): valid, 6 faces and the volume within 1e-6 |
| pipeShellFrenet | `OCCTShapeCreatePipeShellMultiSection` returns nullptr; or maps Frenet to corrected Frenet, corrected Frenet to Frenet and fixed binormal to corrected Frenet | `:159 Expectation failed: Shape.pipeShell(spine: spine, profile: profile, mode: .frenet)`; modes swapped: `:165 Expectation failed: abs(volume - 436.39600453178826) < 1e-6` | pass | `OCCTShapeCreatePipeShellMultiSection` | PASS: rewritten under #766. The circle used to lie in the XY plane, which holds the whole spine, so the kernel's solid was degenerate (mass -6.9e-16) and the test asserted only non-nil; it stands across the spine's start now, and the test asserts valid, SOLID and the volume (Frenet 436.40, corrected Frenet 445.03 on the same spine and profile) |
| pipeShellCorrectedFrenet | `OCCTShapeCreatePipeShellMultiSection` returns nullptr; or maps Frenet to corrected Frenet, corrected Frenet to Frenet and fixed binormal to corrected Frenet | `:183 Expectation failed: Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet)`; modes swapped: `:189 Expectation failed: abs(volume - 299.06536887934379) < 1e-6` | pass | `OCCTShapeCreatePipeShellMultiSection` | PASS: rewritten under #766. The circle used to lie in the XY plane, oblique to the spine's start (volume 84.96 against 299.07 across it); asserts valid, SOLID and the volume (corrected Frenet 299.07, Frenet 293.01) |
| pipeShellFixedBinormal | `OCCTShapeCreatePipeShellMultiSection` returns nullptr; or maps Frenet to corrected Frenet, corrected Frenet to Frenet and fixed binormal to corrected Frenet | `:206 Expectation failed: Shape.pipeShell(spine: spine, profile: profile, mode: .fixed(binormal: SIMD3(0, 0, 1)))`; modes swapped: `:214 Expectation failed: abs(volume - 508.59380610024181) < 1e-6` | pass | `OCCTShapeCreatePipeShellMultiSection` | PASS: rewritten under #766. The XY rectangle on a straight spine along X gave an invalid solid of mass 0; a 5 x 3 rectangle across the start of the 3D spine gives a valid solid, and the volume (fixed binormal 508.59, corrected Frenet 634.64, Frenet 624.29) names the mode |
| pipeShellCreatesShell | `OCCTShapeCreatePipeShellMultiSection` returns nullptr; or ignores `solid: false` and caps the sweep into a solid; or scales the result by 0.5 | `:229 Expectation failed: Shape.pipeShell(spine: spine, profile: profile, mode: .frenet, solid: false)`; solid forced: `:231 Expectation failed: shell.shapeType == .shell`, `:233 Expectation failed: shell.subShapes(ofType: .face).count == 1`, `:235 Expectation failed: abs(area - 376.99111843077515) < 1e-6`; scaled: `:235` | pass | `OCCTShapeCreatePipeShellMultiSection` | PASS: rewritten under #766. The circle had the default Z normal on an X-axis spine, the degenerate sweep of the three pipe tests above, and the test asserted only non-nil; the circle's normal is the spine's direction now and the test asserts SHELL, valid, 1 face and the lateral area 2 * pi * 3 * 20 |
| multiSectionFrenetVaryingRadius | `OCCTShapeCreatePipeShellMultiSection` returns nullptr; or scales the result by 0.5 | `:250 Expectation failed: Shape.pipeShellMultiSection(spine: spine, profiles: stations, mode: .frenet, solid: true)`; scaled: `:258 Expectation failed: abs(volume - 58.643062441853715) < 1e-6` | pass | `OCCTShapeCreatePipeShellMultiSection` | PASS: tightened under #766: `if let v = pipe.volume { #expect(v > 0) }` accepted a nil volume and any positive one; the volume is required and asserted |
| multiSectionAuxiliarySpine | `OCCTShapeCreatePipeShellMultiSection` returns nullptr; or scales the result by 0.5 | `:273 Expectation failed: Shape.pipeShellMultiSection(spine: spine, profiles: [c0, c1], mode: .auxiliary(spine: aux), solid: true)`; scaled: `:280 Expectation failed: abs(volume - 73.30382760882533) < 1e-6` | pass | `OCCTShapeCreatePipeShellMultiSection` | PASS: tightened under #766 (asserted non-nil and valid): the volume, the frustum pi * 10 / 3 * (4 + 2 + 1), is asserted |
| multiSectionProfileCountBounds | `OCCTShapeCreatePipeShellMultiSection` returns nullptr; or scales the result by 0.5 | `:293 Expectation failed: Shape.pipeShellMultiSection(spine: spine, profiles: [one], mode: .frenet)`; scaled: `:297 Expectation failed: abs(volume - 125.6637061435917) < 1e-6` | pass | `OCCTShapeCreatePipeShellMultiSection` | PASS: tightened under #766 (the single-profile half asserted only non-nil): valid and the volume, pi * 4 * 10, are asserted; the empty-profile nil is refused before the kernel (Swift guard and bridge `profileCount < 1`), so only the single-profile half has a kernel counterpart |
| wireLengthLine | `OCCTWireGetLength` returns twice the arc length | `:308 Expectation failed: abs(length! - 10.0) < 0.01` | pass | `OCCTWireGetLength` | PASS |
| wireLengthCircle | `OCCTWireGetLength` returns twice the arc length | `:319 Expectation failed: abs(length! - expected) < 0.1` | pass | `OCCTWireGetLength` | PASS |
| wireCurveInfoCircle | `OCCTWireGetCurveInfo` inverts `isClosed` | `:328 Expectation failed: info!.isClosed` | pass | `OCCTWireGetCurveInfo` | PASS |
| wireCurveInfoLine | `OCCTWireGetCurveInfo` shifts `endX` by +1 | `:342 Expectation failed: abs(info!.endPoint.x - 20.0) < 0.01` | pass | `OCCTWireGetCurveInfo` | PASS |
| wirePointAtParameter | `OCCTWireGetPointAt` shifts x by +1 | `:353 Expectation failed: abs(start!.x) < 0.01`, `:358 Expectation failed: abs(mid!.x - 10.0) < 0.01`, `:363 Expectation failed: abs(end!.x - 20.0) < 0.01` | pass | `OCCTWireGetPointAt` | PASS |
| wireTangentAtParameter | `OCCTWireGetTangentAt` reverses the tangent | `:374 Expectation failed: abs(tangent!.x - 1.0) < 0.01` | pass | `OCCTWireGetTangentAt` | PASS |
| wireCurvatureCircle | `OCCTWireGetCurvatureAt` divides by |d1|^2 instead of |d1|^3 | `:388 Expectation failed: abs(curvature! - 1.0 / radius) < 0.001` | pass | `OCCTWireGetCurvatureAt` | PASS |
| wireCurvatureLine | `OCCTWireGetCurvatureAt` adds 0.01 to the curvature | `:398 Expectation failed: abs(curvature!) < 0.001` | pass | `OCCTWireGetCurvatureAt` | PASS |
| wireCurvePointDerivatives | `OCCTWireGetCurvePointAt` divides by |d1|^2 instead of |d1|^3 | `:409 Expectation failed: abs(cp!.curvature - 1.0 / radius) < 0.001` | pass | `OCCTWireGetCurvePointAt` | PASS |
| wireOffset3D | `OCCTWireOffset3D` translates by -distance | `:425 Expectation failed: abs(info!.startPoint.z - 10.0) < 0.01` | pass | `OCCTWireOffset3D` | PASS |
| bsplineSurface | `OCCTShapeCreateBSplineSurface` returns nullptr | `:441 Expectation failed: surface != nil`, `:442 Expectation failed: surface?.isValid == true` | pass | `OCCTShapeCreateBSplineSurface` | PASS |
| ruledSurfaceBetweenCircles | `OCCTShapeCreateRuled` returns nullptr | `:454 Expectation failed: ruled != nil` | pass | `OCCTShapeCreateRuled` | PASS |
| shellWithOpenFaces | `OCCTShapeShellWithOpenFaces` returns nullptr | `:466 Expectation failed: shelled != nil`, `:467 Expectation failed: shelled?.isValid == true` | pass | `OCCTShapeShellWithOpenFaces` | PASS |
| shellWithSpecificFaceOpen | `OCCTShapeShellWithOpenFaces` returns nullptr | `:479 Expectation failed: shelled != nil` | pass | `OCCTShapeShellWithOpenFaces` | PASS |
