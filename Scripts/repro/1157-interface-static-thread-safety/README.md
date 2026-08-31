# OCCTSwift#1157: Interface_Static thread safety

Issue #1157 asked whether OCCT's process-global `Interface_Static` parameter table (which the
bridge already serializes access to via `igesMutex()`, see #181-B/#359) can be made genuinely
thread-safe at the kernel level, so independent, concurrent STEP/IGES read/write calls no longer
need one shared mutex.

**Answer: partially.** `Interface_Static`'s own backing store is fixable, and fixed (patch `0033`,
TSan-confirmed clean for its own target). But the STEP/IGES/`XSControl` subsystem `Interface_Static`
lives inside has at least eight other classes carrying the identical "unsynchronized process-global
state" shape, one of which (a shared `STEPControl_ActorWrite`/`IGESControl` actor instance mutated
per-transfer through a process-wide singleton controller) is not a one-time startup hazard but a
**persistent, every-concurrent-call race**, independent of anything `Interface_Static` does. `true`
concurrent STEP/IGES I/O is not achievable via a minimal, surgical patch. `igesMutex()` stays.

## The real storage shape (the issue's own sketch was illustrative, and wrong)

`Interface_Static.hxx` declares no static data members at all; every `Set*Val`/`*Val` static
method resolves a name to a per-parameter `Interface_Static` object through
`MoniTool_TypedValue::Stats()`, which returns a reference to **`astats`**, a file-scope
`NCollection_DataMap<TCollection_AsciiString, occ::handle<Standard_Transient>>` declared in
`MoniTool_TypedValue.cxx` (not `Interface_Static.cxx`), mapping parameter name to the boxed object
holding its value. A second, independent file-scope map in the same file, **`thelibtv`**, backs
`AddLib`/`Lib`/`FromLib`/`LibList`/`StaticValue`, unrelated to `Interface_Static`'s own parameter
table. `Interface_Static.cxx` additionally carries its own process-global scratch buffer,
**`static char defmess[31]`**, shared by `CDef`/`IDef`, both of which `sprintf`/`sscanf` into it
and return a `const char*` aliasing the same buffer, a `strtok`-style shared-return-buffer hazard
layered on top of the map race (not reached by the STEP/IGES read/write call chains this
investigation traced, so not exercised by the harness below, but worth recording).

Each named parameter's own value is NOT stored in `Interface_Static` (its `.hxx`-declared
`theival`/`thehval`/`theoval`/`theupdate` are dead, shadowed-but-unused fields, a leftover from the
class hierarchy); the live storage is `MoniTool_TypedValue`'s own `theival`/`thehval`/`theoval`,
mutated by the base class's `SetIntegerValue`/`SetCStringValue`/`SetRealValue` (inherited,
unoverridden, called via virtual dispatch from `Interface_Static::SetIVal`/`SetCVal`/`SetRVal`).
`SetCStringValue` in particular mutates a shared, reference-counted `TCollection_HAsciiString`
buffer in two separate steps (`thehval->Clear(); thehval->AssignCat(val);`), so two threads
concurrently setting the same parameter race on the SAME string buffer object, not merely on
independent copies of one: a genuine memory-safety hazard, not only a logical one.

## Reachability: read constantly mid-operation, not just at entry

Grepped every STEP/IGES-adjacent toolkit (`TKDESTEP`, `TKDEIGES`, `TKXSBase`) for
`Interface_Static::` call sites. Confirmed 30+ reads deep inside per-entity/per-curve/per-surface
conversion code, not cached once at the top of an operation: `BRepToIGES_BREntity` (constructed
once per B-Rep entity translated to IGES) reads `write.convertsurface.mode`/
`write.surfacecurve.mode` in both its constructor and `Init()`; `GeomToIGES_GeomCurve`/
`GeomToIGES_GeomSurface` read `write.iges.offset.mode`/`write.iges.plane.mode` per curve/surface;
`IGESToBRep_CurveAndSurface` reads `read.encoderegularity.angle`, `read.maxprecision.mode`,
`read.precision.mode`, `read.iges.bspline.approxd1.mode`, `read.surfacecurve.mode` per curve.

