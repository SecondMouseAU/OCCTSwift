# OCCTSwift#342/#367/#369 reproducers, boolean-op concurrency

Stress harnesses backing #342's stage-1 classification pass over `OCCTBridge_Modeling.mm`'s
boolean operations (`Fuse`/`Cut`/`Common`/`FuseMulti`).

- `occt_342_boolean_stress.cpp`: the original classification sweep. Found what looked like #367
  (a real bridge fix shipped), then #369's own investigation found the "corruption" that fix
  responded to was actually a bug in **this harness**, now fixed in place (see below).
- `occt_369_threadpool_isolation.cpp`: isolates `OSD_ThreadPool::Launcher` alone (no BOPAlgo).
- `occt_369_contextfunctor2_isolation.cpp`: isolates `BOPTools_Parallel.hxx`'s `ContextFunctor2`
  with a toy solver/context (no real BOP geometry).
- `occt_369_single_call_parallel.cpp`: the reproducer that actually found the root cause — one
  process, no `std::thread` in the driver at all, comparing `SetRunParallel(true)` vs `(false)`
  for a single `BRepAlgoAPI_BuilderAlgo::Build()` call.
- `occt_369_validity_check.cpp`: confirms the "wrong" General Fuse result is a valid,
  `BRepCheck_Analyzer`-clean shape, not corrupted geometry.

## #367, `Shape.fuseAll(_:)` — the fix shipped, but the diagnosis was wrong (corrected by #369)

`occt_342_boolean_stress.cpp` checks two things per scenario: TSan race reports, and a
correctness check against a single-threaded baseline (volume + face count), matching the #298
methodology.

```bash
occt_342_boolean_stress <scenario> <threads> <iterations>
#   fuse | cut | common | mixed | fuse_multi_parallel
```

**`fuse`/`cut`/`common`/`mixed`** (plain `BRepAlgoAPI_Fuse`/`Cut`/`Common`, no internal
parallelism): clean. 10 threads × 200 iterations (`mixed`, 2000 ops total), 0 errors, 0 wrong
results, 0 unsuppressed TSan races.

**`fuse_multi_parallel`** (mirrors `OCCTShapeFuseMulti`'s old `SetRunParallel(true)`) originally
reported **not** clean: 8 threads × 50 iterations, 400/400 operations "diverged" (27 faces instead
of 13; volume matching almost exactly), plus 237 TSan race reports in July 2026. That read as
100% reproducible cross-caller data corruption, and `OCCTShapeFuseMulti` dropped
`SetRunParallel(true)` in response (bridge-only fix, v1.15.16).

**#369 found the 27-vs-13 "divergence" was never corruption**: `runFuseMultiParallel()`
constructs a bare `BRepAlgoAPI_BuilderAlgo`, `SetArguments()` with both shapes and no
`SetTools()` — per that class's own header, *"the class contains API level of the **General
Fuse** algorithm"*, and `BOPAlgo_Builder`'s header is explicit that *"the result of the General
Fuse algorithm itself is a compound containing all split parts of the arguments."* That is a
different OCCT operation from `BRepAlgoAPI_Fuse` (`Object=box`, `Tool=sphere`, `BOPAlgo_BOP` with
`BOPAlgo_FUSE`), which merges same-domain faces into one solid. For this box+sphere pair, General
Fuse legitimately returns an 8-solid, 27-face compound (`occt_369_validity_check.cpp`:
`IsDone=1`, `BRepCheck_Analyzer.IsValid=1`) where `BRepAlgoAPI_Fuse` returns a 1-solid, 13-face
solid — same total enclosed volume (1106.814145 vs 1106.814146), different topology, **both
correct**. `computeBaselines()` computed the "expected" value via `BRepAlgoAPI_Fuse` and compared
`runFuseMultiParallel`'s General Fuse output against it: two different operations, so it read
"wrong" 100% of the time, with or without concurrency.

**Decisive proof, not just a plausible alternative explanation**: `occt_369_single_call_parallel`
runs `BRepAlgoAPI_BuilderAlgo` once, `SetRunParallel(false)` and `(true)`, in a driver with no
`std::thread` at all — the *only* concurrency in the program is the pool's own internal workers,
spawned and joined inside that one `Build()` call. Both give 27 faces, every time, serial or
parallel. And re-running the *original* `fuse_multi_parallel` scenario (both 1 caller alone and 8
concurrent callers) against a freshly rebuilt TSan kernel carrying every currently-patched fix
(including #1154's `TopoDS_TShape::myState` atomic and #1153's `BSplCLib_Cache`/`GeomAdaptor`
mutex, neither of which existed in July): **0 TSan races** in both cases (was 237), while the
face-count "divergence" is unchanged (400/400) because it never depended on concurrency at all —
confirming the 237 July races were real, but were #1153/#1154 (both since fixed as their own,
unrelated intra-operation findings), not a cross-caller pool defect, and happened to co-occur in
the same run as the always-broken face-count comparison.

