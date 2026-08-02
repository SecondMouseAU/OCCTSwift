---
type: policy
title: Issue labels and project-board tracking
description: Every issue carries a type:* and priority:* label, enforced by CI; multi-phase initiatives get a dedicated project board kept current at each workflow step. See Issue tracking.
tags: [policy, issues, labels, project-board, triage]
timestamp: 2026-07-30
---

# Issue labels and project-board tracking

Every issue carries a `type:*` label and a `priority:*` label. `.github/workflows/require-issue-labels.yml`
enforces this: a non-blocking sticky comment names whichever is missing, including on blank issues that
bypass `.github/ISSUE_TEMPLATE/`, whose own templates already apply the correct `type:*` on arrival.

Multi-phase initiatives (the #377 duplication audit, 46 issues across 13 phases) get a dedicated
GitHub Project scoped to that initiative's own issues, with a `Status` field matching its real
workflow stages (Backlog, In Progress, PR Review, Code-Review, Ready, Done) rather than the generic
Todo/In Progress/Done default: [OCCTSwift Refactor (#377)](https://github.com/orgs/SecondMouseAU/projects/2).
`refactor` + `phase:*` labels identify which issues belong to it.

**Update `Status` at the same points the workflow already visits**, not as a separate later pass:
opening a PR moves the card to `PR Review`, a review landing moves it to `Code-Review`. **A merge
into `refactor/381-pass1b` is not `Done`**: that branch is the initiative's own integration branch,
not `main`, so a merged/closed issue stays at `Code-Review` until the initiative's branch itself
reaches `main`. Do not wire the project's native "Item closed" / "Pull request merged" → `Done`
Workflows here: both fire on the branch merge, not the eventual `main` merge, which is exactly the
wrong event for this initiative's shape.

**`Linked pull requests` will not populate for a PR based on anything but the repo's default branch**,
including every `refactor/381-pass1b`-targeted PR in this project. That is GitHub platform behaviour,
not a bug to chase; the issue's own manual close naming the PR (see the repo's release process) is
the real source of truth for that link until the initiative's branch reaches `main`.

For the full rule and rationale, follow the authoritative **Issue tracking** section in
[OKF-STANDARD.md](https://github.com/SecondMouseAU/ecosystem/blob/main/OKF-STANDARD.md).
