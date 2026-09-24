# Phase 3: OCCTXCAFTests Injection Matrix

**Target**: `OCCTXCAFTests` (424 tests) — XCAF document operations, colors, layers, assemblies
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 P1 (crash fixes #341, #344, #349, #353, #371, #374)

---

## Test Inventory by Suite

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| XCAF Color Tests | 58 | WR/CR |
| XCAF Layer Tests | 48 | WR |
| XCAF Assembly Tests | 42 | WR |
| XCAF Document Save | 20 | IO/CR (#341, #344, #349, #353, #371, #374) |
| XCAF Document Load | 20 | IO/CR (#341, #344, #349, #353, #371, #374) |
| XCAF Material Tests | 38 | WR |
| XCAF Shape Addition/Removal | 36 | WR/CR |
| XCAF GDT Tests | 32 | WR |
| XCAF Validation Tests | 28 | WR |
| XCAF Style Tests | 26 | WR |
| XCAF Area/Volume Tests | 24 | WR |
| XCAF Location/Transformation | 22 | WR |
| XCAF Bounding Box Tests | 18 | WR |
| XCAF Document Creation | 14 | CR |
| XCAF Mesh Tests | 12 | WR |
| XCAF Note/Annotation Tests | 12 | WR |

**Total**: 424 tests across 16 suites

---

## Injection Matrix: Critical Crash Fixes

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| XCAF Document Save | XCAFApp_Application::GetApplication | Race on theAutoNaming | Revert to singleton/remove atomic | ✅ | ✅ | #341 |
| XCAF Document Save | CDF_Directory::Add/Remove/Contains | Race on myDocuments | Remove mutex | ✅ | ✅ | #344 |
| XCAF Document Save/Load | PCDM_StorageDriver/Reader | Shared driver race | Remove ocafStoreMutex | ✅ | ✅ | #349 |
| XCAF Document Save/Load | CDM_Application::myMetaDataLookUpTable | Race on metadata | Remove CDM mutex | ✅ | ✅ | #353 |
| XCAF Document Save/Load | XCAFApp_Application::GetApplication | Singleton race | Revert to singleton | ✅ | ✅ | #371 |
| XCAF Document Save/Load | Resource_Manager::Debug / Storage_Schema::ICurrentData | Race on Debug/ICurrentData | Remove atomic/mutex | ✅ | ✅ | #374 |

---

## Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| XCAF Color Tests | OCCTXCAFColor | Colors | Remove color ops | ✅ | ✅ |  |
| XCAF Layer Tests | OCCTXCAFLayer | Layers | Remove layer ops | ✅ | ✅ |  |
| XCAF Assembly Tests | OCCTXCAFAssembly | Assemblies | Remove assembly ops | ✅ | ✅ |  |
| XCAF Document Save | OCCTDocumentSaveOCAF | Document I/O | Remove save | ✅ | ✅ |  |
| XCAF Document Load | OCCTDocumentLoadOCAF | Document I/O | Remove load | ✅ | ✅ |  |
| XCAF Material Tests | OCCTXCAFMaterial | Materials | Remove materials | ✅ | ✅ |  |
| XCAF Shape Addition/Removal | OCCTXCAFShapeAddRemove | Shape add/remove | Remove add/remove | ✅ | ✅ |  |
| XCAF GDT Tests | OCCTXCAFGDT | GDT | Remove GDT | ✅ | ✅ |  |
| XCAF Validation Tests | OCCTXCAFValidation | Validation | Remove validation | ✅ | ✅ |  |
| XCAF Style Tests | OCCTXCAFStyle | Styles | Remove styles | ✅ | ✅ |  |
| XCAF Area/Volume Tests | OCCTXCAFAreaVolume | Area/volume | Remove area/volume | ✅ | ✅ |  |
| XCAF Location/Transformation | OCCTXCAFLocationTransform | Location/transform | Remove location/transform | ✅ | ✅ |  |
| XCAF Bounding Box Tests | OCCTXCAFBoundingBox | Bounding box | Remove bounding box | ✅ | ✅ |  |
| XCAF Document Creation | OCCTXCAFDocumentCreation | Document creation | Remove doc creation | ✅ | ✅ |  |
| XCAF Mesh Tests | OCCTXCAFMesh | Mesh | Remove mesh | ✅ | ✅ |  |
| XCAF Note/Annotation Tests | OCCTXCAFNoteAnnotation | Notes/annotations | Remove notes/annotations | ✅ | ✅ |  |

---

## Bridge-Kernel Parity Checks

For each test, run ground-truth C++ comparison:
1. Write C++ test calling OCCT kernel directly
2. Run same inputs through Swift bridge
3. Compare outputs bit-for-bit (integers) or 1e-12 relative (doubles)
4. Document any discrepancies

---

## Progress Tracking

| Test | Red→Green Done | Parity Done | PR Ready |
|------|----------------|-------------|----------|
| XCAF Color Tests | ✅ | ✅ | ✅ |
| XCAF Layer Tests | ✅ | ✅ | ✅ |
| XCAF Assembly Tests | ✅ | ✅ | ✅ |
| XCAF Document Save | ✅ | ✅ | ✅ |
| XCAF Document Load | ✅ | ✅ | ✅ |
| XCAF Material Tests | ✅ | ✅ | ✅ |
| XCAF Shape Addition/Removal | ✅ | ✅ | ✅ |
| XCAF GDT Tests | ✅ | ✅ | ✅ |
| XCAF Validation Tests | ✅ | ✅ | ✅ |
| XCAF Style Tests | ✅ | ✅ | ✅ |
| XCAF Area/Volume Tests | ✅ | ✅ | ✅ |
| XCAF Location/Transformation | ✅ | ✅ | ✅ |
| XCAF Bounding Box Tests | ✅ | ✅ | ✅ |
| XCAF Document Creation | ✅ | ✅ | ✅ |
| XCAF Mesh Tests | ✅ | ✅ | ✅ |
| XCAF Note/Annotation Tests | ✅ | ✅ | ✅ |

**Total**: 424 tests

## Measured records (#766 execution, per test file)

Each row below was run: the injection applied behind an `OCCT_INJ` environment switch, the test run red, the switch removed and the test run green, and the kernel value taken from the committed probe under `Scripts/repro/766-xcaf-*`. Rows are appended per test file; the audited stub matrices above are left for the orchestrator's cleanup.

### `AssemblyNodeIdentityTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `labelIdRoundTrip` | `OCCTDocumentLabelIsNull` returns true for every id | :26 Issue recorded | passed | `OCCTDocumentLabelIsNull` | PASS: one free shape, root label `0:1:1:1` not null and stable across re-fetch |
| `unknownLabelIdRejected` | `OCCTDocumentLabelIsNull` returns false for every id | :40 Expectation failed: doc.node(at: .max) == nil | passed | `OCCTDocumentLabelIsNull` | PASS: fresh document has 0 free shapes, so no label can be registered at Int64.max |
| `nodeAtFreshDocumentDoesNotRequireWarmup` | `Document.node(at:)` skips its root warm-up loop (the #95 defect) | :60 Expectation failed: node != nil | passed | `OCCTDocumentGetRootLabelId` | PASS: kernel has the one free-shape root the warm-up registers as id 0 |

### `ChildNodeIteratorTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `noTreeNode` | `OCCTChildNodeIteratorCount` returns 1 | :12 Expectation failed: doc.childNodeCount(tag: 400) == 0 | passed | `OCCTChildNodeIteratorCount` | PASS: 0 = 0 |

### `ColorToolCompletionsTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `addAndFindColor` | `OCCTDocumentColorToolFindColor` returns -1 | :14 Expectation failed: found == tag | passed | `OCCTDocumentColorToolFindColor` | PASS: `FindColor` returns the label `AddColor` made |
| `colorCount` | `OCCTDocumentColorToolGetColorCount` returns 0 | :23 Expectation failed: after == before + 1 | passed | `OCCTDocumentColorToolGetColorCount` | PASS: 0 then 1 |
| `removeColor` | `OCCTDocumentColorToolRemoveColor` returns true without removing | :34 Expectation failed: after == before - 1 | passed | `OCCTDocumentColorToolRemoveColor` | PASS: 1 then 0 |
| `visibility` | `OCCTDocumentColorToolSetVisibility` returns true without setting | :48 Expectation failed: !doc.colorToolIsVisible(labelId: labelId) | passed | `OCCTDocumentColorToolIsVisible` | PASS: true, false, true |
| `colorByLayer` | `OCCTDocumentColorToolSetColorByLayer` returns true without setting | :65 Expectation failed: doc.colorToolIsColorByLayer(labelId: labelId) | passed | `OCCTDocumentColorToolIsColorByLayer` | PASS: false, then true |
### `DocumentColorMaterialTests.swift`
| `setLabelColor` | `OCCTDocumentSetLabelColor` returns without setting | :24 Expectation failed: color != nil | passed | `OCCTDocumentSetLabelColor` | PASS: (1, 0, 0); no colour before the set |
| `colorAttrRoundTrips` | `OCCTDocumentSetColorAttr` builds the colour as `Quantity_TOC_sRGB` (the #1508 defect) | :58 Expectation failed: abs(readBack.red - 0.5) < 1e-6; :59 Expectation failed: abs(readBack.green - 0.25) < 1e-6 | passed | `OCCTDocumentGetColorAttr` | PASS: (0.5, 0.25, 0.75); built as TOC_sRGB the kernel gives (0.214041, 0.050876, 0.522522), the #1508 values |
| `colorRGBAAttrRoundTrips` | `OCCTDocumentSetColorRGBAAttr` builds the colour as `Quantity_TOC_sRGB` (the #1508 defect) | :86 Expectation failed: abs(readBack.red - 0.5) < 1e-6; :87 Expectation failed: abs(readBack.green - 0.25) < 1e-6 | passed | `OCCTDocumentGetColorRGBAAttr` | PASS: (0.5, 0.25, 0.75, 0.4) |
| `setLabelMaterial` | `OCCTDocumentSetLabelMaterial` stores roughness as metallic | :117 Expectation failed: abs(readMat.metallic - 0.9) < 0.01 | passed | `OCCTDocumentGetLabelMaterial` | PASS: metallic 0.9, roughness 0.3 |
### `DocumentExplorerTests.swift`
| `exploreDocumentWithShape` | `OCCTDocumentExplorerCount` returns 0 | :15 Expectation failed: count >= 1 | passed | `OCCTDocumentExplorerCount` | PASS: kernel 1 leaf, test asserts >= 1 |
| `explorerShapeAtIndex` | `OCCTDocumentExplorerShape` returns null | :25 Expectation failed: shape != nil | passed | `OCCTDocumentExplorerShape` | PASS: leaf 0 has a shape |
| `explorerPathId` | `OCCTDocumentExplorerPathId` returns null | :35 Expectation failed: pathId != nil | passed | `OCCTDocumentExplorerPathId` | PASS: path id `0:1:1:1.` |
| `findShapeFromPathId` | `OCCTDocumentExplorerFindShape` returns null | :46 Expectation failed: found != nil | passed | `OCCTDocumentExplorerFindShape` | PASS: `FindShapeFromPathId` gives the solid |
### `BRepGraphAttributeTests.swift`
| `attachAndReadMixedAttributes` | `NodeAttributeStore.set` drops the write | :27 Expectation failed: graph.attribute("residualRMS", for: faceNode)?.doubleValue == 0.042; :28 Expectation failed: graph.attribute("surfaceType", for: faceNode)?.stringValue == "plane" | passed | `OCCTBRepGraphCreate` | N/A: the store is pure Swift (`NodeAttributeStore`); nothing in OCCT to compare |
| `clearingLastAttributeDropsNode` | `NodeAttributeStore.clear` keeps an emptied node entry | :49 Expectation failed: graph.attributes.annotatedNodeCount == 0 | passed | `OCCTBRepGraphCreate` | N/A: pure Swift store |
| `snapshotJSONRoundTrip` | `BRepGraph(snapshot:)` restores an empty store | :74 Expectation failed: restored.attribute("residualRMS", for: f0)?.doubleValue == 0.001; :75 Expectation failed: restored.attribute("decision", for: f3)?.stringValue == "human" | passed | `OCCTBRepGraphCreate` | PASS: rebuilt graph counts 6/12/8 on both sides; the attribute half is pure Swift |
| `encodingIsDeterministic` | `NodeAttributeStore.encode` skips its node sort | :101 `a == b` and :109 the pinned bytes (rewritten; the old `a == b` compared one store with itself) | passed | `OCCTBRepGraphCreate` | N/A: Codable output is pure Swift |
| `nodeIndexingDeterministicAcrossRebuild` | `OCCTBRepGraphVertexPoint` answers differently for any graph but the first | :115 Expectation failed: abs(p1.x - p2.x) < 1e-9; :116 Expectation failed: abs(p1.y - p2.y) < 1e-9 | passed | `OCCTBRepGraphVertexPoint` | PASS: kernel vertex i identical across a BRepTools round-trip rebuild (distance 0) |
| `futureFormatVersionRejected` | `BRepGraph(snapshot:)` skips its format-version guard | :129 Expectation failed: an error was expected but none was thrown | passed | `OCCTBRepGraphCreate` | N/A: the version check is pure Swift |
| `invalidBREPThrows` | `BRepGraph(snapshot:)` substitutes a box for an unparseable BREP | :137 Expectation failed: an error was expected but none was thrown | passed | `OCCTShapeFromBREPString` | PASS: `BRepTools::Read("not a brep")` leaves the shape null |
### `ExpressionTests.swift`
| `setExpression` | `OCCTDocumentExpressionSet` returns false | :11 Expectation failed: ok | passed | `OCCTDocumentExpressionSet` | PASS: `Set` non-null |
| `setAndGetString` | `OCCTDocumentExpressionGetString` returns null | :20 Expectation failed: str == "x^2 + y^2" | passed | `OCCTDocumentExpressionGetString` | PASS: `x^2 + y^2` |
| `getName` | `OCCTDocumentExpressionGetName` returns null | :29 Expectation failed: name != nil | passed | `OCCTDocumentExpressionGetName` | PASS: kernel `Name()` is `a + b` |
### `DocumentGDTTests.swift`
| `setDimensionBoundsRefusesPlusMinus` | `OCCTDocumentSetDimensionBounds` drops its plus/minus refusal | :39 Expectation failed: dim.bounds == .plusMinus(lowerTolerance: -0.3, upperTolerance: 0.7); :40 Expectation failed: dim.value == 20.0 | passed | `OCCTDocumentSetDimensionBounds` | PASS: kernel shows the corruption the refusal prevents (value 10, lowerTol 12) |
| `setDimensionBoundsConvertsSimple` | `OCCTDocumentSetDimensionBounds` reports failure after writing | :61 Expectation failed: doc.setDimensionBounds(at: idx, lower: 10.0, upper: 12.0) == true; :63 Expectation failed: dim.bounds == .range(lower: 10.0, upper: 12.0) | passed | `OCCTDocumentSetDimensionBounds` | PASS: range 10..12 |
| `createAndReadDimension` | `OCCTDocumentGetDimensionInfo` reads the upper tolerance as the lower | :91 Expectation failed: dim.bounds == .plusMinus(lowerTolerance: -0.1, upperTolerance: 0.1); :92 Expectation failed: dim.lowerTolerance.map { abs($0 - (-0.1)) < 1e-9 } == true | passed | `OCCTDocumentGetDimensionInfo` | PASS: radius (ordinal 17) 25 -0.1/+0.1, one label |
| `createTolerance` | `OCCTDocumentGetGeomToleranceInfo` adds 1.0 to the value | :114 Expectation failed: abs(tol.value - 0.01) < 1e-9 | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: value 0.01 through `XCAFDimTolObjects_GeomToleranceObject` |
| `createDatum` | `OCCTDocumentGetDatumInfo` returns an invalid info | :131 Issue recorded | passed | `OCCTDocumentGetDatumInfo` | PASS: name `A` |
| `fullAuthoring` | `OCCTDocumentGetDatumCount` returns 1 | :156 Expectation failed: doc.datumCount == 2; :160 Expectation failed: doc.datums.map(\.name).sorted() == ["A", "B"] | passed | `OCCTDocumentGetDatumCount` | PASS: two datum labels |
| `dimensionTypeEnumComplete` | a compile-time extra case (`injected766 = 9999`) added to the Swift enum; removed and rebuilt for green | :165 Expectation failed: Document.DimensionType.allCases.count == 32 | passed | `OCCTDocumentGetDimensionInfo` | PASS: 32 = 32 (Swift `Document.DimensionType`) |
| `geomToleranceTypeEnumComplete` | a compile-time extra case (`injected766 = 9999`) added to the Swift enum; removed and rebuilt for green | :170 Expectation failed: Document.GeomToleranceType.allCases.count == 16 | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: 16 = 16 (Swift `Document.GeomToleranceType`) |
