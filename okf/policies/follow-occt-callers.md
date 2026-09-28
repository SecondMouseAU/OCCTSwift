---
type: policy
title: Follow OCCT's own callers, not just its signature
description: When OCCT leaves a semantic choice open (what a return value means, when a result counts as a failure), the answer is how OCCT's own production callers use the API. Find them and copy them exactly. Reading the callee's source tells you what the value is, not what it means.
tags: [policy, occt, fidelity, bridge, agents]
timestamp: 2026-09-26
---

# Follow OCCT's own callers, not just its signature

A signature does not carry a contract. `bool Perform()` tells you a boolean comes back and nothing
about whether `false` means "failed" or "there was nothing to do". Every bridge function makes that
call, and the answer is **not ours to reason out**. Find how OCCT itself uses the API and copy it.

**The rule.** Before writing a bridge function that has to interpret an OCCT result, and before
accepting or declining a review finding about one:

1. Find OCCT's own callers of that class.
2. Read what they treat as success and what they treat as failure.
3. Do that, exactly, and cite the call site in a comment so the next person does not re-derive it.

If OCCT's callers keep a check, we keep it. If they combine two signals, we combine the same two.
Divergence needs a written reason, the way a carried patch does.

## Reading the callee tells you what the value is, not what it means

This is the trap, and it catches a careful reading, not a lazy one.
[Measure, do not assume](measure-dont-assume.md) says read the source of the thing you are reasoning
about rather than its header comment. That is right, and on its own it is not enough: the source of
`Perform()` tells you which branch returns which boolean. It cannot tell you which of those branches
a caller is supposed to treat as an error, because that decision lives in the callers.

So the source of the function under test answers "what is this value". Only its callers answer "what
do I do with it". You need both, and the second is the one that gets skipped.

## Why: three PRs, one file, two opposite defects

`ShapeUpgrade_ShapeDivide::Perform()` returns `false` for "nothing was split", setting its result to
the input shape, and `true` when it changed something. Its only genuine-failure `false` is a
null-input guard. Eleven bridge wrappers in `OCCTBridge_Healing_Upgrade.mm` interpreted that, and
every one of them got it wrong, in one of two directions (#2769):

- **Seven treated `false` as failure**, so an input that needed no splitting returned `nil` from a
  documented public Swift API (#2766, measured reachable with an ordinary box).
- **Four ignored the return value entirely**, so a genuine failure returned the input shape as
  though it were a result, the #726 shape. Three of those four were introduced or blessed by PRs
  merged across two days: #2743, #2753, #2767.

Each of those PRs read `ShapeUpgrade_ShapeDivide.cxx` and quoted its return statements correctly.
One of them talked a review bot out of a CRITICAL finding on the strength of that reading, and the
decline was right about the proposed fix and wrong about the conclusion. What none of them did was
open OCCT's own callers, where the answer had been sitting the whole time.
`ShapeProcess_OperLibrary.cxx` is OCCT's production shape-processing library, the one STEP and IGES
import healing runs through, and all five of its `ShapeUpgrade_ShapeDivide`-family call sites are
the same two-part test:

```cpp
if (!tool.Perform() && tool.Status(ShapeExtend_FAIL))
{
  return false;   // the failure path
}
ctx->RecordModification(tool.GetContext(), msg);
ctx->SetResult(tool.Result());
return true;      // success, INCLUDING when Perform() returned false
```

`false` alone is not a failure. `false` with `Status(ShapeExtend_FAIL)` is. Neither of the two
answers the bridge had arrived at independently, and not something any amount of reasoning from our
side of the wrapper was going to produce. One grep over OCCT's own tree settles it, and it settles
all eleven functions at once.

The cost of not doing it was not one defect. It was a wrong rule propagating through review: a PR
establishes half the contract, the next PR copies that PR, a third cites the second as precedent,
and the file ends up with two opposite bugs and a comment in each explaining why it is correct.

## Where to look, in order

1. **OCCT's production libraries.** `ShapeProcess_`, `ShapeAlgo_`, `XSAlgo_`, `STEPControl_`,
   `IGESControl_`, `BRepAlgoAPI_`. These are OCCT using its own lower-level classes in anger, and
   they are the strongest signal because they ship in the kernel and are exercised by every import.
2. **DRAW commands**, under `src/Draw/`. Thinner, but they show the intended sequence and what gets
   reported to a user. A useful second opinion: if a DRAW command ignores a value the production
   library checks, the production library is the one to follow.
3. **OCCT's own tests**, where they exist for the class.
4. **The developer guide**, via the `context` MCP per [context-first](context-first.md). Lowest
   weight of the four for this question, because a guide describes the happy path and rarely states
   which return value is an error.

```bash
# the callers, not the callee
grep -rn 'ShapeUpgrade_ShapeDivideAngle' Libraries/occt-src/src --include=*.cxx \
  | grep -v '/ShapeUpgrade/ShapeUpgrade_ShapeDivide'
```

Weigh the count. Five call sites agreeing in the library that runs every STEP import is a contract.
One call site in one DRAW command is a hint.

## When OCCT does not answer

- **No callers at all**, which happens for classes OCCT exposes but does not itself use. Say so in
  the comment, measure the behaviour directly per
  [measure-dont-assume](measure-dont-assume.md), and record the reasoning in the PR body rather
  than in a bare code comment, so the decision is reviewable.
- **Callers disagree.** Follow the production library over DRAW, and note the disagreement. It is
  worth an issue: OCCT's own inconsistency is upstream-reportable, and
  [upstream-occt-patch-process](upstream-occt-patch-process.md) covers where that goes.
- **OCCT's own callers look wrong.** They are still the contract. Wrap faithfully and file the
  defect upstream; do not quietly improve on the kernel inside the bridge. That is the same rule as
  [scope-boundary](scope-boundary.md), applied to semantics rather than to features.

## How to apply

- Cite the call site, with file and line, in the bridge comment. Not a re-derivation from the
  callee's source, which is what three PRs in a row produced. A reader who can see
  `ShapeProcess_OperLibrary.cxx:228` can check the rule in one step.
- Say it once, centrally, when a rule covers many functions. Eleven near-identical comments drift;
  one policy or reference page plus a pointer does not.
- **A review finding about result interpretation is a prompt to go read the callers**, whether you
  end up agreeing with it or not. The finding on #2743 was wrong about the fix and right that
  something was missing, and the reply that declined it would have caught the real answer if it had
  taken the finding as a reason to look rather than a claim to rebut.
- When a bridge function's failure path changes, the public doc comment and its `docs/reference/`
  entry describe OCCT's outcomes, not ours. If OCCT distinguishes three cases and our return type
  collapses them into `nil`, document that collapse rather than inventing a contract.
- SemVer for this class of change is argued against OCCT's contract, not against what a caller may
  have inferred from a doc comment we wrote wrongly. See
  [semver-at-release](semver-at-release.md).

## Related

- [Measure, do not assume](measure-dont-assume.md): observe rather than derive. This policy is the
  half of it that reading the callee cannot supply.
- [Query `context` first](context-first.md): how to look a signature up. This policy is about what
  the signature does not tell you.
- [Stay faithful to OCCT](scope-boundary.md): the same fidelity rule applied to which features
  belong here at all.
- [`okf/references/known-occt-bugs.md`](../references/known-occt-bugs.md): where a genuine kernel
  defect gets recorded once the callers have been checked.
