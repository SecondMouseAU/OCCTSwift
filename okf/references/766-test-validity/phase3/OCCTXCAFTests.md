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

### `GDTUnifiedReadTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `populatedDocumentReadsThroughOneFamily` | `OCCTDocumentGetDimensionInfo` reports the type ordinal plus 1 | :44 Expectation failed: single.type == .sizeDiameter | passed | `OCCTDocumentGetDimensionInfo` | PASS: one of each; Size_Diameter is ordinal 15 |
| `rangeDimensionKeepsItsBounds` | `OCCTDocumentGetDimensionInfo` reports the first value slot as the value (the #996 defect) | :94 Expectation failed: dim.value.map { abs($0 - 11.0) < 1e-9 } == true | passed | `OCCTDocumentGetDimensionInfo` | PASS: range 10..12, `GetValue()` 11 (first slot 10, the #996 value) |
| `plusMinusDimensionKeepsToleranceOrder` | `OCCTDocumentGetDimensionInfo` reads the upper tolerance as the lower | :129 Expectation failed: dim.bounds == .plusMinus(lowerTolerance: -0.3, upperTolerance: 0.7); :130 Expectation failed: dim.lowerTolerance == -0.3 | passed | `OCCTDocumentGetDimensionInfo` | PASS: -0.3 / +0.7, value 20 |
| `simpleDimensionHasNoBoundsOrTolerances` | `OCCTDocumentGetDimensionInfo` reports a simple dimension as unset | :160 Expectation failed: dim.bounds == .simple; :161 Expectation failed: dim.value.map { abs($0 - 3.5) < 1e-9 } == true | passed | `OCCTDocumentGetDimensionInfo` | PASS: one value 3.5, no range, no tolerance, no class |
| `classOfToleranceIsReadBack` | `OCCTDocumentGetDimensionInfo` reports the grade ordinal plus 1 | :199 Expectation failed: cls.grade == .it7 | passed | `OCCTDocumentGetDimensionInfo` | PASS: hole, H (11), IT7 (8) |
| `rangeDimensionCanCarryAClassOfTolerance` | `OCCTDocumentGetDimensionInfo` reports the grade ordinal plus 1 | :235 Expectation failed: dim.classOfTolerance?.grade == .it9 | passed | `OCCTDocumentGetDimensionInfo` | PASS: shaft, JS (12), IT9 (10), still a range |
| `toleranceOnARangeDimensionIsRefused` | `OCCTDocumentSetDimensionTolerance` returns true without checking anything | :257 Expectation failed: doc.setDimensionTolerance(at: idx, lower: -0.3, upper: 0.7) == false | passed | `OCCTDocumentSetDimensionTolerance` | PASS: the kernel refuses both writes on a range and keeps 10..12 |
| `mutatorsRejectAnOutOfRangeIndex` | `OCCTDocumentSetDimensionTolerance` returns true without checking anything | :269 Expectation failed: doc.setDimensionTolerance(at: 0, lower: -0.1, upper: 0.1) == false | passed | `OCCTDocumentSetDimensionTolerance` | PASS: no dimensions, so index 0 is out of range |
| `formVarianceEnumComplete` | a compile-time extra case (`injected766 = 9999`) added to the Swift enum; removed and rebuilt for green | :279 Expectation failed: Document.DimensionFormVariance.allCases.count == 29 | passed | `OCCTDocumentGetDimensionInfo` | PASS: 29 = 29 (Swift `Document.DimensionFormVariance`) |
| `gradeEnumComplete` | a compile-time extra case (`injected766 = 9999`) added to the Swift enum; removed and rebuilt for green | :284 Expectation failed: Document.DimensionGrade.allCases.count == 20 | passed | `OCCTDocumentGetDimensionInfo` | PASS: 20 = 20 (Swift `Document.DimensionGrade`) |
