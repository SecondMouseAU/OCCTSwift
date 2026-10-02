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
### `BOPAlgoBuilderFaceTests.swift` (1 tests)
Probe: `Scripts/repro/766-modeling-bopalgo-builder-face/`.
| buildFaceFromEdges | `OCCTBOPAlgoBuilderFace` returns false, or returns the face twice, or a face of area 1; `OCCTSurfacePlaneFromPointNormal` or `OCCTShapeCreateFaceFromSurface` returns nullptr | `:20 Expectation failed: f.buildFaces(from: edges)` (false); `:22 Expectation failed: r.count == 1` (twice); `:25 Expectation failed: abs(area - 100) < 1e-6` (area 1); `:16 Expectation failed: Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))`, `:17 Expectation failed: Shape.face(from: s, uRange: -5...5, vRange: -5...5)` (fixtures) | pass | `OCCTBOPAlgoBuilderFace` | PASS: rewritten: every step sat in a nested `if let`, so a fixture failure passed, and the count was only `>= 1` |
### `BOPAlgoBuilderSolidTests.swift` (1 tests)
Probe: `Scripts/repro/766-modeling-bopalgo-builder-solid/`.
| buildSolidFromFaces | `OCCTBOPAlgoBuilderSolid` returns false, or returns two results, or a solid of volume 8; `OCCTShapeCreateBox` returns nullptr | `:18 Expectation failed: Shape.buildSolids(from: faces)` (false); `:20 Expectation failed: r.count == 1`, `:23 Expectation failed: solid.volume` (two results, faces not solids); `:24 Expectation failed: abs(volume - 1000) < 1e-6` (volume 8); `:15 Expectation failed: Shape.box(width: 10, height: 10, depth: 10)` (fixture) | pass | `OCCTBOPAlgoBuilderSolid` | PASS: rewritten: every step sat in a nested `if let`, so a fixture failure passed, and the count was only `>= 1` |
### `BOPAlgoCellsBuilderTests.swift` (3 tests)
Probe: `Scripts/repro/766-modeling-bopalgo-cells-builder/`.
| createCellsBuilder | `OCCTCellsBuilderCreate` returns nullptr | `:17 Expectation failed: builder != nil` | pass | `OCCTCellsBuilderCreate` | PASS |
| addRemoveAll | `OCCTCellsBuilderRemoveAllFromResult` does nothing | `:50 Expectation failed: result2?.solids.count == 0` | pass | `OCCTCellsBuilderRemoveAllFromResult` | PASS: rewritten: all assertions sat inside if-let of the builder, and non-nil held after a no-op RemoveAll |
| removeInternalBoundaries | `OCCTCellsBuilderRemoveInternalBoundaries` does nothing | `:81 Expectation failed: result.solids.count == 1` | pass | `OCCTCellsBuilderRemoveInternalBoundaries` | PASS: rewritten: AddAllToResult(update: true) already merges, so the old fixture could not observe RemoveInternalBoundaries |
### `BOPAlgoSectionTests.swift` (3 tests)
Probe: `Scripts/repro/766-modeling-bopalgo-section/`.
| sectionBoxSphere | `OCCTBOPAlgoSection` returns nullptr, or returns its first object; `OCCTShapeCreateBox` or `OCCTShapeCreateSphere` returns nullptr | `:20 Expectation failed: box.section(with: [sphere])` (nullptr); `:22 Expectation failed: edges.count == 7` (first object); `:18 Expectation failed: Shape.box(width: 10, height: 10, depth: 10)`, `:19 Expectation failed: Shape.sphere(radius: 6)` (fixtures) | pass | `OCCTBOPAlgoSection` | PASS: rewritten: asserted only inside if-let of the result; a fixture failure returned silently (`guard ... else { return }`) and is now `try #require` |
| sectionTwoBoxes | `OCCTBOPAlgoSection` returns nullptr, or returns its first object; `OCCTShapeCreateBox` or `OCCTShapeCreateBoxAt` returns nullptr | `:30 Expectation failed: box1.section(with: [box2])` (nullptr); `:31 Expectation failed: result.shapeType == .compound`, `:32 Expectation failed: result.subShapes(ofType: .edge).count == 1` (first object); `:27 Expectation failed: Shape.box(width: 10, height: 10, depth: 10)`, `:28 Expectation failed: Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10)` (fixtures) | pass | `OCCTBOPAlgoSection` | PASS: rewritten; the boxes only touch along the line x = y = 5; a fixture failure returned silently and is now `try #require` |
| staticSection | `OCCTBOPAlgoSection` returns nullptr, or returns its first object; `OCCTShapeCreateBox` or `OCCTShapeCreateSphere` returns nullptr | `:39 Expectation failed: Shape.section(shapes: [box, sphere])` (nullptr); `:41 Expectation failed: edges.count == 7` (first object); `:37 Expectation failed: Shape.box(width: 10, height: 10, depth: 10)`, `:38 Expectation failed: Shape.sphere(radius: 7)` (fixtures) | pass | `OCCTBOPAlgoSection` | PASS: rewritten: asserted only inside if-let of the result; a fixture failure returned silently and is now `try #require` |
### `BOPAlgoShellSplitterTests.swift` (1 tests)
Probe: `Scripts/repro/766-modeling-bopalgo-shell-splitter/`.
| splitSingleShell | `OCCTBOPAlgoShellSplitter` returns false, or returns the shell twice; `OCCTShapeCreateBox` returns nullptr | `:15 Expectation failed: shell.splitShell()` (false); `:19 Expectation failed: r.count == 1` (twice); `:12 Expectation failed: Shape.box(width: 10, height: 10, depth: 10)` (fixture) | pass | `OCCTBOPAlgoShellSplitter` | PASS: rewritten: every step sat in a nested `if let`, so a fixture failure passed |
### `BOPAlgoSplitterTests.swift` (2 tests)
Probe: `Scripts/repro/766-modeling-bopalgo-splitter/`.
| splitBoxes | `OCCTBOPAlgoSplit` returns nullptr | `:21 Issue recorded` | pass | `OCCTBOPAlgoSplit` | PASS: rewritten; the tool shares only the face x = 10 with the object, so nothing is split |
| splitProducesMultipleSolids | `OCCTBOPAlgoSplit` never adds its tools to the BOPAlgo_Splitter | `:40 Issue recorded` | pass | `OCCTBOPAlgoSplit` | PASS: rewritten: asserted only inside if-let of the result |
### `BOPAlgoToolsTests.swift` (2 tests)
Probe: `Scripts/repro/766-modeling-bopalgo-tools/`.
| edgesToWires | `OCCTBOPAlgoEdgesToWires` returns nullptr, or a compound of four single-edge wires; `OCCTBRepLibMakeEdgeFromPoints` or `OCCTShapeCreateCompound` returns nullptr | `:20 Expectation failed: c.edgesToWires()` (nullptr); `:23 Expectation failed: wires.count == 1` (four wires); `:15 Expectation failed: Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))`, `:19 Expectation failed: Shape.compound([edge1, edge2, edge3, edge4])` (fixtures) | pass | `OCCTBOPAlgoEdgesToWires` | PASS: rewritten: every step sat in a nested `if let`, so a fixture failure passed, and the count was only `>= 1` |
| wiresToFaces | `OCCTBOPAlgoWiresToFaces` returns nullptr, or two faces, or a face of area 1; `OCCTBOPAlgoEdgesToWires` returns nullptr | `:37 Expectation failed: w.wiresToFaces()` (nullptr); `:40 Expectation failed: faces.count == 1` (two faces); `:43 Expectation failed: abs(area - 100) < 1e-6` (area 1); `:36 Expectation failed: c.edgesToWires()` (previous step) | pass | `OCCTBOPAlgoWiresToFaces` | PASS: rewritten: every step sat in a nested `if let`, so a fixture failure passed, and the count was only `>= 1` |
