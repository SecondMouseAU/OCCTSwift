# OCCTSwift#771: sub-kind 3 (gate flags that never flip), census run and triage

## Baseline

Two baselines matter here, because the branch moved under this work.

Branched from `origin/refactor/381-pass1b` at `809f148`, where PR #770 (the `hasExtent` fix) was
still open. Sub-kind 3 was built and its first real run against the corpus was taken against that
pre-#770 tree: 7 candidates, including all three `hasExtent` call sites, exactly what a correct
detector should report against code that has the defect. PR #770 merged partway through this work
(`ad1078e`, 2026-08-07T17:57:52Z). `origin/refactor/381-pass1b` was merged into this branch
afterward to pick up the fix, and every number below the first-run note is taken after that merge,
against the corpus with `hasExtent` already fixed.

The self-test does not depend on either baseline: every sub-kind 3 fixture is a synthetic
(header, source) pair, not a read of the live tree, so `hasExtent`'s pre-fix shape stays available
as a positive case regardless of what the real corpus looks like after #770.

## What sub-kind 3 detects

A boolean field, declared on any `typedef struct { ... } Name;` / `struct Name { ... };` in
`Sources/OCCTBridge/` (not filtered by field name), that is assigned literal `false` on at least one
REACHABLE path in the corpus and literal `true` nowhere reachable. Reachable excludes an
`if (false)` / `if (0)` / `while (false)` / `while (0)` block (braced or braceless) and dead code
following an unconditional `return`/`continue`/`break`/`throw` in the same straight-line block; one
shared check applies this to all three of a literal `true`, a literal `false`, and a computed RHS
(see the fifth review round below for why it is one shared check and not three). A field with any
REACHABLE non-literal (computed) assignment is treated as not provably stuck, since the census
cannot evaluate whether that expression can produce `true`. A field whose every `false` write is
itself unreachable drops out of the report entirely, rather than being reported with an empty or a
dead site. Binding a local identifier to a known struct type recognises a local declaration,
value-typed or pointer/reference, single- or multi-declarator (`OCCTShapeAxis *p, *q;`), and a
pointer or reference parameter, so a shared helper that flips the field through `->`/`&`, or a
local alias declared inside the function body, is caught with no special-casing for "this is a
helper" or "this is an alias". A separate, narrower detector covers the Swift side: a
`var x: Bool { ... }` computed property that returns `false` somewhere and `true` nowhere in its
body.

Full algorithm and worked examples are in `Scripts/census-unmeasured-values.py`'s module docstring,
under `SUB-KIND 3 ALGORITHM`.

## What it does not detect, and why

