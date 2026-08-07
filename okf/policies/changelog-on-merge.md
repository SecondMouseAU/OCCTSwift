---
type: policy
title: CHANGELOG entries are written in the PR, not the diff
description: A PR carries its CHANGELOG entry in its body, under a fixed heading. The merging agent transcribes it into docs/CHANGELOG.md at merge time. Nobody edits the Unreleased section in a feature branch.
tags: [policy, process, changelog, merging, agents]
timestamp: 2026-08-07
---

# CHANGELOG entries are written in the PR, not the diff

**A pull request must not modify the `## Unreleased` section of `docs/CHANGELOG.md`.** It carries
its entry in the PR body instead, under a `## CHANGELOG entry` heading. Whoever merges the PR copies
that block into `docs/CHANGELOG.md` on the base branch as part of merging.

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

Write it as the finished text, not as notes. The merger transcribes; they do not draft. This
sentence is the canonical statement of that rule; the PR template points here rather than
restating it.

### If you are merging a PR

Merging is not complete until the entry is in the file. Either:

- add it to `docs/CHANGELOG.md` on the base branch in a commit immediately after the merge, or
- add it to the PR's own branch immediately before merging, once no other PR is between you and the
  base.

The second is fine and sometimes tidier; it just has to be the last thing before the merge, or the
conflict comes back.

Copy the block verbatim. If it is wrong, that is a review comment on the PR, not an edit in transit.

### Exceptions

- **The release commit** rewrites the whole section, moving `## Unreleased` under a version heading.
  That commit edits the file directly, by definition.
- **A PR that fixes the CHANGELOG itself**, for instance a stale cross-reference, edits the file
  directly. It is not adding an entry.

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

## Related

- [Documentation updates are mandatory](docs-current.md), which this does not weaken.
- [No em-dashes, banned words in prose](writing-style.md) applies to the entry, wherever it lives.
