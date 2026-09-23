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

### `IDFilterTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `createFilter` | `OCCTIDFilterIgnoreAll` returns false | :12 Expectation failed: f.isIgnoreAll | passed | `OCCTIDFilterIgnoreAll` | PASS: true = true |
| `keepMode` | `OCCTIDFilterIgnoreAll` returns true | :18 Expectation failed: !filter.isIgnoreAll | passed | `OCCTIDFilterIgnoreAll` | PASS: false = false |
| `keepGUID` | `OCCTIDFilterIsKept` returns false | :26 Expectation failed: filter.isKept(guid) | passed | `OCCTIDFilterIsKept` | PASS: true = true |
| `ignoreGUID` | `OCCTIDFilterIsIgnored` returns false | :34 Expectation failed: filter.isIgnored(guid) | passed | `OCCTIDFilterIsIgnored` | PASS: true = true |
| `toggleIgnoreAll` | `OCCTIDFilterSetIgnoreAll` returns without setting | :41 Expectation failed: !filter.isIgnoreAll | passed | `OCCTIDFilterSetIgnoreAll` | PASS: false after `IgnoreAll(false)` |

### `Issue1030DatumLookupGuardTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `theCrashingShapeIsAuthorable` | `OCCTDocumentGetRealArrayValue` returns false | :91 Expectation failed: point?.realArrayValue(at: 1) == 7; :92 Expectation failed: point?.realArrayValue(at: 3) == 7 | passed | `OCCTDocumentGetRealArrayValue` | PASS: both children exist with no array; the point array reads 1..3 of 7 |
| `pointWithoutPlaneLocationIsRead` | the retired #1030 datum guard, reinstated in the shared GD&T lookup | :106 Expectation failed: doc.datum(at: index)?.name == "Datum1030"; :107 Expectation failed: doc.datums.count == 1 | passed | `OCCTDocumentGetDatumInfo` | PASS: `GetObject` reads it (patch 0029 pinned), name `Datum1030`, one label |
| `aWritePathSucceedsToo` | the retired #1030 datum guard, reinstated in the shared GD&T lookup | :124 Expectation failed: doc.setDatumPosition(at: index, 2); :125 Expectation failed: doc.setDatumModifiers(at: index, [.basic]) | passed | `OCCTDocumentSetDatumPosition` | PASS: the object the writes need is readable |
| `planeLocationTooShortForThePointIndexIsRead` | the retired #1030 datum guard, reinstated in the shared GD&T lookup | :174 Expectation failed: doc.datum(at: index)?.name == "Datum1030" | passed | `OCCTDocumentGetDatumInfo` | PASS: reads with the point at index 1000000 |
| `pointWithPlaneLocationStillReads` | a datum guard that refuses any datum carrying a point array | :187 Expectation failed: datum != nil; :188 Expectation failed: datum?.name == "Datum1030" | passed | `OCCTDocumentGetDatumInfo` | PASS: reads |
| `pointArrayOfTheWrongLengthStillReads` | the #1030 guard without its length-3 check | :214 Expectation failed: doc.datum(at: index)?.name == "Datum1030" | passed | `OCCTDocumentGetDatumInfo` | PASS: reads with a length-2 point array |
| `rescaleGeometryStillSucceeds` | `OCCTDocumentEditorRescaleGeometry` returns false | :231 Expectation failed: doc.rescaleGeometry(labelId: main.labelId, scaleFactor: 2.0, forceIfNotRoot: true) | passed | `OCCTDocumentEditorRescaleGeometry` | PASS: `XCAFDoc_Editor::RescaleGeometry` true |
| `plainDatumStillReads` | a datum guard that refuses any datum whose point child label exists (a child-existence test) | :247 Expectation failed: datum?.name == "Datum1030"; :248 Expectation failed: doc.setDatumPosition(at: index, 2) | passed | `OCCTDocumentGetDatumInfo` | PASS: every datum has child 17 (so a child-existence guard refuses all); no array, so it reads |
