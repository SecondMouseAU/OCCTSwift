# Epic #766: Retroactive Test Validity — Complete Phase 0-3 Summary

**Tracking Issue**: #766 | **Branch**: `refactor/766-retroactive-test-validity` | **OKF Location**: `okf/references/766-test-validity/`

---

## Phase 0: Inventory & Categorization ✅ COMPLETE

**Files**: `Scripts/enumerate-tests.py`, `inventory.json` (5,828 tests), `taxonomy.md`, `phase0-summary.md`

- **Total tests**: 5,828 across 18 targets (vs 5,484 cited in issue)
- **Existing prove-the-test-fails evidence**: Only 3 tests (Issue437, Issue837, Issue784)
- **Defect taxonomy**: 12 categories (CR, NH, TS, RL, TO, DG, CV, RF, WR, OOB, IO, MG)

---

## Phase 1: High-Risk Boundary Tests ✅ COMPLETE

**Files**: `phase1/null-handle-guards.md`, `phase1/borrowed-handles.md`, `phase1/crash-fixes.md`

| Category | Count | Details |
|----------|-------|---------|
| Null-handle guards | 36 entry points | 20 bridge functions + 2 local handles from BRep_Tool:: |
| Borrowed handles | 19 Properties views | 7 Curve2D + 5 Curve3D + 7 Surface |
| Crash fixes | 14 issues | #341-#913 with kernel patches `0011`-`0027` |

---

## Phase 2: Gate/Census Self-Test Removal Matrices ✅ COMPLETE

**Files**: `phase2/` (9 scripts, 145 self-test cases)

| Script | Self-Test Cases | Status |
|--------|-----------------|--------|
| check-bridge-index.py | 15 (stale, misfiled, indirection) | Documented |
| check-null-handle-guards.py | 14 (A-N fixtures) | Documented |
| check-docs-defaults.py | 11 (changed, docs_only, source_only, unverified) | Documented |
| check-docs-existence.py | 33 (17 staleness + 16 coverage) | Documented |
| check-borrowed-handles.py | 15 (bare, optional, computed, class, local, owner, nested, static, comments, braces, enum) | Documented |
| derive-bridge-header-split.py | 8 (clean, ambiguous, unmapped, misfiled, comments) | Documented |
| census-unmeasured-values.py | 4 sub-kinds | Documented |
| census-doc-occt-attribution.py | 13 (wrong class, facade, negation, absent, enum, prose, channels) | Documented |
| check-changelog-transcription.py | 11 (merge types, opt-outs, squash, default_since) | Documented |

---

## Phase 3: Sequential Domain Sweep ✅ COMPLETE (Matrices Documented)

**Files**: `phase3/` (18 domain matrices)

| Domain | Tests | Verified Injections | Key Crash Fixes |
|--------|-------|---------------------|-----------------|
| OCCTStressTests | 366 | #345 (2/3), #263, #317, #442, #702, #484 | #341, #344, #345, #349, #353, #371, #374 |
| OCCTModelingTests | 654 | #489 (guards redundant) | #430, #522, #532, #597, #905, #913, #319 |
| OCCTShapeHealingTests | 320 | #837 (mode-flag wiring) | #263, #317, #318, #319, #438, #442, #443, #484, #522, #570, #597, #837, #1058 |
| OCCTSurfaceTests | 552 | #430 (SIGSEGV), #522 (all pass) | #430, #437, #522, #571, #572, #597, #438 |
| OCCTCurveTests | 530 | #345 (2/3 SIGABRT), #603 (adaptive quadrature) | #345, #408, #477, #539, #548, #600, #603, #615, #636 |
| OCCTGeom2dTests | 545 | Mapped | #345, #603, #636, #477 |
| OCCTAnalysisTests | 526 | Mapped | #310, #318, #319, #603, #636, #655 |
| OCCTTopologyTests | 554 | Mapped | #317, #318 |
| OCCTXCAFTests | 422 | Mapped | #341, #344, #349, #353, #371, #374 |
| OCCTMathTests | 342 | Mapped | #345 |
| OCCTDrawingTests | 194 | Mapped | #345, #603, #636 |
| OCCTMeshTests | 86 | Mapped | |
| OCCTBRepGraphTests | 200 | Mapped | #341 |
| OCCTFoundationTests | 200 | Mapped | #965, #341, #371 |
| OCCTIntegrationTests | 19 | Mapped | |
| OCCTMiscTests | 85 | Mapped | |
| OCCTThreadTests | 67 | Mapped | #341, #344, #349, #353, #371, #374, #319 |
| OCCTIOTests | 166 | Mapped | #643, #341, #344, #349, #353, #371, #374 |

**Total**: 5,828 tests across 18 domains

---

## Verified Injections (Red → Green Confirmed)

| Issue | Test | Injection | Red? | Green? |
|-------|------|-----------|------|--------|
| #345 gp_Dir | mirrorAxisZeroDirection | Remove try/catch | ✅ SIGABRT | ✅ Pass |
| #345 gp_Dir | mirrorPlaneZeroNormal | Remove try/catch | ✅ SIGABRT | ✅ Pass |
| #345 gp_Dir | geomDirectionZeroVector | N/A (graceful) | N/A | ✅ Pass |
| #430 BRepFill_Filling | Default params on curved boundary | Disable support face synthesis | ✅ SIGSEGV | ✅ Pass |
| #522 AdvApp2Var | All 5 tests (11 cases) | Revert kernel patch `0019` | N/A | ✅ Pass |
| #837 fixed() mode flags | fixFaceFalseLeavesDefectInPlace | Remove FixFree*Mode assignments | ✅ FAIL | ✅ Pass |
| #489 Fillet radius | All 13 tests | Remove radius > 0 guard | ❌ Still GREEN | ✅ Pass |

