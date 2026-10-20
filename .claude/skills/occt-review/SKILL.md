---
name: occt-review
description: Step 3 of the upstream OCCT process. An independent, read-only review of a prepared upstream PR branch: does it fix the issue at its cause, does it comply with OCCT's AI instructions, and is it worth a maintainer's time. Returns SEND, REVISE or HOLD. Run it in a fresh agent that did not write the fix.
---

# occt-review: independent check before anything is sent

Run this as the `occt-upstream-reviewer` agent (`.claude/agents/occt-upstream-reviewer.md`), not in the
context that wrote the fix. The reviewer may build and run tests in its own temporary worktree and write
`Scripts/repro/<issue>/REVIEW.md`. It never edits the branch, pushes, comments or files anything.

Inputs: the case directory `Scripts/repro/<issue>/` (CASE.md, logs), the branch, the PR body file.
Read the live instructions first: `git -C upstream/occt show upstream/IR:.github/copilot-instructions.md`.

## A. Does it fix the issue, at its cause

1. **Independent trace.** Without reading the author's reasoning first, trace the failure to its origin
   yourself, then compare with CASE.md's root-cause sentence. Disagreement is a REVISE.
2. **Test fails for the original reason.** Build base `upstream/IR`; run the new test; the failure must match
   the root cause, not an incidental crash. Build the branch; it passes.
3. **Every hunk is needed.** Revert each source hunk alone; some test must fail. Report untested hunks.
4. **Symptom screen.** Flag any tolerance bump, retry, skipped entity, forced success, catch-all, one-input
   special case, or a null check that turns an unexpected failure into an empty result (instructions section 1).
5. **Callers and siblings.** Check the shared contract was not changed under other callers. Note sibling
   sites with the same pattern; do not ask for them in this PR.
6. **Neighbours.** Run the related suites; confirm tests actually ran.
7. **Fork CI.** Read the staging PR's checks at the reviewed head sha (`gh pr checks`). Linux, Windows and
   macOS results, the format check and the non-ASCII check are evidence; a red job is a REVISE until its log
   is read and explained, and an infrastructure failure is named as one. A job that did not run is not a
   pass. Adjudicate any Kilo comment on the staging PR; Kilo is a gate, not an authority.

## B. Compliance

Run `Scripts/occt-staging/occt-precheck.py` when it exists. Then walk sections 1 to 9 of the instructions over every
added line, the commit messages and the PR body: ASCII and banned words; STL owned containers and strings;
`Standard_*` aliases; `auto`; comments that narrate history; separators and banners; anonymous namespace;
inline bodies in `.cxx`; `//!` docs; GTest design (self-contained, deterministic, naming, `ASSERT` versus
`EXPECT`, `EXPECT_THROW` only where the throw is not compiled out, result checked and not just `IsDone()`);
`FILES.cmake` registration; includes. Process: title form, template sections, CLA 1139 ticked, `Closes #N`,
no Claude attribution or downstream references in commits or body, base `IR`, rebased with no merge commits.

## C. Is it worth a maintainer's time

- **Focus:** one defect, one subsystem, a diff a maintainer can read in minutes. Over the size gate: SPLIT.
- **Overlap:** open PRs or recent IR commits on the same files or lines (`gh pr view N --json files` for each
  open PR touching the files). A conflict or duplicate is a HOLD.
- **Redundancy:** would a maintainer fix this faster than they can review it? A one-line fix with an
  unambiguous issue is better as an issue comment with the line.
- **Queue:** our open upstream PRs without a maintainer response against the limit in
  `okf/policies/upstream-pr-volume.md`.
- **Reading cost:** can the PR body be understood in two minutes without our context?

## Verdict

Write `REVIEW.md`: verdict, then findings by severity (MUST-FIX, SHOULD, NOTE) with file and line and the
exact replacement, then what was run and what was not. Verdicts:

- **SEND:** no MUST-FIX, A and C clean. The user still decides.
- **REVISE:** list the changes; the author fixes and the review is rerun on the new head.
- **HOLD:** do not send, with the reason (duplicate, queue full, not reproducible on IR, wrong cause).

Post a short summary of the verdict as a comment on the **staging PR on the fork** (our own repo, no
notification upstream). Report the verdict and the findings table in the reply. Never treat SEND as the
user's approval.
