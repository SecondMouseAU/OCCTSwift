# OCCTSwift#771: sub-kind 3 (gate flags that never flip) — census run and triage

## Baseline

Two baselines matter here, because the branch moved under this work.

Branched from `origin/refactor/381-pass1b` at `809f148`, where PR #770 (the `hasExtent` fix) was
still open. Sub-kind 3 was built and its first real run against the corpus was taken against that
pre-#770 tree: 7 candidates, including all three `hasExtent` call sites, exactly what a correct
detector should report against code that has the defect. **PR #770 merged partway through this
work** (`ad1078e`, `2026-08-07T17:57:52Z`). `origin/refactor/381-pass1b` was merged into this branch
afterward to pick up the fix, and every number below the "First run" note is taken **after** that
merge, against the corpus with `hasExtent` already fixed.

The self-test does not depend on either baseline: every sub-kind 3 fixture is a synthetic
(header, source) pair, not a read of the live tree, so `hasExtent`'s pre-fix shape stays available
as a positive case regardless of what the real corpus looks like after #770.

## What sub-kind 3 detects

A boolean field, declared on any `typedef struct { ... } Name;` / `struct Name { ... };` in
`Sources/OCCTBridge/` (not filtered by field name), that is assigned literal `false` somewhere in
the corpus and literal `true` nowhere reachable — reachable meaning not inside an `if (false)` /
`if (0)` / `while (false)` / `while (0)` block, and not dead code following an unconditional
`return`/`continue`/`break`/`throw` in the same straight-line block. A field with any non-literal
(computed) assignment anywhere is treated as not provably stuck, since the census cannot evaluate
whether that expression can produce `true`. Binding a local identifier to a known struct type
recognises a plain local declaration and a pointer or reference parameter, so a shared helper that
flips the field through `->`/`&` is caught with no special-casing for "this is a helper". A separate,
narrower detector covers the Swift side: a `var x: Bool { ... }` computed property that returns
`false` somewhere and `true` nowhere in its body.

Full algorithm and worked examples are in `Scripts/census-unmeasured-values.py`'s module docstring,
under `SUB-KIND 3 ALGORITHM`.

## What it does not detect, and why

Recorded in the script's own `WHAT SUB-KIND 3 STILL CANNOT SEE` section; summarised here:

