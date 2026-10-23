---
name: occt-intake
description: Step 1 of the upstream OCCT process. Decide whether a defect is worth a maintainer's time, reproduce it on current upstream IR, trace it to the first violated contract (the cause, not the symptom), write the failing GTest first, and produce CASE.md plus the upstream issue draft. Use before any fix is written for the OCCT tree. Stops for the user's approval.
---

# occt-intake: identify the defect and prove it

Read first, every time: `cd upstream/occt && git fetch -q upstream IR && git show upstream/IR:.github/copilot-instructions.md`
(the maintainers' rules, section 1 is this skill). Policy context: `okf/references/occt-ai-instructions.md`
and `okf/policies/upstream-pr-volume.md`.

Output is a case file `Scripts/repro/<OCCTSwift issue>/CASE.md` and an issue draft. **Nothing is filed,
pushed or posted by this skill.** It ends by showing the user CASE.md and asking.

## 0. Sync the staging fork

`Scripts/occt-staging/sync-fork.sh` fast-forwards `SecondMouseAU/OCCT` `IR` to upstream and checks
they match. It refuses if the fork has commits of its own. Run it first; a case is always cut from the
`IR` it prints.

## 1. Value gate (stop here if any answer is no)

Answer in CASE.md, with evidence for each:

1. **Reproduces on current `upstream/IR`**, built from source, not only on our pinned kernel. If IR already
   fixed it, stop and say which commit.
2. **Nobody else has it in flight.** Search upstream issues and PRs (open and merged, any author) by symbol
   and by file: `gh search prs -R Open-Cascade-SAS/OCCT <symbol>`, `gh pr list --search`, and
   `git log upstream/IR --since=<3 months> -- <files>`. If a maintainer or other author has a PR on the same
   lines, stop: comment there instead of opening another.
3. **Who is hurt, and how.** A valid input that gives a wrong answer, a crash or a hang counts. Hardening
   against a damaged or hostile file also counts, but it must be a boundary check at the reader, stated as
   such. A defect only we can reach through our own bridge is ours to guard, not a PR.
4. **Queue check.** Count our open upstream PRs with no maintainer response. At the limit in
   `upstream-pr-volume.md`, the answer is to carry the patch in `Scripts/patches/` and wait, not to open
   another PR.
5. **One defect.** If the cause is two things, write two cases.

## 2. Reproduce

State expected behavior, actual behavior and the smallest reproducer. Separate observation from
hypothesis (instructions section 1). Use the persistent IR build, not a rebuilt-per-task tree:
`upstream/occt` base worktree plus a `ccache` Release build with `BUILD_GTEST=ON`; build only the toolkits the
case needs and `OpenCascadeGTest`. A crash is root-caused, never re-run until it passes. `OCC_CATCH_SIGNALS`
is inert here and `No_Exception` removes `Raise_if` checks: say which of those apply
(`okf/policies/occt-validation-is-compiled-out.md`).

## 3. Trace to the cause

Follow the failing data and control flow back to the **first violated contract or incorrect calculation**
(instructions section 1). Read the callee, its callers and the existing tests. Write the root-cause
statement as one sentence in this form and put it at the top of CASE.md:

> `<function>` assumes `<contract>`; `<input>` breaks it; the failure shows up in `<place>`.

Reject these as fixes, they are symptom handling: a larger tolerance, a retry, a skipped entity, forced
success, a catch-all, a special case for one input, a null check that turns an unexpected failure into an
empty result. Validation is right only at a documented boundary. If the cause is outside the tree we can
change, say so and stop.

Check the other callers and sibling code for the same pattern. Record them as a note; do not widen the case.

## 4. Failing test first

Write the GTest before any fix, in the module's `GTests/` (`ClassName_Test.cxx`, registered in
`FILES.cmake`), self-contained, deterministic, no data files. It must check the requested result, not only
`IsDone()` or the absence of an exception. Run it on unpatched IR with a timeout wrapper that reports
SIGSEGV, SIGBUS or a hang, and keep the output.

The test must fail **for the original reason**: the failure text, signal or stack must match the root-cause
statement. A different crash is a different bug. If the defect has no observable effect a GTest can see
(for example a large allocation that is then refused), find a consequence that is observable, or record
that it is not testable and let the user decide whether the PR is justified.

## 5. CASE.md

Fixed sections: Root cause (the sentence) / Value gate answers / Reproducer / Failing test and its output on
IR / Callers and siblings checked / Overlap with open work / Proposed fix approach and why it is at the
responsible component / Not verified.

Then the issue draft, in the repo's issue style and the instructions' language rules (ASCII, B1 English,
no banned words): title in `Group - Summary` form, Problem, Expected, Actual, Reproducer, Root cause,
Proposed approach. Show CASE.md and the draft in full in the reply and stop. The user files the issue, or
says to.
