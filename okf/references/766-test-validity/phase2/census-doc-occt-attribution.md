# Phase 2: census-doc-occt-attribution.py Self-Test Removal Matrix

**Script**: `Scripts/census-doc-occt-attribution.py` — Docs attributing a method to an OCCT class its bridge fn never reaches

**Baseline**: Run `python3 Scripts/census-doc-occt-attribution.py --self-test` → expect all cases pass

---

## Self-Test Cases (from `self_test()` — 13 cases)

| # | Case Name | Fixture | Mechanism Exercised |
|---|-----------|---------|---------------------|
| 1 | Class bridge fn does not reach IS reported | `BRepPrimAPI_MakeHalfSpace` via `OCCTShapeExtrudeSemiInfinite` | Over-coverage detection |
| 2 | Corrected claim on same method NOT reported | `BRepPrimAPI_MakePrism` via `OCCTShapeExtrudeSemiInfinite` | Correction handling |
| 3 | Claim resolves through heading's Swift member | `BRep_Tool::MaxTolerance` via `maxEdgeTolerance` | Member index resolution |
| 4 | `Package::Static` facade resolves | `TopExp::MapShapes` via `OCCTShapeUniqueEdgeCount` | Facade `Class_Member` resolution |
| 4b | Facade on joined spelling alone | `BRepTools::Update` via `OCCTFacadeJoinedOnly` | Joined spelling resolution |
| 5 | WRONG facade attribution IS reported | `TopExp_Explorer` on method running `TopExp::MapShapes` | Facade discrimination |
| 6 | Negation: class after marker is commentary | `TopExp::MapShapes`; `TopExp_Explorer` is NOT | Negation handling |
| 7 | Wrong class BEFORE positional negation still reported | `BRepPrimAPI_MakeHalfSpace`, not `MakePrism` | Positional negation |
| 7b | Mirror: wrong class AFTER positional negation is commentary | `BRepPrimAPI_MakePrism`, not `MakeHalfSpace` | Positional negation mirror |
| 8 | Class absent from pinned headers | `BRepPrimAPI_MakeVanished` via `OCCTShapeQuilt` | Absent class detection |
| 9 | Non-OCCT prefix_name token | `some_variable` via `OCCTShapeQuilt` | Package manifest filter |
| 9b | All-caps enum value not treated as class | `TopAbs_EDGE` | Enum value filter |
| 10 | Unquoted class name in prose | `BRepTools_Quilt` unquoted in text | Backtick-quote requirement |
| 11 | Unresolvable claim counted unresolved | `noSuchMember` | Unresolved tracking |
| 12 | Channel B: bridge header doc comment | `///` comment on `OCCTMakeEdgeError` | Header doc channel |
| 13 | Channel C: two-column table row | `| shape.edgeCount \| TopExp_Explorer \|` | Table channel |
| 13b | Contrastive clause doesn't silence attribution | `MakeHalfSpace`; corrected from earlier | Clause splitting |

---

## Guard Removal Matrix

| Case | Guard to Remove | Baseline | After Removal | Mechanism Isolated | Disjointness Proof |
|------|----------------|----------|---------------|-------------------|-------------------|
| 1 | Over-coverage detection | 13 pass | 12 pass, 1 MISS | Wrong class attribution | Only case 1 fails |
| 2 | Correction handling | 13 pass | 12 pass, 1 MISS | Corrected claim excluded | Only case 2 fails |
| 3 | Member index resolution | 13 pass | 12 pass, 1 MISS | Heading Swift member | Only case 3 fails |
| 4 | Facade `Class_Member` | 13 pass | 12 pass, 1 MISS | `Foo::Bar` resolution | Only case 4 fails |
| 4b | Joined spelling `Class_Member` | 13 pass | 12 pass, 1 MISS | Joined spelling only | Only case 4b fails |
| 5 | Facade discrimination | 13 pass | 12 pass, 1 MISS | Wrong facade reported | Only case 5 fails |
| 6 | Negation commentary | 13 pass | 12 pass, 1 MISS | "NOT" clause exclusion | Only case 6 fails |
| 7 | Positional negation (before) | 13 pass | 12 pass, 1 MISS | Positional marker cut | Only case 7 fails |
| 7b | Positional negation (after) | 13 pass | 12 pass, 1 MISS | Positional marker cut mirror | Only case 7b fails |
| 8 | Absent class detection | 13 pass | 12 pass, 1 MISS | Pinned headers check | Only case 8 fails |
| 9 | Package manifest filter | 13 pass | 12 pass, 1 MISS | Prefix/package validation | Only case 9 fails |
| 9b | Enum value filter | 13 pass | 12 pass, 1 MISS | `TopAbs_` prefix exclusion | Only case 9b fails |
| 10 | Backtick-quote requirement | 13 pass | 12 pass, 1 MISS | Unquoted prose exclusion | Only case 10 fails |
| 11 | Unresolvable tracking | 13 pass | 12 pass, 1 MISS | `unresolved` bucket | Only case 11 fails |
| 12 | Channel B (header doc) | 13 pass | 12 pass, 1 MISS | `///` comment channel | Only case 12 fails |
| 13 | Channel C (table) | 13 pass | 12 pass, 1 MISS | Table row channel | Only case 13 fails |
| 13b | Clause splitting | 13 pass | 12 pass, 1 MISS | Contrastive clause split | Only case 13b fails |

