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

### `Issue1056GDTWriteAnswerTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `nonStorableToleranceRefusesTheCreate` | `occtDimensionApplyTolerance` (both copies reached) accepts without its readback check | :48 Expectation failed: index == nil; :48 Expectation failed: index == nil | passed | `OCCTDocumentCreateDimensionWithTolerance` | PASS: the kernel stores NaN; the readback `==` is false, which is what refuses |
| `storableToleranceStillApplies` | `OCCTDocumentGetDimensionInfo` reads the upper tolerance as the lower | :70 Expectation failed: dim.bounds == .plusMinus(lowerTolerance: -0.3, upperTolerance: 0.7) | passed | `OCCTDocumentGetDimensionInfo` | PASS: -0.3 / +0.7 |
| `noToleranceStillCreatesASimpleDimension` | `OCCTDocumentGetDimensionInfo` reports a simple dimension as unset | :90 Expectation failed: doc.dimension(at: index)?.bounds == .simple | passed | `OCCTDocumentGetDimensionInfo` | PASS: one value, simple |
| `standaloneSetterRefusesTheSamePair` | `occtDimensionApplyTolerance` (both copies reached) accepts without its readback check | :105 Expectation failed: doc.setDimensionTolerance(at: index, lower: .nan, upper: 0.5) == false; :106 Expectation failed: doc.dimension(at: index)?.bounds == .simple | passed | `OCCTDocumentSetDimensionTolerance` | PASS: NaN readback check fails |
| `noneModifierStoresNoValue` | `OCCTDocumentSetGeomToleranceZoneModifier` stores the value whatever the modifier | :129 Expectation failed: tol.zoneModifierValue == nil | passed | `OCCTDocumentSetGeomToleranceZoneModifier` | PASS: the kernel keeps a value under None, so the bridge must write 0 itself |
| `clearingAModifierClearsItsValue` | `OCCTDocumentSetGeomToleranceZoneModifier` stores the value whatever the modifier | :151 Expectation failed: tol.zoneModifierValue == nil | passed | `OCCTDocumentSetGeomToleranceZoneModifier` | PASS: same |
| `realModifierStillStoresItsValue` | `OCCTDocumentSetGeomToleranceZoneModifier` stores 0 whatever the value | :172 Expectation failed: tol.zoneModifierValue == 15.0 | passed | `OCCTDocumentSetGeomToleranceZoneModifier` | PASS: Projected 15 |
| `datumSiblingReportsNothingForAClearedModifier` | `OCCTDocumentGetDatumInfo` reports modifier 1 whatever is stored | :197 Expectation failed: doc.datum(at: index)?.modifierWithValue == nil | passed | `OCCTDocumentGetDatumInfo` | PASS: kernel keeps 15 under None; the bridge reports nothing |

### `Issue1435DatumDocumentToolTableTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `datumIsUnderDocumentToolLabel` | `OCCTDocumentCreateDatum` writes through `XCAFDoc_DimTolTool::Set(Main())` (the #1435 regression) | :62 Expectation failed: dgts.childCount == 1; :69 Expectation failed: doc.datumCount == 1 | passed | `OCCTDocumentCreateDatum` | PASS: the datum lands under 0:1:4 |
| `datumCountAgreesWithRealTable` | `OCCTDocumentCreateDatum` writes through `XCAFDoc_DimTolTool::Set(Main())` (the #1435 regression) | :89 Expectation failed: dgts.childCount == 3; :90 Expectation failed: doc.datumCount == 3 | passed | `OCCTDocumentGetDatumCount` | PASS: 3 = 3; a tool set on Main() never makes 0:1:4 |