And critically, **`XSControl_Controller::Customise`** — called from `XSControl_WorkSession::
SetController`, itself called from `SelectNorm()`, which every `STEPControl_Reader`/`Writer` and
`IGESControl_Reader`/`Writer` default construction runs internally — calls
`Interface_Static::Items()`, which iterates the *entire* `astats` map, **on every single
reader/writer construction**, whether or not the caller ever calls `SetCVal`/`SetIVal`/`SetRVal`
itself. So the race surface is not "only when the bridge sets a parameter"; it is "every
STEP/IGES reader or writer object ever constructed."

## `thread_local` was the starting hypothesis and is wrong, but not for the reason expected

The task's own framing anticipated a caller-thread-configures/worker-threads-read pattern (the
`SetRunParallel`-style hazard #367/#369 investigated). That pattern does **not** exist here:
grepped the whole of `TKDESTEP`/`TKDEIGES`/`TKXSBase` for `OSD_Parallel`/`OSD_ThreadPool`/
`std::thread`/`tbb::` and found zero hits in the STEP/IGES read/write call chain (the only hits in
the whole `DataExchange` module are in the unrelated `RWGltf_*` glTF reader, and a GTest file for
`STEPCAFControl_Controller` that exercises `OSD_Parallel::For` on an unrelated concurrency
smoke-test, not the DE call chain). Every conversion step runs serially on the calling thread.

The actual reason `thread_local` is wrong is a lazy-registration contract, found by reading
(not guessing) four separate one-time-init guards, only one of which is even mutex-protected:

- `STEPControl_Controller`'s constructor: `static bool init = false; static std::mutex aMutex;`
  guards ~50 `Interface_Static::Init`/`SetCVal`/`SetIVal` calls that register the whole `"step"`/
  `"XSTEP"` parameter family. **Mutex-protected.**
- `STEPCAFControl_Controller::Init()`: the same shape, its own separate `static std::mutex`.
  **Mutex-protected.**
- `STEPControl_Controller::Init()` (the *static factory method*, a different function from the
  constructor above, called by every `STEPControl_Writer`/`Reader` construction): its own
  `static bool inic = false;`, gating whether `new STEPControl_Controller` runs at all. **No
  mutex** — confirmed racing under TSan, see below.
- `IGESControl_Controller`'s constructor: `static bool init = false;` guarding `IGESSolid::Init()`/
  `IGESAppli::Init()`. **No mutex.**
- `IGESData::Init()`: guards ~100 `Interface_Static::Init` calls behind
  `Interface_InterfaceModel::HasTemplate("iges")`. **No mutex.**
- `Interface_Static::Standards()` itself (`Interface_StaticStandards.cxx`, a sibling file to
  `Interface_Static.cxx`): its own `static int THE_Interface_Static_deja = 0;` one-time flag,
  checked/set with no lock at all. **No mutex** — confirmed racing under TSan, see below.

All assume `Interface_Static`'s backing map is a genuine process-wide singleton, populated
exactly once, ever. Making `astats` `thread_local` would let only the very first thread that ever
touches STEP or IGES in the process populate its own copy; every other thread's own thread-local
copy would stay **permanently empty**, because every one of these guards is itself a plain,
non-thread-local flag that would report "already done" and skip re-running on that thread.
`Interface_Static::CVal`/`IVal`/`RVal` would then silently return `""`/`0` for every parameter on
any thread but the first — worse than the current race, and invisible to any reproducer that runs
one operation per thread, exactly the failure mode the task asked to check for.

## Reproducer and empirical findings

`occt_1157_stress.cpp`: eight scenarios, pure C++, no bridge/Swift layer, calling the exact same
OCCT sequences the bridge does (`STEPControl_Reader`/`Writer`, `IGESControl_Reader`/`Writer`, the
same `Interface_Static::Set*Val` calls in the same order) with **no** `igesMutex()`-equivalent
lock — this is "the bridge with the mutex removed" without needing to override-link the actual
`.mm` files, since the bridge's critical section IS exactly this sequence.

