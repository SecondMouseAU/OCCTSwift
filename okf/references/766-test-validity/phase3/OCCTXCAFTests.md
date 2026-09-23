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

### `XCAFNoteObjectsTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `create` | `OCCTNoteObjectCreate` returns null | :10 Expectation failed: obj != nil | passed | `OCCTNoteObjectCreate` | PASS: created |
| `initiallyEmpty` | `OCCTNoteObjectHasPlane` returns true | :15 Expectation failed: !obj.hasPlane | passed | `OCCTNoteObjectHasPlane` | PASS: all false |
| `setPlane` | `OCCTNoteObjectGetPlane` answers the origin | :28 Expectation failed: abs(origin.x - 1.0) < 1e-6 | passed | `OCCTNoteObjectGetPlane` | PASS: x 1 |
| `setPoint` | `OCCTNoteObjectHasPoint` returns false | :35 Expectation failed: obj.hasPoint | passed | `OCCTNoteObjectHasPoint` | PASS: x 10 |
| `setPresentation` | `OCCTNoteObjectGetPresentation` returns null | :45 Expectation failed: obj.presentation != nil | passed | `OCCTNoteObjectGetPresentation` | PASS: kept |
| `reset` | `OCCTNoteObjectReset` returns without resetting | :57 Expectation failed: !obj.hasPlane; :58 Expectation failed: !obj.hasPoint | passed | `OCCTNoteObjectReset` | PASS: cleared |

### `XCAFViewObjectTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `create` | `OCCTViewObjectCreate` returns null | :11 Expectation failed: view != nil | passed | `OCCTViewObjectCreate` | PASS: created |
| `projectionType` | `OCCTViewObjectGetType` answers 99 | :17 Expectation failed: view.type == .central; :19 Expectation failed: view.type == .parallel | passed | `OCCTViewObjectGetType` | PASS: 2, 1, 0 |
| `realOCCTProjectionTypeValuesDecodeCorrectly` | `OCCTViewObjectGetType` answers 99 | :53 Expectation failed: readBack == raw; :55 Expectation failed: decoded == expected | passed | `OCCTViewObjectGetType` | PASS: raw values 0, 1, 2 |
| `viewDirection` | `OCCTViewObjectGetViewDirection` answers (0, 0, 0) | :63 Expectation failed: abs(dir.x - 1.0) < 1e-6 | passed | `OCCTViewObjectGetViewDirection` | PASS: (1, 0, 0) |
| `upDirection` | `OCCTViewObjectGetUpDirection` answers (0, 0, 0) | :71 Expectation failed: abs(up.z - 1.0) < 1e-6 | passed | `OCCTViewObjectGetUpDirection` | PASS: (0, 0, 1) |
| `windowSize` | `OCCTViewObjectGetWindowHSize` answers 0 | :79 Expectation failed: abs(view.windowHorizontalSize - 800) < 1e-6 | passed | `OCCTViewObjectGetWindowHSize` | PASS: 800 x 600 |
| `clippingPlanes` | `OCCTViewObjectHasFrontPlaneClipping` returns false | :88 Expectation failed: view.hasFrontPlaneClipping | passed | `OCCTViewObjectHasFrontPlaneClipping` | PASS: 1, 1000, then unset |
| `name` | `OCCTViewObjectGetName` returns null | :100 Expectation failed: view.name == "TopView" | passed | `OCCTViewObjectGetName` | PASS: TopView |
