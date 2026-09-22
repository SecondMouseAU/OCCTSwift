---
type: policy
title: Required status checks on main
description: gate-scripts is the one required check on main, via a repository ruleset. Never give the job a name key, never require a check that has not yet reported on the base, no pattern rules, and build-and-test stays unrequired until a run of green results says otherwise.
tags: [policy, ci, github, rulesets, branch-protection, agents]
timestamp: 2026-09-07
---

# Required status checks on `main`

`gate-scripts` (the `ci.yml` job that runs every static gate and every `--self-test`) is a
**required status check on `main`** (#649), via repository ruleset id 20252636, "require
gate-scripts on main", the repo's only branch protection. It moved there at the v2.0.0 release
from `refactor/381-pass1b`, the integration branch, now merged.

## Rules

- **Do not give the job a `name:` key.** The published check-run name is the job's `name:` when it
  has one and the job id otherwise, and that string is what the rule matches. A prose name reads
  like a comment, so rewording it would silently stop satisfying the rule while the PR UI looked
  unchanged, the same class of failure the gates themselves exist to catch.
- **Require a check only once it has actually reported `success` on the base branch's HEAD.** A
  required check that never reports blocks every PR permanently with "Expected, waiting for status
  to be reported", and there is no way to clear it. Existing in the workflow file is not enough.
  For a `pull_request` the workflow is read from the merge ref, so once the base has the job every
  PR gets it regardless of how stale the head is.
- **A required check also declines direct pushes**, so `main` takes changes by PR only, the release
  commit included. Measured, not inferred: a throwaway branch was added to the ruleset, an empty
  commit pushed at it, and the push refused with `Required status check "gate-scripts" is
  expected` / `push declined due to repository rule violations`. The CHANGELOG transcription
  therefore goes on the PR's own branch as its last commit, per
  [changelog-on-merge](changelog-on-merge.md).
- **No pattern rule covers `refactor/**`, deliberately.** A pattern is what made #780 expensive:
  renaming a branch to move it out of the pattern **closed its open PR**, and GitHub will not
  reopen one whose head branch was renamed. Being *required* is separate from whether the job
  runs, and that sentence used to read "`gate-scripts` runs on any PR whose base carries `ci.yml`",
  which was **false** until #2146: every workflow filtered `pull_request` by base, so carrying the
  file did nothing unless the base was also named in it. See the rule below. A PR based on a branch
  whose `ci.yml` predates the job still never dispatches it, and requiring it there is exactly the
  unrecoverable stall above.
- **No workflow filters `pull_request` by base branch** (#2146). `ci.yml`, `code-style.yml`,
  `code-structure.yml` and `kernel-integration.yml` all used to carry
  `pull_request: branches: [main, 'refactor/**']`, and `branches:` on a `pull_request` trigger
  filters the **base**, not the head. So a PR into any other base got **no CI at all**, while
  GitHub reported it `mergeStateStatus: CLEAN`, because the ruleset protects `main` and an
  unprotected base requires nothing. Green and never-ran were indistinguishable, which is
  [static-gates](static-gates.md)'s own opening argument arriving through the workflow layer.

  It was found on a stacked #2077 PR carrying thousands of lines of bridge instrumentation that
  `swift build` had never seen. The `v5.0.0-766-execution` branch had already hit it and worked
  around it per-branch, by adding a `766-execution.yml` naming itself as a base; that workaround is
  the evidence the filter was wrong, not a pattern to copy. Every base now gets CI without needing
  its own workflow.

  `push:` keeps its `main` / `refactor/**` filter. A branch with an open PR is covered by
  `pull_request`, so filtering pushes only avoids running everything twice.

- **`build-and-test` is required nowhere, and that is still the right call.** It was 0-for-21 on
  the integration branch under #585 (see [Pinned kernel patch check](pinned-kernel-patch-check.md)),
  and it failed on `main` at the v2.0.0 release commit for an unrelated reason (the manifest
  pointed at a release asset still uploading, so SwiftPM got a 404). Measure a run of green results
  before requiring it, rather than requiring it on one.