**Fix**: `occt_342_boolean_stress.cpp` now computes a separate `gGeneralFuseBaselineVolume`/
`gGeneralFuseBaselineFaces` (same `BRepAlgoAPI_BuilderAlgo`+`SetArguments` pattern, serial) and
`runFuseMultiParallel` compares against that, not the `BRepAlgoAPI_Fuse` baseline. Re-run both
ways against the same freshly rebuilt TSan kernel: solo (1×100) and 8×50 concurrent, **0 errors, 0
wrongResult, 0 races**, both. The `OCCTShapeFuseMulti` bridge comment is corrected to reflect
this; the function itself is left at the serial default (re-enabling `SetRunParallel(true)` there
is very likely safe per this investigation, but is a separate decision from root-causing #369, and
the fuseMulti bridge site's own semantics — `.Shape()` being a compound of split parts rather than
a single merged solid — may be worth a look independent of threading).

## #369, root-causing the mechanism — CLOSED, no bug found

`OSD_ThreadPool::DefaultPool()` is safe for concurrent independent submitters. This section
records what was checked and how, so a future session doesn't have to re-derive it.

### `OSD_ThreadPool` itself

Read `OSD_ThreadPool.hxx`/`.cxx` in full (`Libraries/occt-src/src/FoundationClasses/TKernel/OSD/`).
`EnumeratedThread::Lock()`/`Free()` use a genuine atomic exchange (`myUsageCounter.exchange(1) ==
0`); `Standard_Condition` is a real `std::mutex`+`std::condition_variable`, not a spin-flag;
`Launcher::perform()` = `run()` (wake workers) + `wait()` (blocks until every locked thread's
`myIdleEvent` fires, which only happens after `performJob()` returns), so by the time a `Launcher`
releases its threads, every worker has genuinely finished and is parked. `Standard_Transient`'s
refcount is `std::atomic_int`; `Standard::Allocate`/`Free` in this build (`USE_TBB=OFF`, no
`MMGT_OPT_FLEXIBLE`) are plain `calloc`/`free`, the thread-safe system allocator.

**Empirically confirmed clean**, twice:
- `occt_369_threadpool_isolation.cpp`: `OSD_ThreadPool::Launcher` directly, no BOPAlgo. 10
  threads × 300 iterations (3000 ops): 0 errors, 0 TSan races.
- `occt_369_contextfunctor2_isolation.cpp`: `BOPTools_Parallel::Perform(bool, TypeSolverVector&,
  handle<TypeContext>&)` directly (the exact `ContextFunctor2` path `BOPAlgo_PaveFiller` uses),
  with a toy solver whose `Perform()` claims a private tagged heap slot and a toy context tracking
  which top-level caller last touched it. 10 threads × 200 iterations × 64 items (128,000 solver
  calls): 0 errors, 0 TSan races.

### `BOPTools_Parallel.hxx`

`myContext` (`occ::handle<IntTools_Context>`) is a private member, constructed fresh per
`BOPAlgo_PaveFiller` instance (`BOPAlgo_PaveFiller.cxx:203`), never shared. Every
`NCollection_IncAllocator` `BOPAlgo_Builder`/`BOPAlgo_Tools`/`BOPAlgo_PaveFiller` phase functions
construct is a fresh local (`new NCollection_IncAllocator`), never shared or reused across calls.
`ContextFunctor2::myContextArray` is sized and indexed per-`Launcher` instance, a stack-local
object; `Launcher`'s thread-index renumbering can hand the same numeric index to different
physical `EnumeratedThread`s across concurrent `Launcher`s, but since each `Launcher`'s
`myContextArray` is its own object, that never cross-contaminates (confirmed empirically by the
isolation test above, which specifically probes this).

