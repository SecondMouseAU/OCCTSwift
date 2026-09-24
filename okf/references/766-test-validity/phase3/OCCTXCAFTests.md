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
### `GDTDimensionAccessorTests.swift`
| `qualifierRoundTrips` | `OCCTDocumentGetDimensionInfo` reports qualifier 0 | :42 Expectation failed: qualified.qualifier == .max | passed | `OCCTDocumentGetDimensionInfo` | PASS: 0, Max (2), 0; value 20 and simple kept |
| `angularQualifierRoundTrips` | `OCCTDocumentGetDimensionInfo` reports angular qualifier 0 | :69 Expectation failed: both.angularQualifier == .large | passed | `OCCTDocumentGetDimensionInfo` | PASS: Min (1), Large (2) |
| `decimalPlacesDistinguishAbsenceFromZero` | `OCCTDocumentGetDimensionInfo` tests decimal-place presence with `&&` instead of `or` | :102 Issue recorded | passed | `OCCTDocumentGetDimensionInfo` | PASS: (2,3), (0,4) and (0,0) read back as written; the bridge maps (0,0) to absent |
| `modifiersRoundTripInOrder` | `OCCTDocumentGetDimensionModifier` swaps modifier indices 0 and 1 | :123 Expectation failed: doc.dimension(at: index)?.modifiers == written | passed | `OCCTDocumentGetDimensionModifier` | PASS: order 19, 1, 2 kept; cleared to 0 |
| `typeClassifiersMatchOCCT` | `OCCTDimensionTypeIsDimensionalLocation` returns true | :137 Expectation failed: !Document.DimensionType.sizeDiameter.isDimensionalLocation; :140 Expectation failed: !Document.DimensionType.commonLabel.isDimensionalLocation | passed | `OCCTDimensionTypeIsDimensionalLocation` | PASS: identical, and no type is both |
| `accessorsAreNotSharedBetweenDimensions` | `OCCTDocumentSetDimensionDecimalPlaces` writes to dimension 0 | :173 Expectation failed: a.decimalPlaces == nil; :177 Expectation failed: b.decimalPlaces?.left == 1 | passed | `OCCTDocumentSetDimensionDecimalPlaces` | PASS: separate objects keep separate values |
| `outOfRangeIndicesAreRefused` | `OCCTDocumentSetDimensionQualifier` returns true without checking the index | :193 Expectation failed: !doc.setDimensionQualifier(at: 5, .max) | passed | `OCCTDocumentSetDimensionQualifier` | PASS: one dimension label, so index 5 is out of range |
### `GDTDocumentTests.swift`
| `emptyDocDimensions` | `OCCTDocumentGetDimensionCount` returns 1 | :16 Expectation failed: doc.dimensionCount == 0 | passed | `OCCTDocumentGetDimensionCount` | PASS: 0 = 0 |
| `emptyDocTolerances` | `OCCTDocumentGetGeomToleranceCount` returns 1 | :26 Expectation failed: doc.geomToleranceCount == 0 | passed | `OCCTDocumentGetGeomToleranceCount` | PASS: 0 = 0 |
| `emptyDocDatums` | `OCCTDocumentGetDatumCount` returns 1 | :36 Expectation failed: doc.datumCount == 0 | passed | `OCCTDocumentGetDatumCount` | PASS: 0 on a fresh document |
| `dimensionInvalidIndex` | `OCCTDocumentGetDimensionInfo` returns a valid info for any index | :46 Expectation failed: doc.dimension(at: 0) == nil; :47 Expectation failed: doc.dimension(at: -1) == nil | passed | `OCCTDocumentGetDimensionInfo` | PASS: no dimensions, every index out of range |
| `toleranceInvalidIndex` | `OCCTDocumentGetGeomToleranceInfo` returns a valid info for any index | :57 Expectation failed: doc.geomTolerance(at: 0) == nil; :58 Expectation failed: doc.geomTolerance(at: -1) == nil | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: no tolerances |
| `datumInvalidIndex` | `OCCTDocumentGetDatumInfo` returns a valid info and `OCCTDocumentGetDatumName` an empty name for any index | :67 Expectation failed: doc.datum(at: 0) == nil; :68 Expectation failed: doc.datum(at: -1) == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: no datums |
### `GDTToleranceDatumAccessorTests.swift`
| `toleranceSemanticsRoundTrip` | `OCCTDocumentGetGeomToleranceInfo` reports material requirement 0 | :59 Expectation failed: tol.materialRequirement == .m | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: written values read back; value 0.1, type Position (10) |
| `toleranceZeroValuesAreAbsence` | `OCCTDocumentGetGeomToleranceInfo` treats a zero zone value as present (`>=` for `>`) | :86 Expectation failed: tol.zoneModifierValue == nil | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: kernel stores 0 and 0 with the zone kept; the bridge maps 0 to absent |
| `toleranceModifiersRoundTripInOrder` | `OCCTDocumentGetGeomToleranceModifier` swaps modifier indices 0 and 1 | :107 Expectation failed: doc.geomTolerance(at: index)?.modifiers == written | passed | `OCCTDocumentGetGeomToleranceModifier` | PASS: order kept (3, 15, 13) |
| `datumPositionRoundTrips` | `OCCTDocumentGetDatumInfo` treats position 0 as a place in the frame (`>=` for `>`) | :123 Expectation failed: doc.datum(at: index)?.position == nil; :129 Expectation failed: doc.datum(at: index)?.position == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: 0, 2, 0; the bridge maps 0 to no place |
| `datumModifiersRoundTrip` | `OCCTDocumentGetDatumInfo` drops the valued modifier's value | :152 Expectation failed: datum.modifierWithValue?.value == 12.5 | passed | `OCCTDocumentGetDatumInfo` | PASS: 2, 3; Projected (3) 12.5; cleared to None |
| `datumTargetDimensionsFollowTheType` | `OCCTDocumentGetDatumInfo` reports a width for every target type | :208 Expectation failed: target.width == nil; :217 Expectation failed: target.width == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: the kernel keeps 30 and 18 for every type; the bridge reports length unless Point and width only for Rectangle |
| `degenerateDatumTargetAxisIsRefused` | `OCCTDocumentSetDatumTargetPlacement` substitutes a valid axis for a degenerate one | :235 Expectation failed: !doc.setDatumTargetPlacement(at: index, location: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 0), reference: SIMD3(1, 0, 0), length: 10, width: 0); :244 Expectation failed: doc.datum(at: index)?.target?.length == nil | passed | `OCCTDocumentSetDatumTargetPlacement` | PASS: `gp_Dir(0,0,0)` throws, which the bridge's catch turns into a refusal |
| `accessorsAreNotSharedBetweenEntries` | `OCCTDocumentSetDatumTarget` writes to datum 0 | :282 Expectation failed: a.target == nil; :285 Expectation failed: b.target?.type == .circle | passed | `OCCTDocumentSetDatumTarget` | PASS: separate objects keep separate values |
| `outOfRangeIndicesAreRefused` | `OCCTDocumentSetGeomToleranceTypeOfValue` returns true without checking the index | :299 Expectation failed: !doc.setGeomToleranceValueType(at: 5, .diameter) | passed | `OCCTDocumentSetGeomToleranceTypeOfValue` | PASS: one tolerance and no datums, so index 5 and datum 0 are out of range |
### `Issue1037GDTEnumRangeTests.swift`
| `dimensionModifierOutOfRangeIsRefused` | `OCCTDocumentSetDimensionModifiers` skips its enum range check | :68 Expectation failed: !rejected; :68 Expectation failed: !rejected | passed | `OCCTDocumentSetDimensionModifiers` | PASS: range 0..23, so 24 names nothing |
| `classOfToleranceOutOfRangeIsRefused` | `OCCTDocumentSetDimensionClassOfTolerance` skips its enum range check | :93 Expectation failed: !OCCTDocumentSetDimensionClassOfTolerance(doc.handle, Int32(index), true, 29, 7); :94 Expectation failed: !OCCTDocumentSetDimensionClassOfTolerance(doc.handle, Int32(index), true, 9999, 7) | passed | `OCCTDocumentSetDimensionClassOfTolerance` | PASS: form variance 0..28, grade 0..19; H 11, IT6 7 |
| `geomToleranceModifierOutOfRangeIsRefused` | `OCCTDocumentSetGeomToleranceModifiers` skips its enum range check | :128 Expectation failed: !rejected; :128 Expectation failed: !rejected | passed | `OCCTDocumentSetGeomToleranceModifiers` | PASS: range 0..16, so 17 names nothing |
| `datumModifierOutOfRangeIsRefused` | `OCCTDocumentSetDatumModifiers` skips its enum range check | :152 Expectation failed: !rejected; :152 Expectation failed: !rejected | passed | `OCCTDocumentSetDatumModifiers` | PASS: range 0..21 |
| `emptyModifierArrayStillClears` | `OCCTDocumentSetDatumModifiers` refuses a count of 0 | :169 Expectation failed: OCCTDocumentSetDatumModifiers(doc.handle, Int32(index), nil, 0); :170 Expectation failed: doc.datum(at: index)?.modifiers.isEmpty == true | passed | `OCCTDocumentSetDatumModifiers` | PASS: an empty sequence clears to 0 |
### `Issue1038DatumTargetPlacementTests.swift`
| `placementOnANonTargetIsRefused` | `OCCTDocumentSetDatumTargetPlacement` skips its is-a-target refusal | :40 Expectation failed: !placement(doc, index, length: 30, width: 18) | passed | `OCCTDocumentSetDatumTargetPlacement` | PASS: a fresh datum is not a target |
| `placementOnAnAreaTargetIsRefused` | `OCCTDocumentSetDatumTargetPlacement` skips its Area refusal | :53 Expectation failed: !placement(doc, index, length: 30, width: 18) | passed | `OCCTDocumentSetDatumTargetPlacement` | PASS: Area (4) takes a shape, not an axis |
| `placementOnARectangleTargetStillWorks` | `OCCTDocumentSetDatumTargetPlacement` stores the width as the length | :73 Expectation failed: target?.length == 30 | passed | `OCCTDocumentSetDatumTargetPlacement` | PASS: 30 x 18 |
| `placementAfterClearingTheTargetIsRefused` | `OCCTDocumentSetDatumTargetPlacement` skips its is-a-target refusal | :87 Expectation failed: !placement(doc, index, length: 44, width: 22) | passed | `OCCTDocumentSetDatumTargetPlacement` | PASS: no longer a target after `IsDatumTarget(false)` |
### `Issue1055DatumNameLengthTests.swift`
| `longNameRoundTrips` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :38 Expectation failed: datum.name.count == 100; :39 Expectation failed: datum.name == name | passed | `OCCTDocumentGetDatumName` | PASS: 100 chars both sides |
| `namesAroundTheOldBoundRoundTrip` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :56 Expectation failed: datum.name == name; :56 Expectation failed: datum.name == name | passed | `OCCTDocumentGetDatumName` | PASS: 63, 64, 65 kept |
| `shortBufferReportsTheFullLength` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :77 Expectation failed: reported == 100 | passed | `OCCTDocumentGetDatumName` | PASS: full length 100 |
| `nullBufferReportsTheLength` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :95 Expectation failed: OCCTDocumentGetDatumName(doc.handle, Int32(index), nil, 0) == 100 | passed | `OCCTDocumentGetDatumName` | PASS: 100 |
| `malformedBufferArgumentsAreRefused` | `OCCTDocumentGetDatumName` accepts a negative length | :112 Expectation failed: OCCTDocumentGetDatumName(doc.handle, Int32(index), &buffer, -1) == -1 | passed | `OCCTDocumentGetDatumName` | N/A: argument validation is the bridge's own; no kernel call |
| `datumsEnumerationCarriesWholeNames` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :125 Expectation failed: doc.datums.map(\.name) == names | passed | `OCCTDocumentGetDatumName` | PASS: 1, 100, 200 |
### `Issue1078LayerNameLengthTests.swift`
| `longNameRoundTrips` | `OCCTDocumentGetLayerName` writes an empty name | :37 Expectation failed: !name.isEmpty; :37 Expectation failed: !name.isEmpty | passed | `OCCTDocumentGetLayerName` | MISMATCH: bridge and kernel agree on what the bridge reads, but it reads the wrong table: #2413 |
| `nullBufferReportsTheLength` | `OCCTDocumentGetLayerName` clamps any index to 0 | :56 Expectation failed: OCCTDocumentGetLayerName(handle, count, nil, 0) == -1; :57 Expectation failed: OCCTDocumentGetLayerName(handle, -1, nil, 0) == -1 | passed | `OCCTDocumentGetLayerName` | PASS: 3 entries, so index 3 and -1 are out of range |
| `shortBufferReportsTheFullLength` | `OCCTDocumentGetLayerName` reports the copied length, not the full one | :76 Expectation failed: reported == len | passed | `OCCTDocumentGetLayerName` | PASS: only `VisMaterials` (12) exceeds 10 |
| `malformedBufferArgumentsAreRefused` | `OCCTDocumentGetLayerName` answers 5 for a negative length | :95 Expectation failed: OCCTDocumentGetLayerName(handle, 0, &buffer, -1) == -1 | passed | `OCCTDocumentGetLayerName` | N/A: bridge-only validation |
### `DocumentModifiedTests.swift`
| `setAndCheckModified` | `OCCTDocumentSetModified` returns without marking | :22 Expectation failed: doc.isModified(label) | passed | `OCCTDocumentIsLabelModified` | PASS: true = true |
| `clearModified` | `OCCTDocumentClearModified` returns without purging | :39 Expectation failed: !doc.isModified(label) | passed | `OCCTDocumentClearModified` | PASS: true, then false after `PurgeModified` |
### `DocumentTests.swift`
| `createEmptyDocument` | `OCCTDocumentGetRootCount` returns 1 and `OCCTDocumentGetRootLabelId` returns 0 | :14 Expectation failed: doc.rootNodes.isEmpty | passed | `OCCTDocumentGetRootCount` | PASS: 0 = 0 |
| `lengthUnitReadsBackFromSTEP` | `OCCTDocumentGetLengthUnit` returns false | :39 Expectation failed: doc.lengthUnit | passed | `OCCTDocumentGetLengthUnit` | PASS: kernel 0.001 "mm" |
| `lengthUnitNilOnFreshDocument` | `OCCTDocumentGetLengthUnit` reports a 1.0 "m" unit | :50 Expectation failed: doc.lengthUnit == nil | passed | `OCCTDocumentGetLengthUnit` | PASS: absent = absent |
### `DocumentTransactionTests.swift`
| `openCommit` | `OCCTDocumentHasOpenTransaction` returns false | :18 Expectation failed: doc.hasOpenTransaction | passed | `OCCTDocumentHasOpenTransaction` | PASS: false, true, commit true, false |
| `openAbort` | `OCCTDocumentAbortTransaction` returns without aborting | :40 Expectation failed: !doc.hasOpenTransaction | passed | `OCCTDocumentAbortTransaction` | PASS: false = false |
| `hasOpenTransaction` | `OCCTDocumentCommitTransaction` returns true without committing | :53 Expectation failed: !doc.hasOpenTransaction | passed | `OCCTDocumentCommitTransaction` | PASS: false, true, false |
### `IDFilterTests.swift`
| `createFilter` | `OCCTIDFilterIgnoreAll` returns false | :12 Expectation failed: f.isIgnoreAll | passed | `OCCTIDFilterIgnoreAll` | PASS: true = true |
| `keepMode` | `OCCTIDFilterIgnoreAll` returns true | :18 Expectation failed: !filter.isIgnoreAll | passed | `OCCTIDFilterIgnoreAll` | PASS: false = false |
| `keepGUID` | `OCCTIDFilterIsKept` returns false | :26 Expectation failed: filter.isKept(guid) | passed | `OCCTIDFilterIsKept` | PASS: true = true |
| `ignoreGUID` | `OCCTIDFilterIsIgnored` returns false | :34 Expectation failed: filter.isIgnored(guid) | passed | `OCCTIDFilterIsIgnored` | PASS: true = true |
| `toggleIgnoreAll` | `OCCTIDFilterSetIgnoreAll` returns without setting | :41 Expectation failed: !filter.isIgnoreAll | passed | `OCCTIDFilterSetIgnoreAll` | PASS: false after `IgnoreAll(false)` |
### `Issue1030DatumLookupGuardTests.swift`
| `theCrashingShapeIsAuthorable` | `OCCTDocumentGetRealArrayValue` returns false | :91 Expectation failed: point?.realArrayValue(at: 1) == 7; :92 Expectation failed: point?.realArrayValue(at: 3) == 7 | passed | `OCCTDocumentGetRealArrayValue` | PASS: both children exist with no array; the point array reads 1..3 of 7 |
| `pointWithoutPlaneLocationIsRead` | the retired #1030 datum guard, reinstated in the shared GD&T lookup | :106 Expectation failed: doc.datum(at: index)?.name == "Datum1030"; :107 Expectation failed: doc.datums.count == 1 | passed | `OCCTDocumentGetDatumInfo` | PASS: `GetObject` reads it (patch 0029 pinned), name `Datum1030`, one label |
| `aWritePathSucceedsToo` | the retired #1030 datum guard, reinstated in the shared GD&T lookup | :124 Expectation failed: doc.setDatumPosition(at: index, 2); :125 Expectation failed: doc.setDatumModifiers(at: index, [.basic]) | passed | `OCCTDocumentSetDatumPosition` | PASS: the object the writes need is readable |
| `planeLocationTooShortForThePointIndexIsRead` | the retired #1030 datum guard, reinstated in the shared GD&T lookup | :174 Expectation failed: doc.datum(at: index)?.name == "Datum1030" | passed | `OCCTDocumentGetDatumInfo` | PASS: reads with the point at index 1000000 |
| `pointWithPlaneLocationStillReads` | a datum guard that refuses any datum carrying a point array | :187 Expectation failed: datum != nil; :188 Expectation failed: datum?.name == "Datum1030" | passed | `OCCTDocumentGetDatumInfo` | PASS: reads |
| `pointArrayOfTheWrongLengthStillReads` | the #1030 guard without its length-3 check | :214 Expectation failed: doc.datum(at: index)?.name == "Datum1030" | passed | `OCCTDocumentGetDatumInfo` | PASS: reads with a length-2 point array |
| `rescaleGeometryStillSucceeds` | `OCCTDocumentEditorRescaleGeometry` returns false | :231 Expectation failed: doc.rescaleGeometry(labelId: main.labelId, scaleFactor: 2.0, forceIfNotRoot: true) | passed | `OCCTDocumentEditorRescaleGeometry` | PASS: `XCAFDoc_Editor::RescaleGeometry` true |
| `plainDatumStillReads` | a datum guard that refuses any datum whose point child label exists (a child-existence test) | :247 Expectation failed: datum?.name == "Datum1030"; :248 Expectation failed: doc.setDatumPosition(at: index, 2) | passed | `OCCTDocumentGetDatumInfo` | PASS: every datum has child 17 (so a child-existence guard refuses all); no array, so it reads |
### `DocumentUndoRedoTests.swift`
| `undoLimit` | `OCCTDocumentGetUndoLimit` returns 0 | :15 Expectation failed: doc.undoLimit == 10 | passed | `OCCTDocumentGetUndoLimit` | PASS: 10 = 10 |
| `availableUndos` | `OCCTDocumentGetAvailableUndos` returns 0 | :30 Expectation failed: doc.availableUndos == 1 | passed | `OCCTDocumentGetAvailableUndos` | PASS: 0/0, then 1 |
| `undoRestores` | `OCCTDocumentUndo` returns true without undoing | :58 Expectation failed: doc.availableUndos == 1; :59 Expectation failed: doc.availableRedos == 1 | passed | `OCCTDocumentUndo` | PASS: 2, then undo gives 1/1 |
| `redoAfterUndo` | `OCCTDocumentRedo` returns true without redoing | :82 Expectation failed: doc.availableUndos == 2; :83 Expectation failed: doc.availableRedos == 0 | passed | `OCCTDocumentRedo` | PASS: redo gives 2/0 |
| `undoNothing` | `OCCTDocumentUndo` returns true without undoing | :91 Expectation failed: !result | passed | `OCCTDocumentUndo` | PASS: false = false |
| `multipleUndoRedo` | `OCCTDocumentRedo` returns true without redoing | :115 Expectation failed: doc.availableUndos == 2; :116 Expectation failed: doc.availableRedos == 1 | passed | `OCCTDocumentRedo` | PASS: 3; 0/3; 2/1 |
| `abortNoUndo` | `OCCTDocumentAbortTransaction` commits instead | :132 Expectation failed: doc.availableUndos == 1 | passed | `OCCTDocumentAbortTransaction` | PASS: 1 = 1 |
### `DriverTableTests.swift`
| `tableExists` | `OCCTDriverTableExists` returns false | :13 Expectation failed: DriverTable.exists | passed | `OCCTDriverTableExists` | PASS: `Get()` never null |
| `initAndClear` | `OCCTDriverTableClear` calls `abort()` | process crash (the test has no expectation; a crash is the only failure it can report) | passed | `OCCTDriverTableClear` | PASS: both calls return; see the note on this test |
### `Issue970TransactionAPITests.swift`
| `namedTransactionNamesTheCommittedDelta` | the pending transaction name is dropped at commit | :23 Expectation failed: delta.name == "add part" | passed | `OCCTDocumentCommitWithDelta` | PASS: `TDF_Delta::SetName` keeps it; 2 attribute deltas |
| `aPendingNameDoesNotReachTheNextTransaction` | the pending name survives both the commit and the next unnamed open | :39 Expectation failed: delta.name == "" | passed | `OCCTDocumentCommitWithDelta` | PASS: a delta carries no name unless one is set |
| `anUnnamedOpenSupersedesAPendingName` | `OCCTDocumentOpenTransaction` keeps a pending name | :53 Expectation failed: delta.name == "" | passed | `OCCTDocumentOpenTransaction` | PASS: the second open throws, the delta is unnamed |
| `aRefusedNamedOpenLeavesTheRunningNameAlone` | `OCCTDocumentOpenNamedTransaction` stores its name before the refused open | :66 Expectation failed: delta.name == "first" | passed | `OCCTDocumentOpenNamedTransaction` | PASS: the refused open throws in the kernel |
| `abortDiscardsThePendingName` | the pending name survives both the abort and the next unnamed open | :80 Expectation failed: delta.name == "" | passed | `OCCTDocumentAbortTransaction` | PASS: abort leaves no command and no new delta |
| `commitWithDeltaReturnsADeltaAndKeepsTheUndoLimit` | `OCCTDocumentCommitWithDelta` returns null | :91 Expectation failed: delta != nil; :93 Expectation failed: doc.availableUndos == 1 | passed | `OCCTDocumentCommitWithDelta` | PASS: 1 undo |
| `transactionNumberTracksTheOpenTransaction` | `OCCTDocumentGetTransactionNumber` returns 0 | :103 Expectation failed: doc.transactionNumber == 1 | passed | `OCCTDocumentGetTransactionNumber` | PASS: 0, 1, 0 |
| `repeatedOpensDoNotStack` | `OCCTDocumentGetTransactionNumber` returns 2 while a command is open | :117 Expectation failed: doc.transactionNumber == 1 | passed | `OCCTDocumentGetTransactionNumber` | PASS: second open throws; still 1 |
| `withoutAnUndoLimitNothingOpens` | `OCCTDocumentOpenTransaction` raises a 0 undo limit to 1 | :127 Expectation failed: doc.transactionNumber == 0; :128 Expectation failed: !doc.hasOpenTransaction | passed | `OCCTDocumentOpenTransaction` | PASS: nothing opens at undo limit 0 |
| `openNamedTransactionReportsTheNumberItOpened` | `OCCTDocumentOpenNamedTransaction` opens but answers 0 | :137 Expectation failed: doc.openNamedTransaction("with undo limit") == 1 | passed | `OCCTDocumentOpenNamedTransaction` | PASS: 0, then 1 |
### `Issue1056GDTWriteAnswerTests.swift`
| `nonStorableToleranceRefusesTheCreate` | `occtDimensionApplyTolerance` (both copies reached) accepts without its readback check | :48 Expectation failed: index == nil; :48 Expectation failed: index == nil | passed | `OCCTDocumentCreateDimensionWithTolerance` | PASS: the kernel stores NaN; the readback `==` is false, which is what refuses |
| `storableToleranceStillApplies` | `OCCTDocumentGetDimensionInfo` reads the upper tolerance as the lower | :70 Expectation failed: dim.bounds == .plusMinus(lowerTolerance: -0.3, upperTolerance: 0.7) | passed | `OCCTDocumentGetDimensionInfo` | PASS: -0.3 / +0.7 |
| `noToleranceStillCreatesASimpleDimension` | `OCCTDocumentGetDimensionInfo` reports a simple dimension as unset | :90 Expectation failed: doc.dimension(at: index)?.bounds == .simple | passed | `OCCTDocumentGetDimensionInfo` | PASS: one value, simple |
| `standaloneSetterRefusesTheSamePair` | `occtDimensionApplyTolerance` (both copies reached) accepts without its readback check | :105 Expectation failed: doc.setDimensionTolerance(at: index, lower: .nan, upper: 0.5) == false; :106 Expectation failed: doc.dimension(at: index)?.bounds == .simple | passed | `OCCTDocumentSetDimensionTolerance` | PASS: NaN readback check fails |
| `noneModifierStoresNoValue` | `OCCTDocumentSetGeomToleranceZoneModifier` stores the value whatever the modifier | :129 Expectation failed: tol.zoneModifierValue == nil | passed | `OCCTDocumentSetGeomToleranceZoneModifier` | PASS: the kernel keeps a value under None, so the bridge must write 0 itself |
| `clearingAModifierClearsItsValue` | `OCCTDocumentSetGeomToleranceZoneModifier` stores the value whatever the modifier | :151 Expectation failed: tol.zoneModifierValue == nil | passed | `OCCTDocumentSetGeomToleranceZoneModifier` | PASS: same |
| `realModifierStillStoresItsValue` | `OCCTDocumentSetGeomToleranceZoneModifier` stores 0 whatever the value | :172 Expectation failed: tol.zoneModifierValue == 15.0 | passed | `OCCTDocumentSetGeomToleranceZoneModifier` | PASS: Projected 15 |
| `datumSiblingReportsNothingForAClearedModifier` | `OCCTDocumentGetDatumInfo` reports modifier 1 whatever is stored | :197 Expectation failed: doc.datum(at: index)?.modifierWithValue == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: kernel keeps 15 under None; the bridge reports nothing |
### `Issue1435DatumDocumentToolTableTests.swift`
| `datumIsUnderDocumentToolLabel` | `OCCTDocumentCreateDatum` writes through `XCAFDoc_DimTolTool::Set(Main())` (the #1435 regression) | :62 Expectation failed: dgts.childCount == 1; :69 Expectation failed: doc.datumCount == 1 | passed | `OCCTDocumentCreateDatum` | PASS: the datum lands under 0:1:4 |
| `datumCountAgreesWithRealTable` | `OCCTDocumentCreateDatum` writes through `XCAFDoc_DimTolTool::Set(Main())` (the #1435 regression) | :89 Expectation failed: dgts.childCount == 3; :90 Expectation failed: doc.datumCount == 3 | passed | `OCCTDocumentGetDatumCount` | PASS: 3 = 3; a tool set on Main() never makes 0:1:4 |
### `TDataXtdShapeAttributeTests.swift`
| `setGetShape` | `OCCTDocumentHasShapeAttr` returns false | :18 Expectation failed: label.hasShapeAttribute | passed | `OCCTDocumentHasShapeAttr` | PASS: stored |
| `noShapeAttribute` | `OCCTDocumentHasShapeAttr` returns true | :28 Expectation failed: !label.hasShapeAttribute | passed | `OCCTDocumentHasShapeAttr` | PASS: none on a fresh label |
### `TDataXtdTriangulationAttributeTests.swift`
| `setTriangulation` | `OCCTDocumentTriangulationNbNodes` answers 0 | :18 Expectation failed: label.triangulationNodeCount > 0 | passed | `OCCTDocumentTriangulationNbNodes` | PASS: sphere at 1.0: 168 nodes, 306 triangles |
| `triangulationDeflection` | `OCCTDocumentTriangulationDeflection` answers 0 | :29 Expectation failed: label.triangulationDeflection > 0 | passed | `OCCTDocumentTriangulationDeflection` | PASS: the mesher records a positive deflection |
### `TDFAttributeIteratorTests.swift`
| `attributeCount` | `OCCTDocumentAttributeCount` answers 0 | :19 Expectation failed: count >= 3 | passed | `OCCTDocumentAttributeCount` | PASS: 3 |
| `emptyLabel` | `OCCTDocumentAttributeCount` answers -1 | :26 Expectation failed: count >= 0 | passed | `OCCTDocumentAttributeCount` | PASS: 0 |
| `dataSetIsEmpty` | `OCCTDocumentDataSetIsEmpty` returns true | :33 Expectation failed: !empty | passed | `OCCTDocumentDataSetIsEmpty` | PASS: a label with attributes gives a non-empty data set |
### `TDFChildIDIteratorTests.swift`
| `countByGUID` | `OCCTDocumentChildIDCount` answers 0 | :28 Expectation failed: count == 2 | passed | `OCCTDocumentChildIDCount` | PASS: 2 integer children |
| `emptyResult` | `OCCTDocumentChildIDCount` answers 1 | :36 Expectation failed: count == 0 | passed | `OCCTDocumentChildIDCount` | PASS: 0 |
### `TDFComparisonToolTests.swift`
| `isSelfContained` | `OCCTDocumentIsSelfContained` returns false | :16 Expectation failed: result == true | passed | `OCCTDocumentIsSelfContained` | PASS: true |
### `TDFCopyLabelTests.swift`
| `copyLabelWithName` | `OCCTDocumentCopyLabel` returns true without copying | :20 Expectation failed: dest.name == "Original" | passed | `OCCTDocumentCopyLabel` | PASS: Original copied |
| `copyLabelWithChildren` | `OCCTDocumentCopyLabel` returns true without copying | :34 Expectation failed: dest.hasChild | passed | `OCCTDocumentCopyLabel` | PASS: copied |
### `TDFLabelNameTests.swift`
| `setGetName` | `OCCTDocumentGetLabelName` returns null | :17 Expectation failed: label.name == "MyPart" | passed | `OCCTDocumentGetLabelName` | PASS: MyPart |
| `renameLabel` | `OCCTDocumentSetLabelName` ignores every call after the first | :28 Expectation failed: label.name == "Renamed" | passed | `OCCTDocumentSetLabelName` | PASS: Renamed |
### `TDFReferenceTests.swift`
| `setGetReference` | `OCCTDocumentLabelGetReference` answers -1 | :27 Issue recorded | passed | `OCCTDocumentLabelGetReference` | PASS: points to the target |
| `noReference` | `OCCTDocumentLabelGetReference` answers label 0 | :35 Expectation failed: label.referencedLabel == nil | passed | `OCCTDocumentLabelGetReference` | PASS: none |
### `TDFTransactionNamedTests.swift`
| `openNamedTransaction` | `OCCTDocumentOpenNamedTransaction` opens but answers 0 | :15 Expectation failed: txnNum >= 1 | passed | `OCCTDocumentOpenNamedTransaction` | PASS: 1 |
| `transactionNumber` | `OCCTDocumentGetTransactionNumber` returns 0 | :26 Expectation failed: during == 1 | passed | `OCCTDocumentGetTransactionNumber` | PASS: 0, 1, 0 |
| `commitWithDelta` | `OCCTDocumentCommitWithDelta` returns null | :40 Expectation failed: delta != nil | passed | `OCCTDocumentCommitWithDelta` | PASS: 2 deltas, 0..1 |
| `deltaName` | `OCCTDeltaSetName` returns without naming | :60 Expectation failed: delta.name == "MyDelta" | passed | `OCCTDeltaSetName` | PASS: `SetName` sticks |
### `TDocStdXLinkToolTests.swift`
| `xlinkCopy` | `OCCTDocumentXLinkCopy` returns false | :13 `ok`; the value check is now unconditional (`if let` removed) | passed | `OCCTDocumentXLinkCopy` | PASS: 77 copied |
| `xlinkCopyWithLink` | `OCCTDocumentXLinkCopyWithLink` returns true without copying | `tgt.integer == 88` (rewritten; the old test discarded both the answer and the effect) | passed | `OCCTDocumentXLinkCopyWithLink` | PASS: 88 copied |
### `Issue443TriangulationAttributeTests.swift`
| `boxStoresEveryFace` | the merge keeps only the first face (the #443 defect) | :29 Expectation failed: label.triangulationNodeCount == 24; :30 Expectation failed: label.triangulationTriangleCount == 12 | passed | `OCCTDocumentTriangulationNbNodes` | PASS: 24 / 12 over 6 faces |
| `compoundStoresEveryBody` | the merge keeps only the first face (the #443 defect) | :47 Expectation failed: label.triangulationNodeCount == 48; :48 Expectation failed: label.triangulationTriangleCount == 24 | passed | `OCCTDocumentTriangulationNbNodes` | PASS: 48 / 24 |
| `deflectionControlsDensity` | the merged triangulation's deflection is written as 0 | :69 Expectation failed: coarseLabel.triangulationDeflection > 0; :70 Expectation failed: fineLabel.triangulationDeflection > 0 | passed | `OCCTDocumentTriangulationDeflection` | PASS: 306 vs 516 triangles; 0.627 vs 0.238 |
| `planarDeflection` | the merged triangulation's deflection is written as -1 | :86 Expectation failed: label.triangulationDeflection >= 0 | passed | `OCCTDocumentTriangulationDeflection` | PASS: 3.1e-16 on planar faces |
| `locatedShapeStoresShapeFrame` | nodes are stored without the face location | :117 Expectation failed: node.x >= bounds.min.x - slack && node.x <= bounds.max.x + slack; :120 Expectation failed: node.y >= bounds.min.y - slack && node.y <= bounds.max.y + slack | passed | `OCCTDocumentTriangulationNode` | PASS: nodes at x 95..105 |
| `mirroredShapeStoresEveryFace` | the merge keeps only the first face (the #443 defect) | :142 Expectation failed: label.triangulationNodeCount == 24; :143 Expectation failed: label.triangulationTriangleCount == 12 | passed | `OCCTDocumentTriangulationNbNodes` | PASS: 24 / 12 at x -20..-10 |
| `triangulationNodeBounds` | `OCCTDocumentTriangulationNode` answers (0, 0, 0) for any index | :175 Expectation failed: empty.triangulationNode(at: 1) == nil; :178 Expectation failed: label.triangulationNode(at: 0) == nil | passed | `OCCTDocumentTriangulationNode` | PASS: 1..24 |
| `importedNormalsSurviveTheMerge` | the merge drops every face's normals | :216 Issue recorded | passed | `OCCTDocumentTriangulationNormal` | PASS: BRepMesh leaves no normals (so the B-rep label reads nil); the glTF import is the source of normals |
| `noFaceStoresNothing` | `OCCTDocumentSetTriangulationFromShape` reports success for a shape with no face | :254 Expectation failed: label.setTriangulationFromShape(edge, deflection: 1.0) == false | passed | `OCCTDocumentSetTriangulationFromShape` | PASS: no face, nothing to merge |
### `XCAFPrsStyleTests.swift`
| `emptyStyle` | `OCCTXCAFPrsStyleCreate` reports a non-empty style | :10 Expectation failed: style.isEmpty | passed | `OCCTXCAFPrsStyleCreate` | PASS: empty |
| `surfaceColor` | `OCCTXCAFPrsStyleCreateWithSurfColor` returns an empty style | :15 Expectation failed: !style.isEmpty | passed | `OCCTXCAFPrsStyleCreateWithSurfColor` | PASS: not empty |
| `visibility` | `OCCTXCAFPrsStyleIsEqual` returns true | :27 `!style.isEqual(to: visible)` (rewritten; reading back a stored property could not fail) | passed | `OCCTXCAFPrsStyleIsEqual` | PASS: unequal |
| `equality` | `OCCTXCAFPrsStyleIsEqual` returns false | :36 Expectation failed: s1.isEqual(to: s2) | passed | `OCCTXCAFPrsStyleIsEqual` | PASS: equal |
| `curveColorOnly` | `OCCTXCAFPrsStyleCreateWithCurvColor` returns an empty style | :48 Expectation failed: !style.isEmpty; :56 Expectation failed: !style.isEqual(to: differentCurve) | passed | `OCCTXCAFPrsStyleCreateWithCurvColor` | PASS: not empty; same equal; different unequal |
### `VisMaterialCommonTests.swift`
| `defaultValues` | `OCCTVisMaterialCommonDefault` returns a zeroed material | :10 Expectation failed: mat.isDefined; :11 Expectation failed: abs(mat.diffuseColor.red - 0.8) < 0.02 | passed | `OCCTVisMaterialCommonDefault` | PASS: 0.8 |
| `setProperties` | `OCCTVisMaterialCommonIsEqual` returns true | `!mat.isEqual(to: other)` (rewritten; reading back stored properties could not fail) | passed | `OCCTVisMaterialCommonIsEqual` | PASS: unequal |
| `equality` | `OCCTVisMaterialCommonIsEqual` returns false | :37 Expectation failed: m1.isEqual(to: m2) | passed | `OCCTVisMaterialCommonIsEqual` | PASS: equal |
| `commonMaterialRoughnessFromShininess` | `OCCTMaterialRoughnessFromSpecular` answers 0.1 | :105 Expectation failed: abs(material.roughness - 0.7) < 0.01 | passed | `OCCTDocumentGetLabelMaterial` | N/A: bridge-side conversion (`OCCTMaterialRoughnessFromSpecular`); no kernel roughness exists for a common material |
### `VisMaterialPBRTests.swift`
| `defaultValues` | `OCCTVisMaterialPBRDefault` returns a zeroed material | :10 Expectation failed: pbr.isDefined; :11 Expectation failed: abs(pbr.metallic - 1.0) < 1e-6 | passed | `OCCTVisMaterialPBRDefault` | PASS: 1, 1, 1.5 |
| `setProperties` | `OCCTVisMaterialPBRIsEqual` returns true | `!pbr.isEqual(to: other)` (rewritten; reading back stored properties could not fail) | passed | `OCCTVisMaterialPBRIsEqual` | PASS: unequal |
| `equality` | `OCCTVisMaterialPBRIsEqual` returns false | :39 Expectation failed: p1.isEqual(to: p2) | passed | `OCCTVisMaterialPBRIsEqual` | N/A: same values compare equal (see common) |
### `XCAFComponentMatrixTests.swift`
| `matrixComponentPlacement` | `OCCTDocumentAddComponentMatrix` returns -1 without adding | :20 Expectation failed: doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: rigid) >= 0; :24 Expectation failed: doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: reflect) >= 0 | passed | `OCCTDocumentAddComponentMatrix` | PASS: both added, 2 components |
### `XCAFDocAssemblyGraphTests.swift`
| `createFromDocument` | `OCCTAssemblyGraphNbNodes` answers -1 | :15 Expectation failed: graph.nodeCount >= 0 | passed | `OCCTAssemblyGraphNbNodes` | PASS: counts non-negative |
| `nodeTypeMatchesRealOCCTCategories` | `OCCTAssemblyGraphGetNodeType` answers 0 | :64 Expectation failed: graph.nodeType(at: 1) == .assemblyRoot; :65 Expectation failed: graph.nodeType(at: 2) == .occurrence | passed | `OCCTAssemblyGraphGetNodeType` | PASS: 1 3 2 3 4 |
### `XCAFDocAssemblyItemIdTests.swift`
| `createFromString` | `OCCTAssemblyItemIdPathCount` answers 1 | :11 Expectation failed: id.pathCount == 2 | passed | `OCCTAssemblyItemIdPathCount` | PASS: 2 |
| `emptyIsNull` | `OCCTAssemblyItemIdIsValid` returns true | :16 Expectation failed: !id.isValid | passed | `OCCTAssemblyItemIdIsValid` | PASS: null |
| `equality` | `OCCTAssemblyItemIdIsEqual` returns false | :22 Expectation failed: id1.isEqual(to: id2) | passed | `OCCTAssemblyItemIdIsEqual` | PASS: equal |
| `inequality` | `OCCTAssemblyItemIdIsEqual` returns true | :28 Expectation failed: !id1.isEqual(to: id2) | passed | `OCCTAssemblyItemIdIsEqual` | PASS: unequal |
### `XCAFDocAssemblyItemRefTests.swift`
| `setAndGet` | `OCCTDocumentGetAssemblyItemRef` returns null | :18 Expectation failed: path != nil | passed | `OCCTDocumentGetAssemblyItemRef` | PASS: path kept |
| `subshapeIndex` | `OCCTDocumentAssemblyItemRefHasExtra` returns false | :28 Expectation failed: doc.assemblyItemRefHasExtra(labelId: node.labelId) | passed | `OCCTDocumentAssemblyItemRefHasExtra` | PASS: 3 |
| `clearExtra` | `OCCTDocumentAssemblyItemRefClearExtra` returns true without clearing | :42 Expectation failed: !doc.assemblyItemRefHasExtra(labelId: node.labelId) | passed | `OCCTDocumentAssemblyItemRefClearExtra` | PASS: cleared |
| `isOrphan` | `OCCTDocumentAssemblyItemRefIsOrphan` returns false | :51 Expectation failed: doc.assemblyItemRefIsOrphan(labelId: node.labelId) | passed | `OCCTDocumentAssemblyItemRefIsOrphan` | N/A: the test's path names no label, so it is orphan; the probe's resolvable path is not |
### `XCAFNoteObjectsTests.swift`
| `create` | `OCCTNoteObjectCreate` returns null | :10 Expectation failed: obj != nil | passed | `OCCTNoteObjectCreate` | PASS: created |
| `initiallyEmpty` | `OCCTNoteObjectHasPlane` returns true | :15 Expectation failed: !obj.hasPlane | passed | `OCCTNoteObjectHasPlane` | PASS: all false |
| `setPlane` | `OCCTNoteObjectGetPlane` answers the origin | :28 Expectation failed: abs(origin.x - 1.0) < 1e-6 | passed | `OCCTNoteObjectGetPlane` | PASS: x 1 |
| `setPoint` | `OCCTNoteObjectHasPoint` returns false | :35 Expectation failed: obj.hasPoint | passed | `OCCTNoteObjectHasPoint` | PASS: x 10 |
| `setPresentation` | `OCCTNoteObjectGetPresentation` returns null | :45 Expectation failed: obj.presentation != nil | passed | `OCCTNoteObjectGetPresentation` | PASS: kept |
| `reset` | `OCCTNoteObjectReset` returns without resetting | :57 Expectation failed: !obj.hasPlane; :58 Expectation failed: !obj.hasPoint | passed | `OCCTNoteObjectReset` | PASS: cleared |
### `XCAFViewObjectTests.swift`
| `create` | `OCCTViewObjectCreate` returns null | :11 Expectation failed: view != nil | passed | `OCCTViewObjectCreate` | PASS: created |
| `projectionType` | `OCCTViewObjectGetType` answers 99 | :17 Expectation failed: view.type == .central; :19 Expectation failed: view.type == .parallel | passed | `OCCTViewObjectGetType` | PASS: 2, 1, 0 |
| `realOCCTProjectionTypeValuesDecodeCorrectly` | `OCCTViewObjectGetType` answers 99 | :53 Expectation failed: readBack == raw; :55 Expectation failed: decoded == expected | passed | `OCCTViewObjectGetType` | PASS: raw values 0, 1, 2 |
| `viewDirection` | `OCCTViewObjectGetViewDirection` answers (0, 0, 0) | :63 Expectation failed: abs(dir.x - 1.0) < 1e-6 | passed | `OCCTViewObjectGetViewDirection` | PASS: (1, 0, 0) |
| `upDirection` | `OCCTViewObjectGetUpDirection` answers (0, 0, 0) | :71 Expectation failed: abs(up.z - 1.0) < 1e-6 | passed | `OCCTViewObjectGetUpDirection` | PASS: (0, 0, 1) |
| `windowSize` | `OCCTViewObjectGetWindowHSize` answers 0 | :79 Expectation failed: abs(view.windowHorizontalSize - 800) < 1e-6 | passed | `OCCTViewObjectGetWindowHSize` | PASS: 800 x 600 |
| `clippingPlanes` | `OCCTViewObjectHasFrontPlaneClipping` returns false | :88 Expectation failed: view.hasFrontPlaneClipping | passed | `OCCTViewObjectHasFrontPlaneClipping` | PASS: 1, 1000, then unset |
| `name` | `OCCTViewObjectGetName` returns null | :100 Expectation failed: view.name == "TopView" | passed | `OCCTViewObjectGetName` | PASS: TopView |
### `XDEShapeToolQueryTests.swift`
| `addShapeAndCount` | `OCCTDocumentGetShapeCount` answers 0 | :21 Expectation failed: doc.shapeCount > 0 | passed | `OCCTDocumentGetShapeCount` | PASS: positive |
| `freeShapeCount` | `OCCTDocumentGetFreeShapeCount` answers 0 | :34 Expectation failed: doc.freeShapeCount > 0 | passed | `OCCTDocumentGetFreeShapeCount` | PASS: positive |
| `findAndSearch` | `OCCTDocumentFindShape` answers -1 | :49 Expectation failed: foundId >= 0 | passed | `OCCTDocumentFindShape` | PASS: true, true |
| `newAndRemove` | `OCCTDocumentRemoveShape` returns false | :66 Expectation failed: removed | passed | `OCCTDocumentRemoveShape` | PASS: true |
| `labelQueries` | `OCCTDocumentIsTopLevel` returns false | :82 Expectation failed: root.isTopLevel | passed | `OCCTDocumentIsTopLevel` | PASS: top-level, not a component |
### `XLinkTests.swift`
| `setXLink` | `OCCTDocumentXLinkSet` returns false | :11 Expectation failed: ok | passed | `OCCTDocumentXLinkSet` | PASS: set |
| `documentEntry` | `OCCTDocumentXLinkGetDocumentEntry` returns null | :20 Expectation failed: entry == "/doc/path" | passed | `OCCTDocumentXLinkGetDocumentEntry` | PASS: /doc/path |
| `labelEntry` | `OCCTDocumentXLinkGetLabelEntry` returns null | :29 Expectation failed: entry == "0:1:2" | passed | `OCCTDocumentXLinkGetLabelEntry` | PASS: 0:1:2 |
### `TDataXtdConstraintTests.swift`
| `setAndGetType` | `OCCTDocumentConstraintGetType` answers 3 | :18 Expectation failed: type == .parallel | passed | `OCCTDocumentConstraintGetType` | PASS: PARALLEL (5) |
| `isPlanarAndDimension` | `OCCTDocumentConstraintIsPlanar` returns true | :29 Expectation failed: !doc.constraintIsPlanar(labelId: node.labelId) | passed | `OCCTDocumentConstraintIsPlanar` | PASS: false, false |
| `verifiedFlag` | `OCCTDocumentConstraintGetVerified` returns false | :40 Expectation failed: doc.constraintGetVerified(labelId: node.labelId) | passed | `OCCTDocumentConstraintGetVerified` | PASS: true |
| `noConstraint` | `OCCTDocumentConstraintGetType` answers 0 where there is none | :46 Expectation failed: doc.constraintGetType(labelId: node.labelId) == nil | passed | `OCCTDocumentConstraintGetType` | PASS: no constraint on a fresh label |
### `TDataXtdGeometricAttrTests.swift`
| `setPoint` | `OCCTDocumentSetPointAttr` returns false | :15 Expectation failed: label.setPointAttribute(x: 5.0, y: 10.0, z: 15.0) | passed | `OCCTDocumentSetPointAttr` | PASS: `TDataXtd_Point::Set` non-null |
| `setAxis` | `OCCTDocumentSetAxisAttr` returns false | :22 Expectation failed: label.setAxisAttribute(originX: 0, originY: 0, originZ: 0, directionX: 0, directionY: 0, directionZ: 1) | passed | `OCCTDocumentSetAxisAttr` | PASS: `TDataXtd_Axis::Set` non-null |
| `setPlane` | `OCCTDocumentSetPlaneAttr` returns false | :32 Expectation failed: label.setPlaneAttribute(originX: 0, originY: 0, originZ: 0, normalX: 0, normalY: 0, normalZ: 1) | passed | `OCCTDocumentSetPlaneAttr` | PASS: `TDataXtd_Plane::Set` non-null |
### `TDataXtdGeometryAttributeTests.swift`
| `setGetGeometryType` | `OCCTDocumentGetGeometryType` answers 0 | :18 Expectation failed: label.geometryType() == .point; :21 Expectation failed: label.geometryType() == .plane | passed | `OCCTDocumentGetGeometryType` | PASS: 1, 6, 7 |
| `allGeometryTypes` | `OCCTDocumentGetGeometryType` answers 0 | :36 Expectation failed: label.geometryType() == type; :36 Expectation failed: label.geometryType() == type | passed | `OCCTDocumentGetGeometryType` | PASS: each type reads back |
### `TextLabelAndPointCloudTests.swift`
| `createTextLabel` | `OCCTTextLabelGetInfo` returns false | :15 Expectation failed: label!.text == "Hello" | passed | `OCCTTextLabelGetInfo` | N/A: the text is the bridge's own record |
| `textLabelPosition` | `OCCTTextLabelGetInfo` returns false | :22 Expectation failed: abs(pos.x - 10) < 1e-6; :23 Expectation failed: abs(pos.y - 20) < 1e-6 | passed | `OCCTTextLabelGetInfo` | N/A: position is the bridge's own record |
| `updateText` | `OCCTTextLabelSetText` returns without setting | :31 Expectation failed: label.text == "Updated" | passed | `OCCTTextLabelSetText` | N/A: bridge-held |
| `updatePosition` | `OCCTTextLabelSetPosition` returns without setting | :39 Expectation failed: abs(pos.x - 5) < 1e-6; :40 Expectation failed: abs(pos.y - 10) < 1e-6 | passed | `OCCTTextLabelSetPosition` | N/A: bridge-held |
| `textLabelDefaultHeightMatchesOCCT` | `OCCTTextLabelGetInfo` returns false | :49 Expectation failed: OCCTTextLabelGetInfo(label.handle, &info); :50 Expectation failed: abs(info.height - 16.0) < 1e-6 | passed | `OCCTTextLabelGetInfo` | PASS: 16 = 16 |
| `textLabelHeightRoundTrips` | `OCCTTextLabelSetHeight` returns without setting | :59 Expectation failed: abs(info.height - 30.0) < 1e-6 | passed | `OCCTTextLabelSetHeight` | PASS: 30 |
| `createPointCloud` | `OCCTPointCloudGetCount` answers 0 | :67 Expectation failed: cloud!.count == 3 | passed | `OCCTPointCloudGetCount` | PASS: 3 |
| `pointCloudBounds` | `OCCTPointCloudGetBounds` returns false | :75 Expectation failed: bounds != nil | passed | `OCCTPointCloudGetBounds` | PASS: x -1..4, y 0..5 |
| `pointCloudRetrieval` | `OCCTPointCloudGetPoints` answers 0 | :89 Expectation failed: retrieved.count == 2 | passed | `OCCTPointCloudGetPoints` | N/A: points are the bridge's copy |
| `coloredPointCloud` | `OCCTPointCloudGetColors` answers 0 | :102 Expectation failed: retrievedColors.count == 2 | passed | `OCCTPointCloudGetColors` | N/A: colours are the bridge's copy |
| `emptyPointCloud` | `OCCTPointCloudCreate` builds a one-point cloud from zero points | :110 Expectation failed: cloud == nil | passed | `OCCTPointCloudCreate` | N/A: refused before any OCCT call |
### `TFunctionDriverTableTests.swift`
| `hasDriverUnknown` | `OCCTFunctionDriverTableHasDriver` returns true | :11 Expectation failed: !has | passed | `OCCTFunctionDriverTableHasDriver` | PASS: false |
| `clear` | `OCCTFunctionDriverTableClear` calls `abort()` | process crash (the test has no expectation) | passed | `OCCTFunctionDriverTableClear` | N/A: no expectation; crash-only |
### `TFunctionFunctionAttrTests.swift`
| `createFunction` | `OCCTDocumentFunctionIsFailed` returns true | :18 Expectation failed: !label.functionIsFailed | passed | `OCCTDocumentFunctionIsFailed` | PASS: false |
| `functionFailure` | `OCCTDocumentFunctionGetFailure` answers 0 | :30 Expectation failed: failure == 1 | passed | `OCCTDocumentFunctionGetFailure` | PASS: 1 |
### `TFunctionGraphNodeTests.swift`
| `graphNodeStatus` | `OCCTDocumentGraphNodeGetStatus` answers 99 | :18 Expectation failed: label.graphNodeStatus() == .notExecuted; :21 Expectation failed: label.graphNodeStatus() == .succeeded | passed | `OCCTDocumentGraphNodeGetStatus` | PASS: 1, 3 |
| `graphNodeDeps` | `OCCTDocumentGraphNodeAddNext` returns false | :34 Expectation failed: node1.graphNodeAddNext(tag: node2.tag) | passed | `OCCTDocumentGraphNodeAddNext` | PASS: true, true |
| `allStatuses` | `OCCTDocumentGraphNodeGetStatus` answers 99 | :52 Expectation failed: label.graphNodeStatus() == status; :52 Expectation failed: label.graphNodeStatus() == status | passed | `OCCTDocumentGraphNodeGetStatus` | PASS: round-trips |
### `TFunctionIFunctionTests.swift`
| `newFunction` | `OCCTDocumentNewFunction` returns false | :16 Expectation failed: ok | passed | `OCCTDocumentNewFunction` | N/A: TFunction_IFunction::NewFunction; not probed in this pass, so no kernel value is claimed |
| `deleteFunction` | `OCCTDocumentDeleteFunction` returns false | :26 Expectation failed: deleted | passed | `OCCTDocumentDeleteFunction` | N/A: TFunction_IFunction::DeleteFunction; not probed in this pass, so no kernel value is claimed |
| `functionExecStatus` | `OCCTDocumentFunctionSetExecStatus` returns true without setting | :41 Expectation failed: status == .succeeded | passed | `OCCTDocumentFunctionSetExecStatus` | N/A: status round-trip; not probed in this pass, so no kernel value is claimed |
| `noFunction` | `OCCTDocumentFunctionGetExecStatus` answers 0 | :50 Expectation failed: status == nil | passed | `OCCTDocumentFunctionGetExecStatus` | N/A: no function on a fresh label; not probed in this pass, so no kernel value is claimed |
### `TObjApplicationTests.swift`
| `getInstance` | `OCCTTObjApplicationGetInstance` returns null | :10 Expectation failed: app != nil | passed | `OCCTTObjApplicationGetInstance` | PASS: non-null |
| `verboseFlag` | `OCCTTObjApplicationIsVerbose` returns false | :21 Expectation failed: app.isVerbose | passed | `OCCTTObjApplicationIsVerbose` | PASS: true, false |
| `createDocument` | `OCCTTObjApplicationCreateDocument` returns null | :32 Expectation failed: doc != nil | passed | `OCCTTObjApplicationCreateDocument` | PASS: created |
### `UAttributeTests.swift`
| `setAndHas` | `OCCTUAttributeHas` returns false | :13 Expectation failed: doc.hasUAttribute(tag: 300, guid: guid) | passed | `OCCTUAttributeHas` | PASS: true |
| `differentGUID` | `OCCTUAttributeHas` returns true | :22 Expectation failed: !doc.hasUAttribute(tag: 301, guid: guid2) | passed | `OCCTUAttributeHas` | PASS: g1 yes, g2 no |
| `getID` | `OCCTUAttributeGetID` returns null | :30 Expectation failed: retrieved != nil | passed | `OCCTUAttributeGetID` | N/A: the GUID string is the one passed in; not probed in this pass, so no kernel value is claimed |
### `VariableTests.swift`
| `setVariable` | `OCCTDocumentVariableSet` returns false | :11 Expectation failed: ok | passed | `OCCTDocumentVariableSet` | PASS: set |
| `setAndGetName` | `OCCTDocumentVariableGetName` returns null | :20 Expectation failed: name == "velocity" | passed | `OCCTDocumentVariableGetName` | PASS: velocity |
| `setAndGetValue` | `OCCTDocumentVariableGetValue` answers 0 | :30 Expectation failed: abs(val - 42.5) < 1e-10 | passed | `OCCTDocumentVariableGetValue` | PASS: 42.5 |
| `unitString` | `OCCTDocumentVariableGetUnit` returns null | :39 Expectation failed: unit == "m/s" | passed | `OCCTDocumentVariableGetUnit` | PASS: m/s |
| `constantFlag` | `OCCTDocumentVariableIsConstant` returns true | :49 Expectation failed: !doc.variableIsConstant(at: 1) | passed | `OCCTDocumentVariableIsConstant` | PASS: true, false |
| `assignAndDesassignExpression` | `OCCTDocumentVariableIsAssigned` returns false | :58 Expectation failed: doc.variableIsAssigned(at: 1) | passed | `OCCTDocumentVariableIsAssigned` | PASS: true, false |
### `TNamingBasicTests.swift`
| `createLabel` | `OCCTDocumentCreateLabel` returns -1 | force-unwrap crash on the nil label (`createLabel()!`) | passed | `OCCTDocumentCreateLabel` | PASS: a new child of Main |
| `createChildLabel` | `OCCTDocumentCreateLabel` returns -1 | force-unwrap crash on the nil parent label | passed | `OCCTDocumentCreateLabel` | PASS: a child label |
| `recordPrimitive` | `OCCTDocumentNamingRecord` returns false | :32 Expectation failed: ok | passed | `OCCTDocumentNamingRecord` | PASS: recorded as PRIMITIVE (0) |
| `currentShapeAfterPrimitive` | `OCCTDocumentNamingGetCurrentShape` returns null | :43 Expectation failed: current != nil | passed | `OCCTDocumentNamingGetCurrentShape` | PASS: current shape is the box |
| `storedShape` | `OCCTDocumentNamingGetShape` returns null | :54 Expectation failed: stored != nil | passed | `OCCTDocumentNamingGetShape` | PASS: stored shape is the box |
| `evolutionType` | `OCCTDocumentNamingGetEvolution` answers 99 | :64 Expectation failed: doc.namingEvolution(on: label) == .primitive | passed | `OCCTDocumentNamingGetEvolution` | PASS: PRIMITIVE (0) |
| `noEvolutionOnEmptyLabel` | `OCCTDocumentNamingGetEvolution` answers 0 (primitive) where there is none | :71 Expectation failed: doc.namingEvolution(on: label) == nil | passed | `OCCTDocumentNamingGetEvolution` | PASS: no named shape |
| `historyAfterPrimitive` | `OCCTDocumentNamingHistoryCount` answers 0 | :82 `history.count == 1`, then an index-out-of-range crash on `history[0]` | passed | `OCCTDocumentNamingHistoryCount` | PASS: 1 entry, new only |
| `newShapeFromHistory` | `OCCTDocumentNamingGetNewShape` returns null | :96 Expectation failed: newShape != nil | passed | `OCCTDocumentNamingGetNewShape` | PASS: new present, old absent |
| `modifyEvolution` | `OCCTDocumentNamingGetEvolution` answers 99 | :111 Expectation failed: doc.namingEvolution(on: label) == .modify | passed | `OCCTDocumentNamingGetEvolution` | PASS: MODIFY (2) |
| `deleteEvolution` | `OCCTDocumentNamingGetEvolution` answers 99 | :124 Expectation failed: doc.namingEvolution(on: label) == .delete | passed | `OCCTDocumentNamingGetEvolution` | PASS: DELETE (3) |
| `generatedEvolution` | `OCCTDocumentNamingGetEvolution` answers 99 | :135 Expectation failed: doc.namingEvolution(on: label) == .generated | passed | `OCCTDocumentNamingGetEvolution` | PASS: GENERATED (1), old and new |
| `multipleHistoryEntries` | `OCCTDocumentNamingHistoryCount` answers 0 | :153 Expectation failed: history.count >= 1 | passed | `OCCTDocumentNamingHistoryCount` | PASS: at least 1 |
### `TNamingCopyShapeTests.swift`
| `deepCopyBox` | `OCCTShapeDeepCopy` returns a null shape | :15 Expectation failed: copy.isValid | passed | `OCCTShapeDeepCopy` | PASS: copy exists and is not the same TShape |
| `deepCopySphere` | `OCCTShapeDeepCopy` returns a null shape | :24 Expectation failed: copy.isValid | passed | `OCCTShapeDeepCopy` | PASS: copy exists |
### `TNamingExtensionTests.swift`
| `namingIsEmpty` | `OCCTNamingIsEmpty` returns false | :15 Expectation failed: doc.namingIsEmpty(on: node) | passed | `OCCTNamingIsEmpty` | PASS: empty |
| `namingIsEmptyAfterRecord` | `OCCTNamingIsEmpty` returns true | :23 Expectation failed: !doc.namingIsEmpty(on: node) | passed | `OCCTNamingIsEmpty` | PASS: not empty |
| `namingVersion` | `OCCTNamingGetVersion` answers 7 | :31 Expectation failed: doc.namingVersion(on: node) == 0; :33 Expectation failed: doc.namingVersion(on: node) == 42 | passed | `OCCTNamingGetVersion` | PASS: 0, then 42 |
| `namingOriginalShape` | `OCCTNamingOriginalShape` returns a (null) shape where there is none | :43 Expectation failed: original == nil | passed | `OCCTNamingOriginalShape` | PASS: a primitive has no old shape |
| `namingOriginalShapeFromModify` | `OCCTNamingOriginalShape` returns null | :55 Expectation failed: original != nil | passed | `OCCTNamingOriginalShape` | PASS: the box |
| `namingHasLabel` | `OCCTNamingHasLabel` returns false | :63 Expectation failed: doc.namingHasLabel(shape: box) | passed | `OCCTNamingHasLabel` | PASS: true |
| `namingFindLabel` | `OCCTNamingFindLabel` answers -1 | :72 Expectation failed: found != nil | passed | `OCCTNamingFindLabel` | PASS: the recording label |
| `namingValidUntil` | `OCCTNamingValidUntil` answers -1 | :81 Expectation failed: valid >= 0 | passed | `OCCTNamingValidUntil` | PASS: 1 |
| `sameShapeCount` | `OCCTNamingSameShapeCount` answers 1 | :92 Expectation failed: count >= 2 | passed | `OCCTNamingSameShapeCount` | PASS: 3 labels hold the box |
| `sameShapeLabels` | `OCCTNamingSameShapeLabels` answers 1 | :103 Expectation failed: labels.count >= 2 | passed | `OCCTNamingSameShapeLabels` | PASS: 3 |
### `TNamingTracingTests.swift`
| `traceForward` | `OCCTDocumentNamingTraceForward` answers 0 | :21 Expectation failed: forward.count >= 1 | passed | `OCCTDocumentNamingTraceForward` | PASS: 2 |
| `traceBackward` | `OCCTDocumentNamingTraceBackward` answers 0 | :36 Expectation failed: backward.count >= 1 | passed | `OCCTDocumentNamingTraceBackward` | PASS: 1 |
| `multipleGenerations` | `OCCTDocumentNamingTraceForward` answers 0 | :55 Expectation failed: forward.count >= 2 | passed | `OCCTDocumentNamingTraceForward` | PASS: 2 |
| `emptyTraceForUnrelated` | `OCCTDocumentNamingTraceForward` answers the source shape | :67 Expectation failed: forward.isEmpty | passed | `OCCTDocumentNamingTraceForward` | PASS: not in the used-shape table, so 0 |
| `traceModificationChain` | `OCCTDocumentNamingTraceForward` answers 0 | :81 Expectation failed: forward.count >= 1 | passed | `OCCTDocumentNamingTraceForward` | PASS: at least 1 |
| `forwardTraceExcludesSource` | `OCCTDocumentNamingTraceForward` answers the source shape | :98 Expectation failed: !shape.isSame(as: box) | passed | `OCCTDocumentNamingTraceForward` | PASS: the source is not in its own forward trace |
| `backwardTraceExcludesGenerated` | `OCCTDocumentNamingTraceBackward` answers the given shape | :116 Expectation failed: !shape.isSame(as: sphere) | passed | `OCCTDocumentNamingTraceBackward` | PASS: the shape is not in its own backward trace |
### `TNamingTranslatorTests.swift`
| `translatorCopy` | `OCCTShapeTranslatorCopy` returns null | :12 Expectation failed: Bool(false) | passed | `OCCTShapeTranslatorCopy` | PASS: copied, a distinct TShape |
### `XCAFDocAssemblyIteratorTests.swift`
| `iterateAssembly` | `OCCTDocumentAssemblyItemCount` answers 0 | :16 Expectation failed: count >= 1 | passed | `OCCTDocumentAssemblyItemCount` | PASS: 3 items |
| `smallAssemblyCountIsComplete` | `OCCTDocumentAssemblyItemCount` answers 0 | :32 Expectation failed: count >= 3 | passed | `OCCTDocumentAssemblyItemCount` | PASS: 3 |
### `XCAFDocClippingPlaneToolTests.swift`
| `addAndGet` | `OCCTDocumentClipPlaneToolIsClipPlane` returns false | :15 Expectation failed: doc.clippingPlaneToolIsClipPlane(clip) | passed | `OCCTDocumentClipPlaneToolIsClipPlane` | PASS: z 5, normal z, capping |
| `remove` | `OCCTDocumentClipPlaneToolRemove` returns false | :32 Expectation failed: doc.clippingPlaneToolRemove(clip) | passed | `OCCTDocumentClipPlaneToolRemove` | PASS: removed |
### `XCAFDocColorTests.swift`
| `setAndGetRGB` | `OCCTDocumentSetColorAttr` returns false | :11 Expectation failed: label.setColorAttribute(red: 1.0, green: 0.0, blue: 0.0) | passed | `OCCTDocumentGetColorAttr` | PASS: (1, 0, 0) |
| `setAndGetRGBA` | `OCCTDocumentGetColorAlphaAttr` answers 0 | :27 Expectation failed: abs(label.colorAlphaAttribute - 0.8) < 0.02 | passed | `OCCTDocumentGetColorAlphaAttr` | PASS: 0.8 |
| `namedColor` | `OCCTDocumentGetColorNOCAttr` answers -1 | :38 Expectation failed: noc >= 0 | passed | `OCCTDocumentGetColorNOCAttr` | PASS: 407 for pure red |
### `XCAFDocDimTolTests.swift`
| `setAndGet` | `OCCTDocumentGetDimTolKind` answers 2 | :19 Expectation failed: kind == 1 | passed | `OCCTDocumentGetDimTolKind` | PASS: all four round-trip |
| `noDimTol` | `OCCTDocumentGetDimTolKind` answers 0 where there is none | :39 Expectation failed: doc.dimTolKind(labelId: node.labelId) == nil | passed | `OCCTDocumentGetDimTolKind` | N/A: none on a fresh label |
### `XCAFDocGraphNodeTests.swift`
| `setAndRelate` | `OCCTDocumentGraphNodeNbChildren` answers 0 | :17 Expectation failed: l1.xcafGraphNodeChildCount == 1 | passed | `OCCTDocumentGraphNodeNbChildren` | PASS: 1, 1 |
| `unsetRelationship` | `OCCTDocumentGraphNodeNbFathers` answers 1 | :35 Expectation failed: l2.xcafGraphNodeFatherCount == 0 | passed | `OCCTDocumentGraphNodeNbFathers` | PASS: 0, 0 |
| `isFatherIsChild` | `OCCTDocumentGraphNodeIsFather` / `IsChild` return false and `NbChildren` answers 0 | :52 Expectation failed: isFather \|\| isChild \|\| l1.xcafGraphNodeChildCount > 0 | passed | `OCCTDocumentGraphNodeIsFather` | PASS: IsFather true |
### `XCAFDocLocationTests.swift`
| `setAndGetLocation` | `OCCTDocumentHasLocation` returns false | :15 Expectation failed: label.hasLocationAttribute | passed | `OCCTDocumentGetLocationTranslation` | PASS: (10, 20, 30) |
| `noLocation` | `OCCTDocumentHasLocation` returns true | :28 Expectation failed: !label.hasLocationAttribute | passed | `OCCTDocumentHasLocation` | N/A: none on a fresh label |
### `XCAFDocMaterialTests.swift`
| `setAndGet` | `OCCTDocumentGetMaterialAttrName` returns null | :17 Expectation failed: label.materialAttributeName == "Steel" | passed | `OCCTDocumentGetMaterialAttrName` | PASS: Steel, Carbon steel, 7850 |
| `noMaterial` | `OCCTDocumentHasMaterialAttr` returns true | :29 Expectation failed: !label.hasMaterialAttribute | passed | `OCCTDocumentHasMaterialAttr` | N/A: none on a fresh label |
### `XCAFDocNoteBalloonTests.swift`
| `setAndGet` | `OCCTDocumentSetNoteBalloon` returns false | :11 Expectation failed: label.setNoteBalloon(userName: "User", timeStamp: "2026-03-14", comment: "Balloon text") | passed | `OCCTDocumentSetNoteBalloon` | PASS: Set non-null |
### `XCAFDocNoteBinDataTests.swift`
| `setAndGet` | `OCCTDocumentGetNoteBinDataSize` answers 0 | :18 Expectation failed: label.noteBinDataSize == 4 | passed | `OCCTDocumentGetNoteBinDataSize` | PASS: 4 |
### `XCAFDocNoteCommentTests.swift`
| `setAndGet` | `OCCTDocumentGetNoteCommentText` returns null | :15 Expectation failed: label.noteCommentText == "This is a comment" | passed | `OCCTDocumentGetNoteCommentText` | PASS: Set non-null, text and user match |
### `XCAFDocNotesToolTests.swift`
| `createAndCountNotes` | `OCCTDocumentNotesToolNbNotes` answers 0 | :15 Expectation failed: doc.notesToolNoteCount == 1 | passed | `OCCTDocumentNotesToolNbNotes` | PASS: 0, 1 |
| `createBalloon` | `OCCTDocumentNotesToolCreateBalloon` answers -1 | :24 Expectation failed: note != nil; :25 Expectation failed: doc.notesToolNoteCount == 1 | passed | `OCCTDocumentNotesToolCreateBalloon` | PASS: note non-null, 1 note |
| `createBinData` | `OCCTDocumentNotesToolCreateBinData` answers -1 | :37 Expectation failed: note != nil; :38 Expectation failed: doc.notesToolNoteCount == 1 | passed | `OCCTDocumentNotesToolCreateBinData` | PASS: note non-null, 1 note |
| `deleteAllNotes` | `OCCTDocumentNotesToolDeleteAllNotes` answers 0 | :51 Expectation failed: deleted == 3; :52 Expectation failed: doc.notesToolNoteCount == 0 | passed | `OCCTDocumentNotesToolDeleteAllNotes` | PASS: 3, 3, 0 |
| `orphanNotes` | `OCCTDocumentNotesToolNbOrphanNotes` answers -1 | :60 Expectation failed: doc.notesToolOrphanNoteCount >= 0 | passed | `OCCTDocumentNotesToolNbOrphanNotes` | PASS: >= 0 (kernel: 1 orphan for one comment) |
### `XCAFDocShapeMapToolTests.swift`
| `setShapeAndQuery` | `OCCTDocumentShapeMapToolIsSubShape` returns false | :16 Expectation failed: label.shapeMapToolIsSubShape(face) | passed | `OCCTDocumentShapeMapToolIsSubShape` | PASS: extent 33, face is a sub-shape |
### `DocumentExplorerExtensionTests.swift`
| `explorerDepth` | `OCCTDocumentExplorerDepth` returns -1 | :17 Expectation failed: depth >= 0 | passed | `OCCTDocumentExplorerDepth` | PASS: depth is non-negative on both sides (kernel depth 0 for the lone box node, which is reached) |
| `explorerIsAssembly` | `OCCTDocumentExplorerIsAssembly` returns true | :31 Expectation failed: !isAsm | passed | `OCCTDocumentExplorerIsAssembly` | PASS: false = false |
| `explorerIsAssemblyNeverTrueEvenForARealAssembly` | `OCCTDocumentExplorerIsAssembly` returns true | :72 Expectation failed: !doc.explorerIsAssembly(at: i) | passed | `OCCTDocumentExplorerIsAssembly` | PASS: assembly node is an assembly, the leaf list is non-empty and no leaf is an assembly, on both sides |
| `explorerLocation` | `OCCTDocumentExplorerLocation` writes a translation into the identity branch | :85 `matrix == [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]` (rewritten; the old `count == 12` could not fail) | passed | `OCCTDocumentExplorerLocation` | PASS: identity = identity |
| `explorerLocationOutOfRangeIndexIsATrueIdentity` | `OCCTDocumentExplorerLocation` pre-fills with the pre-#1480 `(i % 4 == i / 3)` formula | :110 Expectation failed: matrix == expectedIdentity | passed | `OCCTDocumentExplorerLocation` | N/A: no kernel counterpart: the identity is the bridge's own pre-filled fallback; the kernel walk reaches no node at that index |
### `DocumentLayerTests.swift`
| `builtInLayers` | `OCCTDocumentGetLayerCount` returns 0 | :12 Expectation failed: doc.layerCount > 0; :14 Expectation failed: !names.isEmpty | passed | `OCCTDocumentGetLayerCount` | EXPECTED_DIVERGENCE: the test asserts the #2413 defect: layers are positive on the bridge (3 tool labels), 0 in the kernel's layer table |
| `outOfRange` | `OCCTDocumentGetLayerName` clamps any index to 0 | :20 Expectation failed: doc.layerName(at: 999) == nil; :21 Expectation failed: doc.layerName(at: -1) == nil | passed | `OCCTDocumentGetLayerName` | PASS: no layer name at index 999 or -1 on both sides (kernel: Value(1000) and Value(0) raise Standard_OutOfRange) |
### `DocumentMaterialTests.swift`
| `emptyMaterials` | `OCCTDocumentGetMaterialCount` returns 1 | :11 Expectation failed: doc.materialCount == 0 | passed | `OCCTDocumentGetMaterialCount` | PASS: 0 materials and an empty list on both sides (the document's own material table is also 0) |
| `outOfRange` | `OCCTDocumentGetMaterialInfo` returns true for any index | :18 Expectation failed: doc.materialInfo(at: 0) == nil | passed | `OCCTDocumentGetMaterialInfo` | PASS: no material info at index 0 on both sides (kernel: 0 labels, Value(1) raises Standard_OutOfRange) |
### `Issue1481DimensionRefCountTests.swift`
| `singleShapeDimensionRegistersOnce` | the dimension is registered with `SetDimension(seq, seq, dim)` (the #1481 defect) | :40 Expectation failed: doc.refDimensionCount(for: labelId) == 1 | passed | `OCCTDocumentGetRefDimensionCount` | PASS: ref dimension count 1 on both sides (kernel single-shape overload 1; the sequence overload gives 2, the #1481 defect) |
| `singleShapeDimensionWithToleranceRegistersOnce` | the dimension is registered with `SetDimension(seq, seq, dim)` (the #1481 defect) | :66 Expectation failed: doc.refDimensionCount(for: labelId) == 1 | passed | `OCCTDocumentGetRefDimensionCount` | PASS: ref dimension count 1 on both sides, with a (-0.1, 0.1) tolerance object attached |
| `twoShapesEachRegisterOnce` | the dimension is registered with `SetDimension(seq, seq, dim)` (the #1481 defect) | :88 Expectation failed: doc.refDimensionCount(for: label1) == 1; :89 Expectation failed: doc.refDimensionCount(for: label2) == 1 | passed | `OCCTDocumentGetRefDimensionCount` | PASS: ref dimension counts [1, 1] and 2 dimension labels on both sides |
### `Issue1588TObjApplicationReleaseTests.swift`
| `singleGetReleaseRoundTrip` | `OCCTTObjApplicationIsVerbose` returns false | :71 Expectation failed: OCCTTObjApplicationIsVerbose(again) | passed | `OCCTTObjApplicationIsVerbose` | PASS: verbose true after SetVerbose(true) on both sides |
| `doubleReleaseDoesNotCorruptSingleton` | `OCCTTObjApplicationIsVerbose` returns true | :89 Expectation failed: !OCCTTObjApplicationIsVerbose(again) | passed | `OCCTTObjApplicationIsVerbose` | PASS: verbose false after SetVerbose(false) and a document created, on both sides |
| `repeatedGetReleaseCyclesDoNotCorruptSingleton` | `OCCTTObjApplicationCreateDocument` returns null | :110 Expectation failed: OCCTTObjApplicationCreateDocument(again) | passed | `OCCTTObjApplicationCreateDocument` | PASS: a document is created on both sides |
| `repeatedSharedAccessDoesNotCorruptSingleton` | `OCCTTObjApplicationIsVerbose` returns false | :134 Expectation failed: app.isVerbose | passed | `OCCTTObjApplicationIsVerbose` | PASS: verbose true after SetVerbose(true) and a document created, on both sides |
### `Issue173AssemblySTEPTests.swift`
| `instancedStructure` | `OCCTDocumentAddComponentMatrix` adds a copy of the part per instance | :42 Expectation failed: count("MANIFOLD_SOLID_BREP") == 1 | passed | `OCCTDocumentAddComponentMatrix` | PASS: 1 BREP, 20 occurrences |
| `roundTrip` | `OCCTDocumentAddComponentMatrix` returns -1 without adding | :69 Expectation failed: maxChildren == n | passed | `OCCTDocumentAddComponentMatrix` | PASS: max components under a root 8 on both sides |
| `emptyPathThrows` | `Exporter.writeSTEPAssembly` returns without writing or throwing | :78 Expectation failed: an error was expected but none was thrown | passed | `OCCTDocumentWriteSTEP` | N/A: no kernel counterpart: the empty-path check is Swift, before any bridge or OCCT call |
### `TDataStdIntegerTests.swift`
| `setGetInteger` | `OCCTDocumentGetIntegerAttr` returns false | :17 Expectation failed: label.integer == 42 | passed | `OCCTDocumentGetIntegerAttr` | PASS: 42 |
| `changeInteger` | `OCCTDocumentGetIntegerAttr` returns false | :26 Expectation failed: label.integer == 99 | passed | `OCCTDocumentGetIntegerAttr` | PASS: 99 after the second Set |
| `noInteger` | `OCCTDocumentGetIntegerAttr` answers 0 where there is none | :34 Expectation failed: label.integer == nil | passed | `OCCTDocumentGetIntegerAttr` | PASS: no integer attribute on a fresh child label, on both sides |
### `TDataStdIntPackedMapTests.swift`
| `setAndAdd` | `OCCTIntPackedMapContains` returns false | :13 Expectation failed: doc.intPackedMapContains(tag: 100, value: 42); :14 Expectation failed: doc.intPackedMapContains(tag: 100, value: 100) | passed | `OCCTIntPackedMapContains` | PASS: both contained |
| `extent` | `OCCTIntPackedMapExtent` returns 0 | :23 Expectation failed: doc.intPackedMapCount(tag: 101) == 3 | passed | `OCCTIntPackedMapExtent` | PASS: 3 |
| `remove` | `OCCTIntPackedMapRemove` returns true without removing | :32 Expectation failed: !doc.intPackedMapContains(tag: 102, value: 10); :33 Expectation failed: doc.intPackedMapCount(tag: 102) == 1 | passed | `OCCTIntPackedMapRemove` | PASS: Remove(10) true, Contains(10) false and extent 1 on both sides |
| `clearAndEmpty` | `OCCTIntPackedMapClear` returns true without clearing | :42 Expectation failed: doc.intPackedMapIsEmpty(tag: 103); :43 Expectation failed: doc.intPackedMapCount(tag: 103) == 0 | passed | `OCCTIntPackedMapClear` | PASS: not empty before Clear, empty with extent 0 after, on both sides |
| `getValues` | `OCCTIntPackedMapGetValues` returns no values | :53 Expectation failed: values.count == 3; :54 Expectation failed: values.contains(7) | passed | `OCCTIntPackedMapGetValues` | PASS: extent 3 and values {7, 42, 99} on both sides (compared as a set, sorted) |
| `changeValues` | `OCCTIntPackedMapChangeValues` returns true without changing | :64 Expectation failed: doc.intPackedMapCount(tag: 105) == 5; :65 Expectation failed: doc.intPackedMapContains(tag: 105, value: 30) | passed | `OCCTIntPackedMapChangeValues` | PASS: 5; 30 in, 1 out |
### `TDataXtdPatternStdTests.swift`
| `setAndGetSignature` | `OCCTDocumentPatternGetSignature` answers 2 | :18 Expectation failed: sig == .linear | passed | `OCCTDocumentPatternGetSignature` | PASS: signature ordinal 1 on both sides (PatternSignature.linear raw value 1) |
| `hasPattern` | `OCCTDocumentHasPattern` returns false | :28 Expectation failed: doc.hasPattern(labelId: node.labelId) | passed | `OCCTDocumentHasPattern` | PASS: true after Set |
| `noPattern` | `OCCTDocumentHasPattern` returns true | :34 Expectation failed: !doc.hasPattern(labelId: node.labelId) | passed | `OCCTDocumentHasPattern` | PASS: no pattern attribute on a fresh label, on both sides |
### `TDataXtdPlacementTests.swift`
| `setAndHas` | `OCCTDocumentHasPlacement` returns false | :15 Expectation failed: doc.hasPlacement(labelId: node.labelId) | passed | `OCCTDocumentHasPlacement` | PASS: true |
| `noPlacement` | `OCCTDocumentHasPlacement` returns true | :21 Expectation failed: !doc.hasPlacement(labelId: node.labelId) | passed | `OCCTDocumentHasPlacement` | PASS: no placement attribute on a fresh label, on both sides |
### `TDataXtdPositionAttributeTests.swift`
| `setGetPosition` | `OCCTDocumentGetPositionAttr` answers (0, 0, 0) | :19 Expectation failed: abs(pos.x - 1.0) < 1e-10; :20 Expectation failed: abs(pos.y - 2.0) < 1e-10 | passed | `OCCTDocumentGetPositionAttr` | PASS: (1, 2, 3) |
| `noPositionAttribute` | `OCCTDocumentHasPositionAttr` returns true | :29 Expectation failed: !label.hasPositionAttribute | passed | `OCCTDocumentHasPositionAttr` | PASS: no position attribute on a fresh label, on both sides |
### `TDataXtdPresentationTests.swift`
| `setAndHas` | `OCCTDocumentHasPresentation` returns false | :16 Expectation failed: doc.hasPresentation(labelId: node.labelId) | passed | `OCCTDocumentHasPresentation` | PASS: true |
| `colorAndTransparency` | `OCCTDocumentPresentationGetColor` answers 0 | :30 Expectation failed: color == 12 | passed | `OCCTDocumentPresentationGetColor` | PASS: 12, 0.5 |
| `widthAndMode` | `OCCTDocumentPresentationGetWidth` answers 0 | :48 Expectation failed: abs(width - 2.0) < 1e-6 | passed | `OCCTDocumentPresentationGetWidth` | PASS: width 2.0 and mode 1 on both sides |
| `displayState` | `OCCTDocumentPresentationIsDisplayed` returns false | :63 Expectation failed: doc.presentationIsDisplayed(labelId: node.labelId) | passed | `OCCTDocumentPresentationIsDisplayed` | PASS: true |
| `unsetPresentation` | `OCCTDocumentUnsetPresentation` returns without unsetting | :74 Expectation failed: !doc.hasPresentation(labelId: node.labelId) | passed | `OCCTDocumentUnsetPresentation` | PASS: gone after Unset |
### `TDFLabelPropertyTests.swift`
| `labelTag` | `OCCTDocumentLabelTag` answers 99 | :17 Expectation failed: main.tag == 1 | passed | `OCCTDocumentLabelTag` | PASS: Main tag 1 |
| `labelDepth` | `OCCTDocumentLabelDepth` answers 5 | :25 Expectation failed: main.depth == 1; :27 Expectation failed: child.depth == 2 | passed | `OCCTDocumentLabelDepth` | PASS: Main depth 1 and depth 2 for a child of Main, on both sides |
| `labelIsNull` | `OCCTDocumentLabelIsNull` returns true for every id | :36 Expectation failed: !main.isNull | passed | `OCCTDocumentLabelIsNull` | PASS: Main is not null on both sides |
| `labelIsRoot` | `OCCTDocumentLabelIsRoot` returns true | :44 Expectation failed: !main.isRoot | passed | `OCCTDocumentLabelIsRoot` | PASS: Main not root; Root() is |
| `labelFather` | `OCCTDocumentLabelFather` answers -1 | :57 `child.father?.labelId == main.labelId` (rewritten; with `father` inside the `if let`, a missing father passed) | passed | `OCCTDocumentLabelFather` | PASS: a child's father is Main on both sides |
| `labelRoot` | `OCCTDocumentLabelIsRoot` returns false | :65 Expectation failed: root.isRoot | passed | `OCCTDocumentLabelRoot` | PASS: the root of a label is the root label on both sides |
| `labelAttributes` | `OCCTDocumentLabelHasAttribute` returns false | :78 Expectation failed: label.hasAttribute | passed | `OCCTDocumentLabelHasAttribute` | PASS: no attributes on a fresh label, at least 1 after a name is set, on both sides |
| `labelChildren` | `OCCTDocumentLabelNbChildren` answers 0 | :92 Expectation failed: parent.childCount == 2 | passed | `OCCTDocumentLabelNbChildren` | PASS: 0, then 2 |
| `labelFindChild` | `OCCTDocumentLabelFindChild` answers -1 | :103 Expectation failed: found != nil; :111 Expectation failed: created != nil | passed | `OCCTDocumentLabelFindChild` | PASS: existing child found, tag 999 absent then created, 2 children after, on both sides |
| `labelForgetAllAttributes` | `OCCTDocumentLabelForgetAllAttributes` returns without forgetting | :124 Expectation failed: !label.hasAttribute | passed | `OCCTDocumentLabelForgetAllAttributes` | PASS: no attribute after |
| `labelDescendants` | `OCCTDocumentGetDescendantLabels` answers 0 | :137 Expectation failed: direct.count == 2; :140 Expectation failed: all.count == 4 | passed | `OCCTDocumentGetDescendantLabels` | PASS: 2 and 4 |
| `labelDescendantsBeyondBufferCap` | `OCCTDocumentGetDescendantLabels` answers 0 | :153 Expectation failed: direct.count == extraCount | passed | `OCCTDocumentGetDescendantLabels` | PASS: 1029 children created and 1029 reported on both sides (no 1024 cap) |
### `TFunctionLogbookTests.swift`
| `logbookBasic` | `OCCTDocumentLogbookIsModified` returns false | :23 Expectation failed: logLabel.logbookIsModified(target1) | passed | `OCCTDocumentLogbookIsModified` | PASS: logbook set, empty when fresh, not empty after SetTouched(t1), t1 modified and t2 not, on both sides |
| `logbookImpactedAndClear` | `OCCTDocumentLogbookClear` returns true without clearing | :36 Expectation failed: logLabel.logbookIsEmpty | passed | `OCCTDocumentLogbookClear` | PASS: empty |
### `TFunctionScopeTests.swift`
| `setFunctionScope` | `OCCTDocumentSetFunctionScope` returns false | :14 Expectation failed: ok | passed | `OCCTDocumentSetFunctionScope` | PASS: the scope attribute is set on the root on both sides |
| `addAndHasFunction` | `OCCTDocumentFunctionScopeHas` returns false | :24 Expectation failed: doc.functionScopeHas(labelId: node.labelId) | passed | `OCCTDocumentFunctionScopeHas` | PASS: true |
| `removeFunction` | `OCCTDocumentFunctionScopeRemove` returns true without removing | :36 Expectation failed: !doc.functionScopeHas(labelId: node.labelId) | passed | `OCCTDocumentFunctionScopeRemove` | PASS: removed |
| `removeAllFunctions` | `OCCTDocumentFunctionScopeRemoveAll` returns true without removing | :49 Expectation failed: doc.functionScopeCount == 0 | passed | `OCCTDocumentFunctionScopeRemoveAll` | PASS: 2 then 0 |
| `freeID` | `OCCTDocumentFunctionScopeGetFreeID` answers 0 | :58 Expectation failed: freeId >= 1; :62 Expectation failed: freeId2 > freeId | passed | `OCCTDocumentFunctionScopeGetFreeID` | PASS: fresh free ID at least 1 and larger after one function is added, on both sides (kernel 1 then 2) |
### `TickTests.swift`
| `setAndHas` | `OCCTDocumentSetTick` returns true without setting | :14 Expectation failed: doc.hasTick(tag: 500) | passed | `OCCTDocumentSetTick` | PASS: false, true |
| `remove` | `OCCTDocumentRemoveTick` returns true without removing | :21 Expectation failed: !doc.hasTick(tag: 501) | passed | `OCCTDocumentRemoveTick` | PASS: the tick is present before removal and absent after, on both sides |
| `removeNonExistent` | `OCCTDocumentRemoveTick` returns true without removing | :26 Expectation failed: !doc.removeTick(tag: 502) | passed | `OCCTDocumentRemoveTick` | PASS: no tick on tag 502, so removal finds nothing, on both sides |
### `TNamingNamingTests.swift`
| `insertNaming` | `OCCTDocumentInsertNaming` returns false | :15 Expectation failed: ok | passed | `OCCTDocumentInsertNaming` | PASS: a naming attribute is inserted on both sides |
| `namingIsDefined` | `OCCTDocumentNamingIsDefined` returns true | :25 Expectation failed: !doc.namingIsDefined(labelId: node.labelId) | passed | `OCCTDocumentNamingIsDefined` | PASS: false on both sides, but the bridge's false is a lookup miss: Insert puts the naming on a child label (see source) |
### `TNamingScopeTests.swift`
| `validAndIsValid` | `OCCTDocumentNamingScopeIsValid` returns false | :14 Expectation failed: doc.namingScopeIsValid(labelId: node.labelId) | passed | `OCCTDocumentNamingScopeIsValid` | PASS: true |
| `unvalid` | `OCCTDocumentNamingScopeUnvalid` returns true without unvalidating | :23 Expectation failed: !doc.namingScopeIsValid(labelId: node.labelId) | passed | `OCCTDocumentNamingScopeUnvalid` | PASS: not valid after Unvalid on both sides |
| `validCount` | `OCCTDocumentNamingScopeValidCount` answers 1 | :32 Expectation failed: doc.namingScopeValidCount >= 2; :34 Expectation failed: doc.namingScopeValidCount == 0 | passed | `OCCTDocumentNamingScopeValidCount` | PASS: at least 2 valid labels after two Valid calls and 0 after Clear, on both sides (kernel count 2) |
### `TNamingSelectResolveTests.swift`
| `selectSubShape` | `OCCTDocumentNamingSelect` returns false | :22 Expectation failed: ok | passed | `OCCTDocumentNamingSelect` | PASS: Select(rectangle face, box) succeeds on both sides |
| `resolveShape` | `OCCTDocumentNamingResolve` returns null | :42 `resolved != nil`, :43 the face count (rewritten; the old test asserted `Bool(true)` only when something came back) | passed | `OCCTDocumentNamingResolve` | PASS: select succeeds, resolve returns a shape holding at least 1 face, on both sides (kernel: a compound of 6 faces) |
| `selectedEvolution` | `OCCTDocumentNamingGetEvolution` answers 99 | :47 Expectation failed: evo == .selected | passed | `OCCTDocumentNamingGetEvolution` | PASS: evolution SELECTED on both sides (the bridge's code is 4, the kernel's ordinal is 5) |
### `XDEAreaVolumeCentroidTests.swift`
| `area` | `OCCTDocumentSetArea` stores twice the area | :21 Expectation failed: abs(area - 2200.0) < 1e-5 | passed | `OCCTDocumentGetArea` | PASS: area 2200.0 on both sides |
| `volume` | `OCCTDocumentSetVolume` stores twice the volume | :40 Expectation failed: abs(vol - 6000.0) < 1e-5 | passed | `OCCTDocumentGetVolume` | PASS: volume 6000.0 on both sides |
| `centroid` | `OCCTDocumentSetCentroid` stores x plus 1 | :59 Expectation failed: abs(c.x - 5.0) < 1e-5 | passed | `OCCTDocumentGetCentroid` | PASS: (5, 10, 15) |
### `XDEAssemblyOperationTests.swift`
| `addComponent` | `OCCTDocumentGetComponentCount` answers 1 | :34 Expectation failed: doc.componentCount(assemblyLabelId: assemblyLabelId) == 2 | passed | `OCCTDocumentGetComponentCount` | PASS: 2 |
| `getComponents` | `OCCTDocumentGetComponentReferredLabelId` answers -1 | :55 Expectation failed: referredId >= 0 | passed | `OCCTDocumentGetComponentReferredLabelId` | PASS: the component and its referred shape are found on both sides (the referred label is the part) |
| `removeComponent` | `OCCTDocumentRemoveComponent` returns without removing | :75 Expectation failed: doc.componentCount(assemblyLabelId: asmId) == 1 | passed | `OCCTDocumentRemoveComponent` | PASS: 2, then 1 |
| `userCount` | `OCCTDocumentGetShapeUserCount` answers 0 | :91 Expectation failed: doc.shapeUserCount(shapeLabelId: boxId) > 0 | passed | `OCCTDocumentGetShapeUserCount` | PASS: the part has at least one user on both sides (kernel count 1) |
| `updateAssemblies` | `OCCTDocumentUpdateAssemblies` returns without updating | the assembly-shape solid count (rewritten; the old test asserted `Bool(true)` after the call) | passed | `OCCTDocumentUpdateAssemblies` | PASS: 1 component and 1 solid in the updated assembly shape, on both sides |
### `XDEEditorTests.swift`
| `editorExpand` | `OCCTDocumentEditorExpand` returns false | `editorExpand(...)` and the component count (rewritten; the old test discarded the result and asserted `Bool(true)`) | passed | `OCCTDocumentEditorExpand` | PASS: Expand returns true and the two-body compound becomes 2 components, on both sides |
| `rescaleGeometry` | `OCCTDocumentEditorRescaleGeometry` returns false | `rescaleGeometry(...)` (rewritten; the old test discarded the result and asserted `Bool(true)`) | passed | `OCCTDocumentEditorRescaleGeometry` | PASS: RescaleGeometry with force returns true on both sides |
### `XDEColorToolByShapeTests.swift`
| `setAndGetColor` | `OCCTDocumentIsShapeColorSet` returns false | :19 Expectation failed: doc.isShapeColorSet(box) | passed | `OCCTDocumentIsShapeColorSet` | PASS: colour set, red 1.0 and green 0.0 on both sides (the test asserts red and green only) |
| `visibility` | `OCCTDocumentSetLabelVisibility` returns without setting | :39 Expectation failed: !node.isVisible | passed | `OCCTDocumentSetLabelVisibility` | PASS: false, true |
| `shapeColorPreservesAlpha` | `OCCTDocumentSetShapeColorRGBA` stores alpha 1 | :69 Expectation failed: abs(got.alpha - 0.5) < 1e-5 | passed | `OCCTDocumentGetShapeColor` | PASS: rgba (0.2, 0.4, 0.6, 0.5) within 1e-5 on both sides (kernel stores single-precision floats) |
| `shapeColorOpaqueUnaffected` | `OCCTDocumentSetShapeColorRGBA` stores alpha 0.5 | :89 Expectation failed: abs(got.alpha - 1.0) < 1e-5 | passed | `OCCTDocumentGetShapeColor` | PASS: alpha 1.0 (a double on both sides) |
### `XDELayerToolExpansionTests.swift`
| `setAndCheck` | `OCCTDocumentIsLayerSet` returns false | :20 Expectation failed: node.isLayerSet("Layer1") | passed | `OCCTDocumentIsLayerSet` | PASS: true |
| `getLayers` | `OCCTDocumentGetLabelLayers` answers 0 | :38 Expectation failed: layers.count == 1 | passed | `OCCTDocumentGetLabelLayers` | PASS: 1, TestLayer |
| `findAndVisibility` | `OCCTDocumentGetLayerVisibility` returns true | :62 Expectation failed: !doc.layerVisibility(layerLabelId: layerLabelId) | passed | `OCCTDocumentGetLayerVisibility` | PASS: found; false, true |
| `getLayersBeyondBufferCap` | `OCCTDocumentGetLabelLayers` answers 0 | :86 Expectation failed: layers.count == extraCount | passed | `OCCTDocumentGetLabelLayers` | PASS: 19 layers set and 19 reported on both sides (no 16-entry cap) |
