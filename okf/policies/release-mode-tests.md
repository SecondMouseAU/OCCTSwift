---
type: policy
title: Release-mode tests
description: CI runs the tests in an optimised (-c release) build under malloc scribbling, because a debug build hides a wrapper released before the C call that receives its handle. A pull request runs the suites that pass a raw handle to the bridge, main, a dispatch and a published release run everything.
tags: [policy, ci, testing, swift, lifetimes, release]
timestamp: 2026-10-10
---

# Release-mode tests

**`swift test` in a debug build cannot see a whole class of defect, so one CI job runs the tests in
an optimised build.** Swift may release an owning wrapper (`let edges = box.edges()`) as soon as its
last use is the `.handle` load, before the C call that receives the pointer runs. A debug build
extends every local's lifetime to the end of its scope, so the same code passes there. #2929 passed
every debug run and failed on wasm; #3130 found the exposure was the public `handle` shape itself.
The static gate `check-borrowed-handle-temporaries.py` ([static-gates](static-gates.md)) catches the
shapes a regex can see. This job catches the rest by running them.

## What runs

`.github/workflows/release-mode-tests.yml`, a reusable workflow, runs `Scripts/release-mode-test.sh`.
That script is the one definition of both scopes, so a local run and CI cannot disagree:

| scope | what it runs | who gets it |
|---|---|---|
| `subset` | every suite whose file mentions `.handle` or `withHandle` | a pull request, and a push to any branch other than `main` |
| `full` | every suite | a push to `main`, `workflow_dispatch`, and the `release` workflow when a release is published |

The subset is derived from the tree, never listed, so a new suite that hands a raw pointer to the
bridge is selected without anyone editing a list. Both scopes build every test target
(`swift build -c release -Xswiftc -enable-testing --build-tests`) and run with `--skip-build`. The
test run, not the build, is under `MallocScribble=1 MallocPreScribble=1 MallocGuardEdges=1
MallocErrorAbort=1`: scribbling is what turned the use-after-free from a stale-but-plausible read
into a failure in 7 of 8 runs (`Scripts/repro/3130-borrowed-handle/`).

## Why the split is where it is

Measured on the CI runner (macos-15, Xcode default, Swift 6.2.4, pinned kernel from the release
asset) and, for the whole-suite numbers, on one M-series Mac (10 cores, shared with other builds, so
those are upper bounds):

| step | wall time |
|---|---|
| `swift build -c release -Xswiftc -enable-testing --build-tests`, CI, five runs | 528 s to 720 s (a restored cache did not shorten it) |
| the whole `subset` job, CI (build plus about 160 tests in 0.4 s) | 10 min 31 s to 13 min 12 s |
| the debug `swift build + test (macOS)` job, CI, same commits | 11 min 14 s to 13 min 38 s |
| the whole `full` job, CI (build 528 s, then 6,888 tests in 324 s with the known failures skipped) | 14 min 59 s |
| `swift test -c release --skip-build`, whole suite, local, no malloc env | 6 min |
| the same under all four `Malloc*` variables, local, three runs | 3 min 22 s to 4 min 8 s |
| the same under `MallocScribble` + `MallocPreScribble` only, local | 4 min 12 s |

