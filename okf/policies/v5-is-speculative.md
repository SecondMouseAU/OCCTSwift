---
type: policy
title: v5 is speculative until OCCT 8.1 exists and has been read
description: There is no v5 scope, plan, branch, date or work. Nothing is built, deprecated or written down as "for v5" until OCCT 8.1 has a tag and the owner says to look.
tags: [policy, process, v5, occt-8.1, planning, agents]
timestamp: 2026-11-28
---

# v5 is speculative until OCCT 8.1 exists and has been read

**There is no v5.** It has no scope, no plan document, no branch, no date and no work. "v5" is a
name for a major release that might follow OCCT 8.1, and OCCT 8.1 has no tag. What is known about
it is what its development branch (`IR`) looked like on the days it was surveyed, and that branch
changes daily. We do not know what we do not know about it.

## The rule

- **Do not start v5 work.** That includes deprecating an API ahead of an 8.1 removal, re-pointing a
  wrapper at an 8.1 form, extending or rebasing a branch or draft pull request that tracks 8.1,
  retiring a carried patch because 8.1 absorbs it, and migrating persisted data for a type 8.1
  removes.
- **Do not write v5 into a doc, comment, issue or pull request as a plan or a fact.** "Retires at
  v5" and "v5 removes it" claim a decision nobody made. Say what is true: "OCCT's `IR` has removed X
  (measured on `<date>`); we have not decided what to do about it".
- **A survey of 8.1 is a dated snapshot, not a scope.** Keep it where it is dated. The survey of
  2026-11-25, and the issues that cite it (`SecondMouseAU/ecosystem#91`, and the draft rebase onto
  `IR`, #3501), are measurements of that day.
- **Reopen this only when OCCT 8.1 has a release tag or a pre-release and the owner says to look.**
  The first step then is a fresh survey of that tag, not the old one.

Work on v4.x is not affected: it stays on OCCT 8.0.2.

## Not to be confused with

`v5.0.0-766-execution`, the branch in [`v5-lift-and-shift`](v5-lift-and-shift.md). That name
belongs to #766's test-validity programme and has nothing to do with the major this page is about.

## Record, not a rule

On 2026-11-25 the owner said no v5 or OCCT 8.1 work until v4.0.0 was out, and that a survey is not a
green light. On 2026-11-28, with v4.0.0 released and the ecosystem moved onto it, they restated it
and asked that v5 be recorded as speculative until we know what 8.1 looks like. The same day they
called three apps (OCCTReconstruct, OCCTParts, OCCTStudio) dormant, so no migration of them is
pending either.