```
Usage: occt_1157_stress <scenario|all> <threads> <iterations> [scratch_dir]
  scenarios: step_write_independent | step_write_warmstart | step_read_independent
             | iges_write_independent | iges_read_independent
             | mixed_step_iges_independent (the issue's own repro snippet, scaled up)
             | cross_talk_schema_unlocked | cross_talk_schema_locked
```

**Sanity (production, non-instrumented `OCCT.xcframework`)**: all scenarios run correctly under
moderate load (4-8 threads, 2-3 iterations each for the file I/O scenarios), 0 functional errors.

**Cross-talk (the logical race, independent of memory safety)**: `cross_talk_schema_unlocked`
(8 threads x 2000 iterations, each thread repeatedly `SetCVal`s `"write.step.schema"` to its own
value, yields, then reads it back) cross-talks **16000/16000 (100%)**. `cross_talk_schema_locked`
— the identical scenario, but every individual `SetCVal`/`CVal` call wrapped in its own
`std::mutex` lock/unlock, simulating exactly what a kernel fix that only makes the *accessor
calls* thread-safe (a container-level lock, or an atomic map) would provide — cross-talks at the
**identical rate, 16000/16000**. This is direct, measured proof that container-level memory
safety and this scenario's logical correctness are independent properties: the race is in the
window between one thread's `Set` and its own later `Get` (or between a caller's `Set` and a read
many stack frames below it inside `Transfer()`/`Write()`), not inside the `Set`/`Get` call itself,
and no per-accessor lock closes that window.

**TSan (kernel-level, against a private minimal-module build, `V8_0_1` + all 32 previously-carried
patches, `FoundationClasses`+`ModelingData`+`ModelingAlgorithms`+`DataExchange`)**:

| Scenario | Threads x Iter | Before (races / exit) | After patch `0033` (races / exit) |
|---|---|---|---|
| `step_write_independent` | 8x20 | 91 races, SIGABRT | 47 races, SIGABRT — but **0** touch `Interface_Static.cxx` |
| `iges_write_independent` | 8x20 | 406 races, SIGABRT | 72 races, SIGABRT — but **0** touch `Interface_Static.cxx` |
| `step_write_warmstart` (single-threaded warm-up in-process, then 8x20 concurrent) | — | 28 races, SIGABRT | 32 races, SIGABRT — but **0** touch `Interface_Static.cxx` |