- **The build dominates and is the same for both scopes.** About 10 to 12 of the 13 minutes are the
  optimised build of every test target. Locally `swift test --skip-build` also refuses to run unless
  every target's `.xctest` bundle exists (`OCCTThreadTests.xctest doesn't exist in file system`,
  measured with only the subset's targets built) and `swift build --target A --target B` builds only
  `B`; #3248's "1m44s + 7s" for one target was measured on a tree where the other seventeen bundles
  already existed. CI's SwiftPM links one `OCCTSwiftPackageTests.xctest`, so there is no narrower
  build to have.
- **What the subset saves is the test phase, about five and a half minutes (324 s against 0.4 s), and a flake surface.** The full
  suite has one measured flake that is not release-specific (#3256, 1 in 40 in debug and 1 in 40 in
  release). `Scripts/merge-pr.py` refuses a PR while any non-wasm check is red, so a flake in a job
  every PR runs costs a re-run on that PR; the same flake on `main` costs a re-run and nothing else.
  The subset is about 160 deterministic tests, so a red there is the hazard.
- **Full release runs on `main`, a dispatch and a release** because a defect a pull request's
  subset did not select (a suite that reaches the hazard without the literal `.handle`) is found
  there, within one merge, and a published release is the point where "the debug suite is green"
  has to mean the shipped build is too.
- **All four `Malloc*` variables**, because three full local runs under them were green and no
  slower than scribbling alone, and `MallocGuardEdges` and `MallocErrorAbort` turn an out-of-bounds
  write into an immediate abort. If a run is ever red with an abort in a suite that has nothing to
  do with lifetimes, drop those two in `Scripts/release-mode-test.sh` before suspecting the suite.

## What the first full runs found

- **Seven `OCCTThreadTests` suites SIGSEGV in release on the CI runner** (#3261), each run alone, in
  7 of 7 plain runs on Swift 6.2.4 and in none on 6.4. It was a real defect, not the toolchain:
  `Shape.loft(profiles:)` did `profiles.map { $0.handle }` and handed the pointers to
  `OCCTShapeCreateLoft*`, and `Shape.screwSweptThreadCutter` (the `threadedHole` and `threadedShaft`
  cutter) calls it on a local `sections` array with no later use. Once `loft` is inlined, nothing
  keeps that array, which fits the wires being freed before `BRepOffsetAPI_ThruSections::AddWire` reads them
  (lldb on the runner stopped in `AddWire` on a wild pointer, `EXC_BAD_ACCESS` in the first
  `ldadd` of a TShape refcount; run 38049863685). `withExtendedLifetime(profiles)` around the C call
  fixed it: 21 of 21 runs of the same seven suites passed (run 38051082613). That the 6.2 optimiser shortens
  the array's life and 6.4 does not is inferred from the two outcomes, not isolated; it would explain why it was invisible locally. The same shape,
  `array.map { $0.handle }` over a parameter, is at about 70 other sites; the gate cannot see it
  (see "WHAT IT CANNOT SEE" in `Scripts/check-borrowed-handle-temporaries.py`) and only a caller that
  passes a dying local reaches it.
- One test failure that is not release-specific:
  `Issue2760HardTimeoutAllPlatformsTests.nonPositiveBoundIsNil` (#3256), 1 in 40 in debug and in
  release.
- 34 test files did not compile for lack of `import simd` (#3253, fixed by #3257, which this job's
  branch carries so that it can build). That is the Swift 6.4 and wasm toolchain, not the optimiser.
- Nothing else in 6,897 tests differed between debug and release locally.

## Proof that it catches the class

With the #2929 shape added to a suite the subset selects (`OCCTEdgeSetSameParameter(edges[0].handle,
false)` after `let edges = box.edges()`), the release run dies with `exited with unexpected signal
code 11` in 6 of 6 runs, with and without the `Malloc*` variables, and the same test passes in 6 of 6
debug runs. The same on CI (throwaway branch, never merged): the `subset` job failed with
`Expectation failed: (b.isValid -> true) == false` on that test (the wrong-answer variant of the
hazard, where locally it was the crash), while `swift build + test (macOS)` on the same commit
passed. Removing `withExtendedLifetime` from `withHandle` itself is **not** caught: the three
`Issue3130BorrowedHandle` tests still pass (#3258), so those tests pin the call sites, not the
helper's contract.

## Rules

- **A suite that takes a native pointer out of a wrapper and hands it to the bridge says `.handle`
  or `withHandle` in its file**, which is what puts it in the subset. A pointer reached some other
  way is not selected by a pull request; `main` still runs it.
- **A suite that crashes in release and passes in debug goes in
  `Scripts/release-mode-known-failures.txt` with its issue**, in the style of
  `Scripts/wasm-test-known-failures.txt`; a bare skip with no issue is a finding.
- **The job is not a required check** and does not become one until it has reported `success` on
  `main` ([required-status-checks](required-status-checks.md)).
- **Do not add a `name:` key to its job** and do not wrap the script call in a pipe that discards
  its exit status: the script already tees to `.build/release-mode-test.log` under `pipefail`.
- **A debug-green, release-red result is a finding, not a flake.** Reproduce it with
  `Scripts/release-mode-test.sh subset` before re-running CI.
