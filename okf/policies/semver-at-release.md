---
type: policy
title: SemVer is assessed at release, not per PR
description: A PR states the version impact it believes it has, in its body. Nobody edits docs/SEMVER.md until the release is being prepared on main, where the whole set is assessed at once.
tags: [policy, process, semver, releases, merging, agents]
timestamp: 2026-08-07
---

# SemVer is assessed at release, not per PR

**A pull request must not modify `docs/SEMVER.md`.** It states the version impact it believes it
has, in its body, under a `## SemVer impact` heading. `docs/SEMVER.md` is written once, when the
release is prepared on `main`, from the whole set of merged PRs at once.

This is the sibling of [CHANGELOG entries are written in the PR, not the diff](changelog-on-merge.md),
and for the same two reasons: one file that every PR edits is a conflict magnet, and the judgement
being recorded is better made over the whole set than one PR at a time.

## Why

**A PR cannot see the release it lands in.** SemVer is a property of the difference between two
released versions, not of a commit. Whether a change is breaking depends on what else ships with it:
a field removed in one PR and reintroduced under a better name in another is one rename to a
consumer, not a removal plus an addition. Asking each PR to classify itself forces a judgement at
the point where the least information exists.

**Per-PR assessment produced a mechanism nobody could apply correctly.** The recorded-exception
ledger accumulated thirteen entries, and by 2026-08-06 twelve of them were marked Unreleased,
meaning they all ship in v2.0.0, a major, where breaking changes are permitted outright and the
mechanism does not apply. The ledger was recording work it had no reason to record. Reviewers then
faulted PRs for *not* adding entries to it: three separate reviews on 2026-08-06 raised a missing
recorded exception against a change shipping in that same major.

**And the counters drifted constantly.** "Twelve" to "thirteen", "the other nine" to "the other
ten", "a thirteenth" to "a fourteenth", each a hand edit in a PR that had no other reason to touch
the file, each an opportunity to conflict with a sibling PR doing the same.

## How to apply

### If you are opening a PR

State the impact you believe your change has:

```markdown
## SemVer impact

MAJOR. `VinertGKResult.absoluteError` is removed. Callers reading it will not compile.
Suggested migration: the field was always 0.0 and never computed, so there is nothing to
migrate to; delete the read.
```

Use `MAJOR`, `MINOR`, `PATCH` or `NONE`, then one sentence on what a consumer sees, then the
migration if there is one. Write it for the person assembling the release notes, who will not have
read your diff.

Do not edit `docs/SEMVER.md`. If your diff contains it, that is a review finding.

**When in doubt, say MAJOR.** The question is "will this break a consumer's build if they take it
blindly", and a wrong MAJOR costs a version number while a wrong MINOR costs a consumer's build.

### If you are reviewing a PR

**Do not raise a missing `docs/SEMVER.md` entry as a finding.** The absence is correct. What is
reviewable is whether the stated `## SemVer impact` matches what the diff actually does, and that is
worth checking: a PR claiming `PATCH` while removing a public field is a real finding.

### If you are preparing a release

Assemble `docs/SEMVER.md` from the merged PRs' stated impacts, on `main`, as part of the release
commit. That is the first point at which the full set is visible, and the only point at which the
resulting version number is a real decision rather than a guess.

Within a major line, a break still needs its recorded exception, and that is written then, from the
PR body that proposed it.

## What this does not change

The SemVer guarantee itself is untouched: no breaking change without a major bump. This moves *when
the assessment is made and written down*, not what it promises.

## The failure mode this introduces

An impact statement can be wrong or missing, and nothing at merge time catches it, which per-PR
editing did at least prompt for.

Three things hold it. The `## SemVer impact` heading is required in
[`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md). Reviewers check the
claim against the diff, which is a better check than the old one because it asks whether the
judgement is *right* rather than whether a file was edited. And the statement lives in the PR body
permanently, so a release assembler who disagrees can re-derive it from the diff.

That last point is the real argument, and it is the same one as
[changelog-on-merge](changelog-on-merge.md): a wrong call caught at release is one conversation,
where a wrong call baked into a ledger over thirteen PRs is an archaeology exercise.

## Related

- [CHANGELOG entries are written in the PR, not the diff](changelog-on-merge.md), the sibling policy.
- [Documentation updates are mandatory](docs-current.md), which this does not weaken.
