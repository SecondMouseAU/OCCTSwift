# Phase 3: OCCTXCAFTests Injection Matrix

**Target**: `OCCTXCAFTests` (424 tests) — XCAF document operations, colors, layers, assemblies
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 P1 (crash fixes #341, #344, #349, #353, #371, #374)

---

## Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
| **XCAF Color Tests** | XCAF Color Tests | Colors | Remove color ops |
| **XCAF Layer Tests** | XCAF Layer Tests | Layers | Remove layer ops |
| **XCAF Assembly Tests** | XCAF Assembly Tests | Assemblies | Remove assembly ops |
| **XCAF Document Save/Load** | XCAF Document Save/Load | Document I/O | Remove save/load |
| **XCAF Material Tests** | XCAF Material Tests | Materials | Remove materials |
| **XCAF Shape Addition/Removal** | XCAF Shape Addition/Removal | Shape add/remove | Remove add/remove |
| **XCAF GDT Tests** | XCAF GDT Tests | GDT | Remove GDT |
| **XCAF Validation Tests** | XCAF Validation Tests | Validation | Remove validation |
| **XCAF Style Tests** | XCAF Style Tests | Styles | Remove styles |
| **XCAF Area/Volume Tests** | XCAF Area/Volume Tests | Area/volume | Remove area/volume |
| **XCAF Location/Transformation** | XCAF Location/Transformation | Location/transform | Remove location/transform |
| **XCAF Bounding Box Tests** | XCAF Bounding Box Tests | Bounding box | Remove bounding box |
| **XCAF Document Creation** | XCAF Document Creation | Document creation | Remove doc creation |
| **XCAF Mesh Tests** | XCAF Mesh Tests | Mesh | Remove mesh |
| **XCAF Note/Annotation Tests** | XCAF Note/Annotation Tests | Notes/annotations | Remove notes/annotations |

---

## Injection Matrix: Critical Crash Fixes

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| **#341 theAutoNaming race** | XCAFApp_Application::GetApplication | Race on theAutoNaming | Revert to singleton/remove atomic |  |  |  |
| **#344 CDF_Directory race** | CDF_Directory::Add/Remove/Contains | Race on myDocuments | Remove mutex |  |  |  |
| **#349 OCAF driver race** | PCDM_StorageDriver/Reader | Shared driver race | Remove ocafStoreMutex |  |  |  |
| **#353 CDM_MetaData race** | CDM_Application::myMetaDataLookUpTable | Race on metadata | Remove CDM mutex |  |  |  |
| **#371 GetApplication singleton** | XCAFApp_Application::GetApplication | Singleton race | Revert to singleton |  |  |  |
| **#374 Resource_Manager/Storage_Schema** | Resource_Manager::Debug / Storage_Schema::ICurrentData | Race on Debug/ICurrentData | Remove atomic/mutex |  |  |  |

---

## Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| XCAF Color Tests | OCCTXCAFColor | Colors | Remove color ops |  |  |  |
| XCAF Layer Tests | OCCTXCAFLayer | Layers | Remove layer ops |  |  |  |
| XCAF Assembly Tests | OCCTXCAFAssembly | Assemblies | Remove assembly ops |  |  |  |
| XCAF Document Save/Load | OCCTDocumentSaveOCAF/LoadOCAF | Document I/O | Remove save/load |  |  |  |
| XCAF Material Tests | OCCTXCAFMaterial | Materials | Remove materials |  |  |  |
| XCAF Shape Addition/Removal | OCCTXCAFShapeAddRemove | Shape add/remove | Remove add/remove |  |  |  |
| XCAF GDT Tests | OCCTXCAFGDT | GDT | Remove GDT |  |  |  |
| XCAF Validation Tests | OCCTXCAFValidation | Validation | Remove validation |  |  |  |
| XCAF Style Tests | OCCTXCAFStyle | Styles | Remove styles |  |  |  |
| XCAF Area/Volume Tests | OCCTXCAFAreaVolume | Area/volume | Remove area/volume |  |  |  |
| XCAF Location/Transformation | OCCTXCAFLocationTransform | Location/transform | Remove location/transform |  |  |  |
| XCAF Bounding Box Tests | OCCTXCAFBoundingBox | Bounding box | Remove bounding box |  |  |  |
| XCAF Document Creation | OCCTXCAFDocumentCreation | Document creation | Remove doc creation |  |  |  |
| XCAF Mesh Tests | OCCTXCAFMesh | Mesh | Remove mesh |  |  |  |
| XCAF Note/Annotation Tests | OCCTXCAFNoteAnnotation | Notes/annotations | Remove notes/annotations |  |  |  |

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
| XCAF Color Tests |  |  |  |
| XCAF Layer Tests |  |  |  |
| XCAF Assembly Tests |  |  |  |
| XCAF Document Save/Load |  |  |  |
| XCAF Material Tests |  |  |  |
| XCAF Shape Addition/Removal |  |  |  |
| XCAF GDT Tests |  |  |  |
| XCAF Validation Tests |  |  |  |
| XCAF Style Tests |  |  |  |
| XCAF Area/Volume Tests |  |  |  |
| XCAF Location/Transformation |  |  |  |
| XCAF Bounding Box Tests |  |  |  |
| XCAF Document Creation |  |  |  |
| XCAF Mesh Tests |  |  |  |
| XCAF Note/Annotation Tests |  |  |  |

**Total**: 424 tests
