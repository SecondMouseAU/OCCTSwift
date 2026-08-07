# OCCTSwift#771: sub-kind 3 (gate flags that never flip) — census run and triage

`census-unmeasured-values.py --gate-flags` (sub-kind 3, added by this issue) run against
`refactor/381-pass1b` at `809f148`. **PR #770 (the `hasExtent` fix) is open, not merged, as of this
run** — `git log --oneline -5 origin/refactor/381-pass1b` shows `809f148` at the tip, and
`gh pr view 770 --json state,mergedAt` reports `"state":"OPEN","mergedAt":null`. That baseline
matters for reading the table below: `hasExtent` is expected to still be reported here, because the
fix for it lives on a sibling, not-yet-merged branch, not because sub-kind 3 failed to notice it was
already fixed.

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

22/22 cases pass (10 pre-existing sub-kind 1/2 cases, unchanged, plus 12 new sub-kind 3 cases: 4
`GATE_MISSED`, 6 `GATE_CLEAN`, 1 `SWIFT_GATE_MISSED`, 1 `SWIFT_GATE_CLEAN`).

Per `okf/policies/prove-the-test-fails.md`, each of the seven mechanisms sub-kind 3 relies on was
disabled in turn in a working copy of the script, `--self-test` re-run, the case-count drop
recorded, and the file restored from an untouched backup before the next probe:

| Rule disabled | Cases correct | Cases flipped |
|---|---|---|
| (baseline) | 22/22 | — |
| 1. Name-prefix independence (bool-field scan restricted to `has*`) | 19/22 | 3 MISSED cases stop being flagged: the seed shape's non-`has` sibling (field `defined`) plus the two dead-`true` cases, which incidentally also use a non-`has` field name |
| 2. Dead-after-terminator exclusion | 21/22 | 1: the dead-after-`return` MISSED case stops being flagged (its `true` is wrongly counted as live) |
| 3. Dead-if-false exclusion | 21/22 | 1: the `if (false)` MISSED case stops being flagged |
| 4. Pointer/reference parameter binding | 20/22 | 2: both helper-indirection CLEAN cases (pointer, reference) become **wrongly flagged**, since their only `true` assignment is no longer attributed to the struct type |
| 5. Local value-typed declaration binding | 18/22 | 4: every MISSED case stops being flagged, since none of their local variables bind to a struct type at all any more |
| 6. Computed-sibling exclusion | 21/22 | 1: the `wasAdjusted`-shaped CLEAN case becomes **wrongly flagged** |
| 7. Swift computed-property detection | 21/22 | 1: the Swift MISSED case stops being flagged |

Every one of the seven rows drops the correct-case count, and no two rows are redundant (each
targets a distinct case or case-pair). Three sub-kind-3 self-test cases — the two correctly-flipping
baselines (`hasExtent`-named and non-`has`-named) and the "reachable `true` under a real condition"
control — are not tied to any single row above; they instead guard the base recognition path itself
(plain `var.field = true` matching, and the false-condition check not over-firing on a genuine
condition) and would only fail if that shared foundation broke, which every row implicitly exercises
by relying on it. This is recorded rather than left implicit, per the #744 lesson that a
self-test case can look like coverage without a removal proving it is.

## Candidates found and verdicts

7 candidates from `--gate-flags` against this baseline. Adjudicated using #763's four verdicts (1.
not an instance, 2. compute it, 3. make absence representable, 4. remove the field):

