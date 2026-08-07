<!--
Source of truth is the OKF bundle (okf/index.md). Ground this change in the relevant
policies / strategies / decisions and keep them current in THIS PR.
-->

## What & why

<!-- One paragraph: what changed and the problem it solves. -->

Closes #

## CHANGELOG entry

<!--
REQUIRED, and it goes HERE rather than in docs/CHANGELOG.md. Do not edit the `## Unreleased`
section in your diff: every PR appends to the top of the same list, so every PR conflicts with
every other PR that lands first. Whoever merges this copies the block below into the file.
See okf/policies/changelog-on-merge.md.

Write it finished, not as notes: see the policy for why the merger transcribes rather than drafts.

If the change genuinely warrants no entry, replace the heading below with "None, <reason>" rather
than deleting the section, so the decision is visible instead of looking like an omission.
-->

### <one-line summary of the change> (#<issue>)

<!-- The entry as it should read under `## Unreleased`, including code fences and links. -->

## SemVer impact

<!--
REQUIRED, and it goes HERE rather than in docs/SEMVER.md. Do not edit that file: SemVer is a
property of the difference between two RELEASES, not of a commit, so it is assessed once on main
when the release is prepared, from every merged PR's stated impact at once.
See okf/policies/semver-at-release.md.

One of MAJOR / MINOR / PATCH / NONE, then one sentence on what a consumer sees, then the migration
if there is one. Write it for whoever assembles the release notes, who has not read your diff.

When in doubt say MAJOR: a wrong MAJOR costs a version number, a wrong MINOR costs a consumer's
build.
-->

MAJOR / MINOR / PATCH / NONE. <what a consumer sees, and the migration if any.>

## Checklist

- [ ] New or changed behavior is covered by a unit test in the same PR (not just manual
      verification), see [SecondMouseAU/OCCTReconstruct#397](https://github.com/SecondMouseAU/OCCTReconstruct/issues/397)
      for the ecosystem-wide test-coverage standard this is piloting.
- [ ] Every new test and every new `--self-test` case was run once with its subject broken, and the
      failure is reported here, see [okf/policies/prove-the-test-fails.md](../okf/policies/prove-the-test-fails.md).
- [ ] The CHANGELOG entry above is complete, and `docs/CHANGELOG.md` is **not** in this diff.
- [ ] The SemVer impact above is stated, and `docs/SEMVER.md` is **not** in this diff.
      It is assessed at release on `main`, not per PR.
      Tick this for a release commit or a PR that fixes the CHANGELOG itself too: those are the
      policy's two exceptions and the file is expected in their diff. Say which one applies in
      "Notes for the reviewer".

## Notes for the reviewer

<!-- Anything non-obvious: trade-offs, why an approach was declined, follow-on issues. -->
