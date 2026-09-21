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

The five censuses today and what each is for:

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
- `census-api-reference-rows.py` (#1679): `docs/API_REFERENCE.md` category-row entries that resolve
  to no declaration in `Sources/`. A removed API leaves its name in a row with every gate green:
  `count-operations.py` treats those rows as illustrative and re-derives the headline totals
  instead, and `check-docs-existence.py` reads `docs/reference/` pages rather than
  `API_REFERENCE`'s tables. #1666's removal was caught by hand; #1634's `revolutionToElementary`
  was still listed until this census found it. It reports rather than gates because the rows mix
  real symbols with umbrella names (`booleanCheck` covers two bridge functions and is itself
  declared nowhere), abbreviations (`thruSectionsCreate` for `OCCTShapeThruSectionsCreate`) and
  category labels (`boss`), and no mechanical rule separates those from a stale entry: 79 of 2,588
  identifier-shaped entries resolve to nothing, and most of them are correct documentation.

One gate reads `Scripts/patches/` rather than `Sources/`: `check-patch-deletes-guarded-symbol.py`
(#2058), which fails when a carried patch deletes a line naming an OCCT symbol a `Tests/` comment
says its invariant depends on. It scans the patch diffs, not `Libraries/occt-src`, which is what
keeps it in this job instead of an hour into `kernel-integration.yml` where #2056 was found.

`check-changelog-transcription.py` is a third kind, a **report**: it audits the branch's merge
history for merges that landed with no CHANGELOG entry, and is not yet a gate.

## The one census outside `gate-scripts`

`census-doc-snippets.py` (#1683) type-checks every fenced ```swift``` block in `docs/` and in `///`
doc comments. `docs-current.md` asks for a runnable snippet on every documented API and nothing had
ever *compiled* one: `check-docs-defaults.py` reads the declaration a reference page restates, and
`check-docs-existence.py` reads its headings and prose, but the example fences went unread, which is
how a factory that never existed reached 18 call sites (#1675). It is the one census this page's rules
do not fully cover, in two ways, both deliberate.

**It is not in `gate-scripts`, because it cannot be.** That job's whole property is pure Python over
the repo's own text, no OCCT and no build; this one needs `OCCTSwift` built to compile a snippet
against. It runs in `ci.yml`'s `swift build + test (macOS)` job instead, after the build it reuses,
and its scripts are outside every count on this page and in `CLAUDE.md`, all of which are derived from
the `gate-scripts` job body alone.

**Its bare run is in CI, unlike every other census's.** The rule above says CI runs only a census's
`--self-test`, since a bare run that always exits 0 could never signal. That reasoning holds for a
census whose output is a list of sites to adjudicate. This one's output is a *number*, the count of
snippets that do not compile, and the number is what tells anyone whether promotion is close; printing
it on every build costs about a minute against a build already paid for. The `--self-test` runs too.

**Why it is a census at all, given the compiler adjudicates.** Not false positives: there is no
measured false-positive class here to discount the way `census-doc-occt-attribution.py` has its 41%.
It is volume. 211 of 3,096 snippets do not compile on `main`, so a required check would be red for
every PR, which is the failure mode in
[required-status-checks](required-status-checks.md) and worse than no check at all. `--strict` exits 1
for anyone who wants gate behaviour on the page they are editing, and promotion is that flag becoming
the default plus a rename to `check-`, once the backlog is zero. #1407 is the precedent: measure the
rate, then gate.

Two of its design choices are worth carrying to any detector that shells out to a compiler:

- **It compiles rather than parsing.** #1675 holds two attempts at a regex that matched argument
  labels against declarations, and a record of how each reported a real API as missing. A Swift
  signature parser good enough to avoid that is a fraction of a compiler, and a compiler is already
  in the build.
- **Every `swiftc` invocation carries a canary**, a file holding a defect the compiler cannot miss,
  and a canary that comes back clean aborts the run. This was not precautionary. The first version
  ran without `-continue-building-after-errors`, the driver stopped scheduling frontend jobs after
  the first batch that failed, and four of eight self-test fixtures reported clean while never being
  compiled at all. A green run and a blind run were indistinguishable, which is this page's own
  opening argument, met in practice. It fired a second time within the hour, on a `-target` whose
  architecture was derived from the built module but whose deployment version was dropped: `swiftc`
  rejected the target before reading a file, produced no per-file diagnostic, and the canary turned
  what would have been "3,096 snippets clean" into an abort.

## Every detector proves it is not blind

Ten of the eleven gates, all five censuses and the merge-history audit take `--self-test`, a
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

`Scripts/git-hooks/pre-commit` runs twenty-seven of `gate-scripts`' twenty-eight invocations, flag for
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
