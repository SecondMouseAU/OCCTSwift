# Phase 2: Gate/Census Script Self-Test Removal Matrices

**Policy**: `prove-the-test-fails.md` — For each `--self-test` case: remove the guard it exercises, run `--self-test`, confirm case count drops, restore. State per row which mechanism it isolates.

---

## Scripts with `--self-test` (9 total)

| Script | Purpose | Self-Test Cases |
|--------|---------|-----------------|
| `check-bridge-index.py` | OCCTBridge.h class → symbol index | 3 categories: stale, misfiled, indirection |
| `check-null-handle-guards.py` | Null handle guards on bridge functions | 10 fixtures: wrapper, cast, alias, helper, local, extern, DownCast, ALLOWED, constructor-init |
| `check-docs-defaults.py` | Swift default parameter docs match declarations | 12 cases: changed, docs_only, source_only, unverified, unmatched |
| `check-docs-existence.py` | Every documented symbol exists in Sources | 16+ cases: stale, historical, clean, coverage |
| `check-borrowed-handles.py` | No struct/enum stores OCCT*Ref without deinit | 16 cases: bare handle, optional, computed, class, local, owner, nested, static, comments, braces, enum |
| `derive-bridge-header-split.py` | Every declaration in correct domain header | 8 cases: clean, ambiguous, unmapped, misfiled, comments |
| `census-unmeasured-values.py` | Values returned as measurements never computed | 4 sub-kinds: production, test, gate, subject/echo |
| `census-doc-occt-attribution.py` | Doc attributions match bridge function reach | 13 cases: wrong class, facade, negation, absent, enum, prose, unresolvable, channels |
| `check-changelog-transcription.py` | Merges have CHANGELOG entries | 10+ cases: merge types, opt-outs, squash, default_since |

---

## Removal Matrix Template per Script

For each script, create a matrix:

| Self-Test Case | Guard/Mechanism Removed | Cases Before | Cases After | Isolated Mechanism | How Verified |
|----------------|------------------------|--------------|-------------|-------------------|--------------|
| Case name | Code change | N | N-1 (or 0) | What it proves | Disjointness evidence |

---

## Next Steps

1. For each script, run `--self-test` to get baseline case count
2. For each self-test case, identify the guard/mechanism it exercises
3. Remove that guard, run `--self-test`, confirm count drops
4. Restore, confirm count returns
5. Document in markdown matrix

**Location**: `okf/references/766-test-validity/phase2/`