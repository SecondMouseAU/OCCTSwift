---
type: reference
title: Injection sweep mechanics
resource: https://github.com/SecondMouseAU/OCCTSwift
tags: [reference, testing, agents, prove-the-test-fails]
description: How to run an injection sweep cheaply and without lying to yourself. Run the built .xctest directly rather than `swift test`, inject by shadowing the bridge import rather than editing a .mm, resolve every anchor uniquely before the first build, assert the switch set against the test set in both directions, make a duplicated body a distinct copy, and name a crash as a crash.
timestamp: 2026-10-03
---

# Injection sweep mechanics

[Prove the test fails](../policies/prove-the-test-fails.md) is the rule. This page is the
mechanics, measured across the batch 7, 8 and 9 lifts, where the sweeps were large enough that
every one of these cost real time or produced a false clean.

## Run the built `.xctest` directly, not `swift test`

**`swift test` re-resolves and re-links on every invocation.** Measured on 2026-10-02 at machine
load 90 to 155, which is the normal state when several agents are working: **1.5 to 5 minutes per
invocation**. A sweep runs the suite once per switch, so a 54-switch sweep is four hours of
waiting.

Run the already-built bundle through `swiftpm-testing-helper` instead: **0.5 seconds**. The same
sweep took forty seconds.

It needs three symlinks into `.build/out/Products/Debug/PackageFrameworks`:

* `XCTest.framework`
* `Testing.framework`
* `libXCTestSwiftSupport.dylib`

They are required because **SIP strips `DYLD_*` from the Xcode-signed helper**, so the usual
environment-variable route to those frameworks never reaches it. This is the single largest saving
available in this repo's test loop, and it also sidesteps the load reaping below, because a run
that takes half a second is not around long enough to be killed.

## Inject by shadowing the bridge import, not by editing a `.mm`

Put the switches in a **temporary Swift file under `Sources/OCCTSwift`** declaring functions with
the same names as the C functions imported from `OCCTBridge`. A module-local declaration wins over
an imported one, so every call site picks up the shadow with no edit to any call site and no edit
to any `.mm`.

Three failure modes disappear with it:

* **Ambient `OCCTSWIFT_BRIDGE_PREBUILT=1` makes a `.mm` edit inert**, silently, and it is the first
  thing that turns a sweep green for the wrong reason. A Swift-side shadow is unaffected.
* **There are no anchors to disambiguate**, because the shadow is keyed on the symbol.
* **Removal is deleting one file**, so the tree cannot be left subtly dirty.

One build serves every switch, gated at runtime by an environment variable.

**It does not work where the test calls the C symbol itself.** A test file carrying both
`@testable import OCCTSwift` and `import OCCTBridge` sees the shadow and the import as equally
visible, and the compiler refuses with `ambiguous use of`. Those switches go in as a one-line
splice at an anchor whose uniqueness you have verified, as below.

## Resolve every anchor uniquely before the first build

Where you do edit source by pattern, assert the pattern is unique **before** compiling anything.
Three sweeps hit this:

* `*outLast = range.second;` matched both `OCCTBRepGraphEdgeRange` and `OCCTBRepGraphCoEdgeRange`;
  `isValid: Bool { counter > 0 }` matched all three UID types.
* Two switches shared `MovePointAndTangent` and two shared `DrawAdaptive`, so the sweep anchored
  each distortion to its enclosing function first and then asserted the replaced text unique
  inside that function's body.
* One ambiguity appeared on the way **back out**: a `firstVertex` injection rewrote a call to
  `OCCTEdgeLastVertexSA(...)`, which then matched the genuine `lastVertex` body, so the revert
  would have edited the wrong function. Give the injected line a marker and restore from git.

An anchor that matches twice does not fail loudly. It edits the wrong thing and the sweep reports a
result about code you did not mean to change.

## Assert the switch set against the test set, both ways

Every changed test red under at least one switch, **and** every switch reddening at least one
changed test. Derive the changed set mechanically from `git diff origin/main..HEAD` rather than
from your own notes.

This is what catches the gaps. One sweep's first pass left exactly one, a switch that nilled
`OCCTSectionBuilderCreate()` but not `...CreateFromShapes`; another found two of its own cases were
placed so the thing they tested could not affect them, and they passed with the subject broken.

Also run the harness once with **no switch set** and confirm the suite is green, so an inert
harness cannot be mistaken for a passing one.

## Two scrapers that read a pass where there was none

* **Swift Testing prints `Test "Display name"` for `@Test("...")`**, and the function name appears
  nowhere on that line. A scraper keyed on function names silently misses every test with a display
  name. The failure lines have the same two shapes, `✘ Test "Name" failed` and `✘ Test f() failed`,
  and a scraper matching one of them once reported nine reds as green.
