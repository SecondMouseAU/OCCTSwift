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
  runs: `gate-scripts` runs on any PR whose base carries `ci.yml`, which is every branch cut from
  `main`. A PR based on a branch whose `ci.yml` predates the job never dispatches it, and requiring
  it there is exactly the unrecoverable stall above.
- **`build-and-test` is required nowhere, and that is still the right call.** It was 0-for-21 on
  the integration branch under #585 (see [Pinned kernel patch check](pinned-kernel-patch-check.md)),
  and it failed on `main` at the v2.0.0 release commit for an unrelated reason (the manifest
  pointed at a release asset still uploading, so SwiftPM got a 404). Measure a run of green results
  before requiring it, rather than requiring it on one.