| Gap | Why not taught |
|---|---|
| A `kind`-style enum with a never-emitted "gate open" case | Needs the full declared case list per enum plus which case means "open", which is semantic, not syntactic — a fundamentally different question from a 2-valued bool. |
| A helper that takes the struct **by value** and returns a modified copy | Only pointer/reference parameters bind a type, deliberately: a byval parameter cannot affect the caller's instance the way "pointer, reference or helper" describes, and accepting it raises the risk of crediting an orphaned, never-called byval helper as if it were live evidence. |
| A cast-based alias (`((T*)ptr)->field = true;`) | Same gap `check-null-handle-guards.py` documents for its own four indirection shapes (#618): the binding regex looks for the type name directly adjacent to the variable, not behind a cast. |
| A more elaborate always-false condition (`if (1 == 2)`, a false-valued macro, `#if 0`, an unreached `switch` case) | Only the literal spellings `false` and `0` are recognised as an always-false condition. |
| A Swift **stored** property mutated across multiple methods | The closer analogue of the C struct case, but it would need the same corpus-wide type-binding machinery applied to Swift class/struct declarations and their methods — a bigger lift than a single self-contained function body, not attempted this pass. |
| Swift dead-code exclusion (if-false / dead-after-return) | Swift conditionals are commonly braceless and paren-less (`if x > 0 {`), which the C-oriented brace/paren-counting machinery does not parse, so the Swift detector only checks for bare `return true`/`return false` literal presence. |
| Call-graph reachability in general | The census is corpus-wide and per-function, not whole-program: a `true` assignment inside a function that is itself never called anywhere is still counted as "the field can be true". See the Bisector finding below for a real instance of exactly this ambiguity. |

## Self-test and removal matrix

25/25 cases pass: the 10 pre-existing sub-kind 1/2 cases plus 3 new sub-kind 1 cases (see the
sub-kind 1 improvement below), plus 12 new sub-kind 3 cases (4 `GATE_MISSED`, 6 `GATE_CLEAN`, 1
`SWIFT_GATE_MISSED`, 1 `SWIFT_GATE_CLEAN`).

Per `okf/policies/prove-the-test-fails.md`, every mechanism this PR added was disabled in turn in a
working copy of the script, `--self-test` re-run, the case-count drop recorded, and the file
restored from an untouched backup before the next probe. Twelve rows, none decorative — every one
drops the correct-case count and no two rows are redundant:

| # | Rule disabled | Cases correct | What flipped |
|---|---|---|---|
| — | (baseline) | 25/25 | — |
| 1 | Sub-kind 3: name-prefix independence (bool-field scan restricted to `has*`) | 22/25 | 3 MISSED cases stop being flagged: the seed shape's non-`has` sibling (field `defined`) plus the two dead-`true` cases, which incidentally also use a non-`has` field name |
| 2 | Sub-kind 3: dead-after-terminator exclusion | 24/25 | 1: the dead-after-`return` MISSED case stops being flagged |
| 3 | Sub-kind 3: dead-if-false exclusion | 24/25 | 1: the `if (false)` MISSED case stops being flagged |
| 4 | Sub-kind 3: pointer/reference parameter binding | 23/25 | 2: both helper-indirection CLEAN cases (pointer, reference) become **wrongly flagged** |
| 5 | Sub-kind 3: local value-typed declaration binding | 21/25 | 4: every sub-kind 3 MISSED case stops being flagged |
| 6 | Sub-kind 3: computed-sibling exclusion | 24/25 | 1: the `wasAdjusted`-shaped CLEAN case becomes **wrongly flagged** |
| 7 | Sub-kind 3: Swift computed-property detection | 24/25 | 1: the Swift MISSED case stops being flagged |
| 8a | Sub-kind 1: whole `is_input_only_struct` config-struct exclusion | 24/25 | 1: the config/options-struct CLEAN case becomes **wrongly flagged** |
| 8b | Sub-kind 1: `push_back`-family protection inside that exclusion | 24/25 | 1: the pre-existing `ShapeAxis`-shaped MISSED case **regresses** (the exact seed shape this whole census exists to catch) |
| 8c | Sub-kind 1: bare-`return` protection inside that exclusion | 24/25 | 1: a dedicated "handed to a call AND returned" MISSED case stops being flagged |
| 8d | Sub-kind 1: array-element-assignment protection inside that exclusion | 24/25 | 1: a dedicated "handed to a call AND copied into an array element" MISSED case stops being flagged |
| 8e | Sub-kind 1: `call_arg_lists`'s paren-depth balancing (swapped for a naive `[^()]*` capture) | 24/25 | 1: the config/options-struct CLEAN case becomes **wrongly flagged** again, for a different reason than 8a — the real corpus check confirms this isn't synthetic-only: the naive regex still excludes the one config-struct site with no nested cast (`MathInteg::KronrodConfig`) but wrongly re-includes all four `BRepGraph::ShapesView::Options` sites, each of which passes `opts` behind a `*(const TopoDS_Shape*)shape` cast argument — sub-kind 1's report count moves 49 → 53 |

Three sub-kind-3 self-test cases — the two correctly-flipping baselines (`hasExtent`-named and
non-`has`-named) and the "reachable `true` under a real condition" control — are not tied to any
single row above; they instead guard the base recognition path itself (plain `var.field = true`
matching, and the false-condition check not over-firing on a genuine condition) and would only fail
if that shared foundation broke, which every row implicitly exercises by relying on it. This is
recorded rather than left implicit: a self-test case can look like coverage without a removal
proving it (#744), and this review explicitly asked whether any case's rule could be deleted without
the count dropping. None of the 25 cases has that property: every one either appears as a
MISSED/FALSE flip in a row above, or is one of these three explicitly-noted controls whose failure
mode is "the shared foundation broke", not "no rule was ever exercised".

## Candidates found and verdicts (post-#770-merge baseline)

3 candidates from `--gate-flags` against the current baseline. Adjudicated using #763's four
verdicts (1. not an instance, 2. compute it, 3. make absence representable, 4. remove the field):

| Candidate | Struct.field | Verdict | Evidence |
|---|---|---|---|
| `OCCTBridge_Mesh.mm:201` `OCCTMeshParametersDefault` | `OCCTMeshParameters.relative` | **1 (not an instance)** | `OCCTMeshParametersDefault()` is a plain default-value factory for a config/options struct passed as an **argument** to `OCCTShapeCreateMeshWithParams`, not read back as a measurement — the same "local config/options struct" and "plain value-type constructor" exclusions sub-kind 1's own docstring already establishes for `OCCTXCAFPrsStyleCreate`. Confirmed genuinely settable, not stuck: `Sources/OCCTSwift/Mesh.swift`'s `MeshParameters` has a public, mutable `var relative: Bool` that a caller sets directly, and `params.relative = relative` (`Mesh.swift:87`) forwards it into the bridge struct at the real call site. |
| `OCCTBridge_Mesh.mm:205` `OCCTMeshParametersDefault` | `OCCTMeshParameters.adjustMinSize` | **1 (not an instance)** | Same reasoning; `Mesh.swift:91` (`params.adjustMinSize = adjustMinSize`). |
| `OCCTBridge_Mesh.mm:206` `OCCTMeshParametersDefault` | `OCCTMeshParameters.allowQualityDecrease` | **1 (not an instance)** | Same reasoning; `Mesh.swift:92` (`params.allowQualityDecrease = allowQualityDecrease`). |

**No verdict-3/verdict-4 instance beyond the seed `hasExtent`, which #770 already fixed.** Before
the #770 merge, this same run also reported `OCCTShapeAxis.hasExtent` at all three call sites
(verdict 3, already fixed there) and `OCCTBisectorPointOnBis.isInfinite` (verdict 4, fixed in this
PR, see below) — 7 candidates total pre-merge, now 3. The `hasExtent` disappearance is the expected,
correct effect of merging in a fix that shipped on a sibling branch, not something this detector did
wrong: **not an instance of it undercounting**, it is the census correctly reflecting a corpus that
changed underneath it.

What the detector would have caught had `hasExtent` not already had a fix in flight: exactly the
`GATE_MISSED` self-test shape it does catch, run against real code — three literal-`false` call
sites, one struct type, zero literal-`true` or computed assignments anywhere in the corpus, reported
by file and line with no name-prefix filtering required to find it. That shape is preserved as a
synthetic self-test fixture specifically so this detector keeps a real positive case even now that
the live tree no longer has one.

### `BisectorPoint`/`OCCTBisectorPointOnBis`/`OCCTBisectorPointOnBisCreate` removed (verdict 4)

Found against the pre-#770-merge baseline (unaffected by the merge; unrelated file). Verified
independently before removing (`okf/policies/measure-dont-assume.md`), not just cited from #763's
earlier one-line note on the same function: read `Bisector_PointOnBis.hxx` from the pinned OCCT
xcframework headers directly. The OCCT class has a real, settable `IsInfinite`/`IsInfinite() const`
pair — the concept is genuine — but `OCCTBisectorPointOnBisCreate` never constructs a
`Bisector_PointOnBis` at all; it echoes 6 raw doubles into a plain C struct with no reference to the
OCCT class. Grepped the whole tree: zero Swift call sites for the bridge function, zero constructor
call sites for the Swift `BisectorPoint` struct it built for, and `BisectorPoint` has no explicit
`public init` (only `public let` fields), so Swift's auto-synthesized memberwise initializer for a
`public struct` is `internal`, not `public` — no external consumer of `OCCTSwift` could construct
one either. Fully orphaned on both sides, matching the #506/PR #547 precedent ("an orphan freezes
its contract") in this same codebase.

Removed: the bridge struct + function (`OCCTBridge_Geom2d.h`/`.mm`, tombstone comments in the
`#500`/`#506` idiom already used elsewhere in that header), the Swift struct
(`BisectorResult.swift`), and its two doc references (`docs/reference/Shape-Recognition.md`,
`docs/API_REFERENCE.md`'s Bisector Intersection row count 2 → 1). `BisectorIntersection`/
`bisectorIntersections(a:b:c:d:)`, the live pair in the same file, are untouched.
`Scripts/count-operations.py`'s derived total is unaffected (4306 before and after): `BisectorPoint`
had no public `func`/computed `var`/`init`/`subscript`, so it was never counted.

**No injection cycle for this fix**, matching PR #770's own precedent for the `selfIntersectionCount`
removal: it is a field/type deletion enforced by the compiler (any surviving reference fails to
build), not a new positive behavioural check to prove wrong-then-right.

## Bonus finding folded in: sub-kind 1's option-struct false positives

Not part of #771's own ask, but surfaced while adjudicating sub-kind 1's other candidates for
comparison and cheap enough to fix in the same script, in the same PR. The single largest group of
noise in sub-kind 1's 54 pre-fix candidates was a local config/options struct built and handed to a
call as an argument (`opts.Flatten = true;` then `Add(shape, opts)`), which is syntactically
identical to a real result struct being built up field by field — the script's own docstring had
already named this exact shape as an unaddressed blind spot, with 5 known sites
(`BRepGraph::ShapesView::Options` x4, `MathInteg::KronrodConfig` x1).

**Fixed**, `is_input_only_struct()`: a tracked local variable is excluded from sub-kind 1 candidacy
if it is handed to some call as a bare argument and never surfaces afterward — "surfaces" meaning a
bare `return var;`, storage into a container (`push_back`/`emplace_back`/`push_front`/
`emplace_front`/`insert`), or a direct `arr[i] = var;` copy into an array/vector element. Any one of
those three protections wins over the exclusion. This had to be built carefully rather than
naively, for two reasons proven by the removal matrix above: (1) the exact seed shape this whole
census exists to catch, `OCCTShapeAxis a` built in a loop then `collected.push_back(a)`, is *also*
"handed to a call as a bare argument" (to `push_back`) — a naive version of this rule would have
made sub-kind 1 blind to the seed defect it was built to find, in the unsafe direction #726
explicitly warns this whole workstream against; and (2) a naive `[^()]*` argument-list capture
cannot see an argument sitting behind a nested cast (`Add(*(const TopoDS_Shape*)shape, opts)`), so
3 of the 5 real sites would have gone unexcluded without a proper paren-depth-matched extractor
(`call_arg_lists`, reusing the same balanced-walk style `catch_spans`/`conditional_brace_positions`
already use for braces).

Measured: sub-kind 1's report count on this tree drops from 54 to 49 candidates — exactly the 5
known sites, confirmed by diffing the full before/after listing rather than just the totals; nothing
else in the list moved.