| Gap | Why not taught |
|---|---|
| A `kind`-style enum with a never-emitted "gate open" case | Needs the full declared case list per enum plus which case means "open", which is semantic, not syntactic, a fundamentally different question from a 2-valued bool. |
| A helper that takes the struct by value and returns a modified copy | Only pointer/reference parameters bind a type, deliberately: a byval parameter cannot affect the caller's instance the way "pointer, reference or helper" describes, and accepting it raises the risk of crediting an orphaned, never-called byval helper as if it were live evidence. |
| A cast-based alias (`((T*)ptr)->field = true;`) | Same gap `check-null-handle-guards.py` documents for its own four indirection shapes (#618): the binding regex looks for the type name directly adjacent to the variable, not behind a cast. |
| A more elaborate always-false condition (`if (1 == 2)`, a false-valued macro, `#if 0`, an unreached `switch` case) | Only the literal spellings `false` and `0` are recognised as an always-false condition. |
| A Swift stored property mutated across multiple methods | The closer analogue of the C struct case, but it would need the same corpus-wide type-binding machinery applied to Swift class/struct declarations and their methods, a bigger lift than a single self-contained function body, not attempted this pass. |
| Swift dead-code exclusion (if-false / dead-after-return) | Swift conditionals are commonly braceless and paren-less (`if x > 0 {`), which the C-oriented brace/paren-counting machinery does not parse, so the Swift detector only checks for bare `return true`/`return false` literal presence. |
| Call-graph reachability in general | The census is corpus-wide and per-function, not whole-program: a `true` assignment inside a function that is itself never called anywhere is still counted as "the field can be true". See the Bisector finding below for a real instance of exactly that ambiguity. |

## Second review round: four confirmed gaps, all fixed

Two rounds of review landed on PR #774, four distinct findings, all in the detector logic itself
rather than in the adjudication. Each was closed the same way, per
`okf/policies/prove-the-test-fails.md`: a self-test case added first, confirmed to fail against the
unfixed code, then the fix applied and the case confirmed to pass.

1. **`false_condition_spans()` only recognised a braced always-false block.** A braceless
   `if (false) field = true;` was not spanned, so the flip counted as reachable and a genuinely
   stuck flag would have gone unreported. Fixed: the function now also matches the braceless form,
   the guarded statement running from the condition to its own top-level `;`.
2. **The store-into-a-container protection matched dot notation only, never `outVec->push_back(a)`.**
   A struct stored through a pointer out-param fell through and could be wrongly classified
   `is_input_only_struct`, excluding a genuine result, the seed `hasExtent` shape one indirection
   further out. Fixed by unifying the check into `call_arg_lists`, which does not care what
   precedes the call.
3. **`CALL_START` had no keyword exclusion**, unlike `c_functions()`, which excludes
   `if`/`for`/`while`/`switch`/`catch`/`return`. So `if (...)`, `for (...)` and `sizeof(...)` were
   treated as argument lists; `sizeof(result)` is not a call at all and cannot consume anything, yet
   excluded `result` from candidacy. Fixed: `call_arg_lists` now excludes `NOT_A_FUNCTION` plus
   `sizeof`.
4. **The store-call check only matched a single-argument form**, so `insert(iterator, value)`,
   `std::vector::insert`'s standard idiom, did not match, despite `insert` being named as protected.
   Fixed by the same unification as (2): the check now searches the whole argument text for a bare
   `var` token, not just a sole argument.

### Removal matrix

The second review round's matrix (19 mechanisms at the time) is superseded by the consolidated,
re-verified matrix after the fifth review round, below "Fifth review round". Numbering was not
preserved across rounds: each round's refactoring changed what a given mechanism even means (the
fourth round's shared-helper factoring in particular made the old per-branch rows describe code
that no longer exists in that shape), so re-deriving the whole matrix fresh each time it moves is
more honest than patching numbers that no longer point at the same lines.

## Third finding, same review, sub-kind 1's own core mechanism

The review also asked whether the same braceless and arrow-notation gaps exist in sub-kind 1 and
sub-kind 2, not just sub-kind 3, since findings 2 and 4 were already sub-kind 1 issues and the split
was not clean.

**Braceless-if in sub-kind 1's core (the original, pre-#774 literal-vs-computed-sibling algorithm,
not the new exclusion):** not applicable. That algorithm has no reachability concept at all; its
`conditional_brace_positions`/`depth_segments` machinery exists for depth-matching sibling fields,
a different question, and a braceless `if` simply does not add depth there, an already-documented
characteristic ("CONDITIONAL DEPTH IS A COUNT, NOT AN IDENTITY") predating this review, not a
new silent-miss risk of the same shape as finding 1.

**Arrow notation in sub-kind 1's core: yes, and it was real.** `FIELD_ASSIGN`, the regex the whole
literal-vs-computed-sibling algorithm is built on, matched dot notation only
(`\b([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*=\s*([^=][^;]*);`), unlike sub-kind 3's `ASSIGN_ANY`, which
already handled dot, arrow and array-index. A result struct built through an out-param pointer
(`out->field = ...;`, common in this bridge: `OCCTBridge_AIS.mm`, `OCCTBridge_Geom2d.mm`) or an
array element (`out[i].field = ...;`) was invisible to sub-kind 1 from the start, a silent
under-report of exactly the kind this whole review is about. Fixed: `FIELD_ASSIGN` now matches the
same three shapes `ASSIGN_ANY` does. A dedicated self-test case (in the consolidated matrix below)
proves it, modelled on a real site, `OCCTBridge_Geom2d.mm`'s `extractBisecSolution`.

**Sub-kind 2 (Swift): neither gap applies, verified against Swift's own grammar, not assumed.**
Swift requires braces on every `if`/`while`/`for` body; there is no braceless form for the parser to
accept, so a braceless-if analogue cannot occur in Swift source at all. Swift also has no `->`
operator; member access is always `.`, including through optional chaining. Both gaps are
structurally impossible in the language sub-kind 2 scans, not merely unobserved in this corpus.