In every case, grepping the TSan output for `Interface_Static.cxx` (not just "does the total drop"
but "does the specific class the patch targets still appear anywhere in any report") goes from
non-zero, with reports whose critical section is literally inside `Interface_Static::Init`'s own
`NCollection_DataMap::emplaceImpl`/`ReSize`/`BeginResize`/`EndResize` (`MoniTool_TypedValue::
Stats()`'s map) or `Interface_Static::SetCStringValue`'s `TCollection_HAsciiString` mutation, to
**zero, in every scenario, every run**. The patch closes exactly what it claims to close.

## What the residual races are, and why they matter more than expected

The `step_write_independent`/`iges_write_independent` residual races (47/72) are not `Interface_
Static`'s fault: they are in `Interface_StaticStandards.cxx`'s own `THE_Interface_Static_deja`
flag, `XSControl_Controller.cxx`'s own `static NCollection_DataMap<...> listad` (a
controller-name-to-instance registry backing `Record()`/`Recorded()`), `STEPControl_Controller::
Init()`'s own `inic` flag, `IFSelect_WorkSession`'s constructor (races on a global named
`errhand`), and (IGES side) `IGESControl_Controller::Init()`'s own flag, `Interface_InterfaceModel::
Template()`, `IGESData_IGESModel::GetFromAnother`, `IGESToBRep::SetAlgoContainer`/`Init()`,
`ShapeProcess::FindOperator`/`Perform`, and `IGESData_GlobalSection.cxx`'s `CopyString` helper —
**at least nine distinct classes/files across `TKXSBase`/`TKDESTEP`/`TKDEIGES` carrying the
identical "unsynchronized process-global lazy-init or registry" shape**, of which `Interface_
Static` was only the one named in the issue.

**The `step_write_warmstart` scenario is the more important measurement.** It forces a single
single-threaded `STEPControl_Writer` construction+write in-process *before* spawning the 8
concurrent threads (`std::thread`'s constructor is a genuine happens-before edge, so every
worker thread correctly observes every one-time flag as already `true` — confirmed empirically:
`XSControl_Controller::Record`, `STEPControl_Controller::Init`'s `inic`, and `Interface_Static::
Standards()`'s flag do NOT appear anywhere in this scenario's race reports, before or after the
patch, proving the warm-up genuinely suppressed those specific one-time-init races). What
**remains** even after a proper warm-up, 28 races before the patch and 32 after (both still
SIGABRT): `STEPControl_ActorWrite::SetGroupMode`/`IsAssembly` and `IFSelect_WorkSession::SendAll`/
its own constructor (racing on `errhand`).

This is a **structural, always-live defect, not a cold-start artifact**: `XSControl_Controller`
registers exactly ONE `STEPControl_Controller` instance per process (by design — `Recorded("STEP")`
looks up a single shared singleton), and that one controller owns exactly one `STEPControl_
ActorWrite` (`myAdaptorWrite`). Every `STEPControl_Writer` construction, on every thread, at any
point in the process's life, ends up sharing that SAME actor object via `SetController()`, and
`Transfer()` mutates its state (`SetGroupMode`, an `IsAssembly` scratch flag) per call. Two
`STEPControl_Writer::Transfer()` calls running concurrently on two different threads, however long
the process has already been running, race on that one shared object — independent of anything
`Interface_Static` does, and not fixable by any patch to `Interface_Static` or to any of the
one-time-init guards above. `IFSelect_WorkSession::errhand`'s race is simpler but equally
persistent: every `XSControl_WorkSession()` construction (one per `STEPControl_Writer`/`Reader`)
writes to that same global, unconditionally, forever.

## The fix: a recursive mutex around `Interface_Static`'s own entry points

`Scripts/patches/0033-Interface_Static-thread-safety-mutex-1157.patch`: a single, function-local
static, thread-safe-lazy-init `std::recursive_mutex` (`StaticsMutex()`, anonymous namespace,
`Interface_Static.cxx`), taken for the whole body of every `Interface_Static` static method that
touches `MoniTool_TypedValue::Stats()` or a per-parameter value: `Init` (both overloads), `Static`,
`IsPresent`, `CDef`, `IDef`, `IsSet`, `CVal`, `IVal`, `RVal`, `SetCVal`, `SetIVal`, `SetRVal`,
`Update`, `IsUpdated`, `Items`, `FillMap`. `SetUptodate()`/`UpdatedStatus()` (`Interface_Static`'s
own instance methods) need no separate lock, since their only three call sites (`Update`,
`IsUpdated`, `Items`) already hold this lock before calling them.

Recursive, not a plain mutex, because several of these call back into each other on the same
thread: `Init`'s `Interface_ParamMisc` branch calls `Static()`, the `'&'` edit-syntax branch calls
`Static()` then mutates the returned handle's own limit/enum fields directly (not
`theival`/`thehval`/`theoval`, so out of scope for this defect, but still executes while the lock
is held), and `Init(char)` calls the `Interface_ParamType` overload then `Static()` again for the
`'p'` post-check. A plain mutex would self-deadlock the very first `STEPControl_Controller`
construction, which makes ~50 such calls, several of the `Interface_ParamMisc` form — the identical
shape `#1153`'s first, rejected patch attempt hit for `BSplCLib_Cache` (see that CLAUDE.md entry).

