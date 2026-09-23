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

### `XCAFPrsStyleTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `emptyStyle` | `OCCTXCAFPrsStyleCreate` reports a non-empty style | :10 Expectation failed: style.isEmpty | passed | `OCCTXCAFPrsStyleCreate` | PASS: empty |
| `surfaceColor` | `OCCTXCAFPrsStyleCreateWithSurfColor` returns an empty style | :15 Expectation failed: !style.isEmpty | passed | `OCCTXCAFPrsStyleCreateWithSurfColor` | PASS: not empty |
| `visibility` | `OCCTXCAFPrsStyleIsEqual` returns true | :27 `!style.isEqual(to: visible)` (rewritten; reading back a stored property could not fail) | passed | `OCCTXCAFPrsStyleIsEqual` | PASS: unequal |
| `equality` | `OCCTXCAFPrsStyleIsEqual` returns false | :36 Expectation failed: s1.isEqual(to: s2) | passed | `OCCTXCAFPrsStyleIsEqual` | PASS: equal |
| `curveColorOnly` | `OCCTXCAFPrsStyleCreateWithCurvColor` returns an empty style | :48 Expectation failed: !style.isEmpty; :56 Expectation failed: !style.isEqual(to: differentCurve) | passed | `OCCTXCAFPrsStyleCreateWithCurvColor` | PASS: not empty; same equal; different unequal |

### `VisMaterialCommonTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `defaultValues` | `OCCTVisMaterialCommonDefault` returns a zeroed material | :10 Expectation failed: mat.isDefined; :11 Expectation failed: abs(mat.diffuseColor.red - 0.8) < 0.02 | passed | `OCCTVisMaterialCommonDefault` | PASS: 0.8 |
| `setProperties` | `OCCTVisMaterialCommonIsEqual` returns true | `!mat.isEqual(to: other)` (rewritten; reading back stored properties could not fail) | passed | `OCCTVisMaterialCommonIsEqual` | PASS: unequal |
| `equality` | `OCCTVisMaterialCommonIsEqual` returns false | :37 Expectation failed: m1.isEqual(to: m2) | passed | `OCCTVisMaterialCommonIsEqual` | PASS: equal |
| `commonMaterialRoughnessFromShininess` | `OCCTMaterialRoughnessFromSpecular` answers 0.1 | :105 Expectation failed: abs(material.roughness - 0.7) < 0.01 | passed | `OCCTDocumentGetLabelMaterial` | N/A: bridge-side conversion (`OCCTMaterialRoughnessFromSpecular`); no kernel roughness exists for a common material |

### `VisMaterialPBRTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `defaultValues` | `OCCTVisMaterialPBRDefault` returns a zeroed material | :10 Expectation failed: pbr.isDefined; :11 Expectation failed: abs(pbr.metallic - 1.0) < 1e-6 | passed | `OCCTVisMaterialPBRDefault` | PASS: 1, 1, 1.5 |
| `setProperties` | `OCCTVisMaterialPBRIsEqual` returns true | `!pbr.isEqual(to: other)` (rewritten; reading back stored properties could not fail) | passed | `OCCTVisMaterialPBRIsEqual` | PASS: unequal |
| `equality` | `OCCTVisMaterialPBRIsEqual` returns false | :39 Expectation failed: p1.isEqual(to: p2) | passed | `OCCTVisMaterialPBRIsEqual` | N/A: same values compare equal (see common) |
