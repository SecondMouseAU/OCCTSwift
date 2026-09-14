# Phase 2: check-borrowed-handles.py Self-Test Removal Matrix

**Script**: `Scripts/check-borrowed-handles.py` — No struct/enum stores `OCCT*Ref` without `deinit`

**Baseline**: Run `python3 Scripts/check-borrowed-handles.py --self-test` → expect all cases pass

---

## Self-Test Cases (from `self_test()`)

| # | Case Name | Mechanism Isolated |
|---|-----------|-------------------|
| 1 | struct storing bare handle | #965 defect itself |
| 2 | struct storing OPTIONAL handle | `?` suffix handling |
| 3 | struct with COMPUTED handle | Stored/computed split |
| 4 | computed handle brace next line | `_opens_a_body_next` |
| 5 | CLASS storing handle | Value/reference split (class has deinit) |
| 6 | LOCAL handle in method | Func-scope frame (false positive source) |
| 7 | struct storing OWNER | Fix shape (NativeHandleView) |
| 8 | struct NESTED in class | Nesting (how real sites are written) |
| 9 | STATIC stored handle on struct | Static modifier |
| 10 | handle named only in comment | Comment stripping (isolates nothing) |
| 11 | unbalanced brace in LINE comment | Line-comment stripping |
| 12 | unbalanced brace in SINGLE-LINE block comment | Single-line block comment clear |
| 13 | MULTI-LINE block comment with braces | In_block tracking (#680 hole) |
| 14 | ENUM storing static handle | Enums as value types (no deinit) |
| 15 | non-handle stored properties only | Clean-tree control |

---

## Guard Removal Matrix

| Case | Guard to Remove | Baseline | After Removal | Mechanism Isolated | Disjointness Proof |
|------|----------------|----------|---------------|-------------------|-------------------|
| 1 | Struct detection + handle type check | 15 pass | 14 pass, 1 MISS | Bare handle in struct | Only case 1 fails |
| 2 | Optional `?` suffix in `HANDLE_TYPE_RE` | 15 pass | 14 pass, 1 MISS | `OCCT*Ref?` matching | Only case 2 fails |
| 3 | Computed property detection (`tail == '{'`) | 15 pass | 14 pass, 1 MISS | Stored vs computed split | Only case 3 fails |
| 4 | `_opens_a_body_next()` | 15 pass | 14 pass, 1 MISS | Brace on next line | Only case 4 fails |
| 5 | `VALUE_KINDS` excludes `class` | 15 pass | 14 pass, 1 MISS | Class has deinit | Only case 5 fails |
| 6 | Scope stack func frame check | 15 pass | 14 pass, 1 MISS | Local variable in method | Only case 6 fails |
| 7 | `NativeHandleView` conformance not checked | 15 pass | 14 pass, 1 MISS | Owner pattern (fix) | Only case 7 fails |
| 8 | Nested scope tracking | 15 pass | 14 pass, 1 MISS | Nested struct in class | Only case 8 fails |
| 9 | Static modifier skip in `PROPERTY_RE` | 15 pass | 14 pass, 1 MISS | `static var/let` | Only case 9 fails |
| 10 | `LINE_COMMENT_RE` strips `//` | 15 pass | 14 pass, 1 MISS | Line comment stripping | Only case 10 fails |
| 11 | Block comment `/* ... */` single-line | 15 pass | 14 pass, 1 MISS | Single-line block comment | Only case 11 fails |
| 12 | Multi-line block `in_block` tracking | 15 pass | 14 pass, 1 MISS | Multi-line block with braces | Only case 12 fails |
| 13 | `TYPE_KINDS` includes `enum` | 15 pass | 14 pass, 1 MISS | Enum as value type | Only case 13 fails |
| 14 | Clean tree (no handle) | 15 pass | 15 pass | Non-handle properties | Only case 14 expects clean |

---

## Key Guards to Remove (code locations)

| Guard | Code Location | Logic |
|-------|--------------|-------|
| `HANDLE_TYPE_RE` | Line 59 | `^OCCT\w*Ref[!?]?$` (matches `?` and `!`) |
| `PROPERTY_RE` | Line 52-57 | Stored property regex (excludes computed) |
| `_opens_a_body_next()` | Line 163-173 | Checks next non-blank line for `{` |
| `VALUE_KINDS` | Line 44 | `('struct', 'enum')` — excludes class |
| Scope stack | `scan_lines()` | Brace tracking + `enclosing[0] in VALUE_KINDS` |
| `strip_comments()` | Line 64-95 | Line + block comment stripping |
| `TYPE_KINDS` | Line 45 | Includes `enum` for type detection |

---

## Removal Procedure

```bash
# For each case:
# 1. Locate the specific check in check-borrowed-handles.py
# 2. Comment out the check (e.g., remove `?` from HANDLE_TYPE_RE, add 'class' to VALUE_KINDS)
# 3. Run: python3 Scripts/check-borrowed-handles.py --self-test
# 4. Confirm: 1 case fails, rest pass
# 5. Restore check
# 6. Confirm: all 15 pass
```

---

## Disjointness Evidence

| Case | Isolates | Proof |
|------|----------|-------|
| 1 | Bare handle in struct | Only fails when struct+handle detection runs |
| 2 | Optional handle | Only fails when `?` suffix removed from regex |
| 3 | Computed property | Only fails when computed check (`tail == '{'`) removed |
| 4 | Brace on next line | Only fails when `_opens_a_body_next` disabled |
| 5 | Class has deinit | Only fails when `class` added to VALUE_KINDS |
| 6 | Local in method | Only fails when func-scope frame check removed |
| 7 | Owner pattern | Only fails when NativeHandleView check added |
| 8 | Nested struct | Only fails when nested scope tracking removed |
| 9 | Static modifier | Only fails when `static` not skipped in PROPERTY_RE |
| 10 | Line comment | Only fails when `LINE_COMMENT_RE` disabled |
| 11 | Single-line block comment | Only fails when single-line `/* */` clear disabled |
| 12 | Multi-line block | Only fails when `in_block` tracking disabled |
| 13 | Enum as value type | Only fails when `enum` removed from TYPE_KINDS |
| 14 | Clean tree | Only fails when detector flags everything |

---

## Notes

- Total self-test cases: **15**
- Each case isolates a specific parsing or scope rule
- "A green removal row is ambiguous" — verify each removal drops exactly one case
- The `strip_comments()` function is critical — it handles the #680 hole (closing `*/` sharing line with real code)