# Phase 3: OCCTXCAFTests Injection Matrix

**Target**: `OCCTXCAFTests` (422 tests) — XCAF document operations, colors, layers, assemblies
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (crash fixes #341, #344, #349, #353, #371, #374)

---

## Test Inventory by Suite

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| XCAF Color Tests | 58 | WR/CR |
| XCAF Layer Tests | 48 | WR |
| XCAF Assembly Tests | 42 | WR |
| XCAF Document Save/Load | 40 | IO/CR (#341, #344, #349, #353, #371, #374) |
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

**Total**: 422 tests across ~15 suites

---

## Injection Matrix: Critical Crash-Related Tests First

### #341: theAutoNaming Race (Kernel Patch `0011`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Concurrent document creation | `OCCTDocumentCreate` → `XCAFApp_Application::GetApplication` | Race on `theAutoNaming` | Revert to singleton / remove atomic |  |  | TSan race |

### #344: CDF_Directory Race (Kernel Patch `0012`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Parallel document save/load | `OCCTDocumentSaveOCAF` / `OCCTDocumentLoadOCAF` | Race on `CDF_Directory` | Remove mutex |  |  | TSan race |

### #349: OCAF Driver Race (Kernel Patch `0014`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Concurrent Save/Load OCAF | `OCCTDocumentSaveOCAF` / `OCCTDocumentLoadOCAF` | Shared driver race | Remove `ocafStoreMutex` |  |  | TSan race |

### #353: CDM_MetaData Race (Kernel Patch `0015`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Concurrent document operations | `OCCTDocumentCreate` / `OCCTDocumentLoadOCAF` | Race on `myMetaDataLookUpTable` | Remove CDM mutexes |  |  | TSan race + SIGABRT |

### #371: GetApplication Singleton (Bridge Fix)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Document creation uses private app | `OCCTDocumentCreate` → `new TDocStd_Application()` | Singleton race | Revert to `XCAFApp_Application::GetApplication()` |  |  | TSan race |

### #374: Resource_Manager / Storage_Schema Races (Kernel Patch `0016`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Concurrent format definition | `OCCTDocumentDefineFormat*` | Race on `Resource_Manager::Debug` | Remove atomic/mutex |  |  | TSan race |
| Concurrent Save/Load | `OCCTDocumentSaveOCAF` / `OCCTDocumentLoadOCAF` | Race on `Storage_Schema::ICurrentData()` | Remove mutex |  |  | TSan race |

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| XCAF Color Tests | 58 |  |  |  |  |
| XCAF Layer Tests | 48 |  |  |  |  |
| XCAF Assembly Tests | 42 |  |  |  |  |
| XCAF Document Save/Load | 40 |  |  |  |  |
| XCAF Material Tests | 38 |  |  |  |  |
| XCAF Shape Addition/Removal | 36 |  |  |  |  |
| ... | ... |  |  |  |  |

**Total**: 422 tests