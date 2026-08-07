---
type: policy
title: Measure, do not assume, and verify with a second construction
description: Derive nothing about a subject from its parameters, its name, or its documentation when you can observe it. When checking a result, rebuild the subject a different way, and prove the two constructions agree on everything except the thing under test.
tags: [policy, measurement, verification, fixtures, agents]
timestamp: 2026-08-07
---

# Measure, do not assume, and verify with a second construction

Two rules, and the second is the one that is easy to skip.

1. **Measure the subject. Do not derive it from its parameters, its identifier, or its
   documentation.** If the thing can be observed, observe it.
2. **When checking a result, rebuild the subject a different way.** A second construction that
   agrees is real corroboration. A second construction that disagrees has found something. But
   prove the two constructions match on everything except the property under test, or the
   disagreement is your own.

## Why

Every entry below is from a single day, 2026-08-06 to 2026-08-07, on this branch.

**Derived from parameters instead of measured.** `Wire.helix`'s default `clockwise: false` reverses
the internal build axis, so the wire starts at `(-r, 0, 0)` descending, not `(r, 0, 0)` ascending as
the parameters suggest. Three separate measurements placed a sweep profile using the assumed start,
each producing a different wrong answer. One of them was published as a table, and the issue was
retitled around a defect that does not exist (#721). The measured start is exactly two radii from
the assumed one, with the tangent sign inverted. One call to the wire's own accessor settles it.

**Derived from an identifier instead of read.** An automated review asserted, with its highest
confidence label, that a guard on `IsParallel()` discarded parallel segments with non-overlapping
ranges. `IsParallel()` does not mean "the tangent directions are parallel"; it reports the
degenerate equidistant-family case, and returns false for disjoint ranges precisely because a unique
answer exists there. The header was in the repo. Measured: the guard never fires for that geometry
and the correct answer is returned (#636, PR #730).

**Derived from documentation instead of the source.** A bridge comment justified hardcoding an
integration error as "GetErrorReached is inline-only in OCCT 8.0.0". True, and the exact reason it
IS callable: an inline accessor is compiled into the caller, so `nm` finding no symbol is expected
rather than evidence. It returns a real value tracking the requested tolerance across six orders of
magnitude (#732).

**A second construction that was different in the wrong way.** Verifying a fixture's ground truth, a
C++ probe rebuilt it with corner-based `BRepPrimAPI_MakeBox(gp_Pnt(0,0,0), ...)` against Swift's
centred `Shape.box`. The two build different solids. The measurement was reported as being of "the
PR's own exact fixture" and it was not (#703, PR #720). The conclusion survived; the confidence did
not deserve to.

**A fixture that had silently stopped meaning its own name.** A test parameterised plate thickness
over 20/40/60/120 while leaving the drill's Z offset at a fixed `-5`. With a centred box the drill
never reached the bottom face, so a test called `throughHole...` built a blind pocket at every
thickness (#723, PR #734). No assertion on the output could have caught it.

The pattern is one thing. In each case a value that could have been observed was instead computed
from something adjacent to it, and the computation was wrong in a way that produced a plausible
number rather than an obvious error.

## How to apply

### Measuring

- If an API can report the property, ask it. A generator's output geometry, a predicate's verdict, a
  library's error estimate.
- If it cannot, read the source of the thing you are reasoning about, not its header comment. This
  repo has been wrong about `GeomFill_Sweep`'s tolerance defaults, `BRepGProp_VinertGK`'s
  accessors, and `Extrema_ExtCC`'s bounds check by trusting adjacent documentation.
- Record what you measured and how, next to the number. A figure with no method attached is
  indistinguishable from a guess a week later.

### The second construction

When you are checking a result, especially someone else's:

- Build the subject a different way. Different API, different entry point, different language.
- **Then prove the two constructions agree on everything except the property under test.** This is
  the step that gets skipped, and skipping it is what turns corroboration into noise. Compare a
  volume, a bounding box, a face count, whatever is cheap and orthogonal.
- If they disagree, find out which is wrong before drawing any conclusion about the original claim.

A second construction is worth much more than re-running the first one. It is also the only way to
catch a fixture that has stopped meaning its name, because the name is the thing you are not
allowed to trust.

### When you are wrong

Say so plainly, in the place the wrong claim lives, and say what the correct measurement is. Three
of the corrections above are recorded as comments on the issues and PRs that carried the wrong
number, because the wrong number is what the next person will find.

## Detectors are a special case, already covered

For anything whose output is "all clear", measurement is not enough: a detector that is blind
reports clean exactly as confidently as one looking at a clean tree.
[Prove the test fails](prove-the-test-fails.md) is the rule there, and its central requirement is
to **remove each guard in turn and confirm the case count drops**. That is not a restatement of this
policy, it is a stronger requirement, and it keeps earning its place: on 2026-08-07 the removal
matrix on a new census script found one of its own cases decorative, because the rule under test was
written twice and the copy being removed was dead code.

Two failures from the same day that measurement alone would not have caught, and removal did:

- A `NameError` in a script's default code path survived a refactor because every self-test case
  passed the argument explicitly and none exercised the default, which is the path CI runs.
- A deprecation annotation reported zero warnings both with and without it, because the build was
  incremental. Forced recompile: two warnings without, none with.

## Related

- [Prove the test fails](prove-the-test-fails.md), the stronger rule for detectors and gates.
- [Query `context` first for OCCT / OCCTSwift docs](context-first.md), which is this policy applied
  to API signatures specifically.
- `docs/v2.0.0-plan.md`'s census-once rule: build each census once as a committed, executable
  artifact, because the alternative is re-deriving it by grep and getting a different wrong answer
  each time.
