# Phase 2: census-unmeasured-values.py Self-Test Removal Matrix

**Script**: `Scripts/census-unmeasured-values.py` — Values returned as measurements that were never computed

**Baseline**: Run `python3 Scripts/census-unmeasured-values.py --self-test` → expect all cases pass

---

## Self-Test Cases (from `self_test()` - 4 sub-kinds)

### Sub-kind 1: Production literal-vs-computed sibling

| # | Case | Source Pattern | Expected |
|---|------|----------------|----------|
| 1-? | PROD_MISSED | Literal used where computation expected | Flagged |
| ? | PROD_CLEAN | Actual computation | Clean |

### Sub-kind 2: Test pinned count with no fixture verification

| # | Case | Test Pattern | Expected |
|---|------|--------------|----------|
| ? | TEST_MISSED | `#expect(count == N)` without fixture verification | Flagged |
| ? | TEST_CLEAN | Fixture verified | Clean |

### Sub-kind 3: Gate flags that never flip

| # | Case | Gate Pattern | Expected |
|---|------|--------------|----------|
| ? | GATE_MISSED | Flag never changes outcome | Flagged |
| ? | GATE_CLEAN | Flag actually used | Clean |
| ? | SWIFT_GATE_MISSED | Swift gate flag never flips | Flagged |
| ? | SWIFT_GATE_CLEAN | Swift flag actually used | Clean |

### Sub-kind 4: Subjects caller never fed + echoed inputs

| # | Case | Pattern | Expected |
|---|------|---------|----------|
| ? | SUBJECT_MISSED | Subject parameter never provided by caller | Flagged |
| ? | SUBJECT_CLEAN | Subject actually used | Clean |
| ? | ECHO_MISSED | Echoed input returned as-is | Flagged |
| ? | ECHO_CLEAN | Input actually processed | Clean |

---

## Guard Removal Matrix (Template)

| Sub-kind | Case | Guard to Remove | Baseline | After Removal | Mechanism |
|----------|------|----------------|----------|---------------|-----------|
| 1 (Production) | PROD_MISSED | Literal detection | All pass | 1 MISS | Literal RHS detection |
| 1 (Production) | PROD_CLEAN | Computation check | All pass | 1 MISS | Computation RHS detection |
| 2 (Test) | TEST_MISSED | Pinned count without fixture | All pass | 1 MISS | Fixture verification check |
| 2 (Test) | TEST_CLEAN | Fixture verification | All pass | 1 MISS | Fixture check |
| 3 (Gate) | GATE_MISSED | Flag never flips | All pass | 1 MISS | Flag flip detection |
| 3 (Gate) | GATE_CLEAN | Flag actually flips | All pass | 1 MISS | Flag usage |
| 3 (Gate) | SWIFT_GATE_MISSED | Swift flag never flips | All pass | 1 MISS | Swift flag flip |
| 3 (Gate) | SWIFT_GATE_CLEAN | Swift flag flips | All pass | 1 MISS | Swift flag usage |
| 4 (Subject) | SUBJECT_MISSED | Subject never provided | All pass | 1 MISS | Subject parameter check |
| 4 (Subject) | SUBJECT_CLEAN | Subject provided | All pass | 1 MISS | Subject usage |
| 4 (Echo) | ECHO_MISSED | Echoed input | All pass | 1 MISS | Echo detection |
| 4 (Echo) | ECHO_CLEAN | Input processed | All pass | 1 MISS | Processing check |

---

## Key Guards to Remove

| Sub-kind | Guard | Code Location |
|----------|-------|---------------|
| 1 (Production) | `echoed_input_candidates()` / `production_candidates()` | Bridge C++ RHS analysis |
| 2 (Test) | `test_candidates()` | Swift test pinned count check |
| 3 (Gate) | `gate_candidates()` / `swift_gate_candidates()` | Flag flip detection |
| 4 (Subject) | `subject_candidates()` / `echoed_input_candidates()` | Subject parameter / echo detection |

---

## Removal Procedure

```bash
# For each case:
# 1. Locate the specific detection in census-unmeasured-values.py
# 2. Comment out the check (e.g., literal detection, flag flip check, subject check)
# 3. Run: python3 Scripts/census-unmeasured-values.py --self-test
# 4. Confirm: 1 case fails, rest pass
# 5. Restore check
# 6. Confirm: all pass
```

---

## Disjointness Evidence

| Sub-kind | Case | Isolates | Proof |
|----------|------|----------|-------|
| 1 | Literal RHS | Only fails when literal pattern check removed |
| 1 | Computation RHS | Only fails when computation pattern check removed |
| 2 | Pinned count | Only fails when fixture verification check removed |
| 2 | Fixture verified | Only fails when fixture check removed |
| 3 | Gate flag flip | Only fails when flag flip check removed |
| 3 | Swift gate flag | Only fails when Swift flag check removed |
| 4 | Subject never fed | Only fails when subject parameter check removed |
| 4 | Echo detection | Only fails when echo pattern check removed |

---

## Notes

- Total cases: Sum of all PROD_MISSED, PROD_CLEAN, TEST_MISSED, TEST_CLEAN, GATE_MISSED, GATE_CLEAN, SWIFT_GATE_MISSED, SWIFT_GATE_CLEAN, SUBJECT_MISSED, SUBJECT_CLEAN, ECHO_MISSED, ECHO_CLEAN
- Each sub-kind has paired MISSED/CLEAN cases — removing a guard should fail exactly one of each pair
- "A green removal row is ambiguous" — verify each removal drops exactly the expected case
- This is a CENSUS, not a gate — exit 0 in report mode, but --self-test exits 1 on failure