* **`swift test --filter` is a regex over the whole test ID across every target.** A bare `degree`
  or `segment` matches other modules and runs far more than intended. Anchor it:
  `OCCTGeom2dTests\.<Suite>/<func>`.
* **Swift Testing colours the failure glyph, and the reset sits between the glyph and the word.**
  The line is `\x1b[91m✘\x1b[0m Test name() failed`, so a pattern anchored on `✘\s+Test` matches
  nothing at all. One sweep's first scraper **read all eleven of its reds as green** on exactly
  that. Strip ANSI before matching, every time. This is the worst of the three because it fails in
  the reassuring direction and the run itself looks normal.

## A result that is not a result

**Exit `-15` or `143` is the machine reaping the run under load**, not a failure and not a pass. A
detached run via `os.setsid` plus a done-file survives it. A long run in a plain background job
does not.

**A pipe hides the exit status.** `Scripts/tsan-stress.sh swift | tail -40` reports `$?` from
`tail`, so a gate exiting 66 on a race is indistinguishable from one exiting 0. Redirect to a file
and read the status separately, or use `set -o pipefail`.

**A known issue passes under a different glyph.** A test carrying a `withKnownIssue` prints
`━ Test "name" passed ... with 1 known issue`, not `✔`. A scraper counting only `✔` reads that
suite one test short, and a baseline check that insists every test passed refuses to run at all,
which is where #2983's runner stopped on its first attempt. Count both glyphs as a pass.

**A crash is a result a runner has to name.** The helper exits with the signal, so `exit < 0` or
`exit > 1` is the process dying rather than a test failing, and every test after the one that died
never ran. #2983's first full matrix hid four of these: a test indexed `viaShapeFix.solids[index]`
before requiring that the result had that many bodies, so four `solidFromShellFixed` switches
(identity, first only, last only, drop last) ended the run with SIGTRAP (exit -5), and the reds each
reported were only the tests that had run before the one that died. The runner reports a crash as a crash, and a test requires the
count before it indexes.

## A restore is not finished until the bundle is relinked

Measured on #3012's sweep, 2026-10-03, and it fails silently. After the sweep put the injected
`.mm` back with `git checkout --`, one `swift build` naming two test targets recompiled
`OCCTBridge.o` and linked the second target against it, and left the first target's bundle linked
against the **injected** bridge. The plain run of that bundle was green, because every switch is off
unless its environment variable is set, so nothing looked wrong. What showed it was running the
bundle with a switch set, which a clean bundle must ignore and the stale one did not: 36 issues. A
second `swift build` relinked it.

So after the restore: rebuild until the bundle holds no injection marker
(`strings <bundle> | grep -c <marker>`, where the marker is a string that exists only in the injected
code), then run it once with a switch set and require green. `swift build` exiting 0 says neither.
`Scripts/repro/3012-commonpart-range1/run-injection-sweep.py` does both and refuses to report a
matrix for a tree it could not prove clean.

## A switch that duplicates a body has to duplicate a distinct one

"The first body twice" is the switch that separates a test pinning **which** body came back from one
pinning how many. Built as the same `TopoDS_Shape` repeated it is not that experiment: a repeated
shape counts once in `subShapes(ofType:)`, so every count caught it and it was `first only` under
another name, which is what #2983's first version of `*_DUP_FIRST` was. Build the repeats with
`OCCTShapeCopy`, which makes new TShapes over the same geometry: the count, the faces and the
volume all stay right and only the position is wrong. Measured on the five entry points
`Issue443FirstOfN` and `Issue442FixSolidMultiBody` cover, it reddened 1, 1, 2, 1 and 3 tests
against `main`'s versions and 7, 5, 8, 5 and 5 against the rewrites.

The same applies to orientation. "Every body inside out" is caught by any volume check, and is not
"the first body fixed and the rest left as they came in", which is the loop a regression would
actually write and which a healthy fixture cannot show, because a body that needed no fix looks
the same fixed or not. Both need a fixture that is wrong in the way the operation repairs.

## Run the switches against the old version too

The sweep's usual job is to prove the new tests have teeth. Running the **same** switches against
the version you replaced measures something the census cannot: what the change actually bought.

Batch 10's BndLib lift reported it, and the two numbers are not close. Against `main`'s versions,
**14 of 19 switches reddened nothing and 17 of 21 tests caught nothing**. After the lift, zero and
zero. One switch was the exact defect its own issue described in its own words, and `main` was
silent on it.

The census delta for the same batch was **three SEVERE**, which understates it by an order of
magnitude, for the reasons under "a gain is a candidate". #2985 was one of them and is fixed, so
an ordering tautology no longer scores as a pin; what remains is in
`census-766-weak-assertions.py`'s "WHAT IT CANNOT SEE", and its first entry is a batch-10 shape
the sweep caught and the census never will: `bb.max.x - bb.min.x > 9.0` where the true span is
10. So where a batch's value is in question, the counterfactual is the measure to trust and it
costs one extra run of a harness you have already built. Report both.

