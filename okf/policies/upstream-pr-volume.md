---
type: policy
title: Upstream PR volume, and the three-step process
description: Our upstream OCCT PRs must earn a maintainer's time. Measured 2026-10-20: 9 merged (April to 10 August, small single-defect PRs, about nine days each), 40 open, 31 of them opened since 10 August with none merged. Work goes through occt-intake, occt-fix-pr and occt-review; open PRs without a maintainer response are capped.
tags: [policy, occt, upstream, process, volume, agents]
timestamp: 2026-10-20
---

# Upstream PR volume, and the three-step process

## What the numbers say (2026-10-20)

- 9 of our PRs merged, between April and 10 August 2026. Each was one defect with a GTest, and the
  median time to merge was about nine days.
- 40 are open. 31 were opened after 10 August. None of our PRs has merged since, while 63 PRs from other
  authors have. The maintainers said on 2026-10-19 that community PRs resume after they finish porting
  their own patches ([discussion 1645](https://github.com/Open-Cascade-SAS/OCCT/discussions/1645)).
- 13 of the 40 have had any human response. No maintainer has asked for changes on any of them.
- An audit of all 43 open PRs against [OCCT's AI instructions](../references/occt-ai-instructions.md) found
  none clean. Common: base `master`, no template or CLA, body text that breaks the language rules,
  comments that narrate the bug, STL containers in tests. Several bundle fixes or add public API.

More PRs do not help. Every open PR costs the maintainers reading and rebasing time we cannot see.

## The rules

1. **Cap on unanswered PRs.** At most **5** open upstream PRs from us with no maintainer response. At the
   cap, a new defect is carried in `Scripts/patches/` and waits. Lift the cap only if the maintainers ask
   for more.
2. **One defect, one PR.** Two root-cause sentences mean two PRs. A diff over about 300 non-test lines or
   across subsystems is split first.
3. **Issue first** for new work, as the maintainers asked, unless a suitable upstream issue exists.
4. **Upstream first, patch second.** The upstream commit is the source of truth; the carried patch is
   derived from it.
5. **Small enough to merge.** Merged PRs of ours were small. If a fix needs a design argument (locking
   models, new public API), raise it as an issue or discussion first and send no code.
6. **Backlog.** Open PRs are fixed in waves (base, template, language, comments), split where the audit
   says, and withdrawn where a maintainer's work has superseded them. A PR is not left open only because
   it exists.

## The staging fork

`SecondMouseAU/OCCT` stages every change before upstream sees it. This replaces the 2026-08 rule against
PRs on the fork: that rule rested on local override-link tests being enough, which they are not for
Linux, Windows or Debug, and a PR inside the fork notifies nobody upstream.

- `IR` on the fork is a pure mirror of upstream and is never committed to.
  `Scripts/occt-staging/sync-fork.sh` fast-forwards it and fails if it differs. `master` is left alone:
  a push to it triggers the fork's two heavy workflows (`Build and Test`, `Master Validation`). Run it at the start of each
  case. No scheduled workflow, because the scoped token has no `workflow` scope.
- A change lives on `fix/<topic>`, cut from the mirrored `IR`, with a draft PR on the fork whose title and
  body are exactly what upstream will get. The fork's CI matrix and Kilo run there.
- The upstream PR reuses the same branch (`--head SecondMouseAU:fix/<topic>`), so its commits and CI results
  are the ones we reviewed. The staging PR is then closed with a link, and the branch deleted on merge.
- Opening anything on `Open-Cascade-SAS/OCCT` still needs the user's go.
- Never name a branch `ir/...`. The Windows runners have a case-insensitive file system, so a branch under `ir/` collides with `IR`, the checkout fetch fails, and the format and non-ASCII jobs go red (measured 2026-10-20). Use `fix/<topic>`.
- The fork's workflows are enabled. `Build and Test` runs on a pull request to any branch and on a push
  to `master` only, so the staging PR is what triggers CI, and each new push to it cancels the run before
  it. Never push to `master` on the fork. Open one staging PR per revision that is ready, not in bulk.

## The process

Each step is a skill; the user approves between steps. Skills push only to the staging fork. Nothing is filed or posted upstream by a skill.

| Step | Skill | Ends with |
|---|---|---|
| 1. Identify | `occt-intake` | `CASE.md`: value gate, reproducer on current IR, root-cause sentence, failing GTest that fails for the original reason, issue draft |
| 2. Fix | `occt-fix-pr` | Branch, commit, PR body, proof logs; draft PR on the staging fork with its CI results |
| 3. Review | `occt-review` (agent `occt-upstream-reviewer`) | `REVIEW.md`: SEND, REVISE or HOLD, by an agent that did not write the fix, using the fork's CI as evidence |

The case record lives in `Scripts/repro/<OCCTSwift issue>/`. The mechanical rules are meant to move into
`Scripts/occt-staging/occt-precheck.py`; until it exists the reviewer applies them by reading.

## Related

[OCCT's AI development instructions](../references/occt-ai-instructions.md),
[Upstream OCCT PRs, style and submission workflow](upstream-occt-style.md),
[Upstream OCCT patch process](upstream-occt-patch-process.md).
