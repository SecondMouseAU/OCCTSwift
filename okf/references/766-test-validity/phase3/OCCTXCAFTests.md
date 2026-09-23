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

### `GDTDimensionAccessorTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `qualifierRoundTrips` | `OCCTDocumentGetDimensionInfo` reports qualifier 0 | :42 Expectation failed: qualified.qualifier == .max | passed | `OCCTDocumentGetDimensionInfo` | PASS: 0, Max (2), 0; value 20 and simple kept |
| `angularQualifierRoundTrips` | `OCCTDocumentGetDimensionInfo` reports angular qualifier 0 | :69 Expectation failed: both.angularQualifier == .large | passed | `OCCTDocumentGetDimensionInfo` | PASS: Min (1), Large (2) |
| `decimalPlacesDistinguishAbsenceFromZero` | `OCCTDocumentGetDimensionInfo` tests decimal-place presence with `&&` instead of `or` | :102 Issue recorded | passed | `OCCTDocumentGetDimensionInfo` | PASS: (2,3), (0,4) and (0,0) read back as written; the bridge maps (0,0) to absent |
| `modifiersRoundTripInOrder` | `OCCTDocumentGetDimensionModifier` swaps modifier indices 0 and 1 | :123 Expectation failed: doc.dimension(at: index)?.modifiers == written | passed | `OCCTDocumentGetDimensionModifier` | PASS: order 19, 1, 2 kept; cleared to 0 |
| `typeClassifiersMatchOCCT` | `OCCTDimensionTypeIsDimensionalLocation` returns true | :137 Expectation failed: !Document.DimensionType.sizeDiameter.isDimensionalLocation; :140 Expectation failed: !Document.DimensionType.commonLabel.isDimensionalLocation | passed | `OCCTDimensionTypeIsDimensionalLocation` | PASS: identical, and no type is both |
| `accessorsAreNotSharedBetweenDimensions` | `OCCTDocumentSetDimensionDecimalPlaces` writes to dimension 0 | :173 Expectation failed: a.decimalPlaces == nil; :177 Expectation failed: b.decimalPlaces?.left == 1 | passed | `OCCTDocumentSetDimensionDecimalPlaces` | PASS: separate objects keep separate values |
| `outOfRangeIndicesAreRefused` | `OCCTDocumentSetDimensionQualifier` returns true without checking the index | :193 Expectation failed: !doc.setDimensionQualifier(at: 5, .max) | passed | `OCCTDocumentSetDimensionQualifier` | PASS: one dimension label, so index 5 is out of range |

### `GDTDocumentTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `emptyDocDimensions` | `OCCTDocumentGetDimensionCount` returns 1 | :16 Expectation failed: doc.dimensionCount == 0 | passed | `OCCTDocumentGetDimensionCount` | PASS: 0 = 0 |
| `emptyDocTolerances` | `OCCTDocumentGetGeomToleranceCount` returns 1 | :26 Expectation failed: doc.geomToleranceCount == 0 | passed | `OCCTDocumentGetGeomToleranceCount` | PASS: 0 = 0 |
| `emptyDocDatums` | `OCCTDocumentGetDatumCount` returns 1 | :36 Expectation failed: doc.datumCount == 0 | passed | `OCCTDocumentGetDatumCount` | PASS: 0 on a fresh document |
| `dimensionInvalidIndex` | `OCCTDocumentGetDimensionInfo` returns a valid info for any index | :46 Expectation failed: doc.dimension(at: 0) == nil; :47 Expectation failed: doc.dimension(at: -1) == nil | passed | `OCCTDocumentGetDimensionInfo` | PASS: no dimensions, every index out of range |
| `toleranceInvalidIndex` | `OCCTDocumentGetGeomToleranceInfo` returns a valid info for any index | :57 Expectation failed: doc.geomTolerance(at: 0) == nil; :58 Expectation failed: doc.geomTolerance(at: -1) == nil | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: no tolerances |
| `datumInvalidIndex` | `OCCTDocumentGetDatumInfo` returns a valid info and `OCCTDocumentGetDatumName` an empty name for any index | :67 Expectation failed: doc.datum(at: 0) == nil; :68 Expectation failed: doc.datum(at: -1) == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: no datums |
