# #2061: `NM_DETECTED`, a process-global non-manifold flag in the STEP read actor

`STEPControl_ActorRead.cxx:208` (upstream master and the pinned `V8_0_1`) declares

```cpp
// Set global var to inform outer methods that current representation item is non-manifold.
// The better way is to pass this information via binder or via TopoDS_Shape itself, however,
// this is very specific info to do so...
bool NM_DETECTED = false;
```

It is reset at `:993`, set at `:1028`/`:1041` while transferring one shape representation, and read
at `:742`/`:805` to decide whether a `COMPOUND` component is **flattened** into its parent or kept
nested. Per-operation state in a process global, so concurrent STEP reads share it.

## Result

| | `NM_DETECTED` race reported | Total TSan races |
|---|---|---|
| **Unpatched** | **5 of 5 runs** | 40 across 5 runs |
| **Patched** (`0037`) | **0 of 5 runs** | 10 across 5 runs |

`6 10` (six threads, ten iterations each) per run, override-linked against
`Libraries/occt-install-tsan`. The race is named outright by TSan:

```
Location is global '(anonymous namespace)::NM_DETECTED'
```

## What is NOT shown, and this matters

**The wrong-shape outcome was not reproduced.** It follows from the code by inspection, and the
flag demonstrably leaks between threads, but the corrupting interleaving did not occur in roughly
ten thousand reads:

| Configuration | Reads that saw the flag set | Reads with a `COMPOUND` result | Shapes actually corrupted |
|---|---|---|---|
| 4 threads x 10 | 25 | 20 | **0** |
| 8 threads x 40 | 211 | 160 | **0** |
| 8 x 25, heavy components, 3:1 setter skew | 186 | 200 | **0** |

Zero overlap at three very different scales is systematic rather than unlucky. Within a thread the
reset at `:993` reliably wins the race to that same thread's read at `:742`, so the corrupting
window is far narrower than the code shape suggests, and the flag-set reads are almost certainly
the non-manifold threads correctly reading their own flag.

So the claim this issue supports is **a confirmed cross-thread data race on a flag that gates shape
construction**, not a demonstrated wrong answer. The harness keeps the shape assertion because it
costs nothing and would catch the outcome if it ever occurs; it must not be quoted as proof that
it does.

**A skew toward the setter threads made things worse, not better.** Raising the non-manifold
readers to 3:1 lowered total contention enough that TSan stopped reporting the race at all
(0 of 1 run). Alternating threads is what produces the 5-of-5 signal. Recorded so the tuning is
not retried.

## Method

The harness generates both fixtures in-process, so no binary test data is carried.

**Non-manifold source.** Three faces sewn with `BRepBuilderAPI_Sewing::SetNonManifoldMode(true)`
so one edge ends with **three** face ancestors. Two things had to be right:

- OCCT's `IsManifoldShape` defines non-manifold as *an edge with more than two face ancestors*. A
  shell plus a detached face is not non-manifold and produces no NMSSR.
- `Interface_Static::SetIVal` **silently fails** on a parameter that has not been declared yet, so
  `STEPControl_Controller::Init()` must run first or `write.step.nonmanifold` never takes and the
  writer emits an ordinary `SHAPE_REPRESENTATION`.

With both right, the file contains `NON_MANIFOLD_SURFACE_SHAPE_REPRESENTATION` and the read sets
the flag.

**Manifold assembly.** Four NAUO components, each a compound of twelve solids, written with
`write.step.assembly 1`. Every component read at `:742` therefore has a `COMPOUND` result, which is
the only shape the branch under test can alter. An earlier fixture with a single compound component
produced 25 flag leaks and 0 observable corruptions purely because the leaks landed on
non-compound reads.

## Reproducing

```bash
INSTALL=Libraries/occt-install-tsan
libs=$(ls $INSTALL/lib/libTK*.a | xargs -n1 basename | sed 's/^lib//;s/\.a$//;s/^/-l/')

# unpatched
clang++ -std=c++17 -fsanitize=thread -g -O1 -w -isysroot "$(xcrun --show-sdk-path)" \
  -I"$INSTALL/include/opencascade" -L"$INSTALL/lib" \
  Scripts/repro/2061-nm-detected/occt_2061_nm_detected.cpp -o /tmp/occt_2061_base \
  $libs -lz -lc++ -framework Foundation

MMGT_OPT=0 TSAN_OPTIONS="halt_on_error=0:suppressions=$PWD/Scripts/tsan.supp" \
  /tmp/occt_2061_base 6 10 /tmp 2>&1 | grep -c "NM_DETECTED"
```

For the patched side, override-link the patched `.cxx` **and** `STEPControl_Controller.cxx`, with
the patched header first on the include path:

```bash
clang++ ... -I<dir holding the patched STEPControl_ActorRead.hxx> -I"$INSTALL/include/opencascade" \
  occt_2061_nm_detected.cpp <patched>/STEPControl_ActorRead.cxx \
  Libraries/occt-src/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Controller.cxx ...
```

Two constraints that are easy to get wrong:

- **`STEPControl_Controller.cxx` must be overridden too.** Adding a member changes
  `sizeof(STEPControl_ActorRead)`, and that file holds the only `new STEPControl_ActorRead` in the
  tree. Leaving it compiled against the old header is an ODR violation with a mis-sized allocation.
- **It must be compiled in place**, not from a copy: it has a relative `#include
  "../RWStepAP214/RWStepAP214.pxx"`.

The pinned `OCCT.xcframework` is **not** usable here: it lacks patch `0033`, so concurrent
`Interface_Static` access is itself unsafe and the run dies before measuring anything.

## The fix

Carried as `Scripts/patches/0037-STEPControl-ActorRead-non-manifold-flag-per-instance-2061.patch`:
the flag becomes a private `STEPControl_ActorRead::myIsNMDetected` with a default member
initialiser. Every read and write is already inside an actor member function, so **no signature
changes** are needed.

This works because `STEPControl_Controller::ActorRead()` never assigns `myAdaptorRead`, only
`myAdaptorWrite` at `:345`, so it constructs a fresh actor per call which
`XSControl_TransferReader::Actor()` caches per session. Had the read actor been shared the way
IGES's is (`IGESControl_Controller` stores its `IGESToBRep_Actor` at construction), a member would
have fixed nothing.
