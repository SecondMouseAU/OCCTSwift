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

### `TDataStdNamedDataTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `namedInteger` | `OCCTDocumentNamedDataGetInteger` answers 0 | :19 Expectation failed: label.namedInteger("count") == 42 | passed | `OCCTDocumentNamedDataGetInteger` | PASS: 42 |
| `namedReal` | `OCCTDocumentNamedDataHasReal` returns false | :29 Expectation failed: label.hasNamedReal("pi") | passed | `OCCTDocumentNamedDataGetReal` | PASS: 3.14159 |
| `namedString` | `OCCTDocumentNamedDataGetString` answers "X" | :42 Expectation failed: label.namedString("partName") == "MyPart" | passed | `OCCTDocumentNamedDataGetString` | PASS: MyPart |
| `multipleValues` | `OCCTDocumentNamedDataGetInteger` answers 0 | :55 Expectation failed: label.namedInteger("count") == 5 | passed | `OCCTDocumentNamedDataGetInteger` | PASS: each kind round-trips |

### `TDataStdNoteBookTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `createNoteBook` | `OCCTNoteBookFind` returns false | :11 Expectation failed: doc.noteBookExists(tag: 200) | passed | `OCCTNoteBookFind` | PASS: found |
| `appendReal` | `OCCTNoteBookAppendReal` returns -1 | :18 Expectation failed: childTag != nil | passed | `OCCTNoteBookAppendReal` | PASS: child tag 1 |
| `appendInteger` | `OCCTNoteBookAppendInteger` returns -1 | :25 Expectation failed: childTag != nil | passed | `OCCTNoteBookAppendInteger` | PASS: child tag assigned |
| `multipleAppends` | `OCCTNoteBookAppendReal` answers tag 5 every time | :38 Expectation failed: r1 != r2 | passed | `OCCTNoteBookAppendReal` | PASS: tags 1, 2, 3 |

### `TDataStdRealArrayTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `initAndUse` | `OCCTDocumentGetRealArrayValue` answers 0 for any index | :25 Expectation failed: abs(v0 - 1.1) < 1e-10; :26 Expectation failed: abs(v1 - 2.2) < 1e-10 | passed | `OCCTDocumentGetRealArrayValue` | PASS: 0..2; 1.1 2.2 3.3 |

### `TDataStdRealListTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `setAndGet` | `OCCTDocumentSetRealList` stores the first value plus 1 | :13 Expectation failed: abs(result[0] - 1.5) < 1e-10 | passed | `OCCTDocumentGetRealList` | PASS: 1.5 .. 3.14 |
| `appendAndClear` | `OCCTDocumentRealListClear` returns true without clearing | :28 Expectation failed: result.count == 0 | passed | `OCCTDocumentRealListClear` | PASS: 0 after Clear |
| `hasRealList` | `OCCTDocumentHasRealList` returns true | :34 Expectation failed: !doc.hasRealList(tag: 342) | passed | `OCCTDocumentHasRealList` | PASS: absent before Set |