## Fourth review round: two more gaps, both PLAUSIBLE, both fixed

A second pass over PR #774 found two further gaps, both marked PLAUSIBLE by the reviewer rather
than confirmed live in the corpus, both in `gate_flag_candidates` itself. Neither had a self-test
case in either direction (the fixture that would catch it, or the fixture that would prove the
absence is safe), which is exactly the coverage gap the reviewer surfaced instead of the defect
itself: a detector's blind spot does not become real when someone writes the code that trips it,
it becomes visible then, and by that point it has been silently under-reporting.

**Finding: the reachability exclusion applied to the `true` branch only, not the computed branch.**
`is_dead_after_terminator`/`dead_spans` gate whether a literal `true` counts as a real flip, but the
sibling `else` branch that adds a struct field to `computed_seen` (marking it "not provably stuck")
had no reachability check of its own:

```cpp
g.hasExtent = false;
if (false) {
    g.hasExtent = someLegacyComputation();   // dead, and not a literal
}
```

would mark `(struct, field)` as not provably stuck and exempt a field that is permanently `false`
in every path that actually executes; the identical "unreachable write masks a stuck gate" shape
this PR spent its second review round hardening for the `true` case, left open one branch over.
Fixed: the same two checks now gate the computed branch too, sharing the exact functions the
`true` branch already calls rather than a second implementation of the same idea.

**Finding: `local_bind` never recognised a pointer or reference declared inside a function body.**
`param_bind` already handled `TYPE* name`/`TYPE& name` for a function PARAMETER, but the sibling
`local_bind` only matched a plain value-typed declaration (`\b(TYPE)\s+(name)\s*(?:=|;|\{)`, no
`*`/`&` branch at all). So `OCCTShapeAxis* p = &a; p->hasExtent = true;`, a local alias declared
inside the function rather than a caller-supplied out-param, bound nothing: `ASSIGN_ANY`'s match on
`p->hasExtent = true` found `bindings.get('p')` was `None` and the assignment was silently skipped,
invisible to sub-kind 3 entirely. This is the SAME shape #774's second review round already fixed
for a shared helper's own POINTER PARAMETER; the review's framing was apt: a detector that
understands `p->field` but not what `p` is bound to is half a feature. Fixed: `local_bind` now has
the same two-branch shape `param_bind` already had, a pointer/reference OR a plain value, so a
local pointer/reference declaration binds exactly like the parameter form always did.

Both fixed the same way as every prior finding: a self-test case added first, confirmed to fail
against the unfixed code, then the fix applied and confirmed to pass
(`okf/policies/prove-the-test-fails.md`). Neither gap was previously listed in the module
docstring's "WHAT SUB-KIND 3 STILL CANNOT SEE" section; since both are now fixed rather than left
open, neither needed to be added there either. Measured against the real corpus: sub-kind 3's
report count is unchanged at 3 candidates after both fixes, and sub-kind 1/2 are unaffected (both
fixes are inside `gate_flag_candidates`, sub-kind 3 only), consistent with the reviewer's own
framing that neither gap was confirmed live, only real as a mechanism.

## Fifth review round: the duplication itself, plus the third literal, plus multi-declarators

A third pass raised three findings. The first is the one that mattered most, because it explains
why the fourth round's own fix was needed at all.

**Finding: the reachability check was duplicated verbatim between the `true` branch and the
computed branch, and that duplication is how the fourth round's bug came to exist.** The check was
added to the `true` branch in the second round and not mirrored to the computed branch until the
fourth: two copies, two chances to forget one. Fixed by factoring both into one function,
`is_dead_assignment(body, pos, segs, dead_spans)`, and routing every branch through it. This closes
the recurrence mechanism, not just the latest instance of it: a fourth call site cannot skip the
check by copy-pasting an outdated version of it, because there is only one version to call.

