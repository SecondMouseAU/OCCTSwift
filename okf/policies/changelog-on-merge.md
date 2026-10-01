---
type: policy
title: CHANGELOG entries are written in the PR, not the diff
description: A PR carries its CHANGELOG entry in its body, under a fixed heading. The merging agent transcribes it into docs/CHANGELOG.md as the last commit on the PR branch before merging. Nobody edits the Unreleased section earlier than that.
tags: [policy, process, changelog, merging, agents]
timestamp: 2026-08-07
---

# CHANGELOG entries are written in the PR, not the diff

**A pull request must not carry its CHANGELOG entry in its diff while it is open.** It carries the
entry in the PR body instead, under a `## CHANGELOG entry` heading. Whoever merges the PR copies
that block into `docs/CHANGELOG.md` as the last commit on the branch, immediately before merging.

The rule is about *when*, not *never*: an entry added at the top of a long-lived branch conflicts
with every PR that lands before it, and an entry added thirty seconds before the merge conflicts
with nothing.

**The rule binds the PR that carries the change, not the transcription itself.** A PR whose only
purpose is to transcribe entries from other PRs' bodies is the merger doing their job, batched, and
is not what this forbids. That case is not hypothetical: on 2026-08-08 a release-prep sweep found
that ten merges had landed with an entry in the PR body that nobody copied across, and
`Scripts/check-changelog-transcription.py --verify-transcribed` later put the real figure higher
still. Writing those in one pass is the remedy, not a violation of it.

Two conditions on that, and they are what keep it from becoming a loophole. The PR must transcribe
and nothing else, so a feature PR cannot smuggle its own entry in under the same banner. And it must
be the only open PR touching the file, which is cheap to check and is the whole reason the rule
exists.

The entry is still mandatory. [Documentation updates are mandatory](docs-current.md) is unchanged.
Only the file the entry lives in until merge has moved.

## Why

Every PR appends to the top of the same section of the same file, so every PR conflicts with every
other PR that lands before it. The conflict is never semantic: it is two additions to one list, and
the resolution is always "keep both". It costs a merge, a resolution, a push, and a fresh CI round
trip, and it recurs for each sibling that lands first.

Measured on 2026-08-06, a single day on `refactor/381-pass1b`:

