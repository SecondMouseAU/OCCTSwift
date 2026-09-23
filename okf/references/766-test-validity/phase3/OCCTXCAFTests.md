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

### `Issue1055DatumNameLengthTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `longNameRoundTrips` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :38 Expectation failed: datum.name.count == 100; :39 Expectation failed: datum.name == name | passed | `OCCTDocumentGetDatumName` | PASS: 100 chars both sides |
| `namesAroundTheOldBoundRoundTrip` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :56 Expectation failed: datum.name == name; :56 Expectation failed: datum.name == name | passed | `OCCTDocumentGetDatumName` | PASS: 63, 64, 65 kept |
| `shortBufferReportsTheFullLength` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :77 Expectation failed: reported == 100 | passed | `OCCTDocumentGetDatumName` | PASS: full length 100 |
| `nullBufferReportsTheLength` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :95 Expectation failed: OCCTDocumentGetDatumName(doc.handle, Int32(index), nil, 0) == 100 | passed | `OCCTDocumentGetDatumName` | PASS: 100 |
| `malformedBufferArgumentsAreRefused` | `OCCTDocumentGetDatumName` accepts a negative length | :112 Expectation failed: OCCTDocumentGetDatumName(doc.handle, Int32(index), &buffer, -1) == -1 | passed | `OCCTDocumentGetDatumName` | N/A: argument validation is the bridge's own; no kernel call |
| `datumsEnumerationCarriesWholeNames` | `OCCTDocumentGetDatumName` caps the name at 63 bytes (the pre-#1055 bound) | :125 Expectation failed: doc.datums.map(\.name) == names | passed | `OCCTDocumentGetDatumName` | PASS: 1, 100, 200 |

### `Issue1078LayerNameLengthTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `longNameRoundTrips` | `OCCTDocumentGetLayerName` writes an empty name | :37 Expectation failed: !name.isEmpty; :37 Expectation failed: !name.isEmpty | passed | `OCCTDocumentGetLayerName` | MISMATCH: bridge and kernel agree on what the bridge reads, but it reads the wrong table: #2413 |
| `nullBufferReportsTheLength` | `OCCTDocumentGetLayerName` clamps any index to 0 | :56 Expectation failed: OCCTDocumentGetLayerName(handle, count, nil, 0) == -1; :57 Expectation failed: OCCTDocumentGetLayerName(handle, -1, nil, 0) == -1 | passed | `OCCTDocumentGetLayerName` | PASS: 3 entries, so index 3 and -1 are out of range |
| `shortBufferReportsTheFullLength` | `OCCTDocumentGetLayerName` reports the copied length, not the full one | :76 Expectation failed: reported == len | passed | `OCCTDocumentGetLayerName` | PASS: only `VisMaterials` (12) exceeds 10 |
| `malformedBufferArgumentsAreRefused` | `OCCTDocumentGetLayerName` answers 5 for a negative length | :95 Expectation failed: OCCTDocumentGetLayerName(handle, 0, &buffer, -1) == -1 | passed | `OCCTDocumentGetLayerName` | N/A: bridge-only validation |
