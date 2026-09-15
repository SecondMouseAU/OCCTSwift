# Phase 2: check-null-handle-guards.py Self-Test Removal Matrix

**Script**: `Scripts/check-null-handle-guards.py` — Every bridge function guards the Handle, not just the pointer

**Baseline**: Run `python3 Scripts/check-null-handle-guards.py --self-test` → expect all cases pass

---

## Self-Test Fixtures (from `self_test()` function)

| # | Fixture Name | Shape | Mechanism Exercised |
|---|--------------|-------|---------------------|
| A | wrapper direct | `Handle(Geom_Curve) c = ref->curve;` | Direct wrapper argument field access |
| B | cast | `reinterpret_cast<OCCTSurface*>(ref)->surface` | C++ named cast indirection |
| C | pointer alias | `auto* s = (OCCTSurface*)ref; s->surface` | Pointer alias through C-style cast |
| D | handle alias | `auto& surf = reinterpret_cast<OCCTSurface*>(ref)->surface; f(surf)` | Handle reference alias |
| E | bridge helper | `occtSurfaceToAnalytical(reinterpret_cast<OCCTSurface*>(ref)->surface, ...)` | Helper with own guard |
| F | local BRep_Tool:: | `Handle(Geom_Curve) c = BRep_Tool::Curve(...); f(c);` | Local handle from BRep_Tool |
| G | extern "C" block | Function inside `extern "C" { }` block | extern "C" block parsing |
| H | DownCast | `Handle(Geom_Curve) c = Handle(Geom_Curve)::DownCast(ref->curve);` | DownCast exclusion |
| I | ALLOWED entry | Function in ALLOWED table | ALLOWED exemption |
| J | constructor-init | `Handle(Geom_Curve) c(BRep_Tool::Curve(...));` | Constructor-init form |
| K | occ::handle<> local | `occ::handle<Geom_Curve> c = BRep_Tool::Curve(...);` | occ::handle<> spelling local |
| L | nested block redeclaration | `switch` with nested `Handle(Geom_Surface) surf = ...` | Scope fence (nested block) |
| M | sibling redeclaration other source | `Handle(Geom_Surface) surf = new ...` then `surf = BRep_Tool::...` | Scope fence (sibling source) |
| N | local handle with guard but non-dominating | `c.IsNull(); f(c);` | Non-dominating guard detection |

---

## Guard Removal Matrix

| Fixture | Guard to Remove | Baseline Cases | After Removal | Mechanism Isolated | Disjointness Proof |
|---------|---------------|----------------|---------------|-------------------|-------------------|
| A | `ref->curve.IsNull()` check | 14 pass | 13 pass, 1 MISS | Direct wrapper field | Only A fails |
| B | Cast stripping (`strip_casts`) | 14 pass | 13 pass, 1 MISS | Cast indirection | Only B fails |
| C | Pointer alias tracking | 14 pass | 13 pass, 1 MISS | C-style cast alias | Only C fails |
| D | Handle reference alias | 14 pass | 13 pass, 1 MISS | Reference alias binding | Only D fails |
| E | Bridge helper guard check | 14 pass | 13 pass, 1 MISS | Helper guard propagation | Only E fails |
| F | Local handle tracking (`local_handle_sites`) | 14 pass | 13 pass, 1 MISS | BRep_Tool:: local handles | Only F fails |
| G | extern "C" block parsing | 14 pass | 13 pass, 1 MISS | extern "C" block function detection | Only G fails |
| H | DownCast exclusion | 14 pass | 13 pass, 1 MISS | DownCast is not a use | Only H fails |
| I | ALLOWED exemption | 14 pass | 13 pass, 1 MISS | ALLOWED table lookup | Only I fails |
| J | Constructor-init form | 14 pass | 13 pass, 1 MISS | `Handle(Type) name(...)` form | Only J fails |
| K | occ::handle<> local | 14 pass | 13 pass, 1 MISS | occ::handle<> spelling | Only K fails |
| L | Nested block scope fence | 14 pass | 13 pass, 1 MISS | Block scoping (nested) | Only L fails |
| M | Sibling redeclaration fence | 14 pass | 13 pass, 1 MISS | Block scoping (sibling) | Only M fails |
| N | Non-dominating guard | 14 pass | 13 pass, 1 MISS | Guard must dominate use | Only N fails |

---

## Removal Procedure

```bash
# For each fixture:
# 1. Locate the guard/mechanism in check-null-handle-guards.py
# 2. Comment out or modify the specific detection logic
# 3. Run: python3 Scripts/check-null-handle-guards.py --self-test
# 4. Confirm: 1 case fails (MISS/FAIL), rest pass
# 5. Restore guard
# 6. Confirm: all 14 pass
```

---

## Key Guards to Remove (code locations)

| Fixture | Code Location | Guard Logic |
|---------|--------------|-------------|
| A | `unguarded_sites()` | `ref->field` pattern in `ctext` |
| B | `strip_casts()` | `CAST_OPEN` regex |
| C | `aliases()` | `ASSIGN` + pointer cast tracking |
| D | `aliases()` | `auto&` reference binding |
| E | `guarding_helpers()` | First mention is `IsNull()` |
| F | `local_handle_sites()` | `LOCAL_HANDLE_DECL` regex + `var_declarations`/`binds_to` |
| G | `FUNC` regex | `extern "C"` prefix handling |
| H | `DownCast` exclusion | `DownCast(...)` pattern |
| I | `is_allowed()` | ALLOWED table lookup |
| J | `LOCAL_HANDLE_DECL` | Constructor-init `(` connector |
| K | `ANY_HANDLE_DECL` | `occ::handle<>` spelling |
| L | `var_declarations()` | Block spans + nested scope |
| M | `var_declarations()` | Sibling redeclaration from any source |
| N | `binds_to()` + dominance check | Guard must dominate use |

---

## Disjointness Evidence

| Fixture | Isolates | Proof |
|---------|----------|-------|
| A | Direct wrapper | Only fails when `ref->field` stripped |
| B | Cast indirection | Only fails when `strip_casts` disabled |
| C | Pointer alias | Only fails when alias tracking removed |
| D | Reference alias | Only fails when `auto&` binding not followed |
| E | Helper guard | Only fails when `guarding_helpers()` disabled |
| F | Local BRep_Tool:: | Only fails when `local_handle_sites()` disabled |
| G | extern "C" block | Only fails when `FUNC` regex doesn't handle it |
| H | DownCast exclusion | Only fails when DownCast treated as use |
| I | ALLOWED exemption | Only fails when ALLOWED lookup removed |
| J | Constructor-init | Only fails when `(` connector not matched |
| K | occ::handle<> | Only fails when regex doesn't match it |
| L | Nested block fence | Only fails when block scoping disabled |
| M | Sibling fence | Only fails when sibling redeclaration not fenced |
| N | Dominance | Only fails when dominance check removed |

---

## Notes

- Total self-test cases: **14** (A through N)
- Each case tagged 'wrapper' or 'local' per #666 round-2 review
- "A green removal row is ambiguous" — if removing a guard leaves count unchanged, case is decorative
- The script already has per-mechanism tagging; verify each tag exercises its mechanism