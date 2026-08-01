# OCCT#1179 reproducer: parallel crash sweep (portable, CI-driven)

`occt_parallel_crash_portable.cpp` is the reproducer that backed
[Open-Cascade-SAS/OCCT#1179](https://github.com/Open-Cascade-SAS/OCCT/issues/1179), a
non-deterministic SIGSEGV/SIGABRT seen when ~1000+ tests ran in parallel on OCCT RC5.

**That bug is fixed.** The root cause turned out not to be a race at all:
`ShapeUpgrade_FaceDivide::Perform()` never initialized `myContext`, so `SplitCurves()` →
`Context()->Apply()` dereferenced a null handle. It *presented* as parallel-only but reproduced
single-threaded. Fixed by our own upstream
[OCCT#1203](https://github.com/Open-Cascade-SAS/OCCT/pull/1203) (one-line lazy init), merged
2026-04-25 and shipped in `V8_0_0`, so it is already in the pinned kernel this repo builds against.

The harness is kept as a regression sweep, not as a live investigation.

## What it does

Two phases over a plain `std::thread` pool, each task building its own independent OCCT objects
(no shared state), reporting crash/pass per group:

1. **Isolated**: 11 operation groups run one at a time, so a crash names the operation that caused
   it. `Extrema_ExtElCS` (line-cylinder, line-sphere, line-cone), `ShapeUpgrade_FaceDivide`
   (box, cylinder), `ShapeUpgrade` divide-continuity, boolean cut, fillet, `ShapeFix`,
   `UnifySameDomain`, and shape creation + `GProp`.
2. **Combined**: all groups mixed.

```bash
occt_test <tasks_per_round> <rounds>     # workflow uses: 300 10
```

## How it differs from its siblings

This is the only reproducer in `Scripts/repro/` that is **driven by CI on two platforms**, and it
deliberately carries no platform APIs and no IGES, so it compiles anywhere with a C++17 compiler and
a stock OCCT build. `.github/workflows/occt-parallel-crash-test.yml` ("OCCT Parallel Crash
Reproducer", `workflow_dispatch` only) builds OCCT from source and runs it on Windows x64 (MSVC) and
macOS arm64 (clang), 5 runs each. Its compile lines for both toolchains are also in the file's own
header comment, for running it by hand.

It is also broader than the boolean-concurrency harnesses in
[`../342-boolean-ops/`](../342-boolean-ops/): those probe one operation family in depth against a
single-threaded correctness baseline, while this one sweeps many operation families for crashes only.

## History

The workflow landed first (e174ae6, 2026-04-14 12:35:37), already naming
`tests\occt_parallel_crash_portable.cpp` on both platforms; the `.cpp` followed 13 seconds later in
the same sitting (d239bd7, 12:35:50), and was restructured into today's isolated-group form two days
after that (103ed61, 2026-04-16). So `Tests/` was a deliberate choice by its author, not an accident.
It moved here in #440 anyway, because a hand-compiled reproducer inside the package's test tree is
still the wrong place for one: it is not a target's source, and its directory made SwiftPM's own
target layout harder to reason about while #440 was being diagnosed.

(#440 and an earlier draft of this file both attributed the `.cpp` to e32c8ba, the #378
`Edge.circleProperties` fix, and inferred from that its placement was incidental. That commit does
not touch this file; `git log --follow` over it shows only d239bd7 and 103ed61, and the only rename
in its history is #440's own.)