**Finding: the `false` branch had no reachability check at all, the third instance of the same
gap.** Fixing the duplication above made this the natural place to close it: routing the `false`
branch through the same `is_dead_assignment` closes both findings together, per the review's own
framing. On the substance: a `false` write in dead code is not evidence a field is stuck, so
skipping it is right, but a field whose EVERY `false` write is dead should not be a candidate at
all, rather than reported with an empty site list. Achieved for free by how `false_sites` is
built: it is populated by appending one live site at a time, so a field with zero live appends
never acquires a key in the dict, and the loop that produces the final report only ever iterates
keys that exist. A field with a MIX of dead and live `false` writes still gets reported, correctly,
and from the live site specifically, verified by direct inspection of `gate_flag_candidates`'s
return value for exactly that fixture (dead site on an earlier line, live site on a later one; the
function returns the later line).

**Finding: `local_bind` (now `local_declarator_bindings`) never handled a multi-declarator
statement**, `OCCTShapeAxis *p, *q;`, because the single-declarator regex required its terminator
(`=`/`;`/`{`) immediately after the first name, and a comma-separated second declarator supplied a
`,` instead. Confirmed this affects even a PURELY VALUE-TYPED multi-declarator
(`OCCTShapeAxis a, b;`), not just the pointer/reference form the review's own example used: the
terminator check fails identically either way, so this is a distinct mechanism from finding 1 in
the fourth round (pointer/reference support), not a variant of it. Fixed by replacing the
single-declarator regex with one that captures the whole comma-separated declarator list and
splits it, each piece optionally carrying its own `*`/`&` and initializer.

### Avoiding the fourth round's "row 5" trap here too

The review separately asked to verify the removal matrix can still isolate each of the three
branches' use of the new shared `is_dead_assignment` helper, rather than having one row that fails
all three at once and calls that coverage. It also flagged, unprompted, that a naive test design
for finding 2 would recreate exactly the fourth round's row-5 ambiguity: a multi-declarator fixture
built entirely from pointer-typed declarators (`OCCTFixtureMultiDeclarator *p, *q;`, the review's
own example, kept below as the close-to-the-report case) cannot be told apart, by the matrix, from
a pointer-support fixture, since disabling either mechanism regresses it. A second, value-typed-only
multi-declarator fixture (`OCCTFixtureMultiDeclaratorPlain unused, a;`) was added specifically to
break that tie: disabling pointer support alone spares it, disabling multi-declarator support alone
does not, which is what makes the two mechanisms separable in the table below rather than merely
asserted to be separate.

### Removal matrix, all twenty-three mechanisms, fully re-derived

36 self-test cases (was 32 after the fourth round: 2 new for the `false`-branch reachability finding,
2 new for the multi-declarator finding). Every mechanism was disabled in turn in a working copy of
the script, `--self-test` re-run, the case-count drop recorded, and the file restored from an
untouched backup before the next probe. Rows 1 to 9 were re-verified against the fifth round's fully
refactored code, not carried over from an earlier run:

