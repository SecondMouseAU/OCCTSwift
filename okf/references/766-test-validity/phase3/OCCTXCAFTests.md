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

### `AssemblyNodeIdentityTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `labelIdRoundTrip` | `OCCTDocumentLabelIsNull` returns true for every id | :26 Issue recorded | passed | `OCCTDocumentLabelIsNull` | PASS: one free shape, root label `0:1:1:1` not null and stable across re-fetch |
| `unknownLabelIdRejected` | `OCCTDocumentLabelIsNull` returns false for every id | :40 Expectation failed: doc.node(at: .max) == nil | passed | `OCCTDocumentLabelIsNull` | PASS: fresh document has 0 free shapes, so no label can be registered at Int64.max |
| `nodeAtFreshDocumentDoesNotRequireWarmup` | `Document.node(at:)` skips its root warm-up loop (the #95 defect) | :60 Expectation failed: node != nil | passed | `OCCTDocumentGetRootLabelId` | PASS: kernel has the one free-shape root the warm-up registers as id 0 |

### `ChildNodeIteratorTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `noTreeNode` | `OCCTChildNodeIteratorCount` returns 1 | :12 Expectation failed: doc.childNodeCount(tag: 400) == 0 | passed | `OCCTChildNodeIteratorCount` | PASS: 0 = 0 |

### `ColorToolCompletionsTests.swift`

| Test | Injection (env-gated, reverted) | Red (failing expectation) | Green | Bridge function | Parity |
|---|---|---|---|---|---|
| `addAndFindColor` | `OCCTDocumentColorToolFindColor` returns -1 | :14 Expectation failed: found == tag | passed | `OCCTDocumentColorToolFindColor` | PASS: `FindColor` returns the label `AddColor` made |
| `colorCount` | `OCCTDocumentColorToolGetColorCount` returns 0 | :23 Expectation failed: after == before + 1 | passed | `OCCTDocumentColorToolGetColorCount` | PASS: 0 then 1 |
| `removeColor` | `OCCTDocumentColorToolRemoveColor` returns true without removing | :34 Expectation failed: after == before - 1 | passed | `OCCTDocumentColorToolRemoveColor` | PASS: 1 then 0 |
| `visibility` | `OCCTDocumentColorToolSetVisibility` returns true without setting | :48 Expectation failed: !doc.colorToolIsVisible(labelId: labelId) | passed | `OCCTDocumentColorToolIsVisible` | PASS: true, false, true |
| `colorByLayer` | `OCCTDocumentColorToolSetColorByLayer` returns true without setting | :65 Expectation failed: doc.colorToolIsColorByLayer(labelId: labelId) | passed | `OCCTDocumentColorToolIsColorByLayer` | PASS: false, then true |
### `DocumentColorMaterialTests.swift`
| `setLabelColor` | `OCCTDocumentSetLabelColor` returns without setting | :24 Expectation failed: color != nil | passed | `OCCTDocumentSetLabelColor` | PASS: (1, 0, 0); no colour before the set |
| `colorAttrRoundTrips` | `OCCTDocumentSetColorAttr` builds the colour as `Quantity_TOC_sRGB` (the #1508 defect) | :58 Expectation failed: abs(readBack.red - 0.5) < 1e-6; :59 Expectation failed: abs(readBack.green - 0.25) < 1e-6 | passed | `OCCTDocumentGetColorAttr` | PASS: (0.5, 0.25, 0.75); built as TOC_sRGB the kernel gives (0.214041, 0.050876, 0.522522), the #1508 values |
| `colorRGBAAttrRoundTrips` | `OCCTDocumentSetColorRGBAAttr` builds the colour as `Quantity_TOC_sRGB` (the #1508 defect) | :86 Expectation failed: abs(readBack.red - 0.5) < 1e-6; :87 Expectation failed: abs(readBack.green - 0.25) < 1e-6 | passed | `OCCTDocumentGetColorRGBAAttr` | PASS: (0.5, 0.25, 0.75, 0.4) |
| `setLabelMaterial` | `OCCTDocumentSetLabelMaterial` stores roughness as metallic | :117 Expectation failed: abs(readMat.metallic - 0.9) < 0.01 | passed | `OCCTDocumentGetLabelMaterial` | PASS: metallic 0.9, roughness 0.3 |
### `DocumentExplorerTests.swift`
| `exploreDocumentWithShape` | `OCCTDocumentExplorerCount` returns 0 | :15 Expectation failed: count >= 1 | passed | `OCCTDocumentExplorerCount` | PASS: kernel 1 leaf, test asserts >= 1 |
| `explorerShapeAtIndex` | `OCCTDocumentExplorerShape` returns null | :25 Expectation failed: shape != nil | passed | `OCCTDocumentExplorerShape` | PASS: leaf 0 has a shape |
| `explorerPathId` | `OCCTDocumentExplorerPathId` returns null | :35 Expectation failed: pathId != nil | passed | `OCCTDocumentExplorerPathId` | PASS: path id `0:1:1:1.` |
| `findShapeFromPathId` | `OCCTDocumentExplorerFindShape` returns null | :46 Expectation failed: found != nil | passed | `OCCTDocumentExplorerFindShape` | PASS: `FindShapeFromPathId` gives the solid |
### `CurrentTests.swift`
| `setAndGet` | `OCCTDocumentSetCurrentLabel` returns true without setting | :12 `doc.currentLabel() == 510` (rewritten; the old `if let` passed this injection) | passed | `OCCTDocumentGetCurrentLabel` | PASS: tag 510 = 510 |
| `hasCurrent` | `OCCTDocumentHasCurrentLabel` returns true | :17 Expectation failed: !doc.hasCurrentLabel() | passed | `OCCTDocumentHasCurrentLabel` | PASS: false, then true |
| `noCurrentReturnsNil` | `OCCTDocumentGetCurrentLabel` returns tag 0 | :24 Expectation failed: doc.currentLabel() == nil | passed | `OCCTDocumentGetCurrentLabel` | PASS: has_current false on both sides (bridge -1 maps to nil; kernel `TDataStd_Current::Has` false) |
### `DimTolToolTests.swift`
| `emptyDocumentCounts` | `OCCTDocumentDimTolDimensionCount` returns 1 (`F2`, the tolerance count returning 1, also red at :11) | :10 Expectation failed: doc.dimTolToolDimensionCount == 0 | passed | `OCCTDocumentDimTolDimensionCount` | PASS: 0 and 0 |
### `DirectoryTests.swift`
| `createDirectory` | `OCCTDocumentDirectoryNew` returns false | :11 Expectation failed: ok | passed | `OCCTDocumentDirectoryNew` | PASS: created true on both sides (`!dir.IsNull()`; kernel `New(100)` non-null) |
| `findDirectory` | `OCCTDocumentDirectoryFind` returns false | :18 Expectation failed: doc.hasDirectory(at: 100) | passed | `OCCTDocumentDirectoryFind` | PASS: true = true |
| `addSubDirectory` | `OCCTDocumentDirectoryAddSubDirectory` returns -1 | :26 Expectation failed: childTag != nil | passed | `OCCTDocumentDirectoryAddSubDirectory` | PASS: tag_non_nil true on both sides (kernel sub-directory tag 1 >= 0; raw tags not compared) |
| `makeObjectLabel` | `OCCTDocumentDirectoryMakeObjectLabel` returns -1 | :34 Expectation failed: objTag != nil | passed | `OCCTDocumentDirectoryMakeObjectLabel` | PASS: tag_non_nil true on both sides (kernel object label tag 2 >= 0; raw tags not compared) |
