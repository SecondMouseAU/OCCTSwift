---
type: policy
title: Helper placement is decided by reach, not by style
description: Where an extracted helper lives is a correctness decision. A `static` helper in a `.mm` is confined to that translation unit, so a copy of the same logic in another `.mm` has no way to converge on it and drifts independently. Count every site with that logic, across every file, before extracting; more than one file means the helper goes in OCCTBridge_Internal.h as inline.
tags: [policy, bridge, duplication, refactor, agents]
timestamp: 2026-09-28
---

# Helper placement is decided by reach, not by style

A `static` helper in a `.mm` is confined to that one translation unit. Nothing outside the file can
call it, so a second copy of the same logic in another `.mm` has no way to converge on it, and the
two drift independently. Placement is therefore a correctness decision, not a formatting
preference, and the decision is made by **reach**: how many sites hold this logic, in how many
files.

**The rule.** Before extracting a helper in `Sources/OCCTBridge/src`:

1. Count every site with that logic, across every file, not only the file you are editing.
2. One file, and only ever one file: `static` in that `.mm` is right.
3. More than one file: the helper goes in `OCCTBridge_Internal.h` as `inline`, and every site is
   routed through it in the same PR.

A helper placed by reach is one decision point. A helper placed by whichever file happened to be
open is a decision point plus however many copies could not reach it.

## Why: the same defect twice, two days apart

**1. `occtComputeBoundingBox`, and the one bounds entry point with no `IsVoid()` guard.** The
helper was file-static in `OCCTBridge_Topology.mm`, where it served `OCCTShapeBoundingBox` and
`OCCTShapeBoundingBoxOptimal`. `OCCTShapeGetBounds` lives in `OCCTBridge_Properties.mm`, could not
reach a file-static, and carried its own copy of the box construction. That copy is the one that
lost the guard: #834's duplication finding was that of the bounds entry points, only one guarded a
void box at all. The placement is not incidental to the defect, it is the reason the defect could
exist. Fixed under #943 (PR #944, merged 2026-08-18) by moving the helper to
`OCCTBridge_Internal.h` as `inline` and routing all three entry points through it. The comment
above the declaration still says so:

> It came from `OCCTBridge_Topology.mm`, where it served
> `OCCTShapeBoundingBox`/`OCCTShapeBoundingBoxOptimal`; `OCCTShapeGetBounds` lives in
> `OCCTBridge_Properties.mm` and could not reach a file-static, which is how the two
> implementations drifted apart in the first place.

