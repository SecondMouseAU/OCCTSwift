# Epic #766: Retroactive Test Validity — Plan

**Tracking Issue**: #766 | **Branch**: `refactor/766-retroactive-test-validity` (sequential domains) | **OKF Location**: `okf/policies/prove-the-test-fails.md` + `okf/references/766-test-validity/`

---

## Background

**Issue**: #766 — "Phase: retroactive test validity, 5484 tests that were never proven to fail"

**Policy**: [`okf/policies/prove-the-test-fails.md`](../okf/policies/prove-the-test-fails.md) — Every test and every detector `--self-test` case must be run once with its subject broken: inject the defect, confirm failure, restore, confirm pass. Report both results.

**Current State**:
- Total test suite: ~5,484 `@Test` functions across 17 per-domain test targets
- **#764** (Closed): "Unmeasured values, test half" — adjudicated 73 pinned-count candidates from the census
- **#767** (Open): "Spike: is mutation coverage viable over this package, and what does it cost per target?" — **partially brought into scope**: mutation findings during this work generate #767 issues
- **#766** (This Epic): Explicitly deferred from v4.0.0; "further segmentation depends on the spike (#767) and explicitly declines to pre-file segments against an unknown method"

---

## Goal

Establish retroactive proof that all 5,484 tests (minus the 73 already done in #764) have been proven to fail per the policy. For each test:
1. Identify the defect it exists to catch
2. Inject that defect (in source or test fixture)
3. Run the test → confirm it fails (red)
4. Restore the fix → confirm it passes (green)
5. Document the injection matrix per test/domain

**Output**: Evidence stored in `okf/references/766-test-validity/` as markdown (per-domain matrices + dashboard)

---

## Constraints & Rules (from OKF Policies)

| Policy | Requirement |
|--------|-------------|
| `prove-the-test-fails.md` | Every test + `--self-test` case: inject defect → red → restore → green → report both |
| `context-first.md` | Never rely on training data for OCCT/OCCTSwift signatures. Look up via `context` MCP (`occt-refman@8.0.1`, `occt`, `occtswift`) first |
| `scope-boundary.md` | This is a **wrapper**. Stay faithful to OCCT. Extensions belong downstream (OCCTSwiftIO, OCCTSwiftMesh, etc.) |
| `measure-dont-assume.md` | Measure, don't derive. No inappropriately hardcoded variables. Verify with second construction |
| `upstream-occt-patch-process.md` | Kernel fixes preferred over bridge fixes. If kernel crash found: file upstream issue with reproducer, don't fix in bridge |
| `issue-tracking.md` | Every issue: `type:*` + `priority:*` labels. Multi-phase gets project board with Status workflow |

---

## Phased Approach (Sequential per Domain)

### Phase 0: Inventory & Categorization (Prerequisite)
**Objective**: Complete, queryable inventory of all 5,484 tests with metadata.

| Task | Description | Output |
|------|-------------|--------|
| 0.1 | Enumerate all `@Test` functions across 17 test targets | `okf/references/766-test-validity/inventory.json`: `target, suite, test, line, file` |
| 0.2 | Classify each test by **defect category** (what it catches) | Taxonomy: null-handle, OOB, timeout, wrong-result, crash, contract-violation, etc. |
| 0.3 | Identify tests with existing prove-the-test-fails evidence ("Prove-the-test-fails record" comments) | Subset marked "done" |
| 0.4 | Cross-reference with #764's 73 candidates | Updated inventory with "done" flags |
| 0.5 | Prioritize remaining by: (a) high-risk OCCT boundaries, (b) detector self-tests, (c) recent crash fixes | Ranked worklist per domain |

**Deliverable**: `okf/references/766-test-validity/inventory.json` + `taxonomy.md`

---

### Phase 1: High-Risk Boundary Tests (Gate Scripts & Crash Fixes)
**Objective**: Prove validity for tests guarding critical OCCT boundaries where a blind test = uncatchable SIGSEGV/SIGABRT.

**Targets** (from known OCCT bugs in CLAUDE.md + all crash-potential bridge functions):
- `check-null-handle-guards.py` — 36 entry points dereferencing `OCCTCurve3DRef`/`SurfaceRef` handles
- `check-borrowed-handles.py` — structs/enums storing `OCCT*Ref` without `deinit`
- Tests for fixed crashes: #341 (theAutoNaming), #344 (CDF_Directory), #345 (gp_Dir), #349 (OCAF driver), #353 (CDM_MetaData), #371 (GetApplication), #374 (Resource_Manager), #430 (BRepFill_Filling), #522 (AdvApp2Var), #532 (cylindrical hole), #597 (GeomFill_Sweep), #603 (CPnts_AbscissaPoint), #643 (GeomTools null), #905/913 (ThruSections)
- **All bridge functions that could crash** — if injection triggers kernel crash: file upstream issue with reproducer, **do not attempt bridge fix**, note existing TSan issues waiting

**Method**: For each test in these areas:
1. Locate the bridge function(s) it exercises
2. Inject the specific defect (remove null guard, remove try/catch, remove mutex, etc.)
3. Run test → confirm failure
4. Restore → confirm pass
5. Record in injection matrix
6. **If kernel crash**: file upstream issue with reproducer; prefer kernel fix over bridge mitigation

**Deliverable**: `okf/references/766-test-validity/phase1-<domain>.md` (per-domain matrices)

---

### Phase 2: Detector Self-Tests (Gate/Census Scripts)
**Objective**: Prove all `--self-test` cases in gate/census scripts actually catch their failure modes.

**Scripts** (9 scripts with `--self-test`):
| Script | Self-Test Cases | Status |
|--------|-----------------|--------|
| `check-bridge-index.py` | `--self-test` | Need proof |
| `check-null-handle-guards.py` | `--self-test` | Need proof |
| `check-docs-defaults.py` | `--self-test` | Need proof |
| `check-docs-existence.py` | `--self-test` | Need proof |
| `check-borrowed-handles.py` | `--self-test` | Need proof |
| `derive-bridge-header-split.py` | `--self-test` | Need proof |
| `count-operations.py` | (none) | N/A |
| `census-unmeasured-values.py` | `--self-test` | Need proof |
| `census-doc-occt-attribution.py` | `--self-test` | Need proof |
| `check-changelog-transcription.py` | `--self-test` | Need proof |

**Method**: Per `prove-the-test-fails.md` §How to Apply:
- For each `--self-test` case: remove the guard it exercises, run `--self-test`, confirm case count drops, restore
- If removing a guard leaves count unchanged → case is decorative → rewrite
- **State per row which mechanism it isolates and how you know** (disjointness evidence)

**Deliverable**: `okf/references/766-test-validity/phase2-<script>.md`

---

### Phase 3: Domain Test Targets (Sequential Sweep)
**Objective**: Prove validity for remaining ~5,300 tests across 17 domains. **Work sequentially, one domain at a time.**

**Domain Order** (by risk/complexity):
1. `OCCTStressTests` — concurrency, TSan, crash reproduction
2. `OCCTModelingTests` — boolean ops, fillets, holes (most OCCT surface)
3. `OCCTShapeHealingTests` — fix/heal operations, degenerate geometry
4. `OCCTSurfaceTests` — geometry evaluation
5. `OCCTCurveTests` — 3D curves
6. `OCCTGeom2dTests` — 2D geometry
7. `OCCTIOTests` — STEP/IGES/OCAF round-trips
8. `OCCTXCAFTests` — XCAF document operations
9. `OCCTDrawingTests` — 2D drawing/projection
10. `OCCTAnalysisTests` — shape analysis
11. `OCCTMathTests` — math/geometry primitives
12. `OCCTMeshTests` — meshing
13. `OCCTBRepGraphTests` — topology graph
14. `OCCTTopologyTests` — topology traversal
15. `OCCTFoundationTests` — core types
16. `OCCTIntegrationTests` — cross-domain
17. `OCCTMiscTests` — miscellaneous
18. `OCCTThreadTests` — thread safety

**Per-Domain Workflow** (sequential, review after each):
```bash
# 1. Focused compile (3s)
swift build --target OCCT<Domain>Tests

# 2. For each test file in domain:
#    a. Identify defect each @Test catches (use context-first: occt-refman for OCCT signatures)
#    b. Create injection (source change or fixture swap) — no inappropriately hardcoded variables
#    c. Run single test: swift test --filter <TestStructName>
#    d. Confirm FAIL, restore, confirm PASS
#    e. Record in domain matrix (markdown table: Test | Defect | Injection | Red? | Green? | Notes)
#    f. If kernel crash → file upstream issue with reproducer (link to #766), don't fix in bridge
#    g. If mutation testing reveals issues → file #767 issue, can PR for review but DON'T MERGE

# 3. Create PR for domain
# 4. User reviews PR → merge what makes sense
# 5. Proceed to next domain
```

**Mutation Testing (#767 partial scope)**:
- Run mutation testing on domain after manual injections complete
- If mutations reveal missing test coverage → file issue under #767 with `type:mutation` `priority:medium`
- Can create PR for review but **do not merge** — user decides

**Deliverable**: `okf/references/766-test-validity/phase3-<domain>.md` per domain

---

### Phase 4: Consolidation & Gate Integration
**Objective**: Make prove-the-test-fails evidence a CI gate.

**Tasks**:
1. Aggregate all injection matrices into dashboard (`okf/references/766-test-validity/dashboard.md`)
2. Add gate script `Scripts/check-test-validity.py` that:
   - Verifies every `@Test` has a linked injection record
   - Runs a sample of injections on CI (time-boxed)
   - Fails if coverage drops below threshold
3. Update `prove-the-test-fails.md` with tooling guidance
4. Document in `CLAUDE.md` → Test Conventions

**Deliverable**: `Scripts/check-test-validity.py` + CI integration + updated policies

---

## Sequential Execution Protocol

**Critical**: Work **one domain at a time**. After each domain:
1. Create PR with domain's injection matrices
2. User reviews PR
3. Merge what makes sense
4. **Only then proceed to next domain**

This prevents treading over new ground and ensures each domain's evidence is solid before moving on.

---

## Tooling Requirements

### New Scripts Needed
1. `Scripts/enumerate-tests.py` — extracts all `@Test` functions with metadata (uses SwiftSyntax or regex)
2. `Scripts/check-test-validity.py` — gate script for Phase 4
3. Injection harness — helper to apply/remove injections cleanly (per-domain)

### Existing Infrastructure to Leverage
- `Scripts/repro/<issue>/` pattern — each injection gets a repro directory
- `swift test --filter <StructName>` — focused test runs
- `swift build --target OCCT<Domain>Tests` — focused compile
- Git worktrees — sequential domain work without conflicts
- `context` MCP — `occt-refman@8.0.1` for OCCT signatures (context-first policy)
- Ground truth C++ tests: compile against `Libraries/OCCT.xcframework` headers when needed

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Tests with prove-the-test-fails evidence | 100% (5,484 / 5,484) |
| Gate script self-tests with removal matrices | 100% (9/9 scripts) |
| High-risk boundary tests proven | 100% (per taxonomy) |
| Injection matrices documented | All phases (markdown in `okf/references/766-test-validity/`) |
| `check-test-validity.py` gate passes | On main branch |
| Kernel crashes found | Filed upstream with reproducers (linked to #766) |
| Mutation findings | Filed as #767 issues (PRs for review, not merged) |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Injection breaks unrelated tests | Focused `swift test --filter`; isolate via worktrees |
| Flaky tests mask injection failures | Run each injection 3×; require consistent fail/pass |
| 5,300 tests too many for manual effort | Phase 3 adopts mutation testing if #767 viable; batch by defect category |
| Gate script self-tests already proven | Phase 2 audit confirms; mark complete |
| v4.0.0 release pressure | Epic explicitly deferred — no release gate conflict |
| Inappropriately hardcoded variables | `measure-dont-assume.md`: measure via API, not derive from params/docs |
| Wrong OCCT signatures | `context-first.md`: query `occt-refman@8.0.1` before coding |
| Bridge fix for kernel bug | `upstream-occt-patch-process.md`: file upstream, prefer kernel fix |

---

## File Structure (OKF References)

```
okf/references/766-test-validity/
├── inventory.json              # Phase 0 output
├── taxonomy.md                 # Defect category taxonomy
├── dashboard.md                # Aggregated view for Phase 4
├── phase1-null-handle-guards.md
├── phase1-borrowed-handles.md
├── phase1-crash-fixes.md       # #341, #344, #345, #349, #353, #371, #374, #430, #522, #532, #597, #603, #643, #905, #913
├── phase2-check-bridge-index.md
├── phase2-check-null-handle-guards.md
├── phase2-check-docs-defaults.md
├── phase2-check-docs-existence.md
├── phase2-check-borrowed-handles.md
├── phase2-derive-bridge-header-split.md
├── phase2-census-unmeasured-values.md
├── phase2-census-doc-occt-attribution.md
├── phase2-check-changelog-transcription.md
├── phase3-OCCTStressTests.md
├── phase3-OCCTModelingTests.md
├── phase3-OCCTShapeHealingTests.md
├── phase3-OCCTSurfaceTests.md
├── phase3-OCCTCurveTests.md
├── phase3-OCCTGeom2dTests.md
├── phase3-OCCTIOTests.md
├── phase3-OCCTXCAFTests.md
├── phase3-OCCTDrawingTests.md
├── phase3-OCCTAnalysisTests.md
├── phase3-OCCTMathTests.md
├── phase3-OCCTMeshTests.md
├── phase3-OCCTBRepGraphTests.md
├── phase3-OCCTTopologyTests.md
├── phase3-OCCTFoundationTests.md
├── phase3-OCCTIntegrationTests.md
├── phase3-OCCTMiscTests.md
└── phase3-OCCTThreadTests.md
```

---

## Next Steps

1. **Create worktree** `refactor/766-retroactive-test-validity` from `main` ✓
2. **Write plan file** to `.kilo/plans/` ✓
3. **Execute Phase 0** — inventory script + categorization