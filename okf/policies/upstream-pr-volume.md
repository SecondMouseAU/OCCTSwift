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

## The process

Each step is a skill; the user approves between steps. Nothing is pushed, filed or posted by a skill.

| Step | Skill | Ends with |
|---|---|---|
| 1. Identify | `occt-intake` | `CASE.md`: value gate, reproducer on current IR, root-cause sentence, failing GTest that fails for the original reason, issue draft |
| 2. Fix | `occt-fix-pr` | Local branch, commit, PR body, proof logs; one focused draft PR |
| 3. Review | `occt-review` (agent `occt-upstream-reviewer`) | `REVIEW.md`: SEND, REVISE or HOLD, by an agent that did not write the fix |

The case record lives in `Scripts/repro/<OCCTSwift issue>/`. The mechanical rules are meant to move into
`upstream/tools/occt-precheck.py`; until it exists the reviewer applies them by reading.

## Related

[OCCT's AI development instructions](../references/occt-ai-instructions.md),
[Upstream OCCT PRs, style and submission workflow](upstream-occt-style.md),
[Upstream OCCT patch process](upstream-occt-patch-process.md).
