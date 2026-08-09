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

## How to apply

For a test: break the code it covers, run it, see red, restore, see green.

For a detector's `--self-test`: remove each guard in turn, run the self-test, confirm the case
count drops, restore. If removing a guard leaves the count unchanged, that case is decorative and
needs rewriting, not celebrating.

Report the matrix. A table of "guard removed" against "cases correct" is short, and it is the
difference between a reviewer trusting the suite and taking your word for it.

## Related

- [Measure, do not assume, and verify with a second construction](measure-dont-assume.md). That is
  the weaker, more general rule; this one is what a *detector* additionally needs, because a blind
  detector reports clean exactly as confidently as a clean tree.

- [Documentation updates are mandatory](docs-current.md)
- [Search before building](search-before-building.md)
- `CLAUDE.md` → Test Conventions, for the repo-specific test rules this sits alongside.
