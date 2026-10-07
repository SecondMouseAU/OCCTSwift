---
type: policy
title: Static gates and censuses
description: The pure-Python gate scripts in Scripts/ are the repo's cheapest correctness signal. A gate exits 1 on a defect; a census exits 0 always and only its --self-test runs in CI; a release check's verdict is taken at the pin, so only its --self-test runs there too. Every detector proves it is not blind. The pre-commit hook mirrors CI flag for flag, with one named exception.
tags: [policy, gates, ci, scripts, detectors, testing, agents]
timestamp: 2026-09-07
---

# Static gates and censuses

The command list lives in `CLAUDE.md`'s "Static Gate Scripts" section. **The counts live here**,
because `CLAUDE.md` states no counted claim about the repo's own inventories any more (#2954): a
number in the working summary is a copy whose only update path is somebody noticing, and this one
was wrong twice before a gate was put on it. This page is the rules behind the list, and the place
every number about the list is written down.

## How many there are

Eighteen gates, seven censuses and one merge-history audit run in `ci.yml`'s `gate-scripts` job,
beside the release check that "The fourth kind" below counts apart from them. Every one of those
numbers is derived from the job rather than kept by hand:
`Scripts/check-inventory-prose.py` reads this sentence against `ci.yml` on every PR and fails when
the two disagree, and `Scripts/repro/819-gate-coverage-audit/gate_coverage.py --check` reads the
same sentence from the other direction, reporting the release check beside it.

## A frozen number says when

A counted claim in prose is one of two things, and the sentence has to say which.

A **live** claim describes the repository as it is now. It is only safe where a script re-derives
it and fails when the two disagree, which is what every entry in `check-inventory-prose.py`'s
`CLAIMS` table is. Written without that, it is a number whose only update path is somebody
noticing, and the repository has watched that fail at the patch count, the gate count, the bridge
file count and the enforced-style population.

A **frozen** claim is a measurement, and a measurement has a date. "The pinned asset holds
thirty-one patches" and "the `v4.0.0-kernel.1` asset held thirty-one patches" are the same number
about the same thing, and only the second stays true. The model sentence is in
[code-style](code-style.md): *"That 272 is a frozen measurement of 2026-09-30 and is deliberately
written as one."* Past tense, or a date, or both. A frozen claim also names the command that
re-derives it, so a reader who needs today's figure does not have to find one.