- **29 commits** touched `docs/CHANGELOG.md`.
- **Seven** separate resolutions of the same keep-both conflict: three on the base branch, and
  **four on one PR alone** (#728), which re-conflicted each time a sibling merged ahead of it.
- #728 was a two-file change, one of them the CHANGELOG. It spent more wall-clock in conflict
  resolution than in review.
- The `## Unreleased` section is 15 entries. Every one of them was an opportunity for this.

The cost is quadratic in the number of PRs in flight, and this branch routinely has six or more.

There is a second, quieter cost. Each resolution is a hand edit to a file with conflict markers in
it, and the only check that nothing was dropped is whoever is doing it counting entries before and
after. That is a manual integrity check running several times a day on the project's own release
record.

## How to apply

### If you are opening a PR

Put the entry in the PR body, verbatim as it should appear in the file:

```markdown
## CHANGELOG entry

### `Shape.thing` no longer returns the wrong answer (#123)

Prose exactly as it should land under `## Unreleased`, including any code fences,
tables and issue links.
```

Do not touch `docs/CHANGELOG.md`. If your diff contains it, that is a review finding.

The block ends at the next `##` heading or at the attribution footer, whichever comes first, so
the entry may be the body's last section and nothing has to follow it. Fenced code inside the
entry is kept verbatim, and a fence quoted in prose elsewhere in the body does not hide the
heading: `merge-pr.py` matches each opening marker with its closing one rather than counting
them. Both of those were defects until #2890, and both were hit while merging on 2026-09-30, one
of them leaving a stray attribution line in the release record.

Write it as the finished text, not as notes. The merger transcribes; they do not draft. This
sentence is the canonical statement of that rule; the PR template points here rather than
restating it.

**Head the entry descriptively, and carry the issue numbers in the heading.** `### Fixed`,
`### Added` and `### Changed` on their own are refused by `merge-pr.py`, with the reason printed
and nothing written. A bare category heading identifies nothing, so the tool cannot tell your
entry from any other entry opening the same way, and nine entries between 2026-09-30 and
2026-10-01 were extracted, printed to the operator and silently discarded for exactly that reason
(#2951). It is also not how the section reads: each entry is spliced in at the top, so N of them
leave N separate `Fixed` buckets in merge order for whoever assembles the release. An entry
covering several kinds of change takes one descriptive heading, not a category split under it.
Clearing the refusal is a one-line edit to the PR body; nothing has been pushed and the PR is not
merged when it fires.

### If you are merging a PR

**Run `python3 Scripts/merge-pr.py <n>`.** It does the whole of what this section asks, in the order
it asks for it: extracts the `## CHANGELOG entry` block from the PR body verbatim, commits it to
`docs/CHANGELOG.md` as the last commit on the PR's branch, pushes, and merges. A section saying
"None" becomes a `No-Changelog:` trailer on the merge commit instead, which is the other half nobody
remembers. `--dry-run` prints every action first and changes nothing.

Merging is not complete until the entry is in the file. **Add it to the PR's own branch as the last
commit before merging**, once no other PR is between you and the base. It has to be last, or the
conflict this policy exists to avoid comes back.

Copy the block verbatim. If it is wrong, that is a review comment on the PR, not an edit in transit.
The script never drafts and never retypes, which is the point of extracting rather than copying:
`feedback-changelog-transcription-repunctuation` records a hand transcription silently repunctuating
an entry against the em-dash ban.

**Why a script and not a checklist item.** #742 named the forgotten-transcription failure, built
`Scripts/check-changelog-transcription.py` for it, and closed with a plan to promote that report to a
required check. #2779 measured what happened instead: three of the five merges between `8740d62d` and
`1429ff69` landed with an entry in the PR body that nobody transcribed, a fourth needed a
`No-Changelog:` trailer and cannot gain one now, and one of the three misses was merged by an agent
with this policy in its own context. The promotion is also not available. The report asks a
post-merge question, so as a required check on a protected base it would fail every open PR for the
*previous* merge's omission, which is neither that PR's fault nor something its author can fix; its
`--verify-transcribed` half reads live PR bodies over the API and takes minutes. A step that cannot
be forgotten is one that is not a step, so the transcription moved into the merge action rather than
growing an enforcement mechanism in front of it. The report stays as the backstop for a merge made
by hand, and `okf/policies/static-gates.md` records what its own CI invocation does and does not see.

#### Why there is only one route now

This used to offer a second: commit the entry onto the base branch immediately after the merge.
**That route is gone on any base with a required status check**, which since v2.0.0 includes `main`.
A required check declines a direct push, measured rather than assumed: pushing an empty commit at a
branch under the rule is refused with `Required status check "gate-scripts" is expected` /
`push declined due to repository rule violations`. A merger following the old instruction meets that
refusal at the least convenient moment, which is why it is deleted here rather than left as an
option that happens to fail.

Putting the entry on the PR branch has a second benefit that was not the reason for the change but
matters: the merge commit then carries the file change, so
`Scripts/check-changelog-transcription.py`'s **plain** run sees it. Under the batch-PR route below,
it does not, and only `--verify-transcribed` can tell a transcribed entry from a missing one.

A ruleset bypass for the merging actor would restore the old route and is deliberately not used.
The point of the required check is that nothing reaches `main` without it; an exemption whose only
job is to let one file skip the gate is the kind of carve-out nobody remembers auditing.

### Exceptions

- **The release commit** rewrites the whole section, moving `## Unreleased` under a version heading.
  That commit edits the file directly, by definition. On a protected base it is still a PR, like
  everything else.
- **A PR that fixes the CHANGELOG itself**, for instance a stale cross-reference, edits the file
  directly. It is not adding an entry.
- **A batch transcription PR** catching up entries that were missed, as described at the top of this
  file. This is the repair route, not the routine one: prefer getting the entry onto the PR branch
  before merging, so the plain audit stays meaningful.

## The failure mode this introduces, and the guard for it

Moving the entry out of the diff means it can be **forgotten at merge**, which the old way made
impossible. That is a real trade and worth stating plainly rather than discovering.

Three things hold it:

1. `## CHANGELOG entry` is a required heading in
   [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md). A PR without one is
   incomplete, the same as a PR without a test.
2. The merger's own checklist: the merge is not done until the entry is in the file. Treat a merged
   PR with no entry the way you would treat a merged PR whose tests never ran.
3. It is recoverable. The text is in the PR body forever, so a missed entry is a lookup, not a
   reconstruction. That is strictly better than a dropped entry during a conflict resolution, which
   leaves no trace anywhere.

A missed entry is a visible gap in a released changelog. A silently dropped one during a hand
conflict resolution is not visible at all, and the old way produced several opportunities for that
per day.

**And a fourth thing, added after the third turned out to be insufficient.** Point 3 says a missed
entry is recoverable because the text is in the PR body forever, which is true and is how #2951's
nine were recovered. What it does not cover is a miss nobody is looking for, because the tool said
the work was already done and the backstop report agreed. Both of those claims are now proved
rather than asserted: `merge-pr.py` prints the file and line its duplicate test matched, re-reads
`docs/CHANGELOG.md` after the splice and refuses to commit, push or merge if the entry is not
under `## Unreleased`; and `check-changelog-transcription.py` skips a bare category heading when
deciding what a PR-body entry is, instead of matching six words that identify nothing. Measured,
the report called all nine of them "transcribed late, nothing to do" for the whole time they were
absent. A detector's "all clear" is worth what its ability to say otherwise is worth, which is
[prove-the-test-fails](prove-the-test-fails.md)'s rule applied to a tool rather than a test.

## Related

- [Documentation updates are mandatory](docs-current.md), which this does not weaken.
- [No em-dashes, banned words in prose](writing-style.md) applies to the entry, wherever it lives.
