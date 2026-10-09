---
type: policy
title: Prove the test fails
description: A passing test is worth nothing until you have watched it fail. Inject the defect it exists to catch, confirm the failure, restore, and report both results.
tags: [policy, testing, detectors, gates, agents]
timestamp: 2026-08-04
---

# Prove the test fails

**Every new test, and every new `--self-test` case, is run once with its subject broken.** Inject
the defect the test exists to catch, confirm it fails, restore, confirm it passes. Report both
results in the PR, not just the green one.

This applies ecosystem-wide, not only the OCCT/OCCTSwift stack. It applies most sharply to
*detectors*: gate scripts, census scripts, linters, anything whose output is "all clear".

## Why

A detector reporting "all clear" because it is blind is indistinguishable from one reporting "all
clear" on a clean tree. Nothing in a green run tells the two apart. The removal check is the only
thing that does.

This is written down because it is a failure this repo keeps having, not because it is good
practice in the abstract:

- Three gate scripts were confidently wrong while reporting all clear: #618, #624, #626.
- `check-null-handle-guards.py` was blind to the shape that produced #656's uncatchable SIGSEGV. It
  checks a bridge function's own handle *arguments*, not a handle obtained locally and passed
  onward, so every gate passed on the crash.
- `derive-swift-file-split.py` never matched a top-level `func`, so free functions were invisible.
  #659 found nine of them by hand, by diffing every top-level line against the ranges the census
  did report.
- `derive-shape-domain-split.py` had no brace-depth check and counted local variables and
  nested-type fields as members: 557 reported against a real 446, and 93 "untested" members against
  a real 17. That wrong number was quoted as a finding before anyone measured it.

## The part that is easy to miss

Adding a `--self-test` is not the rule. Watching it fail is.

`derive-shape-domain-split.py` grew a `--self-test` that passed 6/6 while one of its cases proved
nothing, **twice in a row**:

1. First the block-comment fixture sat *outside* the region the scanner tracks, so the guard it was
   meant to exercise never ran.
2. Then it sat inside, but its braces balanced across the block, so removing the guard changed no
   outcome.