| Candidate | Struct.field | Verdict | Evidence |
|---|---|---|---|
| `OCCTBridge_Topology.mm:653` `OCCTShapeRevolutionAxes` | `OCCTShapeAxis.hasExtent` | **3 (already in progress)** | The #763 seed instance. Fixed on PR #770 (`chore/763-triage-core`, open against this same base, not merged). Not duplicated here — see baseline note above. |
| `OCCTBridge_Topology.mm:694` `OCCTShapeSymmetryAxes` | `OCCTShapeAxis.hasExtent` | **3 (already in progress)** | Same field, second call site. Same fix, same PR. |
| `OCCTBridge_Topology.mm:713` `OCCTShapeSymmetryAxes` | `OCCTShapeAxis.hasExtent` | **3 (already in progress)** | Same field, third call site. Same fix, same PR. |
| `OCCTBridge_Geom2d.mm:2593` `OCCTBisectorPointOnBisCreate` | `OCCTBisectorPointOnBis.isInfinite` | **4 (remove)** | Verified independently (not just cited from #763's earlier note on the same function): `Bisector_PointOnBis`'s bundled OCCT header (`Bisector_PointOnBis.hxx`) has a real, settable `IsInfinite`/`IsInfinite() const` pair, so the concept is genuine on the OCCT class — but `OCCTBisectorPointOnBisCreate` never constructs a `Bisector_PointOnBis` at all; it echoes 6 raw doubles into a plain C struct with no reference to the OCCT class. Grepped the whole tree: zero Swift call sites for `OCCTBisectorPointOnBisCreate`, zero constructor call sites for the Swift `BisectorPoint` struct it builds for, and `BisectorPoint` has no explicit `public init` (only `public let` fields), so Swift's auto-synthesized memberwise initializer for a `public struct` is `internal`, not `public` — meaning no external consumer of the `OCCTSwift` library could construct one either. Fully orphaned on both sides, matching the #506/PR #547 precedent ("an orphan freezes its contract") for this exact codebase. Removed by this PR (bridge struct + function, Swift struct, both doc references). |
| `OCCTBridge_Mesh.mm:201` `OCCTMeshParametersDefault` | `OCCTMeshParameters.relative` | **1 (not an instance)** | `OCCTMeshParametersDefault()` is a plain default-value factory for a config/options struct passed as an **argument** to `OCCTShapeCreateMeshWithParams`, not read back as a measurement — the same "local config/options struct" and "plain value-type constructor" exclusions sub-kind 1's own docstring already establishes for `OCCTXCAFPrsStyleCreate`. Confirmed genuinely settable, not stuck: `Sources/OCCTSwift/Mesh.swift`'s `MeshParameters` has a public, mutable `var relative: Bool` that a caller sets directly, and `params.relative = relative` (`Mesh.swift:87`) forwards it into the bridge struct at the real call site. |
| `OCCTBridge_Mesh.mm:205` `OCCTMeshParametersDefault` | `OCCTMeshParameters.adjustMinSize` | **1 (not an instance)** | Same reasoning; `Mesh.swift:91` (`params.adjustMinSize = adjustMinSize`). |
| `OCCTBridge_Mesh.mm:206` `OCCTMeshParametersDefault` | `OCCTMeshParameters.allowQualityDecrease` | **1 (not an instance)** | Same reasoning; `Mesh.swift:92` (`params.allowQualityDecrease = allowQualityDecrease`). |

**No new verdict-3/verdict-4 instance beyond the seed.** The one genuine new finding
(`OCCTBisectorPointOnBis.isInfinite`) turned out to be dead code around an orphaned function rather
than a stuck gate on a live path — a different root cause than `hasExtent`'s, caught only because
teaching the detector past the `hasX` name filter (indirection shape 1) surfaced a non-`has`-named
field the naive pass could never have seen (the naive pass was scoped to `hasX`-declared fields in
headers to begin with). What the detector would have caught had `hasExtent` not already had an
open fix in flight: exactly the `GATE_MISSED` self-test shape it does catch, run against real code —
three literal-`false` call sites, one struct type, zero literal-`true` or computed assignments
anywhere in the corpus, reported by file and line with no name-prefix filtering required to find it.

## Fix implemented

Removed the orphaned `OCCTBisectorPointOnBis` struct, `OCCTBisectorPointOnBisCreate` bridge
function, and the Swift `BisectorPoint` struct built for it:

- `Sources/OCCTBridge/include/OCCTBridge_Geom2d.h`: struct + declaration replaced with a tombstone
  comment (the `#500`/`#506` idiom already used elsewhere in this header for a prior removal).
- `Sources/OCCTBridge/src/OCCTBridge_Geom2d.mm`: implementation replaced with a tombstone comment.
- `Sources/OCCTSwift/BisectorResult.swift`: `BisectorPoint` struct removed (tombstone comment left
  in its place); `BisectorIntersection` and `bisectorIntersections(a:b:c:d:)`, the live pair in the
  same file, are untouched.
- `docs/reference/Shape-Recognition.md`: `BisectorPoint` subsection removed from "Bisector
  utilities".
- `docs/API_REFERENCE.md`: "Bisector Intersection" row count corrected from 2 to 1
  (`bisectorIntersections` only).

**No injection cycle for this fix**, matching PR #770's own precedent for the `selfIntersectionCount`
removal: it is a field deletion enforced by the compiler (any surviving reference fails to build),
not a new positive behavioural check to prove wrong-then-right. `Scripts/count-operations.py`'s
derived total is unaffected (4306 before and after): `BisectorPoint` had no public `func`, computed
`var`, `init`, or `subscript` to begin with, so it was never counted as an operation.

Verified before removing, not assumed (`okf/policies/measure-dont-assume.md`): read
`Bisector_PointOnBis.hxx` from the pinned OCCT xcframework headers directly rather than trusting
#763's PR-770 note that the function "has no IsInfinite parameter" at face value — confirmed the
class's real constructor list (default, and a 5-arg `Param1/Param2/ParamBis/Distance/Point`
constructor, neither taking an `Infinite` argument) and that `IsInfinite`/`IsInfinite() const` exist
as a genuine, separately-set property on the class, which is what makes this a "dead code around a
real concept" finding rather than a "the concept never existed" one.