So, for any number about this repository: **gate it, date it, or delete it.** Prefer deleting. Most
counted clauses carry no information the universal quantifier does not: "guarded at all 20
construction sites" and "guarded at every construction site" tell a bridge author the same thing,
and only one of them goes stale when the twenty-first is added. The count is worth keeping where it
is evidence rather than instruction, which is why "36 of the 57 entry points crash uncatchably" is
written down in [null-handle-guards](null-handle-guards.md) and no longer in `CLAUDE.md` (#2959).

And **no counted claim about the repository belongs in `CLAUDE.md`** at all (#2954, #2959), gated
or not. That page is loaded into every session in every branch, so a correct edit to the thing
counted reds every other open PR at merge time. The count goes on the `okf/` page that owns the
subject, and `CLAUDE.md` links to it.

## The detectors outside `gate-scripts`

Two detectors gate on every PR from another job, so no count on this page includes them:
`check-doc-snippets.py` in `swift build + test (macOS)` (see "The one gate outside `gate-scripts`"
below) and `check-swift-format.py` in `code-style.yml`. Their populations are recorded here rather
than in `CLAUDE.md`, and each is a frozen measurement, read under the rule above.

**The doc-snippet corpus**, one frozen measurement of **2026-10-02**, from a full
`python3 Scripts/check-doc-snippets.py --require-typecheck` run on the PR for #2976: 8,325 fenced
```swift``` blocks in `docs/` and `///` comments, of which 5,101 are signature restatements the
gate skips (a bodiless `func` is uncompilable anywhere), 3,216 are snippets it type-checks, and 8
carry a `no-typecheck:` exemption. Of the snippets, 1,770 compile and 1,446 are fragments opening
mid-flow with a receiver the prose introduced. Those same 1,770 are linked into the one executable
the `--run` stage executes, because a link each measured over two hours; 1,764 ran clean and six
threw, all of them documented examples reading a `/tmp` path the repo does not ship. `--list` is
the cheap re-derivation of the first four figures and a full run gives the rest.

The shape of the split is the load-bearing part and it is stable: the restatements outnumber the
snippets, which is why a label-matching regex over the whole corpus was the wrong instrument
(#1675).

**The swift-format population**, a frozen measurement of **2026-09-30** (PR for #2852, `de18a98f`):
the four lines of shell it replaced walked `find Sources/OCCTSwift` and reached **230** of the
repo's **1,730** tracked Swift files. The population is now `git ls-files '*.swift'`, all of it:
the two exemption manifests that used to be subtracted from it are retired, so
`git ls-files '*.swift' | wc -l` is today's denominator and
`python3 Scripts/check-swift-format.py --list` prints the population.

## Gates versus censuses

A **gate** exits 1 on a defect and 0 when clean, and CI's `gate-scripts` job runs it bare. A
**census** exits 0 whether or not it finds anything, because its output is a list of sites for a
human to adjudicate, not a verdict on the tree; CI runs only its `--self-test`, since a bare run
could never fail and so could never signal. A census that earns a better false-positive number is
promoted by renaming it `check-` and making it exit 1; the decision is separate from the script.

The seven censuses today and what each is for:

- `census-unmeasured-values.py` (#726): values returned as measurements that were never computed.
  A bare run is the slowest of the five, because sub-kind 4 walks a taint fixpoint per bridge
  function; CI never makes that run, and times the `--self-test` at under a second. The `~13 s`
  this line used to give was a laptop figure with no method recorded, and re-measuring it in #2203
  produced 21, 60 and 75 s on three consecutive runs of one loaded laptop, which is why there is no
  number here now. See "How long the job takes" below for the figure that is measurable.

  **Its sub-kind 5 is the one detector here that is a registry rather than a scan**, and the
  reason is worth copying rather than repeating. #2844 measured that this census cannot see a
  value the KERNEL fabricated: every sub-kind keys on our own code producing it, and #2827's
  by-plane mass came off a real `Mass()` call with every caller input reaching the subject, so
  nothing textual over `Sources/` could reach it. Extending the scan would have meant reading the
  kernel per defect, which is a judgement and not a derivation. So the judgement is written down
  once, per site, and what runs every time is three derived questions about each written judgement:
  does its `okf/references/known-occt-bugs.md` row still exist, does the bridge site that reads the
  value still exist and still cite the issue, and for a defect whose only reader was deleted, has a
  reader come back. **The first failing is a refusal and not a finding** (exit 2), on
  `check-inventory-prose.py`'s precedent: a registered pattern matching nothing is the detector
  going blind, and a blind detector reports all clear exactly as loudly as a clean tree. Because
  CI runs a census's `--self-test` alone, that live-registry check is a `--self-test` case, which
  is what makes a hand-maintained list safe to keep here at all.
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
- `census-compiled-out-validation.py` (#2801): bridge `try`/`catch` protection resting on an OCCT
  validity check that `No_Exception` removed from the kernel, and result accessors read without the
  `IsDone` test that is now the only guard left. It reports rather than gates because the verdict on
  each site is whether the `catch` had another reason to exist, which is a reading. Two things about
  it are worth copying. It reads a **committed derived map**, `Scripts/occt-raise-if-map.txt`, on the
  `census-doc-occt-attribution.py` precedent: the facts it needs live in `Libraries/occt-src`, which
  nothing checks out, so `--write-table` derives them once and `--reverify-table` re-derives and
  diffs at an OCCT version bump, skipping without the tree unless `--require-occt-src`. And its
  plausibility assertions earned their place before it reported anything: a hand-written whitelist of
  "inert" `gp_` value types was wrong about 8 of its 18 entries, and the assertion that the map must
  contradict none of them rejected the run rather than producing a number built on it. The rate is in
  [occt-validation-is-compiled-out](occt-validation-is-compiled-out.md), with the story of how its
  first version reported 89 findings that were an artefact of reusing a gate's regex for a census's
  question.

  **#2946 is the limitation it now states out loud, and the decision is the transferable part.**
  Every channel ends at a `catch`, so the census cannot see a compiled-out check whose absence
  faults before any `catch` runs, which is the expensive half, since `OCC_CATCH_SIGNALS` is inert
  in bridge code. It is not fixable as a derived channel: the map is keyed on the file stem rather
  than the class, two of the four worked examples are an uninitialised member with no raise site
  anywhere, and whether an absence faults rather than returning a wrong value is what the kernel
  does frames later, which no derivation over raise sites records. So the limitation is **recorded
  where it is read**: the `DARK` constant in the script, printed at the end of every bare run and
  held by a `--self-test` case, since a census's self-test is the only thing CI runs. The general
  rule it instances: **a detector that cannot reach a category of its own subject owes that
  category in its output, not in its docstring**, and a case holding the list, because dropping an
  entry otherwise makes the report shorter and greener. The same argument #2934 settled for the
  probe harness. Where the category goes instead is in
  [occt-validation-is-compiled-out](occt-validation-is-compiled-out.md).

  **#2858 widened it from two channels to four and added a kind to the map**, and the calibration
  is the part to copy. Channel three (a caller-controlled index handed to a member whose bound
  test is an out-of-line macro) was written after PR #2870 fixed ten such sites, so it could be
  run against the tree as it stood at that PR's parent: it reports all seven of the sites the PR
  guarded, three of them naming the bound-checked sibling one screen away that is how #2859 was
  found by hand. A channel that reports nothing on a clean tree and everything on the tree the
  defect shipped in is calibrated; one that reports nothing on both is untested. Channel four is a
  committed table with a `--verify` that re-derives it, on the `derive-gdt-enums.py` precedent,
  because its subject (a `#ifndef No_Exception` region that swallows the condition variable and
  not only the raise) cannot be derived from raise sites at all.

  **And #2885 is the general lesson that a committed derivation needs a trigger, not a note.**
  "`--reverify-table` re-derives at an OCCT version bump" was true and was nobody's step, so
  nothing ran it when a *carried patch* changed a raise site: `0042` added a throw to
  `ShapeAnalysis::GetFaceUVBounds` and the map said that class held no live throw for two pins,
  with every gate green, every canary satisfied and every plausibility assertion passing. The
  assertions could not have seen it either, and that is the part to carry: they ask whether the
  map is a map of *an* OCCT tree, not whether it is a map of *this* one, and a map missing one
  throw row is a perfectly good map of the tree it was derived from.

  What closed it is **the artefact recording its own inputs**. `--write-table` stamps the map with
  the OCCT version the tree states and one line per carried patch with a digest, and
  `check-inventory-prose.py` fails when that stamp and `Scripts/patches/` disagree: text against
  text, no tree, red on the PR that carries the patch rather than at some later reading. Three
  properties are worth copying to the next committed derivation:

  - **The stamp is measured, not asserted.** `--write-table` verifies every carried patch is
    really in the tree it is about to derive from, by undoing the patches newest first against the
    file, each hunk's post-image replaced by its pre-image, and refuses to write anything when one
    is not present at its turn. Undoing in order, not matching each patch's added lines, is what
    lets a later patch rewrite an earlier one's lines (0055 over 0051, #3010) without the earlier
    patch reading as missing. A stamp that merely copied today's patch
    list onto yesterday's rows would put the gate to sleep, which is worse than the gap it closes.
  - **It is keyed on the inputs, not on the pin.** The tree `build-occt.sh` patches is the one
    `Scripts/patches/` describes, so an unpinned patch is in this check's subject and not in
    `check-pinned-asset-patches.py`'s. The two are meant to be able to disagree, and saying which
    is which is part of the check.
  - **The half that needs the tree runs where a tree exists.** `--reverify-table
    --require-occt-src` and `--verify-no-exception-regions --require-occt-src` run in
    `kernel-integration.yml` after the patched build, which is triggered by exactly the change
    that makes the map stale. The stamp catches a stale derivation; only the re-derivation catches
    wrong *rows*, and a PR that edits the map alone still gets only the first.

  It is implemented inside `check-inventory-prose.py` rather than as a seventeenth gate, on
  `check_tsan_suppressions()`'s precedent: one artefact has this shape today, that file already
  reads `Scripts/patches/` and already owns every record this repo keeps of the patch inventory,
  and a standalone script for one artefact would be disproportionate. The patch **count** in the
  stamp is a CLAIMS row like every other counted claim; the per-patch digests are what catch a
  patch revised in place, which no count can see.

**Tense is the other thing a repin leaves stale, and `check-inventory-prose.py` reads it too
(#3056).** #3031 pinned eight patches and #3054 then corrected about thirty sentences in ten files
that still called them "NOT built", "not pinned" or "to be deleted when this is pinned". The
counted-claim checks passed throughout, and `census-comment-staleness.py` reads names that no longer
resolve, whereas these named patches that resolve perfectly and were wrong only in tense.
`check_stale_pin_prose()` derives each patch's state from the enumeration `Package.swift` states,
and flags a sentence calling a pinned patch not-yet-pinned. Three properties are worth copying:

- **It does not guess.** It judges a sentence only when it resolves to one patch: a patch number in
  the sentence, a `Package.swift` enumeration row, a table row keyed by a number, or a
  `## NNNN-` section. A past-tense sentence ("was unpinned until v4.0.0-kernel.4"), a patch named
  for comparison ("unlike `0044`") and a sentence naming two patches are silent, so a misread is
  a miss and never a false alarm. A pronoun phrase ("until it is pinned") reads the nearest patch
  before it. The same words about a patch the list does not hold are correct, so an unpinned
  patch's rows need no edit; a self-test case uses a synthetic `0056` for exactly that.
- **It was proved against the defect it was written for.** Replaying `git show 3054^:<file>`
  against the post-#3031 pin state, it flags 18 of #3054's 47 hunks directly: every Package.swift
  row the repin left reading "NOT built" or "WHEN THIS IS PINNED", the by-plane mirror's
  repin instructions in `CLAUDE.md` and `Scripts/patches/README.md`, and the two okf rows. It cannot
  see the 29 others: 15 are kernel tags and counts (`kernel.3`, "thirty-one", "beta.4 not cut") with
  no patch to anchor to, and 14 are the by-plane mirror's own comments and a present-tense row, which
  name no pinned state at all. The self-test replays six excerpts of that text, kept short but taken from
  those revisions.
- **It was a report until the tree was clean, and is a gate now (#3114).** Its false-positive count
  on the live tree was zero from the first day, but it also found sentences that really were stale
  and sat in files the change that added it did not own, and a gate red on its first merge blocks
  every open PR. #3112 therefore printed them under "REPORT, not a gate yet" and exited 0, and #3114
  corrected the twelve it reported (plus two neighbours it could not resolve, "like `0051` and
  `0052`" and "unpinned with `0050` and `0051`", found by reading the sections around them) and
  flipped `PIN_PROSE_IS_GATE`. A bare run now exits 1 on a stale sentence, and a repin that pins a
  patch must rewrite what called it unpinned in the same PR. A sentence kept as history is written
  in the past tense or carries `pin-state-exempt: <reason>`. It is part of
  `check-inventory-prose.py`, not a new script, so the gate and census counts above did not move.

**One gate holds the bridge to the kernel's protocol rather than to a convention of this repo.**
`check-transient-release-idiom.py` (#2974) reads every function in `Sources/OCCTBridge/src/*.mm`
that calls `DecrementRefCounter`, three today, and requires each to be
`opencascade::handle::EndScope` (`Standard_Handle.hxx:389-394`) written out by hand: destroy on the
value the decrement returned, and call the virtual `Delete()`. Two releases wrote a discarded
decrement, a separate relaxed `GetRefCount()` re-read and a bare `delete` instead, which is a race
window three ways over and a bypassed virtual, and that divergence stood from the day those
functions were written, survived review, and survived the PR that was specifically about their
correctness (PR #2969). Three things about it are the general shape rather than this gate's detail.

- **It gates on its first day**, on the rule below: the backlog was zero once #2969 landed, and the
  subject is a use-after-free rather than a list to adjudicate.
- **Its third rule is only usable because it is scoped.** A bare `delete` is correct code in most
  of this tree, since the bridge `new`s its own opaque handle structs; keyed on the functions that
  also call `DecrementRefCounter`, the same rule has a population of three. The rule is not "do not
  write `delete`", it is "do not write `delete` where the kernel writes `Delete()`".
- **A population of zero is a refusal and not a clean run.** If the last raw `Standard_Transient`
  release goes, the gate examined nothing, and nothing in a green check distinguishes that from a
  clean tree, so it exits 2 and says which of the two to check. Its deliberate divergence
  (`OCCTTObjApplicationRelease`, whose singleton must never destroy on a zero count) carries
  `transient-release-exempt: <reason>` in the comment beside it, with the reason required on
  `check-doc-snippets.py`'s precedent.

**One gate holds the bridge to an upstream design rather than to a convention of this repo, and it
is an allowlist.** `check-bridge-adaptor-members.py` (#3065) fails on any stored OCCT adaptor in
`Sources/OCCTBridge` that is not on its two-entry allowlist. OCCT's adaptors own a BSpline
evaluation cache that a `const` evaluator rebuilds in place, and upstream's stated design is that
each worker owns its adaptor, taking `ShallowCopy()` of a shared one. An adaptor built per call is
private by construction, so the bridge's hundreds of those are not the subject; one that outlives a
call (a struct member, a namespace-scope variable, a function-local `static`) is reachable from
every caller of its holder, which is the shared-adaptor shape that read a wrong point in 97 of 97
completed runs once carried patch `0031`'s locks were removed. Two are stored today, `OCCTEdgeCurve`
and `OCCTCompCurve`, behind the Swift `EdgeCurve` and `WireCurve`, and the gate holds the other half
of why that is acceptable: neither class may declare `Sendable`. It gates on its first day, on the
rule below, since the backlog was zero. It refuses on a population of zero and fails on an
allowlist entry that matches nothing, the two ways an allowlist goes silently stale. It is
independent of whether `0031` is carried: it holds a property that is right with or without the
locks.

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
`gate-scripts` jobs that ran the then-current 44-step list.** A laptop measurement would answer a
different question: what this job costs is what it costs a PR, and `ubuntu-latest` is where that is
decided. #2820 has since added two invocations, `check-bridge-type-odr.py` bare and its
`--self-test`, each well under a second; the figures below are not re-measured for them, and the
recipe under "Re-derive it" is how to replace them rather than adjust them by hand.

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

**And type-checking was never the whole question, which is #2851.** A documented example that
compiles and then takes the process down passed this gate, and one did:
`docs/reference/Surface-Analysis.md`'s `extrema(to:)` entry was #2840's crash reproducer, carrying
`≈ 10.0` as its expected answer, and it read as green for as long as #2840's defect existed. The
issue offered four answers and leaned away from executing anything, on a cost argument nobody had
priced. **Priced, the cost is 13 s**: three runs each on one laptop give a median 5 s to
type-check 3,183 snippets and 18 s to type-check and then run the 1,735 that compile, of which
about 6 s is the running and the rest is one compile and one link. So the answer is the one the
issue called too expensive, and three design choices are what make it that cheap and are worth
copying:

- **One executable, not one per case.** Linking a single one-statement snippet against this
  package's merged static archive is 4.4 s measured, so a link each is over two hours. Every
  snippet becomes one function in one binary: one compile, one link, 1,735 cases in 7 s.
- **A resume driver, not a process per case.** The binary takes a starting index and announces
  each case before running it, so a crash names itself and the driver restarts past it. A clean
  corpus is one process; each defect costs one more. The cost scales with the number of failures
  rather than with the size of the population, which is the property that lets a per-PR check
  execute 1,735 programs.
- **A canary with the opposite sign.** The compile stages plant a file that must fail to compile;
  this one plants a case that must fail to *run*. A driver reporting every case clean is
  indistinguishable from a clean corpus, and the ways to get there are ordinary: a binary that
  exits early, a pump thread reading nothing, a watchdog that never fires.

And one more instance of **an artefact this repo has already been caught reading badly twice**,
now three more times in the one PR. The run stage links against compiled code the type-check stage
never needed, and each of the first two attempts answered a question nobody had put to the build
system.

The first took any `lib*.a` beside the module. On the CI runner the module's own directory held
the OCCT kernel archive and nothing else, so the link failed on every `OCCTSwift` symbol, which
looks exactly like finding no archive at all. The second looked for `libOCCTSwift.a` and
`OCCTSwift.o` **by name**, beside the module and then under `.build`, and reported both as
nowhere, which reads as a broken build rather than as a wrong search. **Neither file exists on the
runner and neither ever did.** `OCCTSwift` is an *automatic* library product, so whether a
standalone archive is written at all is SwiftPM's choice and not the manifest's: the Swift Build
backend (`swiftbuild`, the default since Swift 6.4, which is what a laptop runs here) writes both
into `.build/out/Products/Debug`, and the llbuild backend (`native`, still the default in the
Xcode the runner has) writes **neither, anywhere**. It compiles each target into
`<bin>/<Target>.build/` and links those objects straight into every executable.

The third asks. `swift package describe --type json` names the targets behind the `OCCTSwift`
product, a measured 0.7 s against a resolved package, and the objects are taken from each of those
targets' own directories beside the module: `rglob`, not `glob`, because a Clang target nests its
objects under the source directory they came from, so the 74 bridge objects are in
`OCCTBridge.build/src/`. The refusal prints what all three searches saw, including the target list
and whether `describe` could be read at all. `ci.yml` still deletes `libOCCTSwift.a` alongside the
module before the build for #2867's own reason, and the per-target objects need no such step
because they are only ever read from the directory holding the module whose age is already
checked.

**The layout was reproduced locally before the line was changed**, with
`swift build --build-system native`, which is the whole lesson of the two failed attempts: in that
tree the fix passes 1,735 of 1,735 and reverting it reproduces the CI refusal word for word.
Guessing at a remote layout costs a round trip per guess; reproducing it costs one build.

Its backlog was two, both fixed in the same PR, so it gated on its first day under the rule below:
an untrimmed `Curve3D.circularHelix` whose `drawAdaptive()` subdivides an infinite domain forever,
and an untrimmed `Surface.cylinder` handed to `Shape.shell(from:)`. A snippet that **throws** is
not a failure, and six do, every one of them a documented example reading a `/tmp` path the repo
does not ship. A snippet that compiles and must not be run carries `no-run: <reason>` on the
fence, a separate marker from `no-typecheck:` because it answers a separate question, with the
reason required for the same reason.

**Which is also what says when a detector may gate on its first day.** The sequence is about the
backlog, not about a probationary period, so a detector whose backlog is *already* zero has nothing
to work down and gating it immediately costs nobody a red check. `check-bridge-type-odr.py` (#2820)
is that case: the issue measured 83 file-scope type names defined in more than one bridge `.mm`
across 605 definitions and **0 of the 83 disagreeing**, so the gate landed exiting 1 with the tree
clean. Two things made it the right call rather than an exception taken for convenience. The subject
is a defect and not a list to adjudicate: a class defined in several translation units is well formed
only while the definitions are token for token identical, and a divergence in an opaque handle struct
is memory corruption across a boundary the type system cannot see, which the compiler cannot
diagnose because each unit is individually valid. And the gate fires on **disagreement**, not on
duplication, so the 605 legal copies are reported as a census figure beside the verdict and hoisting
one of them into `OCCTBridge_Internal.h` ([helper-placement-by-reach](helper-placement-by-reach.md))
makes the gate quieter rather than louder.

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

**And a freshness check is only as sound as the artefact's provenance, which is #2867.** The same
check then blocked three PRs, refusing over a module older than their sources. It was right about
the ages and wrong about what it was looking at: the module sat at
`.build/debug/Modules/OCCTSwift.swiftmodule`, the llbuild layout's path, and those jobs built on the
Swift Build backend, which writes the bin root instead. One `actions/cache` key served both, so a
module no build in any of those jobs would ever rewrite was the only one the search could find. The
three refusals reported 1925s, 3474s and 3526s; subtract each from its own job's checkout time and
all three give one instant, `2026-09-29T06:48:12Z`, which is what identified it as a cache artefact
rather than that build's output. Two rules come out of it:

- **Delete a cached artefact a detector will read, rather than reasoning about its age.** `ci.yml`
  now clears every `OCCTSwift.swiftmodule` under `.build` between the cache restore and
  `swift build`, so anything the gate finds was written during that job, after the checkout, and is
  newer than every input by construction. That argument survives a build-system change, a layout
  change and a cache key that outlives both; an mtime comparison against a restored artefact does
  not. Nothing in the detector was relaxed to get there.
- **A refusal has to say which artefact it read and when that artefact was written.** The absolute
  time, not the delta. Reconstructing the above took arithmetic across three jobs because each run
  printed only its own difference, which is the same class of gap as a gate reporting success over
  an unstated population.

**Freshness is one axis and identity is another, and #2818 is the second.** Four scripts read
`Libraries/OCCT.xcframework` and decided "this is the pinned kernel" from `os.path.isdir` alone:
`check-766-probe-reproduction.py`, `census-doc-occt-attribution.py`, `derive-gdt-enums.py` and the
release check `check-pinned-asset-patches.py`, which computed the answer and then only printed it.
None of the four looked where SwiftPM actually puts the pinned asset, so a clean checkout reported
SKIPPED over an asset that was present, and a checkout with a locally built one reported verdicts
about a kernel the repo does not pin. Measured, not theoretical: on 2026-09-28 the main checkout's
`Libraries/` archive and the pinned `v4.0.0-kernel.2` archive had different sha256s, and `Libraries/`
was every one of those scripts' default.

`Scripts/occt_asset_identity.py` is the one helper all four now use, placed by reach rather than
copied ([helper-placement-by-reach](helper-placement-by-reach.md)), and its self-test is folded into
each of theirs rather than trusted to its own run. The part worth carrying to any detector that reads
a pinned artefact is **what is actually comparable**: `Package.swift`'s `checksum:` is of the **zip**,
so an extracted tree cannot be hashed into it. Only three things can be compared, and the fourth
answer is a real answer:

- a zip beside the xcframework, sha256ed against `checksum:`, which is the release step's case;
- SwiftPM's own `.build/workspace-state.json` record, which is proof by provenance because SwiftPM
  refuses an artifact whose zip does not hash to that checksum;
- an archive fingerprint, which identifies which kernel was read and makes a past verdict
  attributable, and can never on its own say "this is the pinned one";
- **`unverifiable`**, for an extracted tree with neither, which is what the four used to call pinned.

`--require-pinned-asset` is the #2098 `--require-` mode applied to this axis. Where a detector writes
or compares a **committed** file derived from the pinned kernel (`Scripts/occt-packages.txt`,
`Scripts/occt-gdt-enums.txt`), the requirement is not optional: those modes refuse an unproven asset
whether or not the flag was passed, because baking off-pin enum ordinals into a committed manifest is
a wrong-value defect and the raw values cross the bridge unremapped.

And an acknowledgement about an asset is keyed on the asset, never on the pin. The release check's
`ACKNOWLEDGED` table was keyed on the tag `Package.swift` pins, which is a different thing from the
asset it read, so a row written about the pinned asset suppressed a finding about whatever local
build was on disk.

## Every detector proves it is not blind

Seventeen of the eighteen gates, all seven censuses, the merge-history audit and the release check
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
  a green CI step that examined nothing is a false green. And when a run does skip, **state how many
  cases ran out of how many exist**, as a headline rather than a parenthetical: `check-doc-snippets.py
  --self-test` reported `38 passed, 1 failed (compile cases SKIPPED: no built package)` for a battery
  of 67, five parenthesised words at the end of forty lines of `ok` (#2867). It now prints the two
  counts on the summary line and draws a banner naming the difference and the reason.
- Reading a population you can size independently? Compare the two and fail on a large divergence.
- **Parsing?** Carry a canary the parser cannot miss, and abort when it comes back *empty*. The
  compiler canary's sign, flipped: a compiler canary must fail and a parser canary must match.
  `check-bridge-type-odr.py` does this, and it is what covers the one case two independent scans
  cannot, which is both going blind at once and agreeing at zero.

**And the plausibility check must not be trippable by the refactor the detector recommends.**
`check-bridge-type-odr.py` shipped with `if definitions < 100: abort`, a floor on the absolute size
of its population. Its own output tells the reader to hoist a duplicated type into
`OCCTBridge_Internal.h`, which is what [helper-placement-by-reach](helper-placement-by-reach.md) asks
for, and every hoist removes file-scope definitions from the `.mm` files, so the gate would have
aborted precisely when the work it advocates succeeded, with a message blaming its own parser
(#2833). A floor on **agreement between two independent measurements** has no such direction:
hoisting moves both measurements together, and the fully hoisted end state is nothing to compare
rather than a scan that saw nothing, which the report then says in those words. Prefer an agreement
floor and a canary to a magic number, and where a magic number is unavoidable, ask which legitimate
change would cross it.

**Asking that question retired the second such floor the same week.**
`census-compiled-out-validation.py`'s `derive` aborted on `if files < 5000`, a floor on the OCCT
source files its walk found. The real tree yields 14,671, so the floor sat at 34% of the population
and discriminated nothing: nothing plausible crosses it from above, and a tree of 5,001 files is no
more the pinned tree than one of 4,999. What it was catching is `--occt-src` pointed at something that
is not an OCCT source tree, which lands at 0, and two content canaries catch that while naming which
fact was absent, so the message stops blaming the tree for the script's confusion. The sizing question
moved to where it belonged and already was: the *consumer*, `assert_view_is_plausible`, which refuses
to report from a map of under 500 classes. **A floor in a producer is the shape to look for.** It
cannot act on the answer, and the check it is standing in for belongs to whoever reads the result.

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

`Scripts/git-hooks/pre-commit` runs forty-four of `gate-scripts`' forty-five invocations, flag for
flag. The one it omits is `check-changelog-transcription.py`'s real run, which answers a question
about the branch rather than about the commit being made; its `--self-test` does run. That is the
only deliberate divergence, and it is written here because an undocumented difference between the
hook and CI is exactly what makes a passing hook misleading.

It also runs `Scripts/format-bridge.sh --self-test` and `--check`, which belong to the `code-style`
CI job rather than `gate-scripts`. CI and the hook invoke the same script, so there is one copy of
the file selection to drift. The rest of `code-style` (swift-format, SwiftLint) is
push-and-find-out, because clang-format is the only one whose findings are wholly mechanical. A clang-format violation blocks the commit; a missing clang-format, or one on
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