---

## Key Guards to Remove

| Guard | Code Location | Logic |
|-------|--------------|-------|
| Over-coverage check | `_self_test_case` case 1 | `findings` includes class not in reach |
| Correction handling | `_self_test_case` case 2 | Corrected class matches reach |
| Member index | `_self_test_case` case 3 | `member_syms` resolves to bridge fn |
| Facade resolution | `_self_test_case` case 4 | `Class_Member` in reach set |
| Joined spelling | `_self_test_case` case 4b | `Class_Member` alone in reach |
| Facade discrimination | `_self_test_case` case 5 | Wrong facade in reach, correct not |
| Negation | `_self_test_case` case 6 | `CLAUSE_MARKERS` / `POSITIONAL_MARKERS` |
| Positional negation | `_self_test_case` case 7/7b | Marker position logic |
| Absent class | `_self_test_case` case 8 | Class not in `_FIXTURE_HEADERS` |
| Package manifest | `_self_test_case` case 9 | Prefix not in `_FIXTURE_PREFIXES` |
| Enum value | `_self_test_case` case 9b | `TopAbs` in `_FIXTURE_PREFIXES` |
| Backtick quote | `_self_test_case` case 10 | Quote parsing |
| Unresolvable | `_self_test_case` case 11 | `unresolved` bucket |
| Channel B | `_self_test_case` case 12 | `channel="header-doc"` |
| Channel C | `_self_test_case` case 13 | `doc_claims_from_text` table parsing |
| Clause splitting | `_self_test_case` case 13b | Clause marker splitting |

---

## Removal Procedure

```bash
# For each case:
# 1. Locate the specific check in census-doc-occt-attribution.py
# 2. Comment out the check (e.g., disable over-coverage, correction, negation, etc.)
# 3. Run: python3 Scripts/census-doc-occt-attribution.py --self-test
# 4. Confirm: 1 case fails, rest pass
# 5. Restore check
# 6. Confirm: all 13 pass
```

---

## Disjointness Evidence

| Case | Isolates | Proof |
|------|----------|-------|
| 1 | Over-coverage | Only fails when wrong-class check removed |
| 2 | Correction | Only fails when correction check removed |
| 3 | Member index | Only fails when `member_syms` resolution disabled |
| 4 | Facade | Only fails when `Class_Member` lookup removed |
| 4b | Joined spelling | Only fails when joined spelling alone resolution removed |
| 5 | Facade discrimination | Only fails when facade check removed (case 4 passes, 5 fails) |
| 6 | Negation | Only fails when negation markers disabled |
| 7 | Positional negation | Only fails when positional marker logic removed |
| 8 | Absent class | Only fails when pinned headers check removed |
| 9 | Package manifest | Only fails when prefix validation removed |
| 10 | Backtick quote | Only fails when quote parsing removed |
| 11 | Unresolvable | Only fails when `unresolved` bucket removed |
| 12 | Channel B | Only fails when header-doc channel removed |
| 13 | Channel C | Only fails when table parsing removed |
| 13b | Clause splitting | Only fails when clause marker splitting removed |

---

## Notes

- Total self-test cases: **13** (plus sub-cases 4b, 7b, 9b, 13b)
- Each case isolates a specific attribution resolution rule
- "A green removal row is ambiguous" — verify each removal drops exactly one case
- The detector has 41% false-positive rate — these cases prove it discriminates correctly
- Channels A/B/C are separate parsing paths — must be proven independently