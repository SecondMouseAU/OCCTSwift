---
type: policy
title: Static gates and censuses
description: The pure-Python gate scripts in Scripts/ are the repo's cheapest correctness signal. A gate exits 1 on a defect; a census exits 0 always and only its --self-test runs in CI; a release check's verdict is taken at the pin, so only its --self-test runs there too. Every detector proves it is not blind. The pre-commit hook mirrors CI flag for flag, with one named exception.
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

The six censuses today and what each is for:

- `census-unmeasured-values.py` (#726): values returned as measurements that were never computed.
  A bare run is the slowest of the five, because sub-kind 4 walks a taint fixpoint per bridge
  function; CI never makes that run, and times the `--self-test` at under a second. The `~13 s`
  this line used to give was a laptop figure with no method recorded, and re-measuring it in #2203
  produced 21, 60 and 75 s on three consecutive runs of one loaded laptop, which is why there is no
  number here now. See "How long the job takes" below for the figure that is measurable.
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
- `census-dead-file-statics.py` (#1628): `static` definitions in `Sources/OCCTBridge/src/*.mm` that
  nothing in their own file calls, which is the whole reach a file-static has. It reports rather
  than gates for a reason that is not a false-positive rate: **a dead file-static is not a defect.**
  The compiler drops it, and `-Wunused-function` does not fire on these either, since they are
  `static` non-inline functions the Objective-C++ unit still emits. What it costs is paid by
  readers, by every later audit that re-reads the same body five to twelve times, and by the drift
  the copies hide, which is a list to adjudicate rather than a verdict on the tree. Its
  `--divergence` mode is the sharp half: a name whose dead copies disagree with its live one is a
  fixed defect preserved verbatim next door, which is what
  [helper-placement-by-reach](helper-placement-by-reach.md) predicted in writing and what
  `fillCommonPart` turned out to be. Every rule in it errs towards LIVE, because its consumer is a
  deletion pass: a false dead costs a build break and a false live costs a line.

Three gates read `Scripts/patches/` and `Scripts/patches-wasi/` rather than `Sources/`, and all
three for the same reason: `check-patch-deletes-guarded-symbol.py` (#2058), which fails when a
carried patch deletes a line naming an OCCT symbol a `Tests/` comment says its invariant depends
on; `check-preprocessor-balance.py` (#2167), which fails when a patch's conditional-directive
deltas do not balance; and `check-wasi-patch-base.py` (#2168), which fails when a WASI patch was
not cut from the tree the carried set produces. All three scan the patch diffs, not
`Libraries/occt-src`, which is what keeps them in this job instead of an hour into
`kernel-integration.yml` where #2056 was found. #2167's subject is PR
#2076, where three of fifteen WASI patches left a source file no compiler could preprocess on any
platform, behind a green check that read "all 14 patches apply cleanly": applying cleanly and
preprocessing are different properties. It carries a deeper `--tree` mode that parses whole files
in a real checkout, which `gate-scripts` does not have, so that mode stays out of this job and
takes `--require-tree` where it runs, on the #2098 precedent below.

#2168 is the third property the same PR got wrong, and the one the other two cannot see: all
fifteen patches were authored and `git apply --check`ed against a pristine `V8_0_1`, not against
the tree `build-occt-wasm.sh` patches, so nobody noticed that nine carried patches inject
`std::mutex` into OCCT and that 15 of the 76 threading-dependent files are files this repo patches
itself. `git apply --check` is not reconstructible from patch text, so the gate checks the ways
the two patch sets can contradict each other instead, and [wasi-patch-base](wasi-patch-base.md)
states plainly what that leaves uncaught. Its `--tree` mode is the real check and takes
`--require-tree` on the same #2098 precedent.

`check-changelog-transcription.py` is a third kind, a **report**: it audits the branch's merge
history for merges that landed with no CHANGELOG entry, and is not a gate.

**Two things about it, both measured in #2779, and the second is the one to act on.**

It cannot become a gate in the form #742 proposed, and the reason is structural rather than a
false-positive rate. It asks a post-merge question, and on a base with a required check nothing
lands between two merges, so wired in as a required check it would fail every open PR for the
*previous* merge's omission, which is neither that PR's fault nor something its author can fix.
#2779 measured three such omissions in five consecutive merges, which would have reddened all 31
other open PRs. Its `--verify-transcribed` half cannot gate either: it reads live PR bodies over the
GitHub API and took over two minutes, against this job's defining property.

**And its run in CI examines nothing.** `default_since()` looks for the commit that added
`okf/policies/changelog-on-merge.md`, falls back to the last tag, then to the root commit.
`actions/checkout` fetches depth 1 and no tags, so all three resolve to HEAD, and the step prints
`Merges audited since <HEAD sha>: 0` and passes. Measured on run 36366497846 and reproducible on
every run before it. That is this page's own opening argument met in practice: a green step that
examined nothing looks exactly like a clean tree. The step is left in place in #2779 rather than
quietly fixed, because the two candidate fixes are both real decisions. `fetch-depth: 0` would give
the report its history and roughly double the job's cheapest step; a `--require-history` flag on the
#2098 precedent would turn the false green into a loud red and needs the depth change first, or
`gate-scripts` goes red on every PR at once. The merge-time route #2779 built is what makes the
report a backstop rather than the mechanism, so neither fix is urgent, and neither should be made by
accident.

## The fourth kind: a release check

`gate-scripts` runs one release check, `check-pinned-asset-patches.py` (#2190), and runs its
`--self-test` alone. A **release check** answers a question about something the repo points at
rather than something the repo contains, so its real run belongs to the step where that pointer
moves, not to every PR. This one reads `Libraries/OCCT.xcframework`, 157 MB of static archive per
slice across three slices, to decide whether the pinned asset holds the patches `Scripts/patches/`
says it holds; it is run at the pin, per `CLAUDE.md`'s Release Process and
[pinned-kernel-patch-check](pinned-kernel-patch-check.md).

It is deliberately **not** counted as a gate or as a census, and neither would have been a smaller
edit than saying so:

- not a gate, because a gate's bare run is what gates, and this job cannot make that run at all.
  Calling it the fifteenth gate would say fifteen bare invocations protect `main` when fourteen do.
- not a census, because a census's bare run *could* run here and simply would not signal, exiting 0
  over a list for a human to adjudicate. This one reaches a verdict and exits 1 on a defect. Calling
  it the sixth census would say the repo holds six detectors that report without deciding.

What it shares with a census is only the shape of its CI entry, and that shape is what tells the
buckets apart mechanically: `check-inventory-prose.py` classifies a script the job runs *only* as
`--self-test` and that is not a census as a release check, and requires it to define a
`--require-...` flag, the #2098 mode that turns a run which examined nothing into an error. A gate
whose bare invocation nobody added would otherwise land in this bucket and be counted, and
described here, as a release check.

**Its `--self-test` runs on every PR for a sharper version of the reason every other detector's
does.** A detector consulted once per release is the one whose blindness is most expensive: nothing
between two pins would reveal it, and the run it would be wrong on is the one nobody can repeat
cheaply. #2190 is what that costs. Every count in the repo agreed with every other count, all of
them comparing prose to prose, and the asset shipped carrying two patches nobody had reverted.

## How long the job takes, and how to re-derive it

**Measured 2026-09-28 from the runner's own step timings, over the 21 most recent successful
`gate-scripts` jobs that ran the current 44-step list.** A laptop measurement would answer a
different question: what this job costs is what it costs a PR, and `ubuntu-latest` is where that is
decided.

| | min | median | max |
|---|---|---|---|
| the 37 script invocations, summed | 26 s | **44 s** | 47 s |
| the job, including checkout and `setup-python` | 33 s | **52 s** | 58 s |

**One script is two thirds of it.** `check-throwing-calls.py` runs a median 14 s bare and 15 s for
its `--self-test`, about 30 of the 44. `check-null-handle-guards.py` is 4 s. Every other invocation
is at or under 2 s and most are under 1. That is the useful shape of the number, and it is worth
knowing before adding anything here: the budget belongs to one script, not to the list.

**A local figure is a different number.** The same 37 invocations run on one laptop with other work
on it measured 72 s, 159 s and 182 s across three consecutive runs, and the ordering changed as
well: `check-changelog-transcription.py` was the largest line item locally, 22 to 51 s across four
runs, and is 0 s on the runner. Quote the runner, and say how many runs the figure came from.

**Re-derive it, do not trust it.** The timings are in the Actions API, one call per run:

```bash
gh api /repos/SecondMouseAU/OCCTSwift/actions/runs/<run-id>/jobs \
  --jq '.jobs[] | select(.name=="gate-scripts")
        | {steps: (.steps | length), each: [.steps[] | {(.name): (.started_at + " " + .completed_at)}]}'
```

Two things make a single run misleading. Step timestamps are whole seconds, so a dozen runs or more
are needed before a median means anything, and a run from before the newest gate landed was a
shorter list, so compare `steps | length` against the current job before pooling.

**Why the figure is load-bearing rather than trivia.** It is part of why this job is separate from
the ones that build, and part of why `check-doc-snippets.py` and `check-pinned-asset-patches.py` are
outside it. `CLAUDE.md` used to carry it as `~3s for the lot`, which was true when written, was
about fifteen times off by the time #2203 caught it, and was read as an argument the whole time. So
`CLAUDE.md` now says only "under a minute on the runner", which survives another script being added,
and the precise numbers live here with their method and their date attached.

## The one gate outside `gate-scripts`

`check-doc-snippets.py` (#1683) type-checks every fenced ```swift``` block in `docs/` and in `///`
doc comments. `docs-current.md` asks for a runnable snippet on every documented API and nothing had
ever *compiled* one: `check-docs-defaults.py` reads the declaration a reference page restates, and
`check-docs-existence.py` reads its headings and prose, but the example fences went unread, which is
how a factory that never existed reached 18 call sites (#1675).

**It is not in `gate-scripts`, because it cannot be.** That job's whole property is pure Python over
the repo's own text, no OCCT and no build; this one needs `OCCTSwift` built to compile a snippet
against. It runs in `ci.yml`'s `swift build + test (macOS)` job instead, after the build it reuses,
and it is outside every count on this page and in `CLAUDE.md`, all of which are derived from the
`gate-scripts` job body alone.

**It was a census first, and the promotion is what the measuring was for.** It landed at 211
failures, which is the state [required-status-checks](required-status-checks.md) warns about: a
required check red for every PR is worse than no check. So it reported a *number* rather than a
verdict, and the number is what told anyone whether promotion was close. It reached zero when #2092
reclassified 24 unparseable reference pages that were eliding content the reader supplies, and #2093
fixed the remaining 187 page by page. Then, and only then, `--strict` became the default and the
script was renamed `check-`.

That sequence is the rule worth carrying, not the outcome: **measure the rate, fix the backlog,
then gate.** #1407 is the same precedent. A detector promoted before its backlog is zero teaches
people to ignore a red check, which costs more than the check was ever worth.

There was never a false-positive argument against gating it. Nothing here has a measured
false-positive class to discount the way `census-doc-occt-attribution.py` has its 41%: the compiler
adjudicates. It was volume, and volume is fixable.

Three of its design choices are worth carrying to any detector that shells out to a compiler:

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
- **It checks the age of the build artefact it reads and does not produce.** It compiles against
  whatever `OCCTSwift.swiftmodule` sits in `.build` and never builds one, which is right in CI, where
  the build step runs immediately before it, and a trap on a machine that switches branches: a module
  built from other source reports a correct snippet as broken, and the report names the page rather
  than the module. Three such false failures were taken for defects on PR #2799 before `swift build`
  cleared all three. A module older than its own inputs is now **refused**, exit 2 with or without
  `--require-typecheck`, while a missing module stays the #2098 skip, because a missing build is
  visible to whoever has none and a stale one is invisible to everybody (#2816). The general form:
  **a detector that reads an artefact it does not produce owes a freshness check on it**, and the
  freshness check owes a self-test case run against the real tree, so a misfire arrives as a named
  failure rather than as a refusal on every PR.

## Every detector proves it is not blind

Fourteen of the fifteen gates, all six censuses, the merge-history audit and the release check
take `--self-test`, a fixture battery proving the *detector* catches each failure mode. Run it
whenever you change one of these scripts. Three gate scripts were confidently wrong while
reporting all clear (#618, #624/#630, #626), and a detector reporting "all clear" because it is
blind looks exactly like one reporting "all clear" because the tree is clean. Adding a self-test
case is not the rule; watching it fail is, per [prove-the-test-fails](prove-the-test-fails.md).

`count-operations.py` has no `--self-test` and exits 2 on an unrecognised option rather than
running the report, so writing `count-operations.py --self-test` to match its siblings fails loudly
instead of passing forever. `check-bridge-index`, `check-null-handle-guards`, `derive-gdt-enums`
and `derive-bridge-header-split` exit 2 if run from anywhere but the repo root (#625).

## A self-test is not enough: validate the view, not just the verdict

`--self-test` proves the detector catches the failure modes **you thought of**. It cannot prove the
detector looked at the real input at all. Those are different claims, and the second is the one that
keeps failing.

Three detectors were caught in one day, **all three with a passing `--self-test`**:

| Detector | Reported | Actually saw |
|---|---|---|
| `derive-bridge-header-split.py` | `misfiled: 0` | 2 of `OCCTBridge.h`'s 16 declarations (#2080) |
| `check-doc-snippets.py` in CI | step green | 24 of 3,105 snippets; 3,081 skipped (#2098) |
| `check-doc-snippets.py`'s canary | 51/51 locally | the stubbed path never ran in CI (#2097) |

Each self-test passed because no fixture contained the trigger: a `/*` inside a line comment, an
absent build directory, a skip that only fires where the author's machine has a build. Adding a
fixture per trigger is chasing; the triggers are unbounded.

**So a detector must also assert, on the real run, that its own view is plausible, and fail rather
than report clean when it is not.** The assertion is cheap and specific to what the script reads:

- Parsing headers? Assert every header yields at least one declaration. A header declaring nothing
  would not be in the split.
- Compiling? Carry a **canary** that must fail, and abort when it passes. `check-doc-snippets.py`
  does this, and it caught a second bug within the hour of being added.
- Depending on a build, a clone, a checkout? Assert it is there and **fail in CI** even where
  skipping is right locally, because a contributor without a build still wants partial results while
  a green CI step that examined nothing is a false green.
- Reading a population you can size independently? Compare the two and fail on a large divergence.

The distinction worth holding: **a wrong answer is a bug, an answer about a population that was
never examined is a lie.** The first gets found. The second is invisible precisely when it matters,
because it looks identical to success.

This is not new; it is the sixth instance. #618, #624/#630 and #626 are the same shape three years
of tooling earlier.


## A new gate has a one-time window, and open PRs walk through it

**The PR that adds a gate does not make already-green PRs re-run it.** `main`'s ruleset has
`strict_required_status_checks_policy` **false**, deliberately: requiring every branch to be up to
date before merging would mean rebasing and re-running CI on every open PR each time anything lands,
and this repo routinely has dozens in flight. The cost of that policy is this window.

Measured, on the first occasion it mattered. `check-wasm-kernel-parity.py` merged in PR #2784.
PR #2782 had been open since before that, its checks had passed against a base with no such gate, and
it merged **twenty-nine seconds later** and turned `main` red. The gate was correct, it would have
failed #2782's own run, and it never got one.

**So adding a gate has a step: look at the open PRs it would fail, before or just after merging it.**

```bash
gh pr list --state open --json number,title,headRefName
```

For a gate over a specific file, the cheap version is to check out each candidate branch and run the
gate, or simply to expect the red and fix it forward. Either is fine; what is not fine is being
surprised, because `gate-scripts` is a required check on `main`, so the surprise does not land on one
PR. It lands on `main`, and every open PR fails it until somebody resolves it.

This is not an argument for turning the strict policy on. It is an argument for knowing that a gate's
first day is the one day it cannot protect, and that the remedy is a look at the queue rather than a
change to the ruleset.

## The pre-commit hook

`Scripts/git-hooks/pre-commit` runs thirty-seven of `gate-scripts`' thirty-eight invocations, flag for
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