Both versions looked exactly like coverage. Only removing the guard and watching the test still
pass revealed they were not, and a third pass found the guard itself had an adjacent hole where a
closing `*/` shared a line with real code (#680).

## A green removal row is ambiguous, not reassuring

Removing a guard and seeing nothing fail has two explanations, and the count alone cannot tell them
apart: the guard does nothing, or **something else is standing in front of it**. Three instances in
one day, 2026-08-07:

- **A guard masked by a different bug.** `#762`'s `.convex` block came back green under removal, was
  called decorative, and a geometric argument was written for why it could never matter. Fixing an
  unrelated defect two functions away, a `visited` marking that fired before the wall/junction
  decision, made the same removal fail two tests. The argument had been describing the bug.
- **Two guards backstopping each other.** In the same walk, removing the Z-tolerance bypass and
  removing the `.convex` block each hid the other's effect, so neither injection isolated anything,
  and nor did removing both together.
- **A row exercising one of two mechanisms.** `#771`'s row 5 used only value-typed fixtures, so
  "disable local binding" and "disable value-typed binding" were the same experiment. The row was
  green for a reason unrelated to its label.

So state, per row, **which mechanism it isolates and how you know**. Disjointness is the usual
evidence: `#762`'s injection E fails exactly two tests of 34, and those two also fail under an
unrelated row, so only the disjointness distinguishes isolation from coincidence.

A row that adds nothing is worth keeping if it is labelled as adding nothing. `#762`'s row D
produces the same failure set as row B and says so, which answers a real question rather than
padding the table.

## A matrix proves guards, not fixtures

These are different claims and it is easy to offer the first as evidence for the second. I did, on
2026-08-07, and the injection corrected me within the hour.

A removal matrix modifies the **source**. A fixture that has stopped meaning its name is a property
of the **test**, and a matrix cannot see it: with a dud fixture, the affected rows simply fail fewer
tests, which shows up as a changed count nobody is comparing rather than as a failure.

Measured, in `#762`'s own suite: replacing one `filleted(...)` with the unfilleted shape, so the
fillet silently does nothing, left **all 15 tests passing**. A no-op fillet leaves the sharp pocket,
and the sharp pocket is the control fixture that reports the same one pocket, four walls, not open.
Every assertion downstream was reading a fixture that had stopped meaning its name, in a suite
written specifically to avoid that.

So a test whose subject is an operation needs an assertion that **the operation did something**,
separate from any guard the matrix covers. `try #require(op())` proves non-nil, not non-trivial. A
cheap structural delta works: `#762` asserts the face count rose, since a fillet or chamfer replaces
each target edge with at least one new face.

### A fixture can be absent rather than wrong

That is the same blindness one step further out, and it is worse, because there is nothing to
inspect. `#2830`: a matrix fixture list appended its `"openShell"` entry inside an `if let` on a
call that returns nil for every input it was ever given, so the list was one row short from the day
the fixture was written. Measured, 9 fixtures against the 10 the comment described, for the whole
life of the fixture. No assertion downstream could see it and no injection into the source could
either: the row was not wrong, it was missing, and a matrix that walks a list reads a missing row as
a smaller loop.

So a list a matrix walks needs its **membership** asserted, against a declared set of names rather
than a count, and every fallible fixture factory needs to throw rather than fall back or be skipped.
A `?? input` fallback and an `if let` append are the two shapes to look for; both read as defensive
and both are the defect.

## A setup step is required, not escaped

`guard let x = ... else { return }` and a bare `if let x = x { ... }` wrapped around a test's body
are production shapes, and in a test each one is an escape: Swift Testing records a **pass** for a
function that executed no expectation at all. A test built that way is falsifiable against the one
thing it names and unfalsifiable against everything upstream of it.

`try #require` is the same one-liner and turns each escape into a failure that names itself. It is
also what `CLAUDE.md`'s "never force-unwrap in `#expect`" asks for: that rule is against `result!`
reaching a non-short-circuiting `#expect`, not against requiring the value.

Measured, in `Tests/OCCTXCAFTests/ShapeTool/ShapeToolCompletionsTests.swift` (#2794, fixed in PR #2800). All
nine tests in the suite opened with the same three-deep chain:

```swift
guard let doc = Document.create() else { return }           // passes silently
if let box = Shape.box(width: 10, height: 10, depth: 10) {  // passes silently
    let labelId = doc.addShape(box)
    if labelId >= 0 {                                       // passes silently
        #expect(doc.shapeToolIsFree(labelId: labelId))
```

A `Document.create()` that starts returning nil, a `Shape.box` that starts returning nil, or an
`addShape` that starts returning `-1` makes all nine pass having executed nothing, with no
diagnostic anywhere. The record certifying them was accurate in every column and could not see
this, because every injection in it substituted a wrong **return value** in the bridge function
under test, which leaves the chain intact. So every row was a real expectation failure at a named
line, and not one of them asked whether the expectation was reachable at all.

Two shapes to reject on sight, in review as well as in authoring:

- **A setup step a test escapes rather than requires.** Each escape becomes a `try #require` with a
  message saying what was not there.
- **A test whose only failure mode is a crash.** A subject returning `void` is asserted on the
  state afterwards. Where there is genuinely nothing observable, the test says what was looked for
  and why it is not there, rather than "just check it doesn't crash".

An escape also hides the missing control. Six of those nine subjects assert `false` or `0`, and
`false` and `0` are what the same bridge functions return for a label they cannot resolve, so the
suite needed `findShape(box) == labelId` as independent proof that the label exists and holds the
box before any of its negative assertions meant anything.

`Scripts/census-766-weak-assertions.py` reports the shape, as SEVERE and ESCAPABLE counts over a
file list. It is a census and not a gate because every shape it reads is sometimes correct, and it
has four known blind spots (#2964, #2982, #2985, and a nil-skip whose `else` records nothing), so
a clean count is a reading order rather than a verdict.

## How to apply

For a test: break the code it covers, run it, see red, restore, see green.

For a detector's `--self-test`: remove each guard in turn, run the self-test, confirm the case
count drops, restore. If removing a guard leaves the count unchanged, that case is decorative and
needs rewriting, not celebrating.

Report the matrix. A table of "guard removed" against "cases correct" is short, and it is the
difference between a reviewer trusting the suite and taking your word for it.

## A red row is a reason to keep going, not a reason to stop

**Pin the measured answer whether or not the test already caught the injection.** A red row proves
the test notices the one defect you picked and says nothing about any other, and four weaknesses
survive it:

- a fixture bound by `if let`, or by a `guard let` whose `else` sits on a later line, with no
  `else` branch that records a failure: no arithmetic injection can produce the nil that skips
  every assertion;
- `count >= 1` where the answer is exactly 1: a value injection changes a value, never a count;
- a tolerance window wide enough to swallow a real error but not the injection's delta, such as
  `0.1` on a square distance of 25 against a `+1.0` injection;
- a two-boolean test on one fixture, where inverting the verdict is red and wiring it to a
  constant is green, because the test has no control requiring the opposite answer.

[#2679](https://github.com/SecondMouseAU/OCCTSwift/pull/2679) used the injection row's colour as
its rewrite trigger: it rewrote the four tests that stayed green under their injection and left the
three that went red byte for byte. All three carried the first two weaknesses and between them
they carried all four (#2941). That is not
one PR's slip. Measured over the 403 PRs merged into `v5.0.0-766-execution`, **300 of the 339 that
recorded a Red row left at least one of those tests unchanged, and 266 of them are still weak on
`main`** (#2970).

**For a sweep of any size, read
[Injection sweep mechanics](../references/injection-sweep-mechanics.md) first.** It is how to run
one cheaply (the built `.xctest` through `swiftpm-testing-helper` is 0.5 s against `swift test`'s
1.5 to 5 minutes under load) and how to stop it lying to you: inject by shadowing the bridge
import rather than editing a `.mm`, resolve every anchor uniquely before the first build, and
assert the switch set against the test set in both directions.

## Related

- [Measure, do not assume, and verify with a second construction](measure-dont-assume.md). That is
  the weaker, more general rule; this one is what a *detector* additionally needs, because a blind
  detector reports clean exactly as confidently as a clean tree.

- [Documentation updates are mandatory](docs-current.md)
- [Search before building](search-before-building.md)
- `CLAUDE.md` → Test Conventions, for the repo-specific test rules this sits alongside.
