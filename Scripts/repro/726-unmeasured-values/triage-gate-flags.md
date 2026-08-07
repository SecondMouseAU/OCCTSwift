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
`Sources/OCCTBridge/` (not filtered by field name), that is assigned literal `false` somewhere in
the corpus and literal `true` nowhere reachable. Reachable excludes an `if (false)` / `if (0)` /
`while (false)` / `while (0)` block (braced or braceless, see the second review round below) and
dead code following an unconditional `return`/`continue`/`break`/`throw` in the same straight-line
block; both checks apply equally to a literal `true` and a computed RHS (see the third review round
below). A field with any REACHABLE non-literal (computed) assignment is treated as not provably
stuck, since the census cannot evaluate whether that expression can produce `true`. Binding a local
identifier to a known struct type recognises a local declaration, value-typed or pointer/reference,
and a pointer or reference parameter, so a shared helper that flips the field through `->`/`&`, or
a local alias declared inside the function body, is caught with no special-casing for "this is a
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

### Removal matrix, all nineteen mechanisms

25 self-test cases before the second round became 30 after (3 new sub-kind 1 cases for findings 2
to 4, plus one further case described below, plus 1 new sub-kind 3 case for finding 1), then 32
after the fourth round (one sub-kind 3 case each for the two findings there). Every mechanism sub-
kind 3 and sub-kind 1's config-struct exclusion rely on was disabled in turn in a working copy of
the script, `--self-test` re-run, the case-count drop recorded, and the file restored from an
untouched backup before the next probe. Rows 1 to 13 were re-verified against the fourth round's
refactored code, not just carried over from the second round's own run:

| # | Rule disabled | Cases correct | What flipped |
|---|---|---|---|
| - | (baseline) | 32/32 | - |
| 1 | Sub-kind 3: name-prefix independence | 28/32 | 4 MISSED cases stop being flagged (the seed's non-`has` sibling, both dead-`true` cases, and the braceless case; the two fourth-round cases are unaffected, both using the `hasExtent` name already) |
| 2 | Sub-kind 3: dead-after-terminator exclusion | 31/32 | 1 MISSED case stops being flagged (only the dead-after-return case; the dead-if-false-guarded computed case, row 14, relies on `dead_spans` instead and is unaffected) |
| 3 | Sub-kind 3: dead-if-false exclusion, whole mechanism | 29/32 | 3 MISSED cases stop being flagged: both the braced and the braceless `true` form, AND the new dead-computed case (row 14), confirming it correctly shares this same mechanism rather than reimplementing it |
| 4 | Sub-kind 3: pointer/reference parameter binding | 30/32 | 2 CLEAN cases become wrongly flagged; the new local-pointer case (row 15) is unaffected, since it uses `local_bind`, not `param_bind` |
| 5 | Sub-kind 3: local declaration binding, whole mechanism (value-typed AND pointer/reference) | 26/32 | all 6 sub-kind 3 MISSED cases stop being flagged, including the new dead-computed case (row 14, which also needs a local binding to exist at all) |
| 6 | Sub-kind 3: computed-sibling exclusion (the `computed_seen.add` call itself, reachability check left in place) | 31/32 | 1 CLEAN case becomes wrongly flagged (`wasAdjusted`); unaffected by the fourth round's reachability addition, since that addition guards entry INTO this line, not the line itself |
| 7 | Sub-kind 3: Swift computed-property detection | 31/32 | 1 Swift MISSED case stops being flagged |
| 8a | Sub-kind 1: whole config-struct exclusion | 31/32 | 1 CLEAN case becomes wrongly flagged |
| 8b | Sub-kind 1: whole store-family protection | 29/32 | 3 MISSED cases stop being flagged (the original `push_back` seed shape, the arrow-notation case, and the multi-argument `insert` case) |
| 8c | Sub-kind 1: bare-`return` protection | 31/32 | 1 MISSED case stops being flagged, the "handed to a call AND returned" case |
| 8d | Sub-kind 1: array-element-assignment protection | 31/32 | 1 MISSED case stops being flagged, the "handed to a call AND copied into an array element" case |
| 8e | Sub-kind 1: paren-depth-balanced argument scan (swapped for naive `[^()]*`) | 29/32 | 2 CLEAN/MISSED cases affected: the config-struct case wrongly flagged again, and the multi-argument `insert` case stops being flagged. Confirmed on the real corpus too: report count moves 49 to 53. |
| 9 | Sub-kind 3: braceless if-false specifically (braced form left intact) | 31/32 | 1 MISSED case stops being flagged, the braceless one only |
| 10 | Sub-kind 1: arrow-notation recognition specifically (dot-only reinstated) | 31/32 | 1 MISSED case stops being flagged, the pointer-container case only |
| 11 | Sub-kind 1: multi-argument recognition specifically (single-argument-only reinstated) | 31/32 | 1 MISSED case stops being flagged, the two-argument `insert` case only |
| 12 | Sub-kind 1: `CALL_START` keyword/`sizeof` exclusion | 31/32 | 1 MISSED case stops being flagged, the `sizeof` case |
| 13 | Sub-kind 1: `FIELD_ASSIGN` arrow/array-index matching (dot-only reinstated) | 31/32 | 1 MISSED case stops being flagged, the pointer-out-param result case |
| 14 | Sub-kind 3: reachability check on the COMPUTED branch specifically (`true`-branch check left intact) | 31/32 | 1 MISSED case stops being flagged, the dead-if-false-guarded computed assignment case only |
| 15 | Sub-kind 3: local pointer/reference declaration binding specifically (`local_bind` reverted to value-typed-only, `param_bind` left intact) | 31/32 | 1 CLEAN case becomes wrongly flagged, the local-pointer-alias case only |

Every row drops the count and no two rows are redundant. Two sub-kind-3 CLEAN cases (the two
correctly-flipping baselines) and one control (the "reachable true under a real condition" case)
are not tied to a single row; they guard the shared base-recognition path every row relies on and
would only fail if that broke. Recorded explicitly, per the second review round's own question
about whether any case's rule could be deleted without the count dropping: none of the 32 has that
property.

**Row 5 was flagged in the fourth review round as covering only the value-typed form**, since
before that round `local_bind` had no pointer/reference branch at all, so disabling "local
declaration binding" and disabling "value-typed local declaration binding" were the same
experiment: a matrix row that can only exercise one of two shapes reads as covering both when it
covers one. Row 5 above now disables the WHOLE mechanism (both forms at once, since after the fix
they are one regex with two branches) and row 15 isolates the pointer/reference branch on its own,
closing that gap directly rather than leaving it as a documented limitation of the matrix.

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
same three shapes `ASSIGN_ANY` does. A dedicated self-test case (row 13 above) proves it, modelled
on a real site, `OCCTBridge_Geom2d.mm`'s `extractBisecSolution`.

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
for a shared helper's own POINTER PARAMETER (row 4); the review's framing was apt: a detector that
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
