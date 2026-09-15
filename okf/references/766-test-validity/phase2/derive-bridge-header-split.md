# Phase 2: derive-bridge-header-split.py Self-Test Removal Matrix

**Script**: `Scripts/derive-bridge-header-split.py` — Every declaration sits in the header its .mm owns

**Baseline**: Run `python3 Scripts/derive-bridge-header-split.py --self-test` → expect all cases pass

---

## Self-Test Cases (from `SELF_TEST`)

| # | Case Name | Fixture | Mechanism Exercised |
|---|-----------|---------|---------------------|
| 1 | clean split: nothing flagged | 1 .mm → 1 .h | Basic mapping |
| 2 | ambiguous: two .mm define same symbol | 2 .mm → 1 .h | Ambiguity detection |
| 3 | unmapped: header declares symbol no .mm defines | 1 .mm (empty) → 1 .h | Unmapped detection |
| 4 | misfiled: declared in B.h, defined in A.mm (#673) | A.mm defines, B.h declares | Misfiled detection |
| 5 | line-comment mention not misfile (#673) | B.h has `//` comment | Comment exclusion |
| 6 | block-comment mention not misfile (#673) | B.h has `/* */` comment | Block comment exclusion |
| 7 | symbol only in header comment not declared (#673) | B.h has `// index: ...` | Comment not declaration |
| 8 | symbol only in .mm comment not second definer (#673) | B.mm has `/* */` comment | .mm comment not definition |

---

## Guard Removal Matrix

| Case | Guard to Remove | Baseline | After Removal | Mechanism Isolated | Disjointness Proof |
|------|----------------|----------|---------------|-------------------|-------------------|
| 1 | Basic mapping | 8 pass | 7 pass, 1 MISS | Clean 1:1 mapping | Only case 1 fails |
| 2 | Ambiguity detection | 8 pass | 7 pass, 1 MISS | Multiple .mm define same symbol | Only case 2 fails |
| 3 | Unmapped detection | 8 pass | 7 pass, 1 MISS | Header declares, no .mm defines | Only case 3 fails |
| 4 | Misfiled detection (#673) | 8 pass | 7 pass, 1 MISS | Wrong header declares symbol | Only case 4 fails |
| 5 | Line-comment exclusion | 8 pass | 7 pass, 1 MISS | `//` comment not a declaration | Only case 5 fails |
| 6 | Block-comment exclusion | 8 pass | 7 pass, 1 MISS | `/* */` comment not a declaration | Only case 6 fails |
| 7 | Header comment not declaration | 8 pass | 7 pass, 1 MISS | `strip_comments` on header | Only case 7 fails |
| 8 | .mm comment not definition | 8 pass | 7 pass, 1 MISS | `strip_comments` on .mm | Only case 8 fails |

---

## Key Guards to Remove

| Guard | Code Location | Logic |
|-------|--------------|-------|
| `declared_in()` | Line 110-113 | `strip_comments` + `DECL` regex on header |
| `compute()` mapping | Line 149-156 | `owners` length check (1=map, >1=ambiguous, 0=unmapped) |
| `compute()` misfiled | Line 158-167 | `home` dict vs `mapping` comparison |
| `strip_comments()` | Line 134, 144 | Applied to both headers and .mm files |

---

## Removal Procedure

```bash
# For each case:
# 1. Locate the specific check in derive-bridge-header-split.py
# 2. Comment out the check (e.g., disable ambiguity check, misfiled check, comment stripping)
# 3. Run: python3 Scripts/derive-bridge-header-split.py --self-test
# 4. Confirm: 1 case fails, rest pass
# 5. Restore check
# 6. Confirm: all 8 pass
```

---

## Disjointness Evidence

| Case | Isolates | Proof |
|------|----------|-------|
| 1 | Clean mapping | Only fails when mapping logic broken |
| 2 | Ambiguity | Only fails when `len(owners) > 1` check removed |
| 3 | Unmapped | Only fails when `len(owners) == 0` check removed |
| 4 | Misfiled | Only fails when `home[symbol] != expected` check removed |
| 5 | Line comment | Only fails when `strip_comments` on header removed |
| 6 | Block comment | Only fails when `strip_comments` on header removed |
| 7 | Header comment | Only fails when `strip_comments` on header removed |
| 8 | .mm comment | Only fails when `strip_comments` on .mm removed |

---

## Notes

- Total self-test cases: **8**
- Each case isolates a specific split/mapping rule
- "A green removal row is ambiguous" — verify each removal drops exactly one case
- The comment stripping is critical (#673 fix) — must be proven on both header and .mm sides