| # | Rule disabled | Cases correct | What flipped |
|---|---|---|---|
| - | (baseline) | 36/36 | - |
| 1 | Sub-kind 3: name-prefix independence | 32/36 | 4 MISSED cases stop being flagged (the seed's non-`has` sibling, both dead-`true` cases, and the braceless case; all fifth-round cases are unaffected, all using `hasExtent` already) |
| 2 | Sub-kind 3: `is_dead_after_terminator` (shared sub-mechanism) | 35/36 | 1 MISSED case stops being flagged, the dead-after-return case only |
| 3 | Sub-kind 3: `false_condition_spans` (shared sub-mechanism, whole) | 32/36 | 4 cases affected: both `true`-branch if-false forms, the dead-computed case, AND (new this round) the all-dead-`false` case, confirming the `false` branch now shares this mechanism too |
| 4 | Sub-kind 3: pointer/reference PARAMETER binding (`param_bind`) | 34/36 | 2 CLEAN cases become wrongly flagged |
| 5 | Sub-kind 3: local declaration binding, whole mechanism (`local_declarator_bindings` disabled entirely) | 28/36 | all 7 sub-kind-3 MISSED cases that need any local binding stop being flagged |
| 6 | Sub-kind 3: `computed_seen.add` itself (reachability check left in place) | 34/36 | 1 CLEAN case becomes wrongly flagged (`wasAdjusted`) |
| 7 | Sub-kind 3: Swift computed-property detection | 34/36 | 1 Swift MISSED case stops being flagged |
| 8 | Sub-kind 3: `true`-branch call site to `is_dead_assignment`, specifically | 32/36 | 3 MISSED cases stop being flagged (both if-false forms, dead-after-return); `false`/computed branches unaffected |
| 9 | Sub-kind 3: `false`-branch call site to `is_dead_assignment`, specifically | 34/36 | 1 CLEAN case becomes wrongly flagged, the all-dead-`false` case only; the mixed dead+live case is unaffected (it was never relying on this check to stay flagged, only on it to report the right site) |
| 10 | Sub-kind 3: computed-branch call site to `is_dead_assignment`, specifically | 34/36 | 1 MISSED case stops being flagged, the dead-computed case only |
| 11 | Sub-kind 3: `is_dead_assignment` itself (all three call sites at once) | 30/36 | 5 cases affected at once (both if-false forms, dead-after-return, dead-computed, all-dead-`false`); included to show explicitly that this single combined row tells you less than rows 8 to 10 do, not as a substitute for them |
| 12 | Sub-kind 1: whole config-struct exclusion (`is_input_only_struct`) | 35/36 | 1 CLEAN case becomes wrongly flagged |
| 13 | Sub-kind 1: whole store-family protection | 33/36 | 3 MISSED cases stop being flagged |
| 14 | Sub-kind 1: bare-`return` protection | 35/36 | 1 MISSED case stops being flagged |
| 15 | Sub-kind 1: array-element-assignment protection | 35/36 | 1 MISSED case stops being flagged |
| 16 | Sub-kind 1: paren-depth-balanced argument scan | 33/36 | 2 cases affected; report count moves 49 to 53 on the real corpus |
| 17 | Sub-kind 1: `FIELD_ASSIGN` arrow/array-index matching | 35/36 | 1 MISSED case stops being flagged, the pointer-out-param result case |
| 18 | Sub-kind 3: pointer/reference support in LOCAL declarations, specifically (mandatory-separator `[\*&]` alternative removed, multi-declarator repeat-group left intact) | 34/36 | 2 cases become wrongly flagged: the single-declarator local-pointer case, AND the pointer+multi-declarator case (its first declarator is pointer-typed); the value-only multi-declarator case is UNAFFECTED |
| 19 | Sub-kind 3: multi-declarator support, specifically (comma-continuation repeat-group removed, single-declarator pointer/reference left intact) | 34/36 | 2 cases stop being flagged: the pointer+multi-declarator case AND the value-only multi-declarator case; the single-declarator local-pointer case is UNAFFECTED |

Rows 18 and 19 are the direct answer to "avoid the row-5 trap": each disables one of the two
mechanisms a multi-declarator pointer statement needs, and each leaves a DIFFERENT one of the three
local-binding fixtures unaffected, which is what proves the two mechanisms are actually separable
by this matrix rather than merely asserted to be. Sub-kind 1's own arrow-notation/multi-argument/
`CALL_START`-keyword rows from the fourth round's matrix are omitted here as unchanged (that code
was not touched this round); still verified, via spot-checks re-run against this round's file, not
dropped from the suite.

Every row drops the count and no two rows are redundant. Two sub-kind-3 CLEAN cases (the two
correctly-flipping baselines) and one control (the "reachable true under a real condition" case)
are not tied to a single row; they guard the shared base-recognition path every row relies on and
would only fail if that broke.

## Candidates found and verdicts

### Sub-kind 3, current (post-#770-merge) baseline: 3 candidates

| Candidate | Struct.field | Verdict | Evidence |
|---|---|---|---|
| `OCCTBridge_Mesh.mm:201` `OCCTMeshParametersDefault` | `OCCTMeshParameters.relative` | 1, not an instance | `OCCTMeshParametersDefault()` is a plain default-value factory for a config/options struct passed as an argument to `OCCTShapeCreateMeshWithParams`, not read back as a measurement. Confirmed genuinely settable: `Sources/OCCTSwift/Mesh.swift`'s `MeshParameters` has a public, mutable `var relative: Bool`, and `params.relative = relative` (`Mesh.swift:87`) forwards it at the real call site. |
| `OCCTBridge_Mesh.mm:205` `OCCTMeshParametersDefault` | `OCCTMeshParameters.adjustMinSize` | 1, not an instance | Same reasoning; `Mesh.swift:91`. |
| `OCCTBridge_Mesh.mm:206` `OCCTMeshParametersDefault` | `OCCTMeshParameters.allowQualityDecrease` | 1, not an instance | Same reasoning; `Mesh.swift:92`. |

