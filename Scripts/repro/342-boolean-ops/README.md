# OCCTSwift#342/#367/#369 reproducers — boolean-op concurrency

Stress harnesses backing #342's stage-1 classification pass over `OCCTBridge_Modeling.mm`'s
boolean operations (`Fuse`/`Cut`/`Common`/`FuseMulti`). Two files, two separate findings:

- `occt_342_boolean_stress.cpp` — the original classification sweep. Found #367 (fixed, shipped).
- `occt_369_threadpool_isolation.cpp` — the #369 root-cause follow-up. Narrows the bug's location;
  does **not** find the root cause. Read this before picking #369 back up.

## #367 — `Shape.fuseAll(_:)` data corruption (FIXED, v1.15.16)

`occt_342_boolean_stress.cpp` checks two things per scenario: TSan race reports, and a
correctness check against a single-threaded baseline (volume + face count) — matching the #298
methodology, since a race can produce a wrong-but-plausible result without crashing or without
TSan catching every run's exact interleaving.

```bash
occt_342_boolean_stress <scenario> <threads> <iterations>
#   fuse | cut | common | mixed | fuse_multi_parallel
```

**`fuse`/`cut`/`common`/`mixed`** (plain `BRepAlgoAPI_Fuse`/`Cut`/`Common`, no internal
parallelism): clean. 10 threads × 200 iterations (`mixed`, 2000 ops total) — 0 errors, 0 wrong
results, 0 unsuppressed TSan races.