**2. `occtDocumentInit`, one day later, inside the pass that was auditing for exactly this.** #949
extracted the shared XCAF document-creation boilerplate into `occtDocumentInit` and declared it
`static` in `OCCTBridge_Document.mm`, which reached 2 of the 14 sites that held that logic. The
other 12 sat in `OCCTBridge_IO.mm` with no way to call it, and **6 of those 12 had already lost the
null check on the document handle that their 6 siblings and both `Document.mm` sites kept**. One of
the six, `OCCTImportOBJ`, dereferenced `doc->Main()` on the next line, where a null handle is an
uncatchable signal that the surrounding `catch (...)` does not absorb. Filed as #957 and fixed the
same day (PR #958, merged 2026-08-19) by moving the helper to `OCCTBridge_Internal.h` as `inline`
with two overloads and routing all 14 sites, which is what added the missing guard to the six.

The second instance is what makes this page necessary rather than a note on the first. It happened
while the duplication pass was in progress, and the pass issue had already said "search before
building" and linked [search-before-building](search-before-building.md). That was not enough,
because searching tells you the copies exist and says nothing about where the extraction has to go
to reach them. The specific mechanism has to be named.

## The mechanism, named

Extraction has two halves, and only the first is what "remove the duplication" sounds like:

- **Collapsing N copies into one body** is the visible half, and it is what a review comment asks
  for.
- **Placing that body where all N callers can reach it** is the half that decides whether the
  duplication is actually gone. Place it where only some can reach it and you have not removed the
  duplication; you have added one more copy and made the remaining ones look settled.

A file-static helper is not wrong in itself. It becomes wrong the moment the same logic exists in a
second translation unit, because the second copy can no longer converge. Both defects above are
that sentence, one with an `IsVoid()` check and one with an `IsNull()` check.

## Reach also tells you which copies are reachable at all

The `.mm` splits under #396 copied every file-scope helper into every file of the domain, so a
domain's twelve files each got a definition and eleven of them are called by nobody. #1628 measured
**441 such dead `static` definitions** across the 74 bridge files, and its own prediction is the
point here:

> It hides drift. A fix applied to the live copy leaves eleven stale ones behind that still look
> authoritative.

That has since happened. `fillCommonPart` is defined in twelve `OCCTBridge_Modeling_*.mm` files and
called in exactly one, `OCCTBridge_Modeling_Boolean.mm`. #2251 rewrote the live copy, because the
old body averaged `IntTools_CommonPrt::BoundingPoints`, which nothing in OCCT sets for the parts
`IntTools_EdgeEdge` produces, so every part reported the origin whatever the overlap. The other
eleven definitions are byte-identical to each other and still hold the pre-#2251 body. They are
harmless only because they are dead, and a reader who opens one of them reads a defect that was
fixed a file away.

Counting sites therefore answers two questions at once, and they want different treatment:

- **Reachable copies** are the duplication. Route them through one `inline` helper.
- **Dead copies** are not a correctness bug, and they are not nothing either: they cost every later
  audit, and they make a fixed defect look unfixed. Delete them where you are already touching the
  file, and never "fix" one to match, which propagates the body rather than retiring it.

## It cuts the other way: a helper with one caller is not owed one

Reach decides both directions, and declining an extraction is as much an application of this rule
as performing one. PR #2805 took a review pass that asked for two helpers in the same diff and
answered them oppositely, on reach alone:

- **Declined**, a helper for a curve parameter bounds check at
  `OCCTBridge_Modeling_Boolean.mm:790`. One call site, in one function, in one file. A helper with a
  single caller is indirection without reuse. If a second bounds check of that shape appears, the
  two of them together are the moment to extract it.
- **Accepted**, an explicit `(void)` discard marker on `occtLoadFaceDomain` in
  `OCCTBridge_Properties.mm`, precisely because that one has **two** callers that must not drift
  apart: the non-adaptive overload reads the return, and the adaptive one discards it on purpose
  because `BRepGProp_Gauss` re-derives `NbChildren() == 0` from the face itself. The marker says at
  the call site what the helper's comment says once, so the discard cannot later read as an
  oversight somebody "cleans up" by adding a branch.

Both answers are the same question asked twice. "Extract a helper" and "do not extract a helper" are
not style positions to be traded off against each other; they are what a site count returns.

## How to apply

- **Count before extracting.** Every site with that logic, across every file in
  `Sources/OCCTBridge/src`, not the sites in the file you are editing.
- **The grep is what settles it**, run on the most distinctive call in the body rather than on the
  helper's name, since the copies were written before the name existed:

  ```bash
  grep -rn '<the distinctive call>' Sources/OCCTBridge/src/*.mm
  ```

  Then read the hits: a definition with no call in its own file is a dead copy, not a caller.
- **More than one file means `OCCTBridge_Internal.h`, as `inline`.** It already holds 84 of these,
  including every guard predicate more than one domain needs (`occtShapeIsPresent`,
  `occtShapeHasSurfacelessFace`, `occtComputeBoundingBox`, `occtDocumentInit`, whose 14 routed sites
  have since become 19 across 8 files that a file-static could never have reached). One file, and
  only ever one file, keeps `static` in that `.mm`.
- **Route every site in the same PR.** A helper landed without its callers routed is the #949 shape:
  the extraction is recorded as done and most of the sites still hold their own copy.
- **Sites that are not identical are where the bug usually is.** Record the difference rather than
  flattening it. Six of #957's twelve had already lost a guard, and #943's outlier was the one entry
  point that never had one. An overload, a flag, or a written reason is the answer; silently picking
  one body and applying it everywhere changes behaviour at the sites that differed.
- **A duplication finding is only a chore once you have checked that the copies still agree.** Six
  of #957's twelve had diverged, which is what turned it from drift-prevention into a `type:bug`
  with a guard to restore. Check before labelling it, per [issue-tracking](issue-tracking.md), and
  measure the divergence rather than assuming the copies are the same age, per
  [measure-dont-assume](measure-dont-assume.md).
- **Say the placement decision in the pass issue, not just "deduplicate".** An issue that asks for
  an extraction without stating that placement is decided by reach has shipped the same bug twice
  already.

## Related

- [Search before building](search-before-building.md): find the copies. This policy is the step
  after, where the extraction has to go so that all of them can reach it.
- [Code structure](code-structure.md): which file new code belongs in, and the remediation method
  for a repo that already has copies. That policy places code for readability; this one places it
  for reach, and reach wins where the two disagree.
- [Null handle and null shape guards in the bridge](null-handle-guards.md): both defects above are a
  missing guard, and `OCCTBridge_Internal.h` is where that policy's shared predicates live for the
  same reason.
- [Follow OCCT's own callers](follow-occt-callers.md): its "say it once, centrally, when a rule
  covers many functions" bullet is this policy applied to a comment instead of to code.
- [Measure, do not assume](measure-dont-assume.md): count the sites, never estimate them. Repeated
  hand-recounts of bridge site sets have been caught wrong more than once.