An exhaustive grep of every `.cxx` under `ModelingAlgorithms/TKBO` (`BOPAlgo`/`BOPDS`/`BOPTools`)
and adjacent dirs (`TKMesh`, `TKGeomAlgo`, `TKTopAlgo`) for unsynchronized function-local/file-scope
statics — the pattern behind every prior TSan finding in this project's series — turned up nothing
live: `BOPDS_CommonBlock::PaveBlockOnEdge`'s static fallback handle has zero call sites anywhere in
the tree (dead code); `BRepMesh_IncrementalMesh`'s `IS_IN_PARALLEL` is bypassed by the bridge's own
constructor call; `BRepClass3d_SolidClassifier`'s `STAT` is compiled out entirely (`LBRCOMPT` is
`#define`d `0` on both branches); `BRepLib`'s `thePrecision`/`thePlane` statics (flagged `// TODO -
not thread-safe` in OCCT's own source) are reachable from the boolean-op edge-construction path via
`BOPTools_AlgoTools::MakeSectEdge`, but nothing in this call path ever calls the corresponding
setters, so there is no write to race against.

### Answers to the three open questions

1. **Is `OSD_ThreadPool::DefaultPool()` fundamentally unsafe for concurrent independent
   submitters?** No. Confirmed clean by direct isolation testing at both the `Launcher` level and
   the `ContextFunctor2` level, and by the corrected real-world `fuse_multi_parallel` scenario (0
   races, solo or concurrent). There was never a caller-side bug either — the "corruption" was a
   test-harness comparison bug, not a defect in how `BOPTools_Parallel`/`BOPAlgo_PaveFiller` use
   the pool.
2. **Does this affect anything else opting into internal OCCT parallelism?** `Shape.mesh(parameters:)`
   is the one other live, Swift-reachable, default-`true` surface (`MeshParameters.inParallel`
   defaults `true` in `Sources/OCCTSwift/Mesh.swift`; `OCCTBridge_Mesh.mm:245` forwards it to
   `IMeshTools_Parameters.InParallel`, and `BRepMesh_FaceDiscret.cxx` dispatches via
   `OSD_Parallel::For`, the same `OSD_ThreadPool::DefaultPool()`-backed path). Since the pool
   itself is confirmed safe for concurrent independent submitters, this is not a special risk.
   The other two `SetRunParallel` bridge sites (`OCCTShapeSelfIntersectsBounded` and its sibling in
   `OCCTBridge_Modeling_Boolean.mm`) are hardcoded `false`, not reachable as `true`; the third
   (`OCCTBridge_IO_MeshFormats.mm:577`) is likewise hardcoded `false`.
3. **Is this already known upstream?** No exact match found. `Open-Cascade-SAS/OCCT#1071` ("Improve
   OSD_Parallel and OSD_ThreadPool parallel infrastructure") is a closed (not merged) performance
   PR — chunked work distribution, a new `Reduce()` primitive — unrelated to any correctness defect
   and not evidence of one. Nothing else matched `OSD_ThreadPool`/`BOPTools_Parallel`/concurrent
   `BRepAlgoAPI_BuilderAlgo` in issues or PRs.

### What's left open

Whether to re-enable `SetRunParallel(true)` in `OCCTShapeFuseMulti` now that the mechanism that
prompted removing it is understood not to be real. Separately, whether `OCCTShapeFuseMulti`
should even be using General Fuse (`BRepAlgoAPI_BuilderAlgo`, `.Shape()` a compound of split
pieces) at all for a "fuse multiple shapes into one" API, versus folding the arguments through
`BRepAlgoAPI_Fuse` pairwise or otherwise producing a single merged solid — an existing design
question, unrelated to concurrency, that this investigation did not set out to answer and did not
change.
