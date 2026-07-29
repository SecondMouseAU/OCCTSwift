---
type: policy
title: Issue labels and project-board tracking
description: Every issue carries a type:* and priority:* label, enforced by CI; multi-phase initiatives get a dedicated project board. See Issue tracking.
tags: [policy, issues, labels, project-board, triage]
timestamp: 2026-07-29
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

For the full rule and rationale, follow the authoritative **Issue tracking** section in
[OKF-STANDARD.md](https://github.com/SecondMouseAU/ecosystem/blob/main/OKF-STANDARD.md).
