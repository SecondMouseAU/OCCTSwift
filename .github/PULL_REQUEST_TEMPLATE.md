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

Write it finished, not as notes. The merger transcribes verbatim; they do not draft.
Delete this section only if the change genuinely warrants no entry, and say why in
"Notes for the reviewer".
-->

### <one-line summary of the change> (#<issue>)

<!-- The entry as it should read under `## Unreleased`, including code fences and links. -->

## Checklist

- [ ] New or changed behavior is covered by a unit test in the same PR (not just manual
      verification), see [SecondMouseAU/OCCTReconstruct#397](https://github.com/SecondMouseAU/OCCTReconstruct/issues/397)
      for the ecosystem-wide test-coverage standard this is piloting.
- [ ] Every new test and every new `--self-test` case was run once with its subject broken, and the
      failure is reported here, see [okf/policies/prove-the-test-fails.md](../okf/policies/prove-the-test-fails.md).
- [ ] The CHANGELOG entry above is complete, and `docs/CHANGELOG.md` is **not** in this diff.

## Notes for the reviewer

<!-- Anything non-obvious: trade-offs, why an approach was declined, follow-on issues. -->
