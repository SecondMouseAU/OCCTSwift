# Phase 3: OCCTXCAFTests Injection Matrix

**Target**: `OCCTXCAFTests` (481 tests) — XCAF document operations, colors, layers, assemblies
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 P1 (crash fixes #341, #344, #349, #353, #371, #374)

---

## Test Inventory by Suite

_The 16-row stub inventory (424 tests across 16 suites) was removed by the #1982 evidence correction: none of its suites names a test that exists in `Tests/OCCTXCAFTests`. The measured records below are the inventory._

**Total**: 0 tests across 0 suites (stub inventory removed)

---

## Injection Matrix: Critical Crash Fixes

_The six stub rows for `XCAF Document Save` and `XCAF Document Save/Load` were removed by the #1982 evidence correction: they were ticked with no run. The real save/load tests carry the measured records below._

---

## Injection Matrix

_The 16 stub rows (`OCCTXCAFColor`, `OCCTXCAFLayer` and the rest name bridge functions that do not exist) were removed by the #1982 evidence correction. The per-test matrix is the measured records below._

---

## Bridge-Kernel Parity Checks

For each test, run ground-truth C++ comparison:
1. Write C++ test calling OCCT kernel directly
2. Run same inputs through Swift bridge
3. Compare outputs bit-for-bit (integers) or 1e-12 relative (doubles)
4. Document any discrepancies

---

## Progress Tracking

_The 16 stub progress rows were removed by the #1982 evidence correction; each ticked all three columns with no run._

**Total**: 0 tests (stub progress rows removed)

## Measured records (#766 execution, per test file)

Each row below was run: the injection applied behind an `OCCT_INJ` environment switch, the test run red, the switch removed and the test run green, and the kernel value taken from the committed probe under `Scripts/repro/766-xcaf-*`. Rows are appended per test file. The audited stub matrices that stood above were removed by the #1982 evidence correction.

### `AssemblyNodeIdentityTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `labelIdRoundTrip` | `OCCTDocumentLabelIsNull` returns true for every id | :26 Issue recorded | passed | `OCCTDocumentLabelIsNull` | PASS: one free shape, re-fetched root is the same label and reads the same name, on both sides |
| `unknownLabelIdRejected` | `OCCTDocumentLabelIsNull` returns false for every id | :40 Expectation failed: doc.node(at: .max) == nil | passed | `OCCTDocumentLabelIsNull` | N/A: the labelId registry is the bridge's own vector; no kernel counterpart |
| `nodeAtFreshDocumentDoesNotRequireWarmup` | `Document.node(at:)` skips its root warm-up loop (the #95 defect) | :60 Expectation failed: node != nil | passed | `OCCTDocumentGetRootLabelId` | N/A: labelId 0 is a bridge registry index; the kernel has the root label 0:1:1:1 but no ids |

### `ChildNodeIteratorTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `noTreeNode` | `OCCTChildNodeIteratorCount` returns 1 | :12 Expectation failed: doc.childNodeCount(tag: 400) == 0 | passed | `OCCTChildNodeIteratorCount` | PASS: child count 0 on both sides (no TreeNode attribute on the label) |

### `ColorToolCompletionsTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `addAndFindColor` | `OCCTDocumentColorToolFindColor` returns -1 | :14 Expectation failed: found == tag | passed | `OCCTDocumentColorToolFindColor` | PASS: FindColor returns the label AddColor made, on both sides |
| `colorCount` | `OCCTDocumentColorToolGetColorCount` returns 0 | :23 Expectation failed: after == before + 1 | passed | `OCCTDocumentColorToolGetColorCount` | PASS: colour count grows by 1 on both sides (kernel 0 then 1) |
| `removeColor` | `OCCTDocumentColorToolRemoveColor` returns true without removing | :34 Expectation failed: after == before - 1 | passed | `OCCTDocumentColorToolRemoveColor` | PASS: colour count shrinks by 1 on both sides (kernel 1 then 0) |
| `visibility` | `OCCTDocumentColorToolSetVisibility` returns true without setting | :48 Expectation failed: !doc.colorToolIsVisible(labelId: labelId) | passed | `OCCTDocumentColorToolIsVisible` | PASS: true, false, true |
| `colorByLayer` | `OCCTDocumentColorToolSetColorByLayer` returns true without setting | :65 Expectation failed: doc.colorToolIsColorByLayer(labelId: labelId) | passed | `OCCTDocumentColorToolIsColorByLayer` | PASS: false, then true |
### `DocumentColorMaterialTests.swift`
| `setLabelColor` | `OCCTDocumentSetLabelColor` returns without setting | :24 Expectation failed: color != nil | passed | `OCCTDocumentSetLabelColor` | PASS: rgb (1, 0, 0) on both sides (test tolerance 0.01) |
| `colorAttrRoundTrips` | `OCCTDocumentSetColorAttr` builds the colour as `Quantity_TOC_sRGB` (the #1508 defect) | :58 Expectation failed: abs(readBack.red - 0.5) < 1e-6; :59 Expectation failed: abs(readBack.green - 0.25) < 1e-6 | passed | `OCCTDocumentGetColorAttr` | PASS: rgb (0.5, 0.25, 0.75) on both sides (the sRGB-built defect value is in the transcript) |
| `colorRGBAAttrRoundTrips` | `OCCTDocumentSetColorRGBAAttr` builds the colour as `Quantity_TOC_sRGB` (the #1508 defect) | :86 Expectation failed: abs(readBack.red - 0.5) < 1e-6; :87 Expectation failed: abs(readBack.green - 0.25) < 1e-6 | passed | `OCCTDocumentGetColorRGBAAttr` | PASS: rgba (0.5, 0.25, 0.75, 0.4) on both sides |
| `setLabelMaterial` | `OCCTDocumentSetLabelMaterial` stores roughness as metallic | :117 Expectation failed: abs(readMat.metallic - 0.9) < 0.01 | passed | `OCCTDocumentGetLabelMaterial` | PASS: metallic 0.9 and roughness 0.3 on both sides (test tolerance 0.01) |
### `DocumentExplorerTests.swift`
| `exploreDocumentWithShape` | `OCCTDocumentExplorerCount` returns 0 | :15 Expectation failed: count >= 1 | passed | `OCCTDocumentExplorerCount` | PASS: at least 1 leaf on both sides (kernel 1) |
| `explorerShapeAtIndex` | `OCCTDocumentExplorerShape` returns null | :25 Expectation failed: shape != nil | passed | `OCCTDocumentExplorerShape` | PASS: leaf 0 has a shape on both sides |
| `explorerPathId` | `OCCTDocumentExplorerPathId` returns null | :35 Expectation failed: pathId != nil | passed | `OCCTDocumentExplorerPathId` | PASS: leaf 0 has a path id on both sides (kernel "0:1:1:1.") |
| `findShapeFromPathId` | `OCCTDocumentExplorerFindShape` returns null | :46 Expectation failed: found != nil | passed | `OCCTDocumentExplorerFindShape` | PASS: the path id resolves to a shape on both sides (kernel: a solid) |
### `BRepGraphAttributeTests.swift`
| `attachAndReadMixedAttributes` | `NodeAttributeStore.set` drops the write | :27 Expectation failed: graph.attribute("residualRMS", for: faceNode)?.doubleValue == 0.042; :28 Expectation failed: graph.attribute("surfaceType", for: faceNode)?.stringValue == "plane" | passed | `OCCTBRepGraphCreate` | N/A: the store is pure Swift (`NodeAttributeStore`); nothing in OCCT to compare |
| `clearingLastAttributeDropsNode` | `NodeAttributeStore.clear` keeps an emptied node entry | :49 Expectation failed: graph.attributes.annotatedNodeCount == 0 | passed | `OCCTBRepGraphCreate` | N/A: pure Swift store |
| `snapshotJSONRoundTrip` | `BRepGraph(snapshot:)` restores an empty store | :74 Expectation failed: restored.attribute("residualRMS", for: f0)?.doubleValue == 0.001; :75 Expectation failed: restored.attribute("decision", for: f3)?.stringValue == "human" | passed | `OCCTBRepGraphCreate` | PASS: face and vertex counts preserved across the BREP round trip on both sides (kernel 6 and 8) |
| `encodingIsDeterministic` | `NodeAttributeStore.encode` skips its node sort | :101 `a == b` and :109 the pinned bytes (rewritten; the old `a == b` compared one store with itself) | passed | `OCCTBRepGraphCreate` | N/A: Codable output is pure Swift |
| `nodeIndexingDeterministicAcrossRebuild` | `OCCTBRepGraphVertexPoint` answers differently for any graph but the first | :115 Expectation failed: abs(p1.x - p2.x) < 1e-9; :116 Expectation failed: abs(p1.y - p2.y) < 1e-9 | passed | `OCCTBRepGraphVertexPoint` | PASS: equal counts and vertex i identical across a rebuild on both sides (kernel max distance 0) |
| `futureFormatVersionRejected` | `BRepGraph(snapshot:)` skips its format-version guard | :129 Expectation failed: an error was expected but none was thrown | passed | `OCCTBRepGraphCreate` | N/A: the version check is pure Swift |
| `invalidBREPThrows` | `BRepGraph(snapshot:)` substitutes a box for an unparseable BREP | :137 Expectation failed: an error was expected but none was thrown | passed | `OCCTShapeFromBREPString` | PASS: the text "not a brep" is rejected as a BREP on both sides (Swift throws where the kernel leaves the shape null) |
### `ExpressionTests.swift`
| `setExpression` | `OCCTDocumentExpressionSet` returns false | :11 Expectation failed: ok | passed | `OCCTDocumentExpressionSet` | PASS: an expression attribute is set on both sides |
| `setAndGetString` | `OCCTDocumentExpressionGetString` returns null | :20 Expectation failed: str == "x^2 + y^2" | passed | `OCCTDocumentExpressionGetString` | PASS: `x^2 + y^2` |
| `getName` | `OCCTDocumentExpressionGetName` returns null | :29 Expectation failed: name != nil | passed | `OCCTDocumentExpressionGetName` | PASS: the expression name is readable on both sides (kernel "a + b") |
### `DocumentGDTTests.swift`
| `setDimensionBoundsRefusesPlusMinus` | `OCCTDocumentSetDimensionBounds` drops its plus/minus refusal | :39 Expectation failed: dim.bounds == .plusMinus(lowerTolerance: -0.3, upperTolerance: 0.7); :40 Expectation failed: dim.value == 20.0 | passed | `OCCTDocumentSetDimensionBounds` | EXPECTED_DIVERGENCE: by-design guard: the bridge refuses and keeps (20, -0.3, 0.7); the raw kernel write leaves value 10, lowerTol 12 |
| `setDimensionBoundsConvertsSimple` | `OCCTDocumentSetDimensionBounds` reports failure after writing | :61 Expectation failed: doc.setDimensionBounds(at: idx, lower: 10.0, upper: 12.0) == true; :63 Expectation failed: dim.bounds == .range(lower: 10.0, upper: 12.0) | passed | `OCCTDocumentSetDimensionBounds` | PASS: a simple dimension becomes the range 10..12 on both sides |
| `createAndReadDimension` | `OCCTDocumentGetDimensionInfo` reads the upper tolerance as the lower | :91 Expectation failed: dim.bounds == .plusMinus(lowerTolerance: -0.1, upperTolerance: 0.1); :92 Expectation failed: dim.lowerTolerance.map { abs($0 - (-0.1)) < 1e-9 } == true | passed | `OCCTDocumentGetDimensionInfo` | PASS: radius (ordinal 17) 25 -0.1/+0.1 plus/minus, one label at index 0, on both sides |
| `createTolerance` | `OCCTDocumentGetGeomToleranceInfo` adds 1.0 to the value | :114 Expectation failed: abs(tol.value - 0.01) < 1e-9 | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: flatness (ordinal 7) 0.01 at index 0 on both sides |
| `createDatum` | `OCCTDocumentGetDatumInfo` returns an invalid info | :131 Issue recorded | passed | `OCCTDocumentGetDatumInfo` | PASS: datum "A" at index 0 on both sides |
| `fullAuthoring` | `OCCTDocumentGetDatumCount` returns 1 | :156 Expectation failed: doc.datumCount == 2; :160 Expectation failed: doc.datums.map(\.name).sorted() == ["A", "B"] | passed | `OCCTDocumentGetDatumCount` | PASS: 3 dimensions, 2 tolerances, 2 datums named A and B on both sides |
| `dimensionTypeEnumComplete` | a compile-time extra case (`injected766 = 9999`) added to the Swift enum; removed and rebuilt for green | :165 Expectation failed: Document.DimensionType.allCases.count == 32 | passed | `OCCTDocumentGetDimensionInfo` | PASS: 32 dimension types on both sides |
| `geomToleranceTypeEnumComplete` | a compile-time extra case (`injected766 = 9999`) added to the Swift enum; removed and rebuilt for green | :170 Expectation failed: Document.GeomToleranceType.allCases.count == 16 | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: 16 geometric tolerance types on both sides |
### `GDTDimensionAccessorTests.swift`
| `qualifierRoundTrips` | `OCCTDocumentGetDimensionInfo` reports qualifier 0 | :42 Expectation failed: qualified.qualifier == .max | passed | `OCCTDocumentGetDimensionInfo` | PASS: 0, Max (2), 0; value 20 and simple kept |
| `angularQualifierRoundTrips` | `OCCTDocumentGetDimensionInfo` reports angular qualifier 0 | :69 Expectation failed: both.angularQualifier == .large | passed | `OCCTDocumentGetDimensionInfo` | PASS: Min (1), Large (2) |
| `decimalPlacesDistinguishAbsenceFromZero` | `OCCTDocumentGetDimensionInfo` tests decimal-place presence with `&&` instead of `or` | :102 Issue recorded | passed | `OCCTDocumentGetDimensionInfo` | PASS: (2,3), (0,4) and (0,0) read back as written; the bridge maps (0,0) to absent |
| `modifiersRoundTripInOrder` | `OCCTDocumentGetDimensionModifier` swaps modifier indices 0 and 1 | :123 Expectation failed: doc.dimension(at: index)?.modifiers == written | passed | `OCCTDocumentGetDimensionModifier` | PASS: modifiers 19, 1, 2 kept in order and cleared to 0, on both sides |
| `typeClassifiersMatchOCCT` | `OCCTDimensionTypeIsDimensionalLocation` returns true | :137 Expectation failed: !Document.DimensionType.sizeDiameter.isDimensionalLocation; :140 Expectation failed: !Document.DimensionType.commonLabel.isDimensionalLocation | passed | `OCCTDimensionTypeIsDimensionalLocation` | PASS: identical, and no type is both |
| `accessorsAreNotSharedBetweenDimensions` | `OCCTDocumentSetDimensionDecimalPlaces` writes to dimension 0 | :173 Expectation failed: a.decimalPlaces == nil; :177 Expectation failed: b.decimalPlaces?.left == 1 | passed | `OCCTDocumentSetDimensionDecimalPlaces` | PASS: two dimensions keep their own qualifier, modifiers and places on both sides |
| `outOfRangeIndicesAreRefused` | `OCCTDocumentSetDimensionQualifier` returns true without checking the index | :193 Expectation failed: !doc.setDimensionQualifier(at: 5, .max) | passed | `OCCTDocumentSetDimensionQualifier` | EXPECTED_DIVERGENCE: by-design guard: a negative place count is refused by the bridge; the raw kernel accepts it and reads back (0, 0) |
### `GDTDocumentTests.swift`
| `emptyDocDimensions` | `OCCTDocumentGetDimensionCount` returns 1 | :16 Expectation failed: doc.dimensionCount == 0 | passed | `OCCTDocumentGetDimensionCount` | PASS: 0 dimensions on both sides |
| `emptyDocTolerances` | `OCCTDocumentGetGeomToleranceCount` returns 1 | :26 Expectation failed: doc.geomToleranceCount == 0 | passed | `OCCTDocumentGetGeomToleranceCount` | PASS: 0 geometric tolerances on both sides |
| `emptyDocDatums` | `OCCTDocumentGetDatumCount` returns 1 | :36 Expectation failed: doc.datumCount == 0 | passed | `OCCTDocumentGetDatumCount` | PASS: 0 datums on both sides |
| `dimensionInvalidIndex` | `OCCTDocumentGetDimensionInfo` returns a valid info for any index | :46 Expectation failed: doc.dimension(at: 0) == nil; :47 Expectation failed: doc.dimension(at: -1) == nil | passed | `OCCTDocumentGetDimensionInfo` | PASS: no dimension at index 0, -1 or 999 on both sides |
| `toleranceInvalidIndex` | `OCCTDocumentGetGeomToleranceInfo` returns a valid info for any index | :57 Expectation failed: doc.geomTolerance(at: 0) == nil; :58 Expectation failed: doc.geomTolerance(at: -1) == nil | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: no tolerance at index 0 or -1 on both sides |
| `datumInvalidIndex` | `OCCTDocumentGetDatumInfo` returns a valid info and `OCCTDocumentGetDatumName` an empty name for any index | :67 Expectation failed: doc.datum(at: 0) == nil; :68 Expectation failed: doc.datum(at: -1) == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: no datum at index 0 or -1 on both sides |
### `GDTToleranceDatumAccessorTests.swift`
| `toleranceSemanticsRoundTrip` | `OCCTDocumentGetGeomToleranceInfo` reports material requirement 0 | :59 Expectation failed: tol.materialRequirement == .m | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: written values read back; value 0.1, type Position (10) |
| `toleranceZeroValuesAreAbsence` | `OCCTDocumentGetGeomToleranceInfo` treats a zero zone value as present (`>=` for `>`) | :86 Expectation failed: tol.zoneModifierValue == nil | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: kernel stores 0 and 0 with the zone kept; the bridge maps 0 to absent |
| `toleranceModifiersRoundTripInOrder` | `OCCTDocumentGetGeomToleranceModifier` swaps modifier indices 0 and 1 | :107 Expectation failed: doc.geomTolerance(at: index)?.modifiers == written | passed | `OCCTDocumentGetGeomToleranceModifier` | PASS: modifiers 15, 1, 3 kept in order and cleared to 0, on both sides |
| `datumPositionRoundTrips` | `OCCTDocumentGetDatumInfo` treats position 0 as a place in the frame (`>=` for `>`) | :123 Expectation failed: doc.datum(at: index)?.position == nil; :129 Expectation failed: doc.datum(at: index)?.position == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: 0, 2, 0; the bridge maps 0 to no place |
| `datumModifiersRoundTrip` | `OCCTDocumentGetDatumInfo` drops the valued modifier's value | :152 Expectation failed: datum.modifierWithValue?.value == 12.5 | passed | `OCCTDocumentGetDatumInfo` | PASS: 2, 3; Projected (3) 12.5; cleared to None |
| `datumTargetDimensionsFollowTheType` | `OCCTDocumentGetDatumInfo` reports a width for every target type | :208 Expectation failed: target.width == nil; :217 Expectation failed: target.width == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: rectangle keeps (30, 18), line keeps length 30, point keeps neither, on both sides (read back through the attribute) |
| `degenerateDatumTargetAxisIsRefused` | `OCCTDocumentSetDatumTargetPlacement` substitutes a valid axis for a degenerate one | :235 Expectation failed: !doc.setDatumTargetPlacement(at: index, location: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 0), reference: SIMD3(1, 0, 0), length: 10, width: 0); :244 Expectation failed: doc.datum(at: index)?.target?.length == nil | passed | `OCCTDocumentSetDatumTargetPlacement` | PASS: a zero normal is refused on both sides (the kernel throws) and nothing is persisted |
| `accessorsAreNotSharedBetweenEntries` | `OCCTDocumentSetDatumTarget` writes to datum 0 | :282 Expectation failed: a.target == nil; :285 Expectation failed: b.target?.type == .circle | passed | `OCCTDocumentSetDatumTarget` | PASS: two tolerances and two datums keep their own values on both sides |
| `outOfRangeIndicesAreRefused` | `OCCTDocumentSetGeomToleranceTypeOfValue` returns true without checking the index | :299 Expectation failed: !doc.setGeomToleranceValueType(at: 5, .diameter) | passed | `OCCTDocumentSetGeomToleranceTypeOfValue` | PASS: tolerance index 5 and datum index 0 find nothing and cannot be written, on both sides |
### `Issue1037GDTEnumRangeTests.swift`
| `dimensionModifierOutOfRangeIsRefused` | `OCCTDocumentSetDimensionModifiers` skips its enum range check | :68 Expectation failed: !rejected; :68 Expectation failed: !rejected | passed | `OCCTDocumentSetDimensionModifiers` | EXPECTED_DIVERGENCE: by-design guard: the bridge refuses 24, 9999, -1 and keeps [2, 19]; the raw kernel stores them |
| `classOfToleranceOutOfRangeIsRefused` | `OCCTDocumentSetDimensionClassOfTolerance` skips its enum range check | :93 Expectation failed: !OCCTDocumentSetDimensionClassOfTolerance(doc.handle, Int32(index), true, 29, 7); :94 Expectation failed: !OCCTDocumentSetDimensionClassOfTolerance(doc.handle, Int32(index), true, 9999, 7) | passed | `OCCTDocumentSetDimensionClassOfTolerance` | EXPECTED_DIVERGENCE: by-design guard: the bridge refuses five bad pairs and reports no class; the raw kernel reports a class it cannot name |
| `geomToleranceModifierOutOfRangeIsRefused` | `OCCTDocumentSetGeomToleranceModifiers` skips its enum range check | :128 Expectation failed: !rejected; :128 Expectation failed: !rejected | passed | `OCCTDocumentSetGeomToleranceModifiers` | EXPECTED_DIVERGENCE: by-design guard: the bridge refuses 17, 9999, -1 and keeps 2 modifiers; the raw kernel replaces them with 1 |
| `datumModifierOutOfRangeIsRefused` | `OCCTDocumentSetDatumModifiers` skips its enum range check | :152 Expectation failed: !rejected; :152 Expectation failed: !rejected | passed | `OCCTDocumentSetDatumModifiers` | EXPECTED_DIVERGENCE: by-design guard: the bridge refuses 22, 9999, -1 and keeps [2, 3]; the raw kernel stores them |
| `emptyModifierArrayStillClears` | `OCCTDocumentSetDatumModifiers` refuses a count of 0 | :169 Expectation failed: OCCTDocumentSetDatumModifiers(doc.handle, Int32(index), nil, 0); :170 Expectation failed: doc.datum(at: index)?.modifiers.isEmpty == true | passed | `OCCTDocumentSetDatumModifiers` | PASS: an empty sequence is accepted and clears 2 modifiers to 0 on both sides |
### `Issue1038DatumTargetPlacementTests.swift`
| `placementOnANonTargetIsRefused` | `OCCTDocumentSetDatumTargetPlacement` skips its is-a-target refusal | :40 Expectation failed: !placement(doc, index, length: 30, width: 18) | passed | `OCCTDocumentSetDatumTargetPlacement` | EXPECTED_DIVERGENCE: by-design guard: the bridge refuses a placement on a non-target; the raw kernel accepts it and persists nothing |
| `placementOnAnAreaTargetIsRefused` | `OCCTDocumentSetDatumTargetPlacement` skips its Area refusal | :53 Expectation failed: !placement(doc, index, length: 30, width: 18) | passed | `OCCTDocumentSetDatumTargetPlacement` | EXPECTED_DIVERGENCE: by-design guard: the bridge refuses a placement on an Area target; the raw kernel accepts it and persists nothing |
| `placementOnARectangleTargetStillWorks` | `OCCTDocumentSetDatumTargetPlacement` stores the width as the length | :73 Expectation failed: target?.length == 30 | passed | `OCCTDocumentSetDatumTargetPlacement` | PASS: 30 x 18 |
| `placementAfterClearingTheTargetIsRefused` | `OCCTDocumentSetDatumTargetPlacement` skips its is-a-target refusal | :87 Expectation failed: !placement(doc, index, length: 44, width: 22) | passed | `OCCTDocumentSetDatumTargetPlacement` | EXPECTED_DIVERGENCE: by-design guard: after clearing the mark the bridge refuses a placement; the raw kernel accepts and persists nothing |
### `Issue1055DatumNameLengthTests.swift`
| `longNameRoundTrips` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :38 Expectation failed: datum.name.count == 100; :39 Expectation failed: datum.name == name | passed | `OCCTDocumentGetDatumName` | PASS: 100 chars both sides |
| `namesAroundTheOldBoundRoundTrip` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :56 Expectation failed: datum.name == name; :56 Expectation failed: datum.name == name | passed | `OCCTDocumentGetDatumName` | PASS: 63, 64, 65 kept |
| `shortBufferReportsTheFullLength` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :77 Expectation failed: reported == 100 | passed | `OCCTDocumentGetDatumName` | PASS: name length 100 on both sides (the prefix and terminator are buffer semantics of the bridge) |
| `nullBufferReportsTheLength` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :95 Expectation failed: OCCTDocumentGetDatumName(doc.handle, Int32(index), nil, 0) == 100 | passed | `OCCTDocumentGetDatumName` | PASS: name length 100 and no datum one past the end, on both sides |
| `malformedBufferArgumentsAreRefused` | `OCCTDocumentGetDatumName` accepts a negative length | :112 Expectation failed: OCCTDocumentGetDatumName(doc.handle, Int32(index), &buffer, -1) == -1 | passed | `OCCTDocumentGetDatumName` | N/A: argument validation is the bridge's own; no kernel call |
| `datumsEnumerationCarriesWholeNames` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :125 Expectation failed: doc.datums.map(\.name) == names | passed | `OCCTDocumentGetDatumName` | PASS: 1, 100, 200 |
### `Issue1078LayerNameLengthTests.swift`
| `longNameRoundTrips` | `OCCTDocumentGetLayerName` writes an empty name | :37 Expectation failed: !name.isEmpty; :37 Expectation failed: !name.isEmpty | passed | `OCCTDocumentGetLayerName` | MISMATCH: bridge and kernel agree on what the bridge reads, but it reads the wrong table: #2413 |
| `nullBufferReportsTheLength` | `OCCTDocumentGetLayerName` clamps any index to 0 | :56 Expectation failed: OCCTDocumentGetLayerName(handle, count, nil, 0) == -1; :57 Expectation failed: OCCTDocumentGetLayerName(handle, -1, nil, 0) == -1 | passed | `OCCTDocumentGetLayerName` | PASS: every name length readable, index 3 and -1 find nothing, on both sides (the 3 layers are the #2413 tool labels) |
| `shortBufferReportsTheFullLength` | `OCCTDocumentGetLayerName` reports the copied length, not the full one | :76 Expectation failed: reported == len | passed | `OCCTDocumentGetLayerName` | PASS: only one layer name is longer than 10 characters, length 12, on both sides |
| `malformedBufferArgumentsAreRefused` | `OCCTDocumentGetLayerName` answers 5 for a negative length | :95 Expectation failed: OCCTDocumentGetLayerName(handle, 0, &buffer, -1) == -1 | passed | `OCCTDocumentGetLayerName` | N/A: bridge-only validation |
### `DocumentModifiedTests.swift`
| `setAndCheckModified` | `OCCTDocumentSetModified` returns without marking | :22 Expectation failed: doc.isModified(label) | passed | `OCCTDocumentIsLabelModified` | PASS: modified is true after SetModified on both sides |
| `clearModified` | `OCCTDocumentClearModified` returns without purging | :39 Expectation failed: !doc.isModified(label) | passed | `OCCTDocumentClearModified` | PASS: modified true, then false after the clear, on both sides |
### `DocumentTests.swift`
| `createEmptyDocument` | `OCCTDocumentGetRootCount` returns 1 and `OCCTDocumentGetRootLabelId` returns 0 | :14 Expectation failed: doc.rootNodes.isEmpty | passed | `OCCTDocumentGetRootCount` | PASS: 0 roots on both sides |
| `lengthUnitReadsBackFromSTEP` | `OCCTDocumentGetLengthUnit` returns false | :39 Expectation failed: doc.lengthUnit | passed | `OCCTDocumentGetLengthUnit` | PASS: a STEP round trip carries a positive-scale named unit on both sides (kernel 0.001 mm) |
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
| `theCrashingShapeIsAuthorable` | `OCCTDocumentGetRealArrayValue` returns false | :91 Expectation failed: point?.realArrayValue(at: 1) == 7; :92 Expectation failed: point?.realArrayValue(at: 3) == 7 | passed | `OCCTDocumentGetRealArrayValue` | PASS: datum 0 has children 17 and 14 and no arrays; a point triple of 7 reads 1..3, no plane array, on both sides |
| `pointWithoutPlaneLocationIsRead` | the retired #1030 datum guard, reinstated in the shared GD&T lookup | :106 Expectation failed: doc.datum(at: index)?.name == "Datum1030"; :107 Expectation failed: doc.datums.count == 1 | passed | `OCCTDocumentGetDatumInfo` | PASS: the point-without-plane datum reads on both sides: name Datum1030, 1 readable of 1 label |
| `aWritePathSucceedsToo` | the retired #1030 datum guard, reinstated in the shared GD&T lookup | :124 Expectation failed: doc.setDatumPosition(at: index, 2); :125 Expectation failed: doc.setDatumModifiers(at: index, [.basic]) | passed | `OCCTDocumentSetDatumPosition` | PASS: all five write paths succeed on the point-without-plane datum and the position 2 reads back, on both sides |
| `planeLocationTooShortForThePointIndexIsRead` | the retired #1030 datum guard, reinstated in the shared GD&T lookup | :174 Expectation failed: doc.datum(at: index)?.name == "Datum1030" | passed | `OCCTDocumentGetDatumInfo` | PASS: the datum with a point at index 1000000 reads on both sides |
| `pointWithPlaneLocationStillReads` | a datum guard that refuses any datum carrying a point array | :187 Expectation failed: datum != nil; :188 Expectation failed: datum?.name == "Datum1030" | passed | `OCCTDocumentGetDatumInfo` | PASS: the datum with a point and a plane location reads on both sides |
| `pointArrayOfTheWrongLengthStillReads` | the #1030 guard without its length-3 check | :214 Expectation failed: doc.datum(at: index)?.name == "Datum1030" | passed | `OCCTDocumentGetDatumInfo` | PASS: the datum with a length-2 point array reads on both sides |
| `rescaleGeometryStillSucceeds` | `OCCTDocumentEditorRescaleGeometry` returns false | :231 Expectation failed: doc.rescaleGeometry(labelId: main.labelId, scaleFactor: 2.0, forceIfNotRoot: true) | passed | `OCCTDocumentEditorRescaleGeometry` | PASS: RescaleGeometry with one readable datum succeeds on both sides |
| `plainDatumStillReads` | a datum guard that refuses any datum whose point child label exists (a child-existence test) | :247 Expectation failed: datum?.name == "Datum1030"; :248 Expectation failed: doc.setDatumPosition(at: index, 2) | passed | `OCCTDocumentGetDatumInfo` | PASS: a plain datum reads and takes a position write on both sides |
### `DocumentUndoRedoTests.swift`
| `undoLimit` | `OCCTDocumentGetUndoLimit` returns 0 | :15 Expectation failed: doc.undoLimit == 10 | passed | `OCCTDocumentGetUndoLimit` | PASS: 10 = 10 |
| `availableUndos` | `OCCTDocumentGetAvailableUndos` returns 0 | :30 Expectation failed: doc.availableUndos == 1 | passed | `OCCTDocumentGetAvailableUndos` | PASS: 0/0, then 1 |
| `undoRestores` | `OCCTDocumentUndo` returns true without undoing | :58 Expectation failed: doc.availableUndos == 1; :59 Expectation failed: doc.availableRedos == 1 | passed | `OCCTDocumentUndo` | PASS: 2, then undo gives 1/1 |
| `redoAfterUndo` | `OCCTDocumentRedo` returns true without redoing | :82 Expectation failed: doc.availableUndos == 2; :83 Expectation failed: doc.availableRedos == 0 | passed | `OCCTDocumentRedo` | PASS: redo gives 2/0 |
| `undoNothing` | `OCCTDocumentUndo` returns true without undoing | :91 Expectation failed: !result | passed | `OCCTDocumentUndo` | PASS: false = false |
| `multipleUndoRedo` | `OCCTDocumentRedo` returns true without redoing | :115 Expectation failed: doc.availableUndos == 2; :116 Expectation failed: doc.availableRedos == 1 | passed | `OCCTDocumentRedo` | PASS: 3; 0/3; 2/1 |
| `abortNoUndo` | `OCCTDocumentAbortTransaction` commits instead | :132 Expectation failed: doc.availableUndos == 1 | passed | `OCCTDocumentAbortTransaction` | PASS: 1 = 1 |
### `DriverTableTests.swift`
| `tableExists` | `OCCTDriverTableExists` returns false | :13 Expectation failed: DriverTable.exists | passed | `OCCTDriverTableExists` | PASS: the driver table exists on both sides (Get() never returns null) |
| `initAndClear` | `OCCTDriverTableClear` calls `abort()` | process crash (the test has no expectation; a crash is the only failure it can report) | passed | `OCCTDriverTableClear` | PASS: initStandard and clear return on both sides (no value to compare) |
### `Issue970TransactionAPITests.swift`
| `namedTransactionNamesTheCommittedDelta` | the pending transaction name is dropped at commit | :23 Expectation failed: delta.name == "add part" | passed | `OCCTDocumentCommitWithDelta` | PASS: delta named "add part" with at least 1 attribute delta on both sides (kernel 2) |
| `aPendingNameDoesNotReachTheNextTransaction` | the pending name survives both the commit and the next unnamed open | :39 Expectation failed: delta.name == "" | passed | `OCCTDocumentCommitWithDelta` | PASS: a later unnamed transaction's delta has no name on both sides |
| `anUnnamedOpenSupersedesAPendingName` | `OCCTDocumentOpenTransaction` keeps a pending name | :53 Expectation failed: delta.name == "" | passed | `OCCTDocumentOpenTransaction` | PASS: the second open is refused and the delta is unnamed, on both sides |
| `aRefusedNamedOpenLeavesTheRunningNameAlone` | `OCCTDocumentOpenNamedTransaction` stores its name before the refused open | :66 Expectation failed: delta.name == "first" | passed | `OCCTDocumentOpenNamedTransaction` | PASS: first open 1, second refused, delta named "first" on both sides |
| `abortDiscardsThePendingName` | the pending name survives both the abort and the next unnamed open | :80 Expectation failed: delta.name == "" | passed | `OCCTDocumentAbortTransaction` | PASS: the delta after an aborted transaction is unnamed and there is 1 undo, on both sides |
| `commitWithDeltaReturnsADeltaAndKeepsTheUndoLimit` | `OCCTDocumentCommitWithDelta` returns null | :91 Expectation failed: delta != nil; :93 Expectation failed: doc.availableUndos == 1 | passed | `OCCTDocumentCommitWithDelta` | PASS: a delta is returned, the undo limit stays 10 and there is 1 undo, on both sides |
| `transactionNumberTracksTheOpenTransaction` | `OCCTDocumentGetTransactionNumber` returns 0 | :103 Expectation failed: doc.transactionNumber == 1 | passed | `OCCTDocumentGetTransactionNumber` | PASS: 0, 1, 0 |
| `repeatedOpensDoNotStack` | `OCCTDocumentGetTransactionNumber` returns 2 while a command is open | :117 Expectation failed: doc.transactionNumber == 1 | passed | `OCCTDocumentGetTransactionNumber` | PASS: two opens do not stack (1), and a commit closes it (0), on both sides |
| `withoutAnUndoLimitNothingOpens` | `OCCTDocumentOpenTransaction` raises a 0 undo limit to 1 | :127 Expectation failed: doc.transactionNumber == 0; :128 Expectation failed: !doc.hasOpenTransaction | passed | `OCCTDocumentOpenTransaction` | PASS: nothing opens at undo limit 0 on both sides |
| `openNamedTransactionReportsTheNumberItOpened` | `OCCTDocumentOpenNamedTransaction` opens but answers 0 | :137 Expectation failed: doc.openNamedTransaction("with undo limit") == 1 | passed | `OCCTDocumentOpenNamedTransaction` | PASS: 0 without a limit, 1 with one, 0 after abort, on both sides |
### `Issue1056GDTWriteAnswerTests.swift`
| `nonStorableToleranceRefusesTheCreate` | `occtDimensionApplyTolerance` (both copies reached) accepts without its readback check | :48 Expectation failed: index == nil; :48 Expectation failed: index == nil | passed | `OCCTDocumentCreateDimensionWithTolerance` | EXPECTED_DIVERGENCE: by-design guard: the bridge refuses NaN tolerances and creates nothing; the raw kernel creates the dimension holding NaN |
| `storableToleranceStillApplies` | `OCCTDocumentGetDimensionInfo` reads the upper tolerance as the lower | :70 Expectation failed: dim.bounds == .plusMinus(lowerTolerance: -0.3, upperTolerance: 0.7) | passed | `OCCTDocumentGetDimensionInfo` | PASS: 1 dimension, plus/minus (-0.3, 0.7), value 20, on both sides |
| `noToleranceStillCreatesASimpleDimension` | `OCCTDocumentGetDimensionInfo` reports a simple dimension as unset | :90 Expectation failed: doc.dimension(at: index)?.bounds == .simple | passed | `OCCTDocumentGetDimensionInfo` | PASS: 1 simple dimension on both sides |
| `standaloneSetterRefusesTheSamePair` | `occtDimensionApplyTolerance` (both copies reached) accepts without its readback check | :105 Expectation failed: doc.setDimensionTolerance(at: index, lower: .nan, upper: 0.5) == false; :106 Expectation failed: doc.dimension(at: index)?.bounds == .simple | passed | `OCCTDocumentSetDimensionTolerance` | EXPECTED_DIVERGENCE: by-design guard: the bridge refuses (NaN, 0.5) and keeps the dimension simple; the raw kernel makes it plus/minus with NaN |
| `noneModifierStoresNoValue` | `OCCTDocumentSetGeomToleranceZoneModifier` stores the value whatever the modifier | :129 Expectation failed: tol.zoneModifierValue == nil | passed | `OCCTDocumentSetGeomToleranceZoneModifier` | EXPECTED_DIVERGENCE: by-design guard: a value passed with .none is dropped by the bridge; the raw kernel persists 15 |
| `clearingAModifierClearsItsValue` | `OCCTDocumentSetGeomToleranceZoneModifier` stores the value whatever the modifier | :151 Expectation failed: tol.zoneModifierValue == nil | passed | `OCCTDocumentSetGeomToleranceZoneModifier` | EXPECTED_DIVERGENCE: by-design guard: the bridge clears a zone value with its modifier; the raw kernel keeps 7.5 and a stale 15 |
| `realModifierStillStoresItsValue` | `OCCTDocumentSetGeomToleranceZoneModifier` stores 0 whatever the value | :172 Expectation failed: tol.zoneModifierValue == 15.0 | passed | `OCCTDocumentSetGeomToleranceZoneModifier` | PASS: Projected 15 |
| `datumSiblingReportsNothingForAClearedModifier` | `OCCTDocumentGetDatumInfo` reports modifier 1 whatever is stored | :197 Expectation failed: doc.datum(at: index)?.modifierWithValue == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: a None modifier reports nothing on both sides (the kernel persists value 0 under None for a datum) |
### `Issue1435DatumDocumentToolTableTests.swift`
| `datumIsUnderDocumentToolLabel` | `OCCTDocumentCreateDatum` writes through `XCAFDoc_DimTolTool::Set(Main())` (the #1435 regression) | :62 Expectation failed: dgts.childCount == 1; :69 Expectation failed: doc.datumCount == 1 | passed | `OCCTDocumentCreateDatum` | PASS: the datum lands under 0:1:4 at index 0, 1 child, 1 datum, on both sides |
| `datumCountAgreesWithRealTable` | `OCCTDocumentCreateDatum` writes through `XCAFDoc_DimTolTool::Set(Main())` (the #1435 regression) | :89 Expectation failed: dgts.childCount == 3; :90 Expectation failed: doc.datumCount == 3 | passed | `OCCTDocumentGetDatumCount` | PASS: 3 children under 0:1:4 and 3 datums on both sides |
### `TDataXtdShapeAttributeTests.swift`
| `setGetShape` | `OCCTDocumentHasShapeAttr` returns false | :18 Expectation failed: label.hasShapeAttribute | passed | `OCCTDocumentHasShapeAttr` | PASS: the shape attribute is present and its shape is valid on both sides |
| `noShapeAttribute` | `OCCTDocumentHasShapeAttr` returns true | :28 Expectation failed: !label.hasShapeAttribute | passed | `OCCTDocumentHasShapeAttr` | PASS: no shape attribute and no shape on both sides |
### `TDataXtdTriangulationAttributeTests.swift`
| `setTriangulation` | `OCCTDocumentTriangulationNbNodes` answers 0 | :18 Expectation failed: label.triangulationNodeCount > 0 | passed | `OCCTDocumentTriangulationNbNodes` | PASS: a sphere at deflection 1.0 has nodes and triangles on both sides (kernel 168 and 306) |
| `triangulationDeflection` | `OCCTDocumentTriangulationDeflection` answers 0 | :29 Expectation failed: label.triangulationDeflection > 0 | passed | `OCCTDocumentTriangulationDeflection` | PASS: the box's stored deflection is positive on both sides (kernel 4.97e-16, round-off) |
### `TDFAttributeIteratorTests.swift`
| `attributeCount` | `OCCTDocumentAttributeCount` answers 0 | :19 Expectation failed: count >= 3 | passed | `OCCTDocumentAttributeCount` | PASS: at least 3 attributes on both sides (kernel 3) |
| `emptyLabel` | `OCCTDocumentAttributeCount` answers -1 | :26 Expectation failed: count >= 0 | passed | `OCCTDocumentAttributeCount` | PASS: the created label has 2 attributes (0:1:1 is the ShapeTool label), so the count is at least 0, on both sides |
| `dataSetIsEmpty` | `OCCTDocumentDataSetIsEmpty` returns true | :33 Expectation failed: !empty | passed | `OCCTDocumentDataSetIsEmpty` | PASS: a data set holding the created label is not empty on both sides |
### `TDFChildIDIteratorTests.swift`
| `countByGUID` | `OCCTDocumentChildIDCount` answers 0 | :28 Expectation failed: count == 2 | passed | `OCCTDocumentChildIDCount` | PASS: 2 integer children |
| `emptyResult` | `OCCTDocumentChildIDCount` answers 1 | :36 Expectation failed: count == 0 | passed | `OCCTDocumentChildIDCount` | PASS: 0 |
### `TDFComparisonToolTests.swift`
| `isSelfContained` | `OCCTDocumentIsSelfContained` returns false | :16 Expectation failed: result == true | passed | `OCCTDocumentIsSelfContained` | PASS: true |
### `TDFCopyLabelTests.swift`
| `copyLabelWithName` | `OCCTDocumentCopyLabel` returns true without copying | :20 Expectation failed: dest.name == "Original" | passed | `OCCTDocumentCopyLabel` | PASS: the copy completes and the destination is named Original, on both sides |
| `copyLabelWithChildren` | `OCCTDocumentCopyLabel` returns true without copying | :34 Expectation failed: dest.hasChild | passed | `OCCTDocumentCopyLabel` | PASS: the copy completes and the destination has a child, on both sides |
### `TDFLabelNameTests.swift`
| `setGetName` | `OCCTDocumentGetLabelName` returns null | :17 Expectation failed: label.name == "MyPart" | passed | `OCCTDocumentGetLabelName` | PASS: MyPart |
| `renameLabel` | `OCCTDocumentSetLabelName` ignores every call after the first | :28 Expectation failed: label.name == "Renamed" | passed | `OCCTDocumentSetLabelName` | PASS: Renamed |
### `TDFReferenceTests.swift`
| `setGetReference` | `OCCTDocumentLabelGetReference` answers -1 | :27 Issue recorded | passed | `OCCTDocumentLabelGetReference` | PASS: points to the target |
| `noReference` | `OCCTDocumentLabelGetReference` answers label 0 | :35 Expectation failed: label.referencedLabel == nil | passed | `OCCTDocumentLabelGetReference` | PASS: no TDF_Reference on the created label on both sides |
### `TDFTransactionNamedTests.swift`
| `openNamedTransaction` | `OCCTDocumentOpenNamedTransaction` opens but answers 0 | :15 Expectation failed: txnNum >= 1 | passed | `OCCTDocumentOpenNamedTransaction` | PASS: the open reports at least 1 on both sides (kernel 1) |
| `transactionNumber` | `OCCTDocumentGetTransactionNumber` returns 0 | :26 Expectation failed: during == 1 | passed | `OCCTDocumentGetTransactionNumber` | PASS: 0, 1, 0 across open and commit on both sides |
| `commitWithDelta` | `OCCTDocumentCommitWithDelta` returns null | :40 Expectation failed: delta != nil | passed | `OCCTDocumentCommitWithDelta` | PASS: a non-empty delta with 2 attribute deltas over times 0..1 on both sides |
| `deltaName` | `OCCTDeltaSetName` returns without naming | :60 Expectation failed: delta.name == "MyDelta" | passed | `OCCTDeltaSetName` | PASS: the delta name MyDelta sticks on both sides |
### `TDocStdXLinkToolTests.swift`
| `xlinkCopy` | `OCCTDocumentXLinkCopy` returns false | :13 `ok`; the value check is now unconditional (`if let` removed) | passed | `OCCTDocumentXLinkCopy` | PASS: the copy completes and the target integer is 77 on both sides |
| `xlinkCopyWithLink` | `OCCTDocumentXLinkCopyWithLink` returns true without copying | `tgt.integer == 88` (rewritten; the old test discarded both the answer and the effect) | passed | `OCCTDocumentXLinkCopyWithLink` | PASS: CopyWithLink completes and the target integer is 88 on both sides |
### `Issue443TriangulationAttributeTests.swift`
| `boxStoresEveryFace` | the merge keeps only the first face (the #443 defect) | :29 Expectation failed: label.triangulationNodeCount == 24; :30 Expectation failed: label.triangulationTriangleCount == 12 | passed | `OCCTDocumentTriangulationNbNodes` | PASS: 6 faces, 24 nodes, 12 triangles on both sides |
| `compoundStoresEveryBody` | the merge keeps only the first face (the #443 defect) | :47 Expectation failed: label.triangulationNodeCount == 48; :48 Expectation failed: label.triangulationTriangleCount == 24 | passed | `OCCTDocumentTriangulationNbNodes` | PASS: 12 faces, 48 nodes, 24 triangles on both sides |
| `deflectionControlsDensity` | the merged triangulation's deflection is written as 0 | :69 Expectation failed: coarseLabel.triangulationDeflection > 0; :70 Expectation failed: fineLabel.triangulationDeflection > 0 | passed | `OCCTDocumentTriangulationDeflection` | PASS: fine deflection gives more triangles (516 vs 306) and a smaller stored deflection (0.238 vs 0.627) on both sides |
| `planarDeflection` | the merged triangulation's deflection is written as -1 | :86 Expectation failed: label.triangulationDeflection >= 0 | passed | `OCCTDocumentTriangulationDeflection` | PASS: a planar shape's deflection is >= 0 on both sides (kernel 3.1e-16) |
| `locatedShapeStoresShapeFrame` | nodes are stored without the face location | :117 Expectation failed: node.x >= bounds.min.x - slack && node.x <= bounds.max.x + slack; :120 Expectation failed: node.y >= bounds.min.y - slack && node.y <= bounds.max.y + slack | passed | `OCCTDocumentTriangulationNode` | PASS: 24 nodes, all inside the located box's bounds on all axes, on both sides |
| `mirroredShapeStoresEveryFace` | the merge keeps only the first face (the #443 defect) | :142 Expectation failed: label.triangulationNodeCount == 24; :143 Expectation failed: label.triangulationTriangleCount == 12 | passed | `OCCTDocumentTriangulationNbNodes` | PASS: 24 nodes, 12 triangles, all at negative x inside the mirrored bounds, on both sides |
| `triangulationNodeBounds` | `OCCTDocumentTriangulationNode` answers (0, 0, 0) for any index | :175 Expectation failed: empty.triangulationNode(at: 1) == nil; :178 Expectation failed: label.triangulationNode(at: 0) == nil | passed | `OCCTDocumentTriangulationNode` | PASS: nodes exist at 1..24 only, and an attribute-less label yields none, on both sides |
| `importedNormalsSurviveTheMerge` | the merge drops every face's normals | :216 Issue recorded | passed | `OCCTDocumentTriangulationNormal` | PASS: the glTF import carries unit outward normals and the B-Rep mesh carries none, on both sides |
| `noFaceStoresNothing` | `OCCTDocumentSetTriangulationFromShape` reports success for a shape with no face | :254 Expectation failed: label.setTriangulationFromShape(edge, deflection: 1.0) == false | passed | `OCCTDocumentSetTriangulationFromShape` | PASS: a shape with no face stores nothing (0 nodes, 0 triangles) on both sides |
### `XCAFPrsStyleTests.swift`
| `emptyStyle` | `OCCTXCAFPrsStyleCreate` reports a non-empty style | :10 Expectation failed: style.isEmpty | passed | `OCCTXCAFPrsStyleCreate` | PASS: empty |
| `surfaceColor` | `OCCTXCAFPrsStyleCreateWithSurfColor` returns an empty style | :15 Expectation failed: !style.isEmpty | passed | `OCCTXCAFPrsStyleCreateWithSurfColor` | PASS: not empty |
| `visibility` | `OCCTXCAFPrsStyleIsEqual` returns true | :27 `!style.isEqual(to: visible)` (rewritten; reading back a stored property could not fail) | passed | `OCCTXCAFPrsStyleIsEqual` | PASS: a visible copy of an invisible style compares unequal on both sides |
| `equality` | `OCCTXCAFPrsStyleIsEqual` returns false | :36 Expectation failed: s1.isEqual(to: s2) | passed | `OCCTXCAFPrsStyleIsEqual` | PASS: equal |
| `curveColorOnly` | `OCCTXCAFPrsStyleCreateWithCurvColor` returns an empty style | :48 Expectation failed: !style.isEmpty; :56 Expectation failed: !style.isEqual(to: differentCurve) | passed | `OCCTXCAFPrsStyleCreateWithCurvColor` | PASS: not empty; same equal; different unequal |
### `VisMaterialCommonTests.swift`
| `defaultValues` | `OCCTVisMaterialCommonDefault` returns a zeroed material | :10 Expectation failed: mat.isDefined; :11 Expectation failed: abs(mat.diffuseColor.red - 0.8) < 0.02 | passed | `OCCTVisMaterialCommonDefault` | PASS: 0.8 |
| `setProperties` | `OCCTVisMaterialCommonIsEqual` returns true | `!mat.isEqual(to: other)` (rewritten; reading back stored properties could not fail) | passed | `OCCTVisMaterialCommonIsEqual` | PASS: materials that differ in shininess compare unequal on both sides |
| `equality` | `OCCTVisMaterialCommonIsEqual` returns false | :37 Expectation failed: m1.isEqual(to: m2) | passed | `OCCTVisMaterialCommonIsEqual` | PASS: equal |
| `commonMaterialRoughnessFromShininess` | `OCCTMaterialRoughnessFromSpecular` answers 0.1 | :105 Expectation failed: abs(material.roughness - 0.7) < 0.01 | passed | `OCCTDocumentGetLabelMaterial` | PASS: roughness within 0.01 of 0.7 on both sides (kernel RoughnessFromSpecular 0.699999988 for Shininess 0.3) |
### `VisMaterialPBRTests.swift`
| `defaultValues` | `OCCTVisMaterialPBRDefault` returns a zeroed material | :10 Expectation failed: pbr.isDefined; :11 Expectation failed: abs(pbr.metallic - 1.0) < 1e-6 | passed | `OCCTVisMaterialPBRDefault` | PASS: 1, 1, 1.5 |
| `setProperties` | `OCCTVisMaterialPBRIsEqual` returns true | `!pbr.isEqual(to: other)` (rewritten; reading back stored properties could not fail) | passed | `OCCTVisMaterialPBRIsEqual` | PASS: materials that differ in roughness compare unequal on both sides |
| `equality` | `OCCTVisMaterialPBRIsEqual` returns false | :39 Expectation failed: p1.isEqual(to: p2) | passed | `OCCTVisMaterialPBRIsEqual` | PASS: equal materials compare equal on both sides |
### `XCAFComponentMatrixTests.swift`
| `matrixComponentPlacement` | `OCCTDocumentAddComponentMatrix` returns -1 without adding | :20 Expectation failed: doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: rigid) >= 0; :24 Expectation failed: doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: reflect) >= 0 | passed | `OCCTDocumentAddComponentMatrix` | PASS: rigid and reflection components are both added and the count is 2 on both sides |
### `XCAFDocAssemblyGraphTests.swift`
| `createFromDocument` | `OCCTAssemblyGraphNbNodes` answers -1 | :15 Expectation failed: graph.nodeCount >= 0 | passed | `OCCTAssemblyGraphNbNodes` | PASS: the graph's counts are non-negative on both sides (kernel 0, 0, 0 for a document with no shape) |
| `nodeTypeMatchesRealOCCTCategories` | `OCCTAssemblyGraphGetNodeType` answers 0 | :64 Expectation failed: graph.nodeType(at: 1) == .assemblyRoot; :65 Expectation failed: graph.nodeType(at: 2) == .occurrence | passed | `OCCTAssemblyGraphGetNodeType` | PASS: 1 3 2 3 4 |
### `XCAFDocAssemblyItemIdTests.swift`
| `createFromString` | `OCCTAssemblyItemIdPathCount` answers 1 | :11 Expectation failed: id.pathCount == 2 | passed | `OCCTAssemblyItemIdPathCount` | PASS: the item id is valid with a path of 2 on both sides |
| `emptyIsNull` | `OCCTAssemblyItemIdIsValid` returns true | :16 Expectation failed: !id.isValid | passed | `OCCTAssemblyItemIdIsValid` | PASS: the empty item id is not valid on both sides |
| `equality` | `OCCTAssemblyItemIdIsEqual` returns false | :22 Expectation failed: id1.isEqual(to: id2) | passed | `OCCTAssemblyItemIdIsEqual` | PASS: equal |
| `inequality` | `OCCTAssemblyItemIdIsEqual` returns true | :28 Expectation failed: !id1.isEqual(to: id2) | passed | `OCCTAssemblyItemIdIsEqual` | PASS: unequal |
### `XCAFDocAssemblyItemRefTests.swift`
| `setAndGet` | `OCCTDocumentGetAssemblyItemRef` returns null | :18 Expectation failed: path != nil | passed | `OCCTDocumentGetAssemblyItemRef` | PASS: path kept |
| `subshapeIndex` | `OCCTDocumentAssemblyItemRefHasExtra` returns false | :28 Expectation failed: doc.assemblyItemRefHasExtra(labelId: node.labelId) | passed | `OCCTDocumentAssemblyItemRefHasExtra` | PASS: 3 |
| `clearExtra` | `OCCTDocumentAssemblyItemRefClearExtra` returns true without clearing | :42 Expectation failed: !doc.assemblyItemRefHasExtra(labelId: node.labelId) | passed | `OCCTDocumentAssemblyItemRefClearExtra` | PASS: cleared |
| `isOrphan` | `OCCTDocumentAssemblyItemRefIsOrphan` returns false | :51 Expectation failed: doc.assemblyItemRefIsOrphan(labelId: node.labelId) | passed | `OCCTDocumentAssemblyItemRefIsOrphan` | PASS: a ref to a path that names no label is orphan on both sides |
### `XCAFNoteObjectsTests.swift`
| `create` | `OCCTNoteObjectCreate` returns null | :10 Expectation failed: obj != nil | passed | `OCCTNoteObjectCreate` | PASS: the note object is created on both sides (trivial) |
| `initiallyEmpty` | `OCCTNoteObjectHasPlane` returns true | :15 Expectation failed: !obj.hasPlane | passed | `OCCTNoteObjectHasPlane` | PASS: all false |
| `setPlane` | `OCCTNoteObjectGetPlane` answers the origin | :28 Expectation failed: abs(origin.x - 1.0) < 1e-6 | passed | `OCCTNoteObjectGetPlane` | PASS: the plane is set with origin x = 1 on both sides |
| `setPoint` | `OCCTNoteObjectHasPoint` returns false | :35 Expectation failed: obj.hasPoint | passed | `OCCTNoteObjectHasPoint` | PASS: the point is set with x = 10 on both sides |
| `setPresentation` | `OCCTNoteObjectGetPresentation` returns null | :45 Expectation failed: obj.presentation != nil | passed | `OCCTNoteObjectGetPresentation` | PASS: kept |
| `reset` | `OCCTNoteObjectReset` returns without resetting | :57 Expectation failed: !obj.hasPlane; :58 Expectation failed: !obj.hasPoint | passed | `OCCTNoteObjectReset` | PASS: cleared |
### `XCAFViewObjectTests.swift`
| `create` | `OCCTViewObjectCreate` returns null | :11 Expectation failed: view != nil | passed | `OCCTViewObjectCreate` | PASS: the view object is created on both sides (trivial) |
| `projectionType` | `OCCTViewObjectGetType` answers 99 | :17 Expectation failed: view.type == .central; :19 Expectation failed: view.type == .parallel | passed | `OCCTViewObjectGetType` | PASS: projection types read back 2, 1, 0 on both sides |
| `realOCCTProjectionTypeValuesDecodeCorrectly` | `OCCTViewObjectGetType` answers 99 | :53 Expectation failed: readBack == raw; :55 Expectation failed: decoded == expected | passed | `OCCTViewObjectGetType` | PASS: raw projection values 0, 1, 2 round-trip on both sides |
| `viewDirection` | `OCCTViewObjectGetViewDirection` answers (0, 0, 0) | :63 Expectation failed: abs(dir.x - 1.0) < 1e-6 | passed | `OCCTViewObjectGetViewDirection` | PASS: (1, 0, 0) |
| `upDirection` | `OCCTViewObjectGetUpDirection` answers (0, 0, 0) | :71 Expectation failed: abs(up.z - 1.0) < 1e-6 | passed | `OCCTViewObjectGetUpDirection` | PASS: (0, 0, 1) |
| `windowSize` | `OCCTViewObjectGetWindowHSize` answers 0 | :79 Expectation failed: abs(view.windowHorizontalSize - 800) < 1e-6 | passed | `OCCTViewObjectGetWindowHSize` | PASS: 800 x 600 |
| `clippingPlanes` | `OCCTViewObjectHasFrontPlaneClipping` returns false | :88 Expectation failed: view.hasFrontPlaneClipping | passed | `OCCTViewObjectHasFrontPlaneClipping` | PASS: 1, 1000, then unset |
| `name` | `OCCTViewObjectGetName` returns null | :100 Expectation failed: view.name == "TopView" | passed | `OCCTViewObjectGetName` | PASS: TopView |
### `XDEShapeToolQueryTests.swift`
| `addShapeAndCount` | `OCCTDocumentGetShapeCount` answers 0 | :21 Expectation failed: doc.shapeCount > 0 | passed | `OCCTDocumentGetShapeCount` | PASS: the shape count is positive on both sides (kernel 1) |
| `freeShapeCount` | `OCCTDocumentGetFreeShapeCount` answers 0 | :34 Expectation failed: doc.freeShapeCount > 0 | passed | `OCCTDocumentGetFreeShapeCount` | PASS: the free shape count is positive on both sides (kernel 1) |
| `findAndSearch` | `OCCTDocumentFindShape` answers -1 | :49 Expectation failed: foundId >= 0 | passed | `OCCTDocumentFindShape` | PASS: FindShape and SearchShape both find the box on both sides |
| `newAndRemove` | `OCCTDocumentRemoveShape` returns false | :66 Expectation failed: removed | passed | `OCCTDocumentRemoveShape` | PASS: true |
| `labelQueries` | `OCCTDocumentIsTopLevel` returns false | :82 Expectation failed: root.isTopLevel | passed | `OCCTDocumentIsTopLevel` | PASS: top-level, not a component |
### `XLinkTests.swift`
| `setXLink` | `OCCTDocumentXLinkSet` returns false | :11 Expectation failed: ok | passed | `OCCTDocumentXLinkSet` | PASS: an XLink is set on the tag-1 label on both sides |
| `documentEntry` | `OCCTDocumentXLinkGetDocumentEntry` returns null | :20 Expectation failed: entry == "/doc/path" | passed | `OCCTDocumentXLinkGetDocumentEntry` | PASS: /doc/path |
| `labelEntry` | `OCCTDocumentXLinkGetLabelEntry` returns null | :29 Expectation failed: entry == "0:1:2" | passed | `OCCTDocumentXLinkGetLabelEntry` | PASS: 0:1:2 |
### `TDataXtdConstraintTests.swift`
| `setAndGetType` | `OCCTDocumentConstraintGetType` answers 3 | :18 Expectation failed: type == .parallel | passed | `OCCTDocumentConstraintGetType` | PASS: PARALLEL (5) |
| `isPlanarAndDimension` | `OCCTDocumentConstraintIsPlanar` returns true | :29 Expectation failed: !doc.constraintIsPlanar(labelId: node.labelId) | passed | `OCCTDocumentConstraintIsPlanar` | PASS: false, false |
| `verifiedFlag` | `OCCTDocumentConstraintGetVerified` returns false | :40 Expectation failed: doc.constraintGetVerified(labelId: node.labelId) | passed | `OCCTDocumentConstraintGetVerified` | PASS: true |
| `noConstraint` | `OCCTDocumentConstraintGetType` answers 0 where there is none | :46 Expectation failed: doc.constraintGetType(labelId: node.labelId) == nil | passed | `OCCTDocumentConstraintGetType` | PASS: no constraint on the created label on both sides |
### `TDataXtdGeometricAttrTests.swift`
| `setPoint` | `OCCTDocumentSetPointAttr` returns false | :15 Expectation failed: label.setPointAttribute(x: 5.0, y: 10.0, z: 15.0) | passed | `OCCTDocumentSetPointAttr` | PASS: the point attribute is set on both sides |
| `setAxis` | `OCCTDocumentSetAxisAttr` returns false | :22 Expectation failed: label.setAxisAttribute(originX: 0, originY: 0, originZ: 0, directionX: 0, directionY: 0, directionZ: 1) | passed | `OCCTDocumentSetAxisAttr` | PASS: the axis attribute is set on both sides |
| `setPlane` | `OCCTDocumentSetPlaneAttr` returns false | :32 Expectation failed: label.setPlaneAttribute(originX: 0, originY: 0, originZ: 0, normalX: 0, normalY: 0, normalZ: 1) | passed | `OCCTDocumentSetPlaneAttr` | PASS: the plane attribute is set on both sides |
### `TDataXtdGeometryAttributeTests.swift`
| `setGetGeometryType` | `OCCTDocumentGetGeometryType` answers 0 | :18 Expectation failed: label.geometryType() == .point; :21 Expectation failed: label.geometryType() == .plane | passed | `OCCTDocumentGetGeometryType` | PASS: the geometry attribute reads back point (1), plane (6) and cylinder (7) on both sides |
| `allGeometryTypes` | `OCCTDocumentGetGeometryType` answers 0 | :36 Expectation failed: label.geometryType() == type; :36 Expectation failed: label.geometryType() == type | passed | `OCCTDocumentGetGeometryType` | PASS: all eight geometry types round-trip on both sides |
### `TextLabelAndPointCloudTests.swift`
| `createTextLabel` | `OCCTTextLabelGetInfo` returns false | :15 Expectation failed: label!.text == "Hello" | passed | `OCCTTextLabelGetInfo` | PASS: text "Hello" on both sides (AIS_TextLabel is the kernel object) |
| `textLabelPosition` | `OCCTTextLabelGetInfo` returns false | :22 Expectation failed: abs(pos.x - 10) < 1e-6; :23 Expectation failed: abs(pos.y - 20) < 1e-6 | passed | `OCCTTextLabelGetInfo` | PASS: position (10, 20, 30) on both sides (kernel exact) |
| `updateText` | `OCCTTextLabelSetText` returns without setting | :31 Expectation failed: label.text == "Updated" | passed | `OCCTTextLabelSetText` | PASS: updated text "Updated" on both sides |
| `updatePosition` | `OCCTTextLabelSetPosition` returns without setting | :39 Expectation failed: abs(pos.x - 5) < 1e-6; :40 Expectation failed: abs(pos.y - 10) < 1e-6 | passed | `OCCTTextLabelSetPosition` | PASS: position x, y = (5, 10) on both sides after the update (kernel z 15, not asserted) |
| `textLabelDefaultHeightMatchesOCCT` | `OCCTTextLabelGetInfo` returns false | :49 Expectation failed: OCCTTextLabelGetInfo(label.handle, &info); :50 Expectation failed: abs(info.height - 16.0) < 1e-6 | passed | `OCCTTextLabelGetInfo` | PASS: the default text height is 16 on both sides |
| `textLabelHeightRoundTrips` | `OCCTTextLabelSetHeight` returns without setting | :59 Expectation failed: abs(info.height - 30.0) < 1e-6 | passed | `OCCTTextLabelSetHeight` | PASS: the height 30 reads back on both sides |
| `createPointCloud` | `OCCTPointCloudGetCount` answers 0 | :67 Expectation failed: cloud!.count == 3 | passed | `OCCTPointCloudGetCount` | PASS: 3 |
| `pointCloudBounds` | `OCCTPointCloudGetBounds` returns false | :75 Expectation failed: bounds != nil | passed | `OCCTPointCloudGetBounds` | PASS: x -1..4, y 0..5 |
| `pointCloudRetrieval` | `OCCTPointCloudGetPoints` answers 0 | :89 Expectation failed: retrieved.count == 2 | passed | `OCCTPointCloudGetPoints` | N/A: the points are the bridge's own copy (no OCCT class) |
| `coloredPointCloud` | `OCCTPointCloudGetColors` answers 0 | :102 Expectation failed: retrievedColors.count == 2 | passed | `OCCTPointCloudGetColors` | N/A: the colours are the bridge's own copy (no OCCT class) |
| `emptyPointCloud` | `OCCTPointCloudCreate` builds a one-point cloud from zero points | :110 Expectation failed: cloud == nil | passed | `OCCTPointCloudCreate` | N/A: refused before any OCCT call |
### `TFunctionDriverTableTests.swift`
| `hasDriverUnknown` | `OCCTFunctionDriverTableHasDriver` returns true | :11 Expectation failed: !has | passed | `OCCTFunctionDriverTableHasDriver` | PASS: false |
| `clear` | `OCCTFunctionDriverTableClear` calls `abort()` | process crash (the test has no expectation) | passed | `OCCTFunctionDriverTableClear` | N/A: no expectation; the test is a no-crash check and Clear() returns void |
### `TFunctionFunctionAttrTests.swift`
| `createFunction` | `OCCTDocumentFunctionIsFailed` returns true | :18 Expectation failed: !label.functionIsFailed | passed | `OCCTDocumentFunctionIsFailed` | PASS: false |
| `functionFailure` | `OCCTDocumentFunctionGetFailure` answers 0 | :30 Expectation failed: failure == 1 | passed | `OCCTDocumentFunctionGetFailure` | PASS: 1 |
### `TFunctionGraphNodeTests.swift`
| `graphNodeStatus` | `OCCTDocumentGraphNodeGetStatus` answers 99 | :18 Expectation failed: label.graphNodeStatus() == .notExecuted; :21 Expectation failed: label.graphNodeStatus() == .succeeded | passed | `OCCTDocumentGraphNodeGetStatus` | PASS: statuses NotExecuted (1) and Succeeded (3) read back on both sides |
| `graphNodeDeps` | `OCCTDocumentGraphNodeAddNext` returns false | :34 Expectation failed: node1.graphNodeAddNext(tag: node2.tag) | passed | `OCCTDocumentGraphNodeAddNext` | PASS: true, true |
| `allStatuses` | `OCCTDocumentGraphNodeGetStatus` answers 99 | :52 Expectation failed: label.graphNodeStatus() == status; :52 Expectation failed: label.graphNodeStatus() == status | passed | `OCCTDocumentGraphNodeGetStatus` | PASS: all five execution statuses round-trip on both sides |
### `TFunctionIFunctionTests.swift`
| `newFunction` | `OCCTDocumentNewFunction` returns false | :16 Expectation failed: ok | passed | `OCCTDocumentNewFunction` | PASS: the function attribute exists after NewFunction on both sides (NewFunction's own return is false, unused) |
| `deleteFunction` | `OCCTDocumentDeleteFunction` returns false | :26 Expectation failed: deleted | passed | `OCCTDocumentDeleteFunction` | PASS: DeleteFunction succeeds on both sides |
| `functionExecStatus` | `OCCTDocumentFunctionSetExecStatus` returns true without setting | :41 Expectation failed: status == .succeeded | passed | `OCCTDocumentFunctionSetExecStatus` | PASS: status WrongDefinition then Succeeded on both sides |
| `noFunction` | `OCCTDocumentFunctionGetExecStatus` answers 0 | :50 Expectation failed: status == nil | passed | `OCCTDocumentFunctionGetExecStatus` | PASS: no function attribute on a fresh label, so no status is readable on both sides |
### `TObjApplicationTests.swift`
| `getInstance` | `OCCTTObjApplicationGetInstance` returns null | :10 Expectation failed: app != nil | passed | `OCCTTObjApplicationGetInstance` | PASS: the TObj application instance exists on both sides |
| `verboseFlag` | `OCCTTObjApplicationIsVerbose` returns false | :21 Expectation failed: app.isVerbose | passed | `OCCTTObjApplicationIsVerbose` | PASS: the verbose flag reads true then false on both sides |
| `createDocument` | `OCCTTObjApplicationCreateDocument` returns null | :32 Expectation failed: doc != nil | passed | `OCCTTObjApplicationCreateDocument` | PASS: the TObj application creates a document on both sides |
### `UAttributeTests.swift`
| `setAndHas` | `OCCTUAttributeHas` returns false | :13 Expectation failed: doc.hasUAttribute(tag: 300, guid: guid) | passed | `OCCTUAttributeHas` | PASS: true |
| `differentGUID` | `OCCTUAttributeHas` returns true | :22 Expectation failed: !doc.hasUAttribute(tag: 301, guid: guid2) | passed | `OCCTUAttributeHas` | PASS: g1 yes, g2 no |
| `getID` | `OCCTUAttributeGetID` returns null | :30 Expectation failed: retrieved != nil | passed | `OCCTUAttributeGetID` | N/A: the GUID string is the one passed in; not probed in this pass, so no kernel value is claimed |
### `VariableTests.swift`
| `setVariable` | `OCCTDocumentVariableSet` returns false | :11 Expectation failed: ok | passed | `OCCTDocumentVariableSet` | PASS: a variable is set on the tag-1 label on both sides |
| `setAndGetName` | `OCCTDocumentVariableGetName` returns null | :20 Expectation failed: name == "velocity" | passed | `OCCTDocumentVariableGetName` | PASS: velocity |
| `setAndGetValue` | `OCCTDocumentVariableGetValue` answers 0 | :30 Expectation failed: abs(val - 42.5) < 1e-10 | passed | `OCCTDocumentVariableGetValue` | PASS: 42.5 |
| `unitString` | `OCCTDocumentVariableGetUnit` returns null | :39 Expectation failed: unit == "m/s" | passed | `OCCTDocumentVariableGetUnit` | PASS: m/s |
| `constantFlag` | `OCCTDocumentVariableIsConstant` returns true | :49 Expectation failed: !doc.variableIsConstant(at: 1) | passed | `OCCTDocumentVariableIsConstant` | PASS: true, false |
| `assignAndDesassignExpression` | `OCCTDocumentVariableIsAssigned` returns false | :58 Expectation failed: doc.variableIsAssigned(at: 1) | passed | `OCCTDocumentVariableIsAssigned` | PASS: true, false |
### `TNamingBasicTests.swift`
| `createLabel` | `OCCTDocumentCreateLabel` returns -1 | force-unwrap crash on the nil label (`createLabel()!`) | passed | `OCCTDocumentCreateLabel` | PASS: a label is created on both sides |
| `createChildLabel` | `OCCTDocumentCreateLabel` returns -1 | force-unwrap crash on the nil parent label | passed | `OCCTDocumentCreateLabel` | PASS: a child label is created on both sides |
| `recordPrimitive` | `OCCTDocumentNamingRecord` returns false | :32 Expectation failed: ok | passed | `OCCTDocumentNamingRecord` | PASS: the primitive record is made and reads as PRIMITIVE on both sides |
| `currentShapeAfterPrimitive` | `OCCTDocumentNamingGetCurrentShape` returns null | :43 Expectation failed: current != nil | passed | `OCCTDocumentNamingGetCurrentShape` | PASS: the current shape is found (the box) on both sides |
| `storedShape` | `OCCTDocumentNamingGetShape` returns null | :54 Expectation failed: stored != nil | passed | `OCCTDocumentNamingGetShape` | PASS: the stored shape is found (the box) on both sides |
| `evolutionType` | `OCCTDocumentNamingGetEvolution` answers 99 | :64 Expectation failed: doc.namingEvolution(on: label) == .primitive | passed | `OCCTDocumentNamingGetEvolution` | PASS: PRIMITIVE (0) |
| `noEvolutionOnEmptyLabel` | `OCCTDocumentNamingGetEvolution` answers 0 (primitive) where there is none | :71 Expectation failed: doc.namingEvolution(on: label) == nil | passed | `OCCTDocumentNamingGetEvolution` | PASS: no evolution is readable on a label with no naming, on both sides |
| `historyAfterPrimitive` | `OCCTDocumentNamingHistoryCount` answers 0 | :82 `history.count == 1`, then an index-out-of-range crash on `history[0]` | passed | `OCCTDocumentNamingHistoryCount` | PASS: one history entry with a new shape and no old shape on both sides |
| `newShapeFromHistory` | `OCCTDocumentNamingGetNewShape` returns null | :96 Expectation failed: newShape != nil | passed | `OCCTDocumentNamingGetNewShape` | PASS: new present, old absent |
| `modifyEvolution` | `OCCTDocumentNamingGetEvolution` answers 99 | :111 Expectation failed: doc.namingEvolution(on: label) == .modify | passed | `OCCTDocumentNamingGetEvolution` | PASS: the evolution is MODIFY and a current shape exists on both sides |
| `deleteEvolution` | `OCCTDocumentNamingGetEvolution` answers 99 | :124 Expectation failed: doc.namingEvolution(on: label) == .delete | passed | `OCCTDocumentNamingGetEvolution` | PASS: DELETE (3) |
| `generatedEvolution` | `OCCTDocumentNamingGetEvolution` answers 99 | :135 Expectation failed: doc.namingEvolution(on: label) == .generated | passed | `OCCTDocumentNamingGetEvolution` | PASS: GENERATED with one entry holding an old and a new shape on both sides |
| `multipleHistoryEntries` | `OCCTDocumentNamingHistoryCount` answers 0 | :153 Expectation failed: history.count >= 1 | passed | `OCCTDocumentNamingHistoryCount` | PASS: at least 1 history entry on both sides (kernel 1) |
### `TNamingCopyShapeTests.swift`
| `deepCopyBox` | `OCCTShapeDeepCopy` returns a null shape | :15 Expectation failed: copy.isValid | passed | `OCCTShapeDeepCopy` | PASS: the deep copy of a box is returned and valid on both sides |
| `deepCopySphere` | `OCCTShapeDeepCopy` returns a null shape | :24 Expectation failed: copy.isValid | passed | `OCCTShapeDeepCopy` | PASS: the deep copy of a sphere is returned and valid on both sides |
### `TNamingExtensionTests.swift`
| `namingIsEmpty` | `OCCTNamingIsEmpty` returns false | :15 Expectation failed: doc.namingIsEmpty(on: node) | passed | `OCCTNamingIsEmpty` | PASS: no naming on the created label on both sides |
| `namingIsEmptyAfterRecord` | `OCCTNamingIsEmpty` returns true | :23 Expectation failed: !doc.namingIsEmpty(on: node) | passed | `OCCTNamingIsEmpty` | PASS: not empty |
| `namingVersion` | `OCCTNamingGetVersion` answers 7 | :31 Expectation failed: doc.namingVersion(on: node) == 0; :33 Expectation failed: doc.namingVersion(on: node) == 42 | passed | `OCCTNamingGetVersion` | PASS: 0, then 42 |
| `namingOriginalShape` | `OCCTNamingOriginalShape` returns a (null) shape where there is none | :43 Expectation failed: original == nil | passed | `OCCTNamingOriginalShape` | PASS: a primitive has no original shape on both sides |
| `namingOriginalShapeFromModify` | `OCCTNamingOriginalShape` returns null | :55 Expectation failed: original != nil | passed | `OCCTNamingOriginalShape` | PASS: a modify record's original shape is found (the box) on both sides |
| `namingHasLabel` | `OCCTNamingHasLabel` returns false | :63 Expectation failed: doc.namingHasLabel(shape: box) | passed | `OCCTNamingHasLabel` | PASS: true |
| `namingFindLabel` | `OCCTNamingFindLabel` answers -1 | :72 Expectation failed: found != nil | passed | `OCCTNamingFindLabel` | PASS: the recording label is found on both sides |
| `namingValidUntil` | `OCCTNamingValidUntil` answers -1 | :81 Expectation failed: valid >= 0 | passed | `OCCTNamingValidUntil` | PASS: ValidUntil is >= 0 on both sides (kernel 0) |
| `sameShapeCount` | `OCCTNamingSameShapeCount` answers 1 | :92 Expectation failed: count >= 2 | passed | `OCCTNamingSameShapeCount` | PASS: at least 2 labels hold the box on both sides (kernel 2) |
| `sameShapeLabels` | `OCCTNamingSameShapeLabels` answers 1 | :103 Expectation failed: labels.count >= 2 | passed | `OCCTNamingSameShapeLabels` | PASS: at least 2 labels are listed on both sides (kernel 2) |
### `TNamingTracingTests.swift`
| `traceForward` | `OCCTDocumentNamingTraceForward` answers 0 | :21 Expectation failed: forward.count >= 1 | passed | `OCCTDocumentNamingTraceForward` | PASS: the forward trace finds 1 shape on both sides |
| `traceBackward` | `OCCTDocumentNamingTraceBackward` answers 0 | :36 Expectation failed: backward.count >= 1 | passed | `OCCTDocumentNamingTraceBackward` | PASS: the backward trace finds 1 shape on both sides |
| `multipleGenerations` | `OCCTDocumentNamingTraceForward` answers 0 | :55 Expectation failed: forward.count >= 2 | passed | `OCCTDocumentNamingTraceForward` | PASS: the forward trace finds both generated shapes on both sides |
| `emptyTraceForUnrelated` | `OCCTDocumentNamingTraceForward` answers the source shape | :67 Expectation failed: forward.isEmpty | passed | `OCCTDocumentNamingTraceForward` | PASS: the trace from an unrelated shape is empty on both sides (the kernel iterator throws) |
| `traceModificationChain` | `OCCTDocumentNamingTraceForward` answers 0 | :81 Expectation failed: forward.count >= 1 | passed | `OCCTDocumentNamingTraceForward` | PASS: the forward trace through a modify finds 1 shape on both sides |
| `forwardTraceExcludesSource` | `OCCTDocumentNamingTraceForward` answers the source shape | :98 Expectation failed: !shape.isSame(as: box) | passed | `OCCTDocumentNamingTraceForward` | PASS: the forward trace finds the generated shape and not the source on both sides |
| `backwardTraceExcludesGenerated` | `OCCTDocumentNamingTraceBackward` answers the given shape | :116 Expectation failed: !shape.isSame(as: sphere) | passed | `OCCTDocumentNamingTraceBackward` | PASS: the backward trace finds the source and not the generated shape on both sides |
### `TNamingTranslatorTests.swift`
| `translatorCopy` | `OCCTShapeTranslatorCopy` returns null | :12 Expectation failed: Bool(false) | passed | `OCCTShapeTranslatorCopy` | PASS: the translator copy is returned, valid and not the same shape on both sides |
### `XCAFDocAssemblyIteratorTests.swift`
| `iterateAssembly` | `OCCTDocumentAssemblyItemCount` answers 0 | :16 Expectation failed: count >= 1 | passed | `OCCTDocumentAssemblyItemCount` | PASS: the count is complete and at least 1 on both sides (kernel 1) |
| `smallAssemblyCountIsComplete` | `OCCTDocumentAssemblyItemCount` answers 0 | :32 Expectation failed: count >= 3 | passed | `OCCTDocumentAssemblyItemCount` | PASS: the count is complete and at least 3 on both sides (kernel 3) |
### `XCAFDocClippingPlaneToolTests.swift`
| `addAndGet` | `OCCTDocumentClipPlaneToolIsClipPlane` returns false | :15 Expectation failed: doc.clippingPlaneToolIsClipPlane(clip) | passed | `OCCTDocumentClipPlaneToolIsClipPlane` | PASS: z 5, normal z, capping |
| `remove` | `OCCTDocumentClipPlaneToolRemove` returns false | :32 Expectation failed: doc.clippingPlaneToolRemove(clip) | passed | `OCCTDocumentClipPlaneToolRemove` | PASS: removed |
### `XCAFDocColorTests.swift`
| `setAndGetRGB` | `OCCTDocumentSetColorAttr` returns false | :11 Expectation failed: label.setColorAttribute(red: 1.0, green: 0.0, blue: 0.0) | passed | `OCCTDocumentGetColorAttr` | PASS: (1, 0, 0) |
| `setAndGetRGBA` | `OCCTDocumentGetColorAlphaAttr` answers 0 | :27 Expectation failed: abs(label.colorAlphaAttribute - 0.8) < 0.02 | passed | `OCCTDocumentGetColorAlphaAttr` | PASS: 0.8 |
| `namedColor` | `OCCTDocumentGetColorNOCAttr` answers -1 | :38 Expectation failed: noc >= 0 | passed | `OCCTDocumentGetColorNOCAttr` | PASS: the named-colour ordinal is >= 0 on both sides (kernel 407) |
### `XCAFDocDimTolTests.swift`
| `setAndGet` | `OCCTDocumentGetDimTolKind` answers 2 | :19 Expectation failed: kind == 1 | passed | `OCCTDocumentGetDimTolKind` | PASS: all four round-trip |
| `noDimTol` | `OCCTDocumentGetDimTolKind` answers 0 where there is none | :39 Expectation failed: doc.dimTolKind(labelId: node.labelId) == nil | passed | `OCCTDocumentGetDimTolKind` | PASS: no XCAFDoc_DimTol on a fresh label on both sides |
### `XCAFDocGraphNodeTests.swift`
| `setAndRelate` | `OCCTDocumentGraphNodeNbChildren` answers 0 | :17 Expectation failed: l1.xcafGraphNodeChildCount == 1 | passed | `OCCTDocumentGraphNodeNbChildren` | PASS: 1, 1 |
| `unsetRelationship` | `OCCTDocumentGraphNodeNbFathers` answers 1 | :35 Expectation failed: l2.xcafGraphNodeFatherCount == 0 | passed | `OCCTDocumentGraphNodeNbFathers` | PASS: 0, 0 |
| `isFatherIsChild` | `OCCTDocumentGraphNodeIsFather` / `IsChild` return false and `NbChildren` answers 0 | :52 Expectation failed: isFather \|\| isChild \|\| l1.xcafGraphNodeChildCount > 0 | passed | `OCCTDocumentGraphNodeIsFather` | PASS: the graph nodes report a father-child relation on both sides |
### `XCAFDocLocationTests.swift`
| `setAndGetLocation` | `OCCTDocumentHasLocation` returns false | :15 Expectation failed: label.hasLocationAttribute | passed | `OCCTDocumentGetLocationTranslation` | PASS: (10, 20, 30) |
| `noLocation` | `OCCTDocumentHasLocation` returns true | :28 Expectation failed: !label.hasLocationAttribute | passed | `OCCTDocumentHasLocation` | PASS: no XCAFDoc_Location on a fresh label on both sides |
### `XCAFDocMaterialTests.swift`
| `setAndGet` | `OCCTDocumentGetMaterialAttrName` returns null | :17 Expectation failed: label.materialAttributeName == "Steel" | passed | `OCCTDocumentGetMaterialAttrName` | PASS: Steel, Carbon steel, 7850 |
| `noMaterial` | `OCCTDocumentHasMaterialAttr` returns true | :29 Expectation failed: !label.hasMaterialAttribute | passed | `OCCTDocumentHasMaterialAttr` | PASS: no XCAFDoc_Material on a fresh label on both sides |
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
| `setShapeAndQuery` | `OCCTDocumentShapeMapToolIsSubShape` returns false | :16 Expectation failed: label.shapeMapToolIsSubShape(face) | passed | `OCCTDocumentShapeMapToolIsSubShape` | PASS: the first face is a sub-shape and the extent is positive on both sides (kernel 33) |
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