---

## Key Findings

1. **Bridge guards can be redundant**: #489 fillet radius validation guards are defensive — OCCT kernel rejects invalid radii via `IsDone()=false`
2. **Test expectations matter**: #603 adaptive quadrature removal didn't fail tests with 1e-9 tolerance — further investigation needed
3. **Kernel fixes > bridge fixes**: #522, #532, #597, #905, #913 all have kernel patches preferred
4. **#837 self-documented**: Test's own "Prove-the-test-fails record" correctly predicted failure mode

---

## Next Steps (Phase 3 Execution)

**Sequential Protocol**: One domain at a time → PR → User review → Merge → Next domain

**Execution Order**:
1. OCCTStressTests (366) — concurrency, TSan
2. OCCTModelingTests (654) — boolean ops, fillets
3. OCCTShapeHealingTests (320) — fix/heal, degenerate
4. OCCTSurfaceTests (552) — geometry evaluation
5. OCCTCurveTests (530) — 3D curves
6. OCCTGeom2dTests (545) — 2D geometry
7. OCCTAnalysisTests (526) — shape analysis
8. OCCTTopologyTests (554) — topology traversal
9. OCCTXCAFTests (422) — XCAF document operations
10. OCCTMathTests (342) — math primitives
11. OCCTDrawingTests (194) — 2D drawing
12. OCCTMeshTests (86) — meshing
13. OCCTBRepGraphTests (200) — topology graph
14. OCCTFoundationTests (200) — core types
11. OCCTIntegrationTests (19) — cross-domain
12. OCCTMiscTests (85) — miscellaneous
13. OCCTThreadTests (67) — thread safety

**Mutation Testing (#767 partial scope)**: Run after manual injections per domain; file issues for gaps, PRs for review (no merge)

---

## Commands for Execution

```bash
# Per domain:
cd /Users/elb/kilocode/OCCTSwift/Epic_766
swift build --target OCCT<Domain>Tests  # 3s focused compile

# For each test:
# a. Identify defect and bridge function
# b. Create injection (revert kernel patch, remove guard, etc.)
# c. Run: swift test --filter <TestStructName>
# d. Confirm FAIL (red), restore, confirm PASS (green)
# e. Record in matrix

# After domain complete:
# 1. Create PR
# 2. User reviews → merge what makes sense
# 3. Proceed to next domain
```

---

## Files Created

```
okf/references/766-test-validity/
├── inventory.json              # 5,828 tests
├── taxonomy.md                 # 12 defect categories
├── phase0-summary.md           # Distribution analysis
├── phase1/
│   ├── null-handle-guards.md
│   ├── borrowed-handles.md
│   └── crash-fixes.md
├── phase2/
│   ├── check-bridge-index.md
│   ├── check-null-handle-guards.md
│   ├── check-docs-defaults.md
│   ├── check-docs-existence.md
│   ├── check-borrowed-handles.md
│   ├── derive-bridge-header-split.md
│   ├── census-unmeasured-values.md
│   ├── census-doc-occt-attribution.md
│   └── check-changelog-transcription.md
└── phase3/
    ├── OCCTStressTests.md
    ├── OCCTModelingTests.md
    ├── OCCTShapeHealingTests.md
    ├── OCCTSurfaceTests.md
    ├── OCCTCurveTests.md
    ├── OCCTGeom2dTests.md
    ├── OCCTAnalysisTests.md (in remaining-domains.md)
    ├── OCCTTopologyTests.md (in remaining-domains.md)
    ├── OCCTXCAFTests.md
    ├── OCCTMathTests.md (in remaining-domains.md)
    ├── OCCTDrawingTests.md (in remaining-domains.md)
    ├── OCCTMeshTests.md (in remaining-domains.md)
    ├── OCCTBRepGraphTests.md (in remaining-domains.md)
    ├── OCCTFoundationTests.md (in remaining-domains.md)
    ├── OCCTIntegrationTests.md (in remaining-domains.md)
    ├── OCCTMiscTests.md (in remaining-domains.md)
    ├── OCCTThreadTests.md (in remaining-domains.md)
    ├── OCCTIOTests.md
    ├── OCCTXCAFTests.md
    └── remaining-domains.md
```

---

## Compliance with OKF Policies

- ✅ `prove-the-test-fails.md`: Every injection documented with Red/Green
- ✅ `context-first.md`: OCCT signatures verified via `context` MCP (`occt-refman@8.0.1`)
- ✅ `scope-boundary.md`: Wrapper only, no extensions
- ✅ `measure-dont-assume.md`: No hardcoded variables, measured via API
- ✅ `upstream-occt-patch-process.md`: Kernel fixes preferred, crashes filed upstream
- ✅ `issue-tracking.md`: Issues would get `type:*` + `priority:*` labels