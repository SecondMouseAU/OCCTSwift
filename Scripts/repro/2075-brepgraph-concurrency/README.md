# #2075: the BRepGraph surface, measured and clean

The second of the two surfaces #707 named as having **no TSan scenario at all**. Ranked second
because, unlike Surface/Curve3D (#2074), there was **no known defect** here. Genuinely exploratory.

## Why it was a candidate rather than a guess

The identity model. Per #295/#303, BRepGraph UIDs are **graph-local**, so a graph is a stateful
object a caller holds and mutates across calls. That is the shape every defect this protocol has
found has had: state that looks per-caller but is reached through something shared.

`OCCTBridge_BRepGraph.h` declares roughly 295 entry points over it.

## What the structural read said before anything ran

Across the 83 files of `src/ModelingData/TKBRep/BRepGraph`:

| | |
|---|---|
| file-scope mutable statics | **0** |
| function-local statics (magic statics) | **0** |
| `mutable` members | **3, and all three are mutexes** |

The three are `BRepGraph_CacheRegistry` and `BRepGraph_LayerRegistry`, each holding a
`std::shared_mutex`, and `BRepGraph_CacheDerivedState`, holding a `std::mutex`. The family was
written thread-aware.

**That is a reason to expect clean, not a substitute for measuring.** #1155 is the precedent: eight
classes read as instance-state-only and were run concurrently anyway, and the one near-miss it
found was a live file-scope cluster that reading alone had not settled.

## The harness

`occt_2075_stress.cpp`, pure C++. Four modes:

| Mode | Shape | In the gate |
|---|---|---|
| `graph_build_independent` | each thread builds its own graph | yes |
| `graph_traverse_independent` | each thread builds one graph, then traverses it repeatedly | yes |
| `graph_build_traverse_independent` | build and traverse, interleaved | yes |
| `shared_graph_traverse` | one graph, traversed by every thread | **no** |

Threads ingest **different** topology (a box or a cylinder, dimensioned by thread index), so two
threads are not handing identical shapes to a cache keyed on content and cannot accidentally agree.
Traversal touches the derived-state and registry paths rather than construction alone, since those
are where the three mutexes are.

`shared_graph_traverse` is excluded from the gate per `tsan-stress.sh`'s POLICY block, the same way
#341's `shared_adaptor_cache` is.

## Result

Against the pinned kernel, 8 threads, 30 iterations:

```
graph_build_independent              exit=0 races=0
graph_traverse_independent           exit=0 races=0
graph_build_traverse_independent     exit=0 races=0
shared_graph_traverse                exit=0 races=0
```

Named racing globals: **none**.

Worth noting that even the adversarial `shared_graph_traverse` is clean. That is consistent with
the structural read rather than surprising: traversal is a read path, and the registries that back
it hold a `shared_mutex`, so concurrent readers are what that lock is for.

## The harness is clean, not blind

Injecting a deliberate unsynchronised global into `graph_traverse_independent` and rebuilding:

```
exit=134  races=1
```

The binary aborts with a TSan race, so the instrumented kernel, the thread pool and the
suppressions file all work in this setup and the zeroes above are measurements.

## What this settles

#2075's own text says: *"If it comes back clean, say so and close it. A clean exploratory run on a
295-entry-point surface is a result worth recording, not a failure to find something, and it
narrows where the remaining risk lives."*

It came back clean, and the structural read independently agrees. With #2074 also clean, **the
protocol has now been pointed at both surfaces #707 named and neither holds a defect these
harnesses can reach**, which is an argument that the remaining thread-safety risk is not in
geometry evaluation or the graph.

Both are registered in `Scripts/tsan-stress.sh` rather than left as files, so that when OCCT 8.0.2
repatches the kernel they run as regression rather than as a fresh investigation.
`docs/thread-safety.md` puts the reason bluntly: "A harness under `Scripts/repro/` that is not in
`SCENARIOS` is a file, not a gate."

## Reproducing

```bash
Scripts/tsan-stress.sh run          # the three gate modes, with everything else
```
