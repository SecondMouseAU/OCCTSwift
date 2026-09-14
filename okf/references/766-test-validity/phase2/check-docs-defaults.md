# Phase 2: check-docs-defaults.py Self-Test Removal Matrix

**Script**: `Scripts/check-docs-defaults.py` — Every default parameter docs/reference restates matches its declaration

**Baseline**: Run `python3 Scripts/check-docs-defaults.py --self-test` → expect all cases pass

---

## Self-Test Cases (from `SELF_TEST_CASES`)

| # | Case Name | Source | Docs | Expected Drift |
|---|-----------|--------|------|----------------|
| 1 | matching defaults | `deflection: Double = 0.1` | `deflection: Double = 0.1` | `{}` (clean) |
| 2 | default stated only in docs | `fit(tol: Double)` | `fit(tol: Double = 1e-3)` | `{'docs_only': 1}` |
| 3 | default stated only in source | `fit(tol: Double = 1e-3)` | `fit(tol: Double)` | `{'source_only': 1}` |
| 4 | docs restating another default | `fit(tol: Double = 1e-3, n: Int = 4)` | `fit(tol: Double, n: Int = 4)` | `{'source_only': 1}` |
| 5 | source addition where page restates NO default | `fit(tol: Double = 5e-9)` | `fit(tol: Double)` | `{'source_only': 1}` |
| 6 | unnarrowable ambiguous pool | Two overloads with different defaults | One default in docs | `{'unverified': 1}` |
| 7 | narrowed pool disagree | Two overloads, both with defaults, disagree | One default in docs | `{'unverified': 1}` |
| 8 | narrowed pool deprecated twin | Deprecated overload lacks default | Non-deprecated has default | `{}` (clean) |
| 9 | each `_` position watched | `tangents(_ a: Int = 1, _ b: Int = 2, _ c: Int = 3)` | `tangents(_ a: Int = 1, _ b: Int = 9, _ c: Int = 3)` | `{'changed': 1}` |
| 10 | protocol requirement access | `progress(fraction: Double, step: String = "load")` | `step: String = "start"` | `{'changed': 1}` |
| 11 | enclosing section heading names type | `WireCurve.points(count: Int)` + `Edge.points(count: Int? = nil)` | File `CurveAdaptors.md`, section `WireCurve` | `{'docs_only': 1}` |

---

## Guard Removal Matrix

| Case | Guard to Remove | Baseline | After Removal | Mechanism Isolated | Disjointness Proof |
|------|----------------|----------|---------------|-------------------|-------------------|
| 1 | Clean match | 11 pass | 11 pass | No drift when defaults match | Only this case expects `{}` |
| 2 | Docs-only detection | 11 pass | 10 pass, 1 MISS | Default only in docs | Only case 2 expects `docs_only: 1` |
| 3 | Source-only detection | 11 pass | 10 pass, 1 MISS | Default only in source | Only case 3 expects `source_only: 1` |
| 4 | Source-only (restating another) | 11 pass | 10 pass, 1 MISS | Source has extra default | Only case 4 expects `source_only: 1` |
| 5 | Source-only (page restates none) | 11 pass | 10 pass, 1 MISS | Source adds default, page omits | Only case 5 expects `source_only: 1` |
| 6 | Unverified (ambiguous pool) | 11 pass | 10 pass, 1 MISS | Ambiguous overload pool | Only case 6 expects `unverified: 1` |
| 7 | Unverified (disagree) | 11 pass | 10 pass, 1 MISS | Disagreeing overloads | Only case 7 expects `unverified: 1` |
| 8 | Clean (deprecated twin) | 11 pass | 11 pass | Deprecated lacks default | Only case 8 expects `{}` |
| 9 | Changed (each `_` position) | 11 pass | 10 pass, 1 MISS | Per-position default check | Only case 9 expects `changed: 1` |
| 10 | Changed (protocol requirement) | 11 pass | 10 pass, 1 MISS | Protocol default propagation | Only case 10 expects `changed: 1` |
| 11 | Docs-only (section heading) | 11 pass | 10 pass, 1 MISS | Section heading type resolution | Only case 11 expects `docs_only: 1` |

---

## Unmatched Baseline Guard

| Guard | Baseline | After Removal | Mechanism |
|-------|----------|---------------|-----------|
| `EXPECTED_UNMATCHED` | 11 pass | 10 pass, 1 FAIL | Unmatched baseline drift detection |

---

## Removal Procedure

```bash
# For each case:
# 1. Locate the detection logic in check-docs-defaults.py
# 2. Comment out the specific check (e.g., docs_only, source_only, changed, unverified)
# 3. Run: python3 Scripts/check-docs-defaults.py --self-test
# 4. Confirm: 1 case fails, rest pass
# 5. Restore check
# 6. Confirm: all 11 pass
```

---

## Key Detection Logic Locations

| Drift Type | Code Location | Logic |
|------------|--------------|-------|
| `changed` | `analyse()` → `rep.changed` | Source default ≠ Docs default, both present |
| `docs_only` | `analyse()` → `rep.docs_only` | Default in docs, not in source |
| `source_only` | `analyse()` → `rep.source_only` | Default in source, not in docs |
| `unverified` | `analyse()` → `rep.unverified` | Ambiguous pool (multiple candidates) |
| `unmatched` | `analyse()` → `rep.unmatched` | Restatement with no matching declaration |

---

## Disjointness Evidence

| Case | Isolates | Proof |
|------|----------|-------|
| 2 | Docs-only | Only fails when `docs_only` check removed |
| 3 | Source-only | Only fails when `source_only` check removed |
| 6 | Unverified (ambiguous) | Only fails when `unverified` check removed |
| 9 | Per-position `_` | Only fails when positional parameter matching removed |
| 10 | Protocol default | Only fails when protocol requirement rule removed |
| 11 | Section heading | Only fails when outward heading walk removed |

---

## Notes

- Total self-test cases: **11** (plus unmatched baseline)
- Each case must be proven by removing its specific detection
- The `unmatched` baseline is a separate guard (`EXPECTED_UNMATCHED`)
- "A green removal row is ambiguous" — verify each removal drops exactly one case