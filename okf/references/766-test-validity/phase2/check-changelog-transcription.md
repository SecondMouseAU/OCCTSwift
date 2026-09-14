# Phase 2: check-changelog-transcription.py Self-Test Removal Matrix

**Script**: `Scripts/check-changelog-transcription.py` — Merges that landed with no CHANGELOG entry

**Baseline**: Run `python3 Scripts/check-changelog-transcription.py --self-test` → expect all cases pass

---

## Self-Test Cases (from `self_test()` + `_verify_cases()`)

| # | Case Name | Fixture | Expected |
|---|-----------|---------|----------|
| 1 | Merge whose branch carried entry is clean | Merge a | Not reported |
| 2 | Merge with no entry anywhere is reported | Merge b | Reported |
| 3 | Merge with No-Changelog and reason is opt-out | Merge c | Opted out |
| 4 | Entry transcribed in follow-up commit is clean | Merge d | Not reported |
| 5 | No-Changelog with no reason is NOT opt-out | Merge e | Reported |
| 6 | No landing is both reported and opted out | (disjoint) | Not both |
| 7 | Squash landing with no entry is reported | `(#901)` | Reported |
| 8 | Squash landing carrying entry is clean | `(#902)` | Not reported |
| 9 | Later branch's entry not credited to earlier merge | Merge h | Reported |
| 10 | Later merge owning entry is clean | Merge i | Not reported |
| 11 | `default_since()` resolves without error | Default since | Resolves |

---

## Guard Removal Matrix

| Case | Guard to Remove | Baseline | After Removal | Mechanism Isolated | Disjointness Proof |
|------|----------------|----------|---------------|-------------------|-------------------|
| 1 | Branch entry detection | 11 pass | 10 pass, 1 MISS | PR body entry = transcribed | Only case 1 fails |
| 2 | No entry detection | 11 pass | 10 pass, 1 MISS | Absent entry = reported | Only case 2 fails |
| 3 | No-Changelog with reason | 11 pass | 10 pass, 1 MISS | Opt-out trailer parsing | Only case 3 fails |
| 4 | Follow-up commit entry | 11 pass | 10 pass, 1 MISS | Post-merge transcription | Only case 4 fails |
| 5 | No-Changelog no reason | 11 pass | 10 pass, 1 MISS | Empty opt-out rejected | Only case 5 fails |
| 6 | Disjointness (reported ∩ opted_out = ∅) | 11 pass | 10 pass, 1 MISS | Mutually exclusive sets | Only case 6 fails |
| 7 | Squash landing no entry | 11 pass | 10 pass, 1 MISS | Squash merge detection | Only case 7 fails |
| 8 | Squash landing with entry | 11 pass | 10 pass, 1 MISS | Squash + PR body entry | Only case 8 fails |
| 9 | Later branch not credited to earlier | 11 pass | 10 pass, 1 MISS | Entry ownership by merge | Only case 9 fails |
| 10 | Later merge owns entry | 11 pass | 10 pass, 1 MISS | Entry belongs to landing merge | Only case 10 fails |
| 11 | `default_since()` resolution | 11 pass | 10 pass, 1 MISS | Default since ref resolution | Only case 11 fails |

---

## Key Guards to Remove

| Guard | Code Location | Logic |
|-------|--------------|-------|
| PR body entry check | `audit()` → `untranscribed` | `has_entry_in_pr_body()` |
| No-Changelog trailer | `audit()` → `opts` | `trailers["No-Changelog"]` |
| No-Changelog reason check | `audit()` | `reason` non-empty |
| Follow-up commit scan | `audit()` | Commit message contains entry |
| Squash merge detection | `_build_fixture()` | `#NNN` in merge subject |
| Entry ownership | `audit()` | Entry matches landing merge |
| `default_since()` | Line 547 | `default_since()` resolution |

---

## Removal Procedure

```bash
# For each case:
# 1. Locate the specific check in check-changelog-transcription.py
# 2. Comment out the check (e.g., disable No-Changelog parsing, squash detection)
# 3. Run: python3 Scripts/check-changelog-transcription.py --self-test
# 4. Confirm: 1 case fails, rest pass
# 5. Restore check
# 6. Confirm: all 11 pass
```

---

## Disjointness Evidence

| Case | Isolates | Proof |
|------|----------|-------|
| 1 | Branch entry | Only fails when PR body entry check removed |
| 2 | No entry | Only fails when absent entry check removed |
| 3 | Opt-out with reason | Only fails when No-Changelog + reason check removed |
| 4 | Follow-up commit | Only fails when post-merge commit scan removed |
| 5 | Empty opt-out | Only fails when empty reason check removed |
| 6 | Disjoint sets | Only fails when `reported ∩ opted_out` check removed |
| 7 | Squash no entry | Only fails when squash merge detection removed |
| 8 | Squash with entry | Only fails when squash + entry check removed |
| 9 | Entry ownership | Only fails when entry-to-merge matching removed |
| 11 | `default_since()` | Only fails when default since resolution removed |

---

## Notes

- Total self-test cases: **11** (10 from git fixture + 1 `default_since()`)
- The git fixture is built in a temp directory — must verify it builds correctly
- "A green removal row is ambiguous" — verify each removal drops exactly one case
- The script uses real git operations — removal must not break fixture building