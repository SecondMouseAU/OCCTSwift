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

Measured on one M-series Mac (10 cores, shared with other agent builds, load average 25 to 250
while measuring, so every wall time is an upper bound), pinned kernel from the release asset:

| step | wall time |
|---|---|
| `swift build -c release -Xswiftc -enable-testing --build-tests`, cold to the first compile error (#3255) | 6 min 2 s |
| the same build to completion, after fixing #3255 and a SIGTERM from load | 4 min + 9 min |
| `swift test -c release --skip-build`, whole suite, 6,897 tests, no malloc env | 6 min (359 s) |
| the same under `MallocScribble` + `MallocPreScribble` | 4 min 12 s |
| the same under all four `Malloc*` variables, three runs | 3 min 45 s, 4 min 8 s, 3 min 22 s |
| the subset (about 160 tests in 36 suites), all four variables | about 35 s, nearly all of it loading the 18 bundles |
| for scale, the debug `swift build + test (macOS)` job on CI | 13 to 16 min |

- **The build cannot be narrowed.** `swift test --skip-build` refuses to run unless every target's
  `.xctest` bundle exists (`OCCTThreadTests.xctest doesn't exist in file system`, measured with only
  the subset's targets built), and `swift build --target A --target B` builds only `B`. #3248's
  "1m44s + 7s" for one target was measured on a tree where the other seventeen bundles already
  existed. So the subset and the full run pay the same build.
- **What the subset saves is the test phase, about four minutes, and a flake surface.** The full
  suite has one measured flake that is not release-specific (#3256, 1 in 40 in debug and 1 in 40 in
  release). `Scripts/merge-pr.py` refuses a PR while any non-wasm check is red, so a flake in a job
  every PR runs costs a re-run on that PR; the same flake on `main` costs a re-run and nothing else.
  The subset is about 160 deterministic tests, so a red there is the hazard.
- **Full release runs on `main`, a dispatch and a release** because a defect a pull request's
  subset did not select (a suite that reaches the hazard without the literal `.handle`) is found
  there, within one merge, and a published release is the point where "the debug suite is green"
  has to mean the shipped build is too.
- **All four `Malloc*` variables**, because three full runs under them were green and no slower than
  scribbling alone, and `MallocGuardEdges` and `MallocErrorAbort` turn an out-of-bounds write into an
  immediate abort. If a run is ever red with an abort in a suite that has nothing to do with
  lifetimes, drop those two in `Scripts/release-mode-test.sh` before suspecting the suite.

## What the first full run found

Compile failure, release only: 34 test files used `simd_length` or `simd_distance` without
`import simd` and compiled in debug only because a sibling file's import leaks within a module
(#3255, fixed with the job: it cannot build without it). Test failure in the full run: one,
`Issue2760HardTimeoutAllPlatformsTests.nonPositiveBoundIsNil`, also reproducible in debug
(#3256). Nothing else in 6,897 tests differed between debug and release.

## Proof that it catches the class

With the #2929 shape added to a suite the subset selects (`OCCTEdgeSetSameParameter(edges[0].handle,
false)` after `let edges = box.edges()`), the release run dies with `exited with unexpected signal
code 11` in 6 of 6 runs, with and without the `Malloc*` variables, and the same test passes in 6 of 6
debug runs. Removing `withExtendedLifetime` from `withHandle` itself is **not** caught: the three
`Issue3130BorrowedHandle` tests still pass (#3258), so those tests pin the call sites, not the
helper's contract.

## Rules

- **A suite that takes a native pointer out of a wrapper and hands it to the bridge says `.handle`
  or `withHandle` in its file**, which is what puts it in the subset. A pointer reached some other
  way is not selected by a pull request; `main` still runs it.
- **The job is not a required check** and does not become one until it has reported `success` on
  `main` ([required-status-checks](required-status-checks.md)).
- **Do not add a `name:` key to its job** and do not wrap the script call in a pipe that discards
  its exit status: the script already tees to `.build/release-mode-test.log` under `pipefail`.
- **A debug-green, release-red result is a finding, not a flake.** Reproduce it with
  `Scripts/release-mode-test.sh subset` before re-running CI.