**`fuse_multi_parallel`** (mirrors `OCCTShapeFuseMulti`'s old `SetRunParallel(true)`): **not**
clean. 8 threads × 50 iterations — **400/400 operations (100%) produced wrong results** (27 faces
instead of the correct 13; volume matched almost exactly, consistent with duplicated/torn geometry
rather than floating-point imprecision), plus 237 TSan race reports across foundational topology
code (`TopoDS_Builder::Add`, `TopExp_Explorer::Init`/`Next`, `BRep_Tool::Range`,
`BOPTools_AlgoTools::MakeSplitEdge`).

Clearest captured trace: thread T1's own top-level `Build()` call allocates a `TopoDS_Vertex` via
its own `BOPAlgo_PaveFiller::PerformEF` → `BOPTools_AlgoTools::MakeNewVertex`. Thread T9 — a
worker spawned by a *different*, unrelated top-level caller T4's `OSD_ThreadPool` dispatch — reads
and writes that same heap block from inside `BOPTools_AlgoTools::MakeSplitEdge`. Two independent
`BRepAlgoAPI_BuilderAlgo::Build()` calls, each requesting internal parallelism, submit work to the
same process-wide `OSD_ThreadPool::DefaultPool()`, and a worker ends up touching data that belongs
to a completely different top-level call.

**Fix (bridge-only, no kernel patch)**: `OCCTShapeFuseMulti` dropped `SetRunParallel(true)`
entirely — removes the trigger rather than locking around a known-corrupting path. Grepped
`Sources/OCCTBridge/src/*.mm` exhaustively: this was the *only* call site that ever set it.

## #369 — root-causing the mechanism (OPEN, not fixed)

`OCCTShapeFuseMulti`'s trigger is gone, so nothing currently ships this bug. But the *mechanism*
— why two independent top-level `BRepAlgoAPI_BuilderAlgo::Build()` calls corrupt each other's data
when both use `SetRunParallel(true)` — was never found. This section is the state of that
investigation, so a future session doesn't have to re-derive the parts already ruled out.

### Ruled out: `OSD_ThreadPool` itself

Read `OSD_ThreadPool.hxx`/`.cxx` in full (`Libraries/occt-src/src/FoundationClasses/TKernel/OSD/`).
The pool's own documentation states the design intent explicitly: "concurrent threads trying to
use the same thread pool will run sequentially" — i.e. `Launcher`'s constructor is *supposed* to
degrade safely (lock as many free threads as available, fall back toward single-threaded) when
another `Launcher` already holds some of the pool.

Checked the actual mechanism:
- `EnumeratedThread::Lock()`/`Free()` use a genuine atomic exchange
  (`myUsageCounter.exchange(1) == 0`) — two concurrent `Launcher`s can never both successfully lock
  the same `EnumeratedThread`.
- `Standard_Condition` (`myWakeEvent`/`myIdleEvent`) is a real memory fence: proper
  `std::mutex` + `std::condition_variable`, not a spin-flag — so a write made before `Set()` on one
  thread is correctly visible after `Wait()` returns on another.
- `Launcher::perform()` = `run()` (wake workers) + `wait()` (`WaitIdle()` on each, which blocks on
  `myIdleEvent`, itself `Set()` only after `performJob()` completes and nulls `myJob`) — so by the
  time a `Launcher` releases (`Free()`s) its threads, each worker has genuinely finished the prior
  job and is parked back at `myWakeEvent.Wait()`.

**Empirically confirmed clean**: `occt_369_threadpool_isolation.cpp` uses `OSD_ThreadPool::Launcher`
directly — no BOPAlgo, no OCCT geometry at all. Each of N concurrent top-level callers creates its
own `Launcher` on the shared `DefaultPool()` and dispatches trivial work: write a unique per-call
tag into a private `std::vector` slot (indexed by *data* index, not thread index — deliberately, to
also catch any thread-index mixup), read it back immediately, and re-check the whole buffer at the
end. Any cross-`Launcher` interference would show up as a foreign tag.

```bash
occt_369_threadpool_isolation <threads> <iterations>
```

10 threads × 300 iterations (3000 operations): **0 errors, 0 TSan races.** `OSD_ThreadPool`'s own
Lock/Free/WakeUp/WaitIdle bookkeeping is safe for concurrent independent `Launcher` users under
this test. The bug is narrowed to something in `BOPTools_Parallel`/`BOPAlgo_PaveFiller`'s
*specific use* of the pool, not the pool primitive itself.

### Read but not yet conclusive: `BOPTools_Parallel.hxx`

`Libraries/occt-src/src/ModelingAlgorithms/TKBO/BOPTools/BOPTools_Parallel.hxx` — the direct
consumer `BOPAlgo_PaveFiller` uses (via `ContextFunctor2`, the `OSD_ThreadPool::Launcher`-based
path taken when `OSD_Parallel::ToUseOcctThreads()` is true). Checked the obvious candidates:

- `ContextFunctor2::myContextArray` is sized per-`Launcher` (`[LowerThreadIndex(),
  UpperThreadIndex())`) and indexed by `theThreadIndex` — which `Launcher`'s constructor renumbers
  to a *local*, 0-based index per `Launcher` instance (`// make thread index to fit into myThreads
  range` in `OSD_ThreadPool.cxx`). Two concurrent `Launcher`s can end up assigning the *same local
  index value* to *different* underlying `EnumeratedThread`s — but each `Launcher`'s own
  `myContextArray` is a separate, stack-local object, so this shouldn't cross-contaminate on its
  own; didn't find a flaw here on inspection.
- `SetContext()` binds the self-thread's slot (`ChangeLast()`) to the caller's own context — looks
  correctly scoped per top-level call.
- The data index (`theIndex`, from `JobRange::It()`'s atomic fetch-add) comes from a `JobRange`
  constructed fresh per `Launcher::Perform()` call — also looks correctly scoped.

None of this is a confirmed root cause — just what's been read and not yet found broken. The
actual corrupted object in the original trace (a `TopoDS_Vertex`) is allocated and consumed several
layers below this file, inside `BOPAlgo_PaveFiller`/`BOPDS_DS`/`IntTools_Context` — none of which
have been read yet.

### Suggested next steps, in order of expected leverage

1. **Extend `occt_369_threadpool_isolation.cpp`'s pattern to use `ContextFunctor2` directly** with
   a toy "solver" type (something with a trivial `Perform()`/`SetContext()`, not real BOP geometry)
   instead of the private-buffer functor it uses now. This keeps the exact context-array/
   thread-index machinery from `BOPTools_Parallel.hxx` in the loop while still avoiding
   `BOPAlgo_PaveFiller`'s complexity — if THIS reproduces corruption, the bug is confirmed inside
   `BOPTools_Parallel.hxx` itself (`ContextFunctor2`), not below it. If it stays clean, the bug is
   further down, inside `BOPAlgo_PaveFiller`/`BOPDS_DS`/`IntTools_Context`.
2. If narrowed to `BOPAlgo_PaveFiller`, read `BOPAlgo_PaveFiller::Prepare()` and
   `BOPAlgo_PaveFiller::MakeSplitEdges()` (`BOPAlgo_PaveFiller_7.cxx`) end to end — the two frames
   from the original trace — looking specifically for anything **shared across `BOPAlgo_PaveFiller`
   instances** rather than owned per-instance (a global/static cache, a shared allocator pool
   keyed by something coarser than "this one call," or a `BOPDS_DS`/`IntTools_Context` member that
   isn't actually reset/reallocated per top-level call the way it's assumed to be).
3. Check whether `NCollection_BaseAllocator::CommonBaseAllocator()` (used by `ContextFunctor2` to
   construct each per-thread `IntTools_Context`, see `BOPTools_Parallel.hxx:138`) is itself safe
   for concurrent use by unrelated top-level calls — if it's a shared pool-style allocator with any
   fast-path assumption about single-caller use, that would explain corruption spanning many
   unrelated topology functions (matches the *breadth* of the 237 TSan reports better than a single
   narrow indexing bug would).
4. Check whether this is already known/reported upstream before assuming it's novel — search
   Open-Cascade-SAS/OCCT's issue tracker for `OSD_ThreadPool`/`BOPTools_Parallel`/concurrent
   `BRepAlgoAPI_BuilderAlgo` before filing anything new.

### Why this matters beyond `fuseAll`

`ContextFunctor2` is `BOPTools_Parallel`'s general context-dependent parallel path — used
throughout `BOPAlgo_PaveFiller` internals whenever `SetRunParallel(true)` is honored, not just via
`OCCTShapeFuseMulti`. If the root cause turns out to be in `BOPTools_Parallel.hxx` or
`BOPAlgo_PaveFiller` itself (steps 1-2 above), it's a latent risk for *any* future OCCTSwift bridge
call that enables internal BOP parallelism, not specific to the one call site #367 fixed. Worth
re-auditing `Sources/OCCTBridge/src/*.mm` for `SetRunParallel`/`InParallel`/`SetParallel` calls
again once (if) the actual mechanism is found, in case a future addition reintroduces it elsewhere.
