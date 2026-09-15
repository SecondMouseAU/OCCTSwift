# Phase 2: check-docs-existence.py Self-Test Removal Matrix

**Script**: `Scripts/check-docs-existence.py` — Every symbol documented as current still exists in Sources

**Baseline**: Run `python3 Scripts/check-docs-existence.py --self-test` → expect all cases pass

---

## Self-Test Cases (from `SELF_TEST_CASES` + `_coverage_self_test`)

### Staleness Cases

| # | Case Name | Source | Docs | Expected |
|---|-----------|--------|------|----------|
| 1 | documented member not stale | `public func documented() {}` | `### Widget.documented()` | clean |
| 2 | undocumented member IS stale | `public func undocumented() {}` | (missing) | stale |
| 3 | underscore-prefixed excluded | `public func _hidden() {}` | (missing) | clean (excluded) |
| 4 | CodingKeys excluded | `public var excluded: Int { 0 }` | (missing) | clean (excluded) |
| 5 | explicit internal not counted | `internal func internalHelper() {}` | (missing) | clean (non-public) |
| 6 | private not counted | `private func privateHelper() {}` | (missing) | clean (non-public) |
| 7 | fileprivate not counted | `fileprivate func fileprivateHelper() {}` | (missing) | clean (non-public) |
| 8 | implicit internal not counted | `func implicitlyInternal() {}` | (missing) | clean (non-public) |
| 9 | public setter only inside | `public private(set) var settableOnlyInside: Int` | (missing) | clean (non-public setter) |
| 10 | nested type in public extension | `public extension Widget { struct Nested { public let carried: Int } }` | `### Widget.Nested.carried` | clean |
| 11 | bare extension nested type | `extension Widget { struct BareNested { public let notCarried: Int } }` | (missing) | clean (extension not public) |
| 12 | public inside internal | `internal struct Hidden { public func publicInsideInternal() {} }` | (missing) | clean (type non-public) |
| 13 | protocol requirement | `public protocol Shaped { func requirement() }` | `### Shaped.requirement()` | clean |
| 14 | enum case | `public enum Mode { case fast; case slow }` | `### Mode.fast` / `### Mode.slow` | clean |
| 15 | internal enum | `internal enum HiddenMode { case quiet }` | (missing) | clean |
| 16 | extension member | `public extension Widget { func fromPublicExtension() {} }` | `### Widget.fromPublicExtension()` | clean |
| 17 | bare extension member | `extension Widget { func fromBareExtension() {} }` | (missing) | clean |

### Coverage Cases (16 additional)

| # | Case Name | Mechanism |
|---|-----------|-----------|
| 18 | documented member not missing | Not in `missing` |
| 19 | undocumented member IS missing | In `missing` |
| 20 | underscore-prefixed excluded | `_hidden` not in missing |
| 21 | CodingKeys excluded | `excluded` not in missing |
| 22 | explicit internal not counted | `internalHelper` not in missing |
| 23 | private not counted | `privateHelper` not in missing |
| 24 | fileprivate not counted | `fileprivateHelper` not in missing |
| 25 | implicit internal not counted | `implicitlyInternal` not in missing |
| 26 | public setter only inside | `settableOnlyInside` not in missing |
| 27 | nested type in public extension | `carried` not in missing |
| 28 | bare extension nested type | `notCarried` not in missing |
| 29 | public inside internal | `publicInsideInternal` not in missing |
| 30 | protocol requirement | `requirement` not in missing |
| 31 | enum case | `fast` / `slow` not in missing |
| 32 | internal enum | `quiet` not in missing |
| 33 | extension member | `fromPublicExtension` not in missing |

---

## Guard Removal Matrix

| Case | Guard to Remove | Baseline | After Removal | Mechanism Isolated | Disjointness Proof |
|------|----------------|----------|---------------|-------------------|-------------------|
| 1 | Documented member check | 17 pass | 16 pass, 1 MISS | Public member documented | Only case 1 expects clean |
| 2 | Undocumented member check | 17 pass | 16 pass, 1 MISS | Public member undocumented | Only case 2 expects stale |
| 3 | Underscore prefix exclusion | 17 pass | 16 pass, 1 MISS | `_` prefix exclusion | Only case 3 expects clean |
| 4 | CodingKeys exclusion | 17 pass | 16 pass, 1 MISS | `CodingKeys` exclusion | Only case 4 expects clean |
| 5 | Explicit internal exclusion | 17 pass | 16 pass, 1 MISS | `internal` access exclusion | Only case 5 expects clean |
| 6 | Private exclusion | 17 pass | 16 pass, 1 MISS | `private` access exclusion | Only case 6 expects clean |
| 7 | Fileprivate exclusion | 17 pass | 16 pass, 1 MISS | `fileprivate` exclusion | Only case 7 expects clean |
| 8 | Implicit internal exclusion | 17 pass | 16 pass, 1 MISS | Implicit internal exclusion | Only case 8 expects clean |
| 9 | Private setter exclusion | 17 pass | 16 pass, 1 MISS | `private(set)` exclusion | Only case 9 expects clean |
| 10 | Nested in public extension | 17 pass | 16 pass, 1 MISS | Public extension nested type | Only case 10 expects clean |
| 11 | Bare extension nested | 17 pass | 16 pass, 1 MISS | Bare extension nested type | Only case 11 expects clean |
| 12 | Public inside internal | 17 pass | 16 pass, 1 MISS | Public member in internal type | Only case 12 expects clean |
| 13 | Protocol requirement | 17 pass | 16 pass, 1 MISS | Protocol requirement access | Only case 13 expects clean |
| 14 | Enum case | 17 pass | 16 pass, 1 MISS | Enum case access | Only case 14 expects clean |
| 15 | Internal enum | 17 pass | 16 pass, 1 MISS | Internal enum exclusion | Only case 15 expects clean |
| 16 | Public extension member | 17 pass | 16 pass, 1 MISS | Public extension member | Only case 16 expects clean |
| 17 | Bare extension member | 17 pass | 16 pass, 1 MISS | Bare extension member | Only case 17 expects clean |