## Measure both sides at the same instant

`origin/main` is shared across every worktree and moves while you work. A batch that measures
"before" against `origin/main` at the start and "after" against it at the end is comparing two
different trees, and the error is not small: one batch's repo-wide SEVERE comparison read **+20**
when the true delta was **-39**, and two runs of an identical `census-766-unlifted-tests.py
--onto origin/main` minutes apart disagreed about which paths were ABSENT.

`git archive origin/main Tests` into a scratch tree, then measure both sides against that frozen
copy. Rebase immediately before pushing, and re-derive any figure you quote in the PR body after
the rebase rather than carrying it across.

The same applies to a figure handed to you in a brief. Three batches in one day were given a
repo-wide SEVERE number that had already moved; every one of them re-measured and said so, which
is the behaviour to copy. **Re-measure, do not quote.**

A kernel repin is one of the moves. #2983's sweep was written on `v4.0.0-kernel.3` and `origin/main`
repinned to `v4.0.0-kernel.4` while it ran, so every pinned value was re-checked and the matrices
re-run on the new asset before the PR body quoted either. And a gate that compares against
`origin/main` reads the **local ref**, which another worktree's `git fetch` advances:
`check-style-manifest.py` reported "grew by 1 entry" about a file the branch had never touched.
Rebase first, then read the gate.

## A rebase can leave the module stale, and `swift build` will not fix it

After a rebase, `check-doc-snippets.py` refuses with `module ... OLDER than the newest module
input`, and rebuilding does not clear it. The build system is content-hashed, so a source whose
content the rebase did not change but whose mtime it bumped leaves the module's own mtime behind,
and nothing rebuilds.

    rm -rf .build/out/Products/Debug/OCCTSwift.swiftmodule && swift build

With an ambient `OCCTSWIFT_BRIDGE_PREBUILT=1` this is guaranteed on any rebase that touches a
bridge `.mm`.

## Restore with git, never by reverse-replacement

Undoing an injection by replacing the new text with the old looks symmetrical and is not. Two
edits in one injection shared a replacement string, so the reverse-replace matched twice and threw
**from inside a `finally`**, which both left the tree dirty and discarded that injection's result.

`git checkout -- <paths>` is the only safe restore. It is also the only one that cannot leave a
half-reverted file behind when the sweep is interrupted.

**Commit the new tests before swapping the old ones in.** The "before" column needs `main`'s
versions of the test files in the tree, and `git checkout HEAD -- <files>` puts back what was
**committed**, not what the files held when you swapped. #2983's sweep lost a helper rewrite that
way and found out only because a grep for the helper's call sites came back empty.

## A green switch can be the finding

A switch that reddens nothing is usually a bad switch, and occasionally it is a measurement.
`G2D_UNIFORM` came back green because `GCPnts_UniformAbscissa` returns exactly the requested count
on the pinned kernel, so the surplus-point path the switch distorted is **unreachable from that
test** (#2977). Probe before concluding the switch was wrong: the alternative conclusion is that
the guard under test is dead.

Two more from #2983, one for each way the green was not a bad switch:

* **The fixture gave the subject nothing to do.** Three history switches (the history of the first
  body alone, of the last alone, of an unrelated run) reddened nothing against the old suite, and
  the switches were fine. A healthy box repairs nothing, so `record(of:)` read 0 modified, 0
  generated, not deleted for every face, and a history covering no body answers exactly like one
  covering both. Probe the subject's output for the fixture before blaming the switch. The fix was
  an input with something to record: a one-face shell whose face has its wire out of order, which
  `ShapeFix_Face` replaces, once per body.
* **The contract promises nothing there.** `UP_SWAP` (the bodies of `upgraded()` in reverse order)
  is still green after the rewrite, because sewing chooses the order and the call never says which.
  The switch models a change nobody is entitled to expect, and the green row is a statement about
  the contract. Its siblings on `solid(from:)`, `solidFromShellFixed()`, `fixSolid()` and the
  history variant, which do promise exploration order, are red. Say which kind a green row is, so
  the next reader does not hunt for a missing assertion.

## Related

- [Prove the test fails](../policies/prove-the-test-fails.md), the rule these mechanics serve.
- [Lifting work off `v5.0.0-766-execution`](../policies/v5-lift-and-shift.md), where the sweeps
  that produced these measurements were run.
- `Scripts/repro/2983-shapehealing-resweep/`, a whole sweep kept as evidence: the Swift shadows, the
  two gated edits, the switch list under `GROSS`, `SEMANTIC` and `FIXTURE` headers, the runner, and
  the before and after matrices, for the multi-body, orientation and history shapes above.
