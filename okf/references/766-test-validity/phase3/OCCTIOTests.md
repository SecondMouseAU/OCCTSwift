# Phase 3: OCCTIOTests Injection Matrix

**Target**: `OCCTIOTests` (166 tests) — STEP/IGES/OCAF round-trips
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🔴 Critical (null handles #643, crash fixes #341, #344, #349, #353, #371, #374)

---

## Test Inventory by Suite

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| STEP Round-Trip Tests | 42 | IO/CR |
| IGES Round-Trip Tests | 38 | IO/CR |
| OCAF Round-Trip Tests | 32 | IO/CR (#341, #344, #349, #353, #371, #374) |
| BREP Round-Trip Tests | 24 | IO |
| STL/OBJ/GLTF Round-Trip Tests | 18 | IO |
| GeomTools Null Handle Tests (#643) | 12 | CR (#643) |

**Total**: 166 tests across ~8 suites

---

## Injection Matrix: Critical Crash-Related Tests First

### #643: GeomTools Null Handle Write (Kernel Patch `0023`)

**Issue**: `GeomTools_Curve2dSet::Add` / `GeomTools_SurfaceSet::Add` accept null handle, crash on `Write()`.

**Kernel Patch**: `0023` — guard `Add()` with `IsNull()` check.

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| GeomTools_Curve2dSet::Write with null handle | `OCCTGeomToolsCurve2dSetWrite` | Null handle accepted | Remove null guard |  |  | SIGSEGV on Write |
| GeomTools_SurfaceSet::Write with null handle | `OCCTGeomToolsSurfaceSetWrite` | Null handle accepted | Remove null guard |  |  | SIGSEGV on Write |
| GeomTools_CurveSet::Write with null handle | `OCCTGeomToolsCurveSetWrite` | Already guarded | Control |  |  | Should pass |

### #341/#344/#349/#353/#371/#374: OCAF Round-Trip Crashes (TSan)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Concurrent STEP read/write | `OCCTDocumentLoadSTEP` / `OCCTDocumentSaveSTEP` | TSan races | Remove mutexes/atomics |  |  | TSan race |
| Concurrent OCAF save/load | `OCCTDocumentSaveOCAF` / `OCCTDocumentLoadOCAF` | TSan races | Remove ocafStoreMutex |  |  | TSan race |
| Document with CDM metadata | `OCCTDocumentCreate` → CDM | TSan races | Remove CDM mutex |  |  | TSan race |

---

## Injection Matrix: Null-Handle Guards (IO Entry Points)

From `check-null-handle-guards.py` ALLOWED table - 2 IO entry points need null guards.

| Bridge Function | OCCT Call | Test Coverage | Injection Status |
|-----------------|-----------|---------------|------------------|
| `OCCTGeomToolsCurve2dSetWrite` | `GeomTools_Curve2dSet::Write` | IOTests | |
| `OCCTGeomToolsSurfaceSetWrite` | `GeomTools_SurfaceSet::Write` | IOTests | |

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| STEP Round-Trip Tests | 42 |  |  |  |  |
| IGES Round-Trip Tests | 38 |  |  |  |  |
| OCAF Round-Trip Tests | 32 |  |  |  |  |
| BREP Round-Trip Tests | 24 |  |  |  |  |
| STL/OBJ/GLTF Round-Trip Tests | 18 |  |  |  |  |
| GeomTools Null Handle Tests (#643) | 12 |  |  |  |  |

**Total**: 166 tests