`OCCTShapeAxis.hasExtent` no longer appears, fixed on #770, already merged into this base. Before
that merge, this same detector's first real run against the corpus reported exactly the three
`hasExtent` call sites plus one further genuine finding, described next.

### `BisectorPoint`/`OCCTBisectorPointOnBis`/`OCCTBisectorPointOnBisCreate` removed (verdict 4)

Found against the pre-#770-merge baseline. Verified independently before removing
(`okf/policies/measure-dont-assume.md`), not just cited from #763's earlier one-line note on the
same function: read `Bisector_PointOnBis.hxx` from the pinned OCCT xcframework headers directly.
The OCCT class has a real, settable `IsInfinite`/`IsInfinite() const` pair, the concept is genuine,
but `OCCTBisectorPointOnBisCreate` never constructs a `Bisector_PointOnBis` at all; it echoes 6 raw
doubles into a plain C struct with no reference to the OCCT class. Grepped the whole tree: zero
Swift call sites for the bridge function, zero constructor call sites for the Swift `BisectorPoint`
struct it built for, and `BisectorPoint` has no explicit `public init` (only `public let` fields),
so Swift's auto-synthesized memberwise initializer for a `public struct` is `internal`, not
`public`, so no external consumer of `OCCTSwift` could construct one either. Fully orphaned on both
sides, matching the #506/PR #547 precedent ("an orphan freezes its contract") in this same
codebase.