`Interface_Static::Standards()` (defined in a **separate** file, `Interface_StaticStandards.cxx`,
deliberately not touched by this patch, since its own `THE_Interface_Static_deja` one-time flag is
a sibling defect of the same shape as the four controller-side guards, not a defect in
`Interface_Static`'s storage itself) needs no direct guard for the storage-safety claim this patch
makes: it only ever calls through the now-locked `Interface_Static::Init`/`SetIVal` entry points,
never touching `Stats()` or a parameter's value fields itself. Two concurrent `Standards()` calls
interleaving at the per-`Init()`-call granularity is safe under the fix: whichever thread's
`Init()` for a given name runs first wins (creates the entry, under the lock), the other's
`IsBound()` check (also under the lock) sees it and returns `false` harmlessly — confirmed
empirically: zero `Interface_Static.cxx` races in any TSan run, patched, including scenarios that
still race on `Standards()`'s own unrelated flag.

## What this fix does NOT do

**It does not make two independent, concurrently-running STEP/IGES operations that set DIFFERENT
values for the SAME named parameter produce correct output.** `Interface_Static` is a shared
global used as an IMPLICIT parameter-passing channel between a caller's `SetCVal`/`SetIVal`/
`SetRVal` and reads many stack frames below it inside `Transfer()`/`Write()`/`ReadFile()`. The
`cross_talk_schema_locked` measurement above proves this directly: identical 100% cross-talk with
or without a per-accessor lock.

**It does not make the wider STEP/IGES/`XSControl` subsystem thread-safe.** At least eight sibling
classes across `TKXSBase`/`TKDESTEP`/`TKDEIGES` carry the identical unsynchronized-global-state
shape, one of which (`STEPControl_ActorWrite` state shared through the single registered
`STEPControl_Controller`, and `IFSelect_WorkSession::errhand`) is a persistent, always-live race
under ordinary concurrent use, not a cold-start artifact a warm-up removes. A genuine fix for
"true concurrent STEP/IGES I/O" would mean auditing and restructuring the ownership of
`XSControl_Controller`'s per-format singleton (so `myAdaptorWrite`/`myAdaptorRead` become
per-operation state, not per-controller-singleton state) plus at least eight more classes — an
architectural project, not a "minimal, surgical" patch by any reasonable measure, the same class
of judgment this project already reached for `GeomPlate_MakeApprox::ApproxError()` (#597) and
`BRepFeat_Builder::PartsOfTool()`'s sibling defect.

OCCTSwift's own `igesMutex()` (`Sources/OCCTBridge/src/OCCTBridge_IO_StepFormat.mm`/
`OCCTBridge_IO_IgesFormat.mm`) stays in place, unchanged, after this patch: it is the only thing in
this codebase (or, on this evidence, in OCCT itself) that actually serializes the whole
configure-then-run window per operation, closing not just `Interface_Static`'s own race but every
one of the eight-plus sibling races documented above, none of which this patch or any
`Interface_Static`-scoped fix could reach.

**`thelibtv`** (`MoniTool_TypedValue.cxx`'s other file-scope `NCollection_DataMap`) has the
identical shape and is not fixed: its only callers in the whole `DataExchange` module are
`Interface_GTool.cxx` (an unrelated generic-tool registration mechanism) and
`MoniTool_TypedValue.cxx` itself, none reachable from the STEP/IGES read/write call chains this
investigation traced.

**`IFSelect_ParamEditor::Apply()`'s direct `TypedValue(i)->SetHStringValue(...)` call** (a
different, non-`Interface_Static::Set*Val` mutation path) was checked and confirmed unreachable
from the bridge: `XSControl_Controller::Customise` constructs the editor and its `EditForm` (via
`paramed->Form(false)`) but never calls `Apply()` on it, `Apply()` only runs when a caller
interactively submits an edited form, which nothing in `Sources/OCCTBridge` does.

## Files

- `occt_1157_stress.cpp` — the reproducer, eight scenarios.
- `Scripts/patches/0033-Interface_Static-thread-safety-mutex-1157.patch` — the fix.
