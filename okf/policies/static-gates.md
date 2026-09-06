---
type: policy
title: Static gates and censuses
description: The pure-Python gate scripts in Scripts/ are the repo's cheapest correctness signal. A gate exits 1 on a defect; a census exits 0 always and only its --self-test runs in CI. Every detector proves it is not blind. The pre-commit hook mirrors CI flag for flag, with one named exception.
tags: [policy, gates, ci, scripts, detectors, testing, agents]
timestamp: 2026-09-07
---

# Static gates and censuses

The command list, and the sentence stating how many of each kind there are, live in `CLAUDE.md`'s
"Static Gate Scripts" section; `Scripts/repro/819-gate-coverage-audit/gate_coverage.py` parses
that sentence against `ci.yml` and fails if they disagree. This page is the rules behind the list.

## Gates versus censuses

A **gate** exits 1 on a defect and 0 when clean, and CI's `gate-scripts` job runs it bare. A
**census** exits 0 whether or not it finds anything, because its output is a list of sites for a
human to adjudicate, not a verdict on the tree; CI runs only its `--self-test`, since a bare run
could never fail and so could never signal. A census that earns a better false-positive number is
promoted by renaming it `check-` and making it exit 1; the decision is separate from the script.

The four censuses today and what each is for:

- `census-unmeasured-values.py` (#726): values returned as measurements that were never computed.
  A bare run is ~13 s because sub-kind 4 walks a taint fixpoint per bridge function; the
  `--self-test` stays under a second.
- `census-doc-occt-attribution.py` (#928): docs attributing a method to an OCCT class its bridge
  function never reaches, #807's over-coverage detector. The class-existence half wants
  `Libraries/OCCT.xcframework`'s pinned headers and reports SKIPPED without them, the normal case in
  CI; the attribution half runs anywhere off the committed `Scripts/occt-packages.txt`
  (`--reverify-packages` diffs it against the headers, `--write-packages` rewrites it). It caught
  25 of #808's 26 confirmed findings and 6 of #809's 6 under a removal matrix, with a measured
  false-positive rate of 41% over a 40-row hand-adjudicated sample
  (`Scripts/repro/928-over-coverage-detector/`, re-scorable with `score_sample.py`). That rate is
  why it reports rather than gates.
- `census-arguments-tuple-shapes.py` (#1057): `@Test(arguments:)` elements whose layout trips the
  toolchain defect in `CLAUDE.md`'s Test Conventions. Its `unknown` verdict is the point: the layout
  rule is necessary and not sufficient, so guessing would be wrong in the direction that costs a
  real test. It reads the test function's signature, not the literal, because a first version
  required `SIMD3<Double>` spelled out and was blind to `SIMD3(1, 0, 0)`, which is how this tree
  writes 3,266 of its literals.
- `census-comment-staleness.py` (#872): comments naming a symbol, flag or patch that no longer
  resolves. Its patch-citation channel scans `CLAUDE.md` and the two `okf/references/` pages that
  cite `Scripts/patches/NNNN-*` files.

`check-changelog-transcription.py` is a third kind, a **report**: it audits the branch's merge
history for merges that landed with no CHANGELOG entry, and is not yet a gate.

## Every detector proves it is not blind

Seven of the eight gates, all four censuses and the merge-history audit take `--self-test`, a
fixture battery proving the *detector* catches each failure mode. Run it whenever you change one of
these scripts. Three gate scripts were confidently wrong while reporting all clear (#618,
#624/#630, #626), and a detector reporting "all clear" because it is blind looks exactly like one
reporting "all clear" because the tree is clean. Adding a self-test case is not the rule; watching
it fail is, per [prove-the-test-fails](prove-the-test-fails.md).

`count-operations.py` has no `--self-test` and exits 2 on an unrecognised option rather than
running the report, so writing `count-operations.py --self-test` to match its siblings fails loudly
instead of passing forever. `check-bridge-index`, `check-null-handle-guards`, `derive-gdt-enums`
and `derive-bridge-header-split` exit 2 if run from anywhere but the repo root (#625).

## The pre-commit hook

`Scripts/git-hooks/pre-commit` runs twenty of `gate-scripts`' twenty-one invocations, flag for
flag. The one it omits is `check-changelog-transcription.py`'s real run, which answers a question
about the branch rather than about the commit being made; its `--self-test` does run. That is the
only deliberate divergence, and it is written here because an undocumented difference between the
hook and CI is exactly what makes a passing hook misleading.

It also runs `Scripts/format-bridge.sh --self-test` and `--check`, which belong to the `code-style`
CI job rather than `gate-scripts`. CI and the hook invoke the same script, so there is one copy of
the file selection to drift. The rest of `code-style` (swift-format, SwiftLint,
`check-style-manifest.py`) is push-and-find-out, because clang-format is the only one whose findings
are wholly mechanical. A clang-format violation blocks the commit; a missing clang-format, or one on
a major the pin (`Scripts/clang-format-version.txt`) disagrees with, only warns, the same way a
missing `python3` does. A wrong major does not fail the `--self-test` either, since what that
proves is that the detector is not blind, which holds at any version.

The hook is opt-in and not installed by cloning:

```bash
# main checkout, surgical, leaves other hooks alone
ln -s ../../Scripts/git-hooks/pre-commit .git/hooks/pre-commit

# a linked worktree's .git is a file, so the symlink above fails with "Not a directory"; use either:
git config core.hooksPath Scripts/git-hooks                              # per-worktree
ln -s <main>/Scripts/git-hooks/pre-commit <main>/.git/hooks/pre-commit  # once, covers every worktree
```

`core.hooksPath` replaces `.git/hooks` rather than adding to it, so any existing hook stops firing
while it is set. `git commit --no-verify` skips the hook. It checks the working tree rather than the
staged snapshot, runs whatever `python3` is on PATH (CI pins 3.12), and exits 0 with a warning if
`python3` is missing. CI is the authority.