Removed: the bridge struct and function (`OCCTBridge_Geom2d.h`/`.mm`, tombstone comments in the
`#500`/`#506` idiom already used elsewhere in that header), the Swift struct
(`BisectorResult.swift`), and its two doc references (`docs/reference/Shape-Recognition.md`,
`docs/API_REFERENCE.md`'s Bisector Intersection row count 2 to 1). `BisectorIntersection`/
`bisectorIntersections(a:b:c:d:)`, the live pair in the same file, are untouched.
`Scripts/count-operations.py`'s derived total is unaffected (4306 before and after): `BisectorPoint`
had no public `func`/computed `var`/`init`/`subscript`, so it was never counted.

No injection cycle for this fix, matching PR #770's own precedent for the `selfIntersectionCount`
removal: it is a field/type deletion enforced by the compiler, not a new positive behavioural check.

### Sub-kind 1: 49 to 73 candidates once `FIELD_ASSIGN` sees arrow/array-index, 24 new lines adjudicated

Fixing sub-kind 1's own arrow-notation gap (above) surfaced 24 new candidates. New candidates are
the point, not a complication, so all 24 are adjudicated here rather than left as a raw count.

**Verdict 1, not an instance, structural (10 of 16 `qualifier = 0` sites):**
`OCCTGccCircle2d2PtRad`, `OCCTGccCircle2d3Pt`, `OCCTGccAnaLin2dBisec`, `OCCTGccAnaLin2dTanParPt`,
`OCCTGccAnaLin2dTanPerPtLin`, `OCCTGccAnaLin2dTanOblPt` (`OCCTBridge_Geom2d.mm`) take no
qualifier-shaped input at all (pure point/multi-point constructions, where "inside/outside" has no
meaning), so `qualifier = 0` there is structural, the same shape as the Bisector `radius = 0` for a
line case below.

**Verdict 2, compute it (10 of 16 `qualifier = 0` sites, filed as #781):**
`OCCTGccCircle2d2TanPt`, `OCCTGccCircle2dTanCen`, `OCCTGccCircle2d2TanRad`,
`OCCTGccCircle2dTanPtRad`, `OCCTGccLine2d2Tan`, `OCCTGccLine2dTanPt`,
`OCCTGccAnaCirc2d2TanOnLinLin`, `OCCTGccAnaCirc2dTanOnRadLin`, `OCCTGeom2dGccCirc2d2TanOn`,
`OCCTGeom2dGccCirc2dTanOnRad` each take a real qualifier/position input yet report `qualifier = 0`
for every solution. Confirmed genuinely computable: `Geom2dGcc_Circ2dTanCen::WhichQualifier(Index,
GccEnt_Position&)` and `Geom2dGcc_Circ2d3Tan::WhichQualifier(Index, Position&, Position&,
Position&)` both exist in the pinned OCCT headers, and four sibling functions in the same file
already call an equivalent accessor and assign a real value. Not fixed in this PR: the ten sites
need per-function OCCT-header verification and a resolved design question (the two-input-qualifier
functions have no obvious single-field mapping), out of proportion to a detector-fix PR. Filed as
issue #781.

**Verdict 1, not an instance, confirmed by reading (4 more sites):**
- `OCCTAnalyzePointCloud` (`OCCTBridge_Spatial.mm`): `outResult->type = 0/1/2/3` across four
  `if`/`else if`/`else` branches, a branch-selected classification tag, a different literal per
  branch, not a fabrication.
- `OCCTGeomFillConstrainedInfo` (`OCCTBridge_Surface.mm`): `info->isValid = true` inside the
  success branch, `info->isValid = false` after the loop on the not-found path, a legitimate
  default-then-flip success flag, both literals genuinely reached on distinct control-flow paths.
- `OCCTExtremaExtPElC2dCirc`/`OCCTExtremaExtPElC2dLin` (`OCCTBridge_Geom2d.mm`, 2 sites):
  `out[i].param1 = 0` beside a computed `out[i].param2`. `Extrema_ExtPElC2d` computes the extremum
  between a POINT and an elementary curve; the point side has no parameter to report, only the
  curve side does, so 0 is a structural placeholder for a genuinely parameter-less operand.

**Needs investigation, not adjudicated with confidence (4 sites, filed as part of #781):**
`OCCTCurve2DIntersect`/`OCCTCurve2DSelfIntersect` (`OCCTBridge_Geom2d.mm`, 2 fields each) set
`out[i].u1 = 0; out[i].u2 = 0;` with an existing comment admitting the limitation. Verified against
the pinned `Geom2dAPI_InterCurveCurve.hxx`: confirmed no direct parameter accessor exists. Not ruled
out: projecting the returned point back onto each source curve to recover the parameters
indirectly. Unlike the `qualifier` sites this is not confirmed computable, only not-yet-ruled-out,
and `0` is a value a genuine intersection parameter could coincide with, so this is the same
"0 collides with a real answer" ambiguity #726 exists to find, not a confirmed structural
non-applicability like `param1` above.

Full evidence and the scope note for why the qualifier/u1u2 fixes are not attempted in this PR:
issue #781.

## Bonus finding folded into this PR: sub-kind 1's option-struct false positives

Not part of #771's own ask, but cheap enough while already in the script, so folded in rather than
silently skipped. The single largest group of false positives in sub-kind 1's candidates was a
local config/options struct handed to a call as an argument (`opts.Flatten = true;` then
`Add(shape, opts)`), syntactically identical to a real result struct built field by field, and
already named as an unaddressed blind spot in the script's own docstring (5 known sites:
`BRepGraph::ShapesView::Options` x4, `MathInteg::KronrodConfig` x1).

`is_input_only_struct()` excludes a tracked local var handed to a call as a bare argument, unless
protected by being returned bare, stored into a container (`push_back`/`emplace_back`/
`push_front`/`emplace_front`/`insert`, through either `.` or `->`, as one argument among several or
the only one, after the second review round), or copied into an array element. Both the exclusion
and each protection had to be built carefully, not naively: the exact seed shape this census exists
to catch (`OCCTShapeAxis a` built in a loop, `collected.push_back(a)`) is also "handed to a call as
a bare argument", an unprotected version of this rule would have made sub-kind 1 blind to the seed
defect, the unsafe direction #726 explicitly warns this whole workstream against. A naive
`[^()]*` argument-list scan also cannot see an argument behind a nested cast
(`Add(*(const TopoDS_Shape*)shape, opts)`), missing 3 of the 5 real sites; `call_arg_lists()` does
the same paren-depth walk `catch_spans`/`conditional_brace_positions` already use for braces.

Measured: sub-kind 1's report count 54 to 49 after the first fix (exactly the 5 known sites),
unaffected by the second review round's fixes on this corpus (no arrow-notation or multi-argument
store call happens to exist among the real config-struct sites), and 49 to 73 once `FIELD_ASSIGN`
itself gained arrow/array-index support, the sub-kind 1 core-mechanism fix described above.