---

## Coverage Guard Removal Matrix

| Case | Guard to Remove | Baseline | After Removal | Mechanism |
|------|----------------|----------|---------------|-----------|
| 18 | `documented` not in missing | 16 pass | 15 pass, 1 MISS | Documented member excluded |
| 19 | `undocumented` in missing | 16 pass | 15 pass, 1 MISS | Undocumented member included |
| 20 | `_hidden` excluded | 16 pass | 15 pass, 1 MISS | Underscore exclusion |
| 21 | `excluded` (CodingKeys) excluded | 16 pass | 15 pass, 1 MISS | CodingKeys exclusion |
| 22 | `internalHelper` excluded | 16 pass | 15 pass, 1 MISS | Internal access exclusion |
| 23 | `privateHelper` excluded | 16 pass | 15 pass, 1 MISS | Private access exclusion |
| 24 | `fileprivateHelper` excluded | 16 pass | 15 pass, 1 MISS | Fileprivate access exclusion |
| 25 | `implicitlyInternal` excluded | 16 pass | 15 pass, 1 MISS | Implicit internal exclusion |
| 26 | `settableOnlyInside` excluded | 16 pass | 15 pass, 1 MISS | Private setter exclusion |
| 27 | `carried` excluded | 16 pass | 15 pass, 1 MISS | Public extension nested |
| 28 | `notCarried` excluded | 16 pass | 15 pass, 1 MISS | Bare extension nested |
| 29 | `publicInsideInternal` excluded | 16 pass | 15 pass, 1 MISS | Public in internal type |
| 30 | `requirement` excluded | 16 pass | 15 pass, 1 MISS | Protocol requirement |
| 31 | `fast`/`slow` excluded | 16 pass | 15 pass, 1 MISS | Enum case |
| 32 | `quiet` excluded | 16 pass | 15 pass, 1 MISS | Internal enum |
| 33 | `fromPublicExtension` excluded | 16 pass | 15 pass, 1 MISS | Public extension member |

---

## Key Guards to Remove

| Guard | Code Location | Logic |
|-------|--------------|-------|
| Public member check | `scan_doc_file()` | `access.is_public` |
| Underscore exclusion | `coverage()` | `name.startswith('_')` |
| CodingKeys exclusion | `coverage()` | `type_name == 'CodingKeys'` |
| Access level checks | `coverage()` | `access.is_public` for type and member |
| Extension public check | `extract_source_symbols()` | `extension` + `public` |
| Protocol requirement | `resolve_conformances()` | `protocol_requirement` flag |
| Enum case | `coverage()` | `enum` parent access |
| Extension member | `extract_source_symbols()` | `extension` context |

---

## Removal Procedure

```bash
# For each case:
# 1. Locate the specific check in check-docs-existence.py
# 2. Comment out the check (e.g., underscore exclusion, access level filter)
# 3. Run: python3 Scripts/check-docs-existence.py --self-test
# 4. Confirm: 1 case fails, rest pass
# 5. Restore check
# 6. Confirm: all pass
```

---

## Disjointness Evidence

| Case | Isolates | Proof |
|------|----------|-------|
| 2 | Undocumented detection | Only fails when undocumented member check removed |
| 3 | Underscore exclusion | Only fails when `_` prefix check removed |
| 4 | CodingKeys exclusion | Only fails when CodingKeys check removed |
| 10 | Public extension nested | Only fails when public extension handling removed |
| 13 | Protocol requirement | Only fails when protocol requirement rule removed |
| 14 | Enum case | Only fails when enum case rule removed |
| 18 | Coverage documented | Only fails when `seen` tracking removed |
| 19 | Coverage undocumented | Only fails when `missing` population removed |

---

## Notes

- Total self-test cases: **33** (17 staleness + 16 coverage)
- Each case isolates a specific access-level or visibility rule
- "A green removal row is ambiguous" — verify each removal drops exactly one case
- The `_coverage_self_test()` is separate and tests the coverage logic specifically