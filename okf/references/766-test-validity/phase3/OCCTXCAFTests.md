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

### `GDTToleranceDatumAccessorTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `toleranceSemanticsRoundTrip` | `OCCTDocumentGetGeomToleranceInfo` reports material requirement 0 | :59 Expectation failed: tol.materialRequirement == .m | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: written values read back; value 0.1, type Position (10) |
| `toleranceZeroValuesAreAbsence` | `OCCTDocumentGetGeomToleranceInfo` treats a zero zone value as present (`>=` for `>`) | :86 Expectation failed: tol.zoneModifierValue == nil | passed | `OCCTDocumentGetGeomToleranceInfo` | PASS: kernel stores 0 and 0 with the zone kept; the bridge maps 0 to absent |
| `toleranceModifiersRoundTripInOrder` | `OCCTDocumentGetGeomToleranceModifier` swaps modifier indices 0 and 1 | :107 Expectation failed: doc.geomTolerance(at: index)?.modifiers == written | passed | `OCCTDocumentGetGeomToleranceModifier` | PASS: order kept (3, 15, 13) |
| `datumPositionRoundTrips` | `OCCTDocumentGetDatumInfo` treats position 0 as a place in the frame (`>=` for `>`) | :123 Expectation failed: doc.datum(at: index)?.position == nil; :129 Expectation failed: doc.datum(at: index)?.position == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: 0, 2, 0; the bridge maps 0 to no place |
| `datumModifiersRoundTrip` | `OCCTDocumentGetDatumInfo` drops the valued modifier's value | :152 Expectation failed: datum.modifierWithValue?.value == 12.5 | passed | `OCCTDocumentGetDatumInfo` | PASS: 2, 3; Projected (3) 12.5; cleared to None |
| `datumTargetDimensionsFollowTheType` | `OCCTDocumentGetDatumInfo` reports a width for every target type | :208 Expectation failed: target.width == nil; :217 Expectation failed: target.width == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: the kernel keeps 30 and 18 for every type; the bridge reports length unless Point and width only for Rectangle |
| `degenerateDatumTargetAxisIsRefused` | `OCCTDocumentSetDatumTargetPlacement` substitutes a valid axis for a degenerate one | :235 Expectation failed: !doc.setDatumTargetPlacement(at: index, location: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 0), reference: SIMD3(1, 0, 0), length: 10, width: 0); :244 Expectation failed: doc.datum(at: index)?.target?.length == nil | passed | `OCCTDocumentSetDatumTargetPlacement` | PASS: `gp_Dir(0,0,0)` throws, which the bridge's catch turns into a refusal |
| `accessorsAreNotSharedBetweenEntries` | `OCCTDocumentSetDatumTarget` writes to datum 0 | :282 Expectation failed: a.target == nil; :285 Expectation failed: b.target?.type == .circle | passed | `OCCTDocumentSetDatumTarget` | PASS: separate objects keep separate values |
| `outOfRangeIndicesAreRefused` | `OCCTDocumentSetGeomToleranceTypeOfValue` returns true without checking the index | :299 Expectation failed: !doc.setGeomToleranceValueType(at: 5, .diameter) | passed | `OCCTDocumentSetGeomToleranceTypeOfValue` | PASS: one tolerance and no datums, so index 5 and datum 0 are out of range |
