---
title: Thread Safety
nav_order: 9
---

# Thread Safety in OCCTSwift

## TL;DR

OCCT is **not thread-safe** for concurrent access to shared geometry. Use `OCCTSerial.withLock { }` to serialize multi-step workflows, or `shape.copy(copyGeometry: true)` / `Shape.deepCopy(shape)` to create independent geometry for parallel processing — **not** the no-argument instance `shape.deepCopy()`, which only clones topology; see below (#831).

## The Problem

OCCT has several thread-unsafe patterns:

1. **BSpline evaluation caches** — `GeomAdaptor_Curve` and `GeomAdaptor_Surface` have mutable `BSplCLib_Cache`/`BSplSLib_Cache` that are written during `const` evaluation methods without synchronization. Two threads evaluating the same adaptor will race.

2. **Topology flag mutations** — `TopoDS_TShape::myState` uses non-atomic `uint16_t` with bitwise operations. Concurrent flag modification on shared TShapes is a data race.

3. **Various algorithms** — `BRepBuilderAPI_Transform`, `BRepClass3d_SolidClassifier`, `GeomAPI_ProjectPointOnSurf`, and others have internal mutable state.

4. **Shared geometry after booleans** — Boolean operations can produce result shapes that share edge/face geometry with input shapes via the same `TopoDS_TShape` handles. Subsequent operations on both the original and result can race on shared adaptors.

5. **Non-reentrant statics in the fillet solid-reconstruction (issue #298) — fixed in v1.12.3.** `BRepFilletAPI_MakeFillet` reconstructs its result solid through OCCT's legacy `TopOpeBRepBuild` boolean engine (`ChFi3d_Builder::Compute` → `TopOpeBRepBuild_HBuilder::MergeSolid` → `TopOpeBRepBuild_Builder::SplitSolid`), which passed state between methods through file-scope `static` variables. The functional culprit is `STATIC_SOLIDINDEX`: `SplitSolid` sets it to 1/2 to tell `FillSolid` which operand it is splitting, and `FillSolid` reads it back to pick the operand shape. That made the whole fillet/chamfer path **non-reentrant**: two builds on *independent* shapes on separate threads clobbered each other's flag, so `FillSolid` mis-classified faces and returned a **wrong-but-plausible solid** (one solid, positive volume, but fails `BRepCheck`) — silent bad geometry, not a crash. Distinct from items 1–4: no geometry is shared at the Swift level, yet the operation raced on a process-global. ThreadSanitizer on a concurrent fuse+fillet stress pinpointed it (the blend solver's scratch caches — `BlendFunc_ConstRad`/`EvolRad`, `ChFi3d_Builder` `checkcurve` — also raced, but benignly: `STATIC_SOLIDINDEX` alone accounts for the corruption). **Fixed** by converting the fillet-path statics to `thread_local` (carried as `Scripts/patches/0003`, upstreamed as [Open-Cascade-SAS/OCCT#1374](https://github.com/Open-Cascade-SAS/OCCT/pull/1374)); the pinned xcframework now includes the fix, so fillet/chamfer are genuinely reentrant and the interim `occtFilletMutex` serialization shipped in v1.12.1 has been **removed** — concurrent fillet/chamfer builds run in parallel again.

## What IS Thread-Safe

- **Handle reference counting** (`occ::handle<T>`) — atomic `std::atomic_int` refcount
- **Reading shape topology** — immutable once built
- **Completely independent shapes** — shapes with no shared TShapes or geometry handles. This now includes 3D fillet and chamfer: the process-global statics that made them unsafe (item 5) were fixed in v1.12.3, so concurrent fillet/chamfer builds on independent shapes are safe again — and parallel (no longer serialised).
- **OCCT's internal parallel algorithms** — `BOPAlgo_*` with `SetRunParallel(true)`, `BRepCheck_Analyzer` with `SetParallel(true)`, `BRepMesh_IncrementalMesh`

## The Solution

### OCCTSerial — Global Recursive Mutex

OCCTSwift provides a global recursive mutex (`OCCTSerial`) backed by `std::recursive_mutex` in the C bridge. Use it to serialize access:

```swift
// Protect a multi-step workflow
let result = OCCTSerial.withLock {
    let box = Shape.box(width: 10, height: 10, depth: 10)!
    let filleted = box.filleted(radius: 1)!
    return filleted.drilled(at: .zero, direction: SIMD3(0, 0, -1), radius: 3)
}
```

The lock is **recursive** — nested calls are safe:
```swift
OCCTSerial.withLock {
    // This won't deadlock even though the inner call also acquires the lock
    OCCTSerial.withLock {
        let box = Shape.box(width: 5, height: 5, depth: 5)
    }
}
```

### Independent Geometry for Parallelism — three copy APIs, only two actually copy geometry (#831)

`Shape` has three "deep copy" entry points, and this section previously conflated them —
it claimed the no-argument `shape.deepCopy()` used `BRepBuilderAPI_Copy` with independent
geometry, which is wrong on both counts (verified by reading the OCCT source each one
actually calls, not just its header comment):

| API | OCCT mechanism | Geometry / mesh independence |
|---|---|---|
| `shape.copy(copyGeometry:copyMesh:)` (instance) | `BRepBuilderAPI_Copy` | **Yes**, when `copyGeometry`/`copyMesh` are `true` (the defaults are `true`/`false`) — clones `Geom_Surface`/`Geom_Curve`/`Poly_Triangulation` via their own `->Copy()`. |
| `Shape.deepCopy(_:copyGeometry:copyMesh:)` (static) | `BRepTools_CopyModification` | **Yes**, same clone mechanism as `copy()` — `BRepBuilderAPI_Copy` is a thin convenience wrapper around exactly this class, so the two are the same operation reached two ways (defaults `true`/`true`, note the different `copyMesh` default from `copy()`). |
| `shape.deepCopy()` (instance, no parameters) | `TNaming_CopyShape::CopyTool` | **No.** Builds new `TopoDS_TShape`s (independent *topology*), but `TNaming_TranslateTool::UpdateFace`/`UpdateEdge` assign the *same* `Handle(Geom_Surface)`/`Handle(Geom_Curve)`/`Handle(Poly_Triangulation)` to the copy — no geometry or mesh cloning at all. |

For parallel geometry workflows, use `copy(copyGeometry: true)` or the static `deepCopy(_:)` —
**not** the no-argument instance `deepCopy()`, which does not protect against the
shared-geometry races (items 1–4 above), since the two shapes still point at the same
`Geom_Surface`/`Geom_Curve` objects those races live on:

```swift
let original = Shape.box(width: 10, height: 10, depth: 10)!

// Create 4 independent copies for parallel processing — copyGeometry: true clones the
// actual Geom_Surface/Geom_Curve handles, not just the topology.
let copies = (0..<4).map { _ in original.copy(copyGeometry: true)! }

// Process each copy on a different thread. Independence protects against the
// shared-geometry races (items 1–4); the `filleted` call is safe because the
// fillet path is reentrant as of v1.12.3 (item 5, issue #298).
DispatchQueue.concurrentPerform(iterations: 4) { i in
    let result = copies[i].filleted(radius: Double(i + 1))
    // Use result...
}
```

**A real, already-shipped call site relies on the weaker guarantee**:
`Shape.isSelfIntersecting(hardTimeout:)` (`Shape.swift`) uses the no-argument instance
`deepCopy()` to get a probe shape for a detached background thread, on the reasoning that an
orphaned computation past the deadline can keep running without racing the caller. Per the
table above, that probe shares `Geom_Surface`/`Geom_Curve` handles (and the mutable evaluation
caches on them, item 1) with `self` — a well-evidenced latent risk (read from the OCCT source
chain, not reproduced under ThreadSanitizer) rather than a confirmed race, tracked in #831 as a
candidate follow-up rather than changed here.

### Manual Lock/Unlock

For advanced use cases:
```swift
OCCTSerial.lock()
defer { OCCTSerial.unlock() }
// Multiple OCCT operations that must be atomic
```

### 3D fillet/chamfer thread safety (issue #298)

Fillet and chamfer are **safe to call concurrently on independent shapes**, with no
lock on your side and no `deepCopy()` required — `Shape.filleted`, `Shape.chamfered`,
the fillet/chamfer builders, and `SheetMetal.Builder.build` (which fillets internally)
are all reentrant.

This required a kernel fix, not just caller discipline: the racing state (item 5)
lived in OCCT's own file-scope statics, not in any shape the caller could copy. The
history:

- **v1.12.1** shipped an interim mitigation — a dedicated bridge mutex
  (`occtFilletMutex`) serialised every 3D fillet/chamfer build. Correct, but it meant
  fillet/chamfer could not run in parallel.
- **v1.12.3** ships the real fix in the pinned kernel (`Scripts/patches/0003`,
  upstreamed as [OCCT#1374](https://github.com/Open-Cascade-SAS/OCCT/pull/1374)):
  the fillet-path statics are `thread_local`, so the operation is genuinely reentrant.
  The `occtFilletMutex` serialization was **removed** — concurrent fillet/chamfer
  builds now run fully in parallel, like every other operation.

2D fillets/chamfers (`BRepFilletAPI_MakeFillet2d`) were never affected — they use the
separate analytic `ChFi2d` toolkit with no such statics.

### Document creation thread safety (issues #341, #344)

`Document.create()`, `Document.loadOBJ`/`loadSTEP`/`loadGLTF`/etc., and every other
document-producing API are **safe to call concurrently** as of v1.15.6 — no lock
needed on your side.

Every one of these calls goes through a single process-wide `XCAFApp_Application`
singleton (`XCAFApp_Application::GetApplication()`), so two kernel fixes were needed,
both in OCCT itself, not the bridge:

- **v1.15.5** (`Scripts/patches/0011`, issue #341): `XCAFDoc_ShapeTool::theAutoNaming`,
  a process-global flag mutated by every document-tree build, raced across concurrent
  OBJ/glTF import. Fixed via `XCAFDoc_ShapeTool::AutoNamingScope` (a mutex-backed RAII
  scope) plus making the flag itself `std::atomic<bool>`. **Revised in v1.15.15**
  (issue #363) after upstream review: the mutex only serialized the three known
  override call sites against each other, not every other read of the flag elsewhere
  in the file, so an unrelated unscoped caller could still observe another thread's
  temporary override. `OwnAutoNamingScope` replaces it, saving/restoring a per-instance
  override on `XCAFDoc_ShapeTool` (already one instance per document) instead of a
  shared flag — no locking needed at all, since independent documents never touch
  anything shared. See the `#341` entry in `CLAUDE.md`'s Known OCCT Bugs for the full
  writeup, including why the naive "set on entry, unset on exit" version of this fix
  would have broken `XCAFDoc_Editor::Expand()`'s self-recursion.
- **v1.15.6** (`Scripts/patches/0012`, issue #344): an uncatchable SIGSEGV survived the
  v1.15.5 fix — a genuinely different pair of races, in `GetApplication()`'s lazy
  singleton init (two threads could each construct their own instance) and
  `CDF_Directory::Add` (the singleton's document registry, mutated with no locking at
  all). Fixed via a thread-safe static initializer and a private mutex on
  `CDF_Directory`. Fixing the singleton init meant every caller genuinely shares one
  `TDocStd_Application` instance for the first time (as intended), which surfaced more
  races on that instance's format-registration state — `TDocStd_Application::Resources()`
  (same lazy-init bug as `GetApplication()`), `Resource_Manager`'s internal maps, and
  `CDF_Application::myReaders`/`myWriters` — all fixed in the same patch.

An interim bridge-side mutex (`meshCafMutex()`, serializing every OBJ/glTF/PLY bridge
call) shipped in v1.15.4 between these two kernel fixes and was removed once v1.15.5
made the underlying OCCT calls safe on their own — the same "bridge mitigation, then
kernel fix" pattern as #298 above.

Concurrent `Document.saveOCAF`/`saveOCAFInPlace`/`loadOCAF` of the **same target format**
was a separate issue (#349): `CDF_Application::WriterFromFormat`/`ReaderFromFormat` cache
one storage/retrieval driver instance per format and reuse it for every call, but the
driver's own `Write()`/`Read()` isn't reentrant — its instance-level scratch state (e.g.
`BinLDrivers_DocumentStorageDriver`'s `myRelocTable`) corrupts under two concurrent
callers. **v1.15.6 shipped an interim bridge-side mitigation** (`ocafStoreMutex()` in
`OCCTBridge_Document.mm`) — the same "bridge mitigation, then kernel fix" pattern as
#298/#341 above — and **v1.15.9 (`Scripts/patches/0014`) fixed the underlying kernel
non-reentrancy**: a mutex on `PCDM_StorageDriver`/`PCDM_Reader` held at the call sites that
invoke a cached, possibly-shared driver. `ocafStoreMutex()` stayed in place afterward as
defense-in-depth (same pattern again), and turned out to still be load-bearing for a
different reason once v1.15.17 (#371) moved documents off the shared singleton — see below.
Plain shape-format I/O (STEP/IGES/BREP/OBJ/glTF) is unaffected — this only ever covered the
OCAF (`.bcaf`/`.xcaf`-style binary/XML document) persistence entry points.

### STEP/IGES data-exchange thread safety (issues #181, #359)

Every STEP and IGES import/export call is **safe to call concurrently** as of v1.15.12 — no
lock needed on your side. `STEPControl`/`STEPCAFControl`/`IGESControl` readers and writers all
read and write OCCT's process-global `Interface_Static` parameter table
([Open-Cascade-SAS/OCCT#1179](https://github.com/Open-Cascade-SAS/OCCT/issues/1179)), so the
bridge serializes every data-exchange (DE) call on a single shared mutex (`igesMutex()` in
`OCCTBridge_IO.mm`). This is a wrapper-level fix, not an OCCT kernel patch — OCCT's own DE
readers/writers aren't thread-safe by design, same as issue #298's original framing.

- **#181-B** (fixed via PR #184) found this for concurrent `writeSTEP`: two STEP writes on
  different threads SIGSEGV'd inside `STEPCAFControl_Writer`/`STEPControl_Writer` at once. The
  fix serialized the STEP/IGES *writer* entry points that existed at the time.
- **#359** found the same lock never covered STEP *import* at all (the #181-B report was
  specifically about writes), and 3 writer entry points added after PR #184 shipped
  (`OCCTExportSTEPWithName`, `OCCTExportSTEPWithModeProgress`, `OCCTDocumentWriteSTEPWithModes`)
  never picked up the lock either — 18 functions total. Fixed by extending `igesMutex()`
  coverage to all 18, matching the existing convention.

Distinct from issue #280 (constructing a `STEPCAFControl_Reader` poisons subsequent STEP
writes) — that's a different, already-fixed mechanism confirmed *not* `Interface_Static`-related,
resolved via an upstream kernel patch in v1.10.1.

### Naming-scope validation and font enumeration thread safety (issues #361, #363)

Two more process-global bridge singletons, found scoping #342. Both are **safe to call
concurrently** — bridge-only fixes, no OCCT kernel change needed since the shared state lives in
bridge-owned globals, not inside OCCT's own classes — but they took different fixes, worth
contrasting:

- **`Document.namingScopeValid`/`namingScopeIsValid`/`namingScopeValidChildren`/`namingScopeUnvalid`/
  `namingScopeClear`/`namingScopeValidCount`** originally went through one process-wide
  `TNaming_Scope` instance shared across every `Document`. v1.15.13 (#361) added a mutex
  (`docNamingScopeMutex()`) around every access, which fixed the underlying race —
  `TNaming_Scope`'s own `NCollection_Map<TDF_Label> myValid` has no internal synchronization — but
  left a design bug in place: every `Document` still shared the *same* map, so one document's
  valid-label set could leak into another's regardless of locking. Upstream reviewer feedback on
  #341's analogous `AutoNamingScope` fix ([OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388) —
  "a mutex is not the right tool here... usage remains unprotected") prompted a second look:
  **v1.15.14 (#363) moves naming scope onto a `TNaming_Scope` field on `OCCTDocument` itself** — no
  lock needed at all, since two threads working on two different `Document` instances no longer
  touch anything shared. `docNamingScopeMutex()` was removed. The general lesson: a mutex is the
  right tool only when the state is *genuinely* meant to be one shared resource; when it was
  wrongly made global/shared in the first place, the fix is relocating ownership to whatever object
  actually owns the data, not locking access to the wrong owner.
- **`FontManager`** (`fontCount`, `fontName`, `fontPath`, `fontHasAspect`, `initDatabase`) shares
  a process-global font-list cache with an unsynchronized check-then-act lazy-init, plus
  `initDatabase()` could reassign the cache at any time, racing an in-progress read. Fixed via
  `fontListMutex()` in `OCCTBridge_Visualization.mm`, held for every access (population and read).

### `Shape.fuseAll(_:)` internal parallelism (issue #367)

`Shape.fuseAll(_:)` is **safe to call concurrently** as of v1.15.16. It previously set
`builder.SetRunParallel(true)` on its `BRepAlgoAPI_BuilderAlgo` — internal OCCT parallelism for a
single call, not multiple independent calls. Under concurrent load this was actively unsafe: two
threads' top-level `Build()` calls, each requesting internal parallelism, submit work to the same
process-wide `OSD_ThreadPool::DefaultPool()`, and worker threads from one caller's dispatch can end
up processing another caller's data. Confirmed via TSan stress
(`Scripts/repro/342-boolean-ops/`, `fuse_multi_parallel` scenario): **100% of concurrent runs
produced wrong results** (27 faces instead of the correct 13), plus 237 race reports across
foundational topology code (`TopoDS_Builder::Add`, `TopExp_Explorer`, `BRep_Tool::Range`,
`BOPTools_AlgoTools::MakeSplitEdge`) — not a rare interleaving, a reliably reproducible one.

**Fixed** by dropping `SetRunParallel(true)` entirely — `Shape.fuseAll(_:)` now runs on OCCT's safe
serial default, same as `Shape.union(with:)`/`.subtracting(_:)`/`.intersecting(_:)` (which never
set it and were already confirmed clean under the same stress: 2000 concurrent mixed operations,
zero errors, zero wrong results, zero races). This is the only bridge call site that ever set
`SetRunParallel(true)` — grepped exhaustively across `Sources/OCCTBridge/src/*.mm`.

This is a distinct, more severe finding than a missing lock on bridge-owned state (#359/#361/#363):
it points at `OSD_ThreadPool`/`BOPTools_Parallel` — OCCT's own shared-pool parallel-dispatch
infrastructure — potentially not being safe for concurrent independent top-level callers at all,
not just this one call site. Root-causing that properly is tracked as a dedicated follow-up
investigation in **#369**, out of scope for this release; removing the trigger was the correct
immediate fix regardless of what the eventual root cause turns out to be.

**#369 status**: `OSD_ThreadPool` itself is exonerated — a synthetic stress test using
`OSD_ThreadPool::Launcher` directly (no BOPAlgo, no OCCT geometry) ran 3000 concurrent operations
clean, and reading `OSD_ThreadPool.cxx`'s `Lock`/`Free`/`WakeUp`/`WaitIdle` protocol found no flaw.
The bug is narrowed to `BOPTools_Parallel`/`BOPAlgo_PaveFiller`'s specific use of the pool, not yet
root-caused. Full investigation trail, ruled-out hypotheses, and concrete next steps:
[`Scripts/repro/342-boolean-ops/README.md`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/342-boolean-ops).

### Private `TDocStd_Application` per document, not a shared singleton (issue #371)

v1.15.17 stops routing every `OCCTDocument` through the shared
`XCAFApp_Application::GetApplication()` singleton described in the #341/#344 section above.
Per upstream maintainer feedback on [OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396)
(our #353 repro issue) — `GetApplication()` "exists solely for compatibility reasons"; OCCT's own
guidance since 7.1 is a private `TDocStd_Application` per caller — `OCCTDocument`'s constructor
now does `app = new TDocStd_Application()` instead. Ground-truth C++ testing confirmed this
behaves identically to the singleton for our usage (create, attach XCAF tools, add shape, set
color, retarget storage format, save, reload with a separate private instance), and header
inspection confirmed the state #344/#349/#353 fixed (`CDF_Directory::myDocuments`,
`CDF_Application::myReaders`/`myWriters`, `CDM_Application::myMetaDataLookUpTable`) is per-instance,
not static — a private app per document makes that state exclusive to one document by
construction, so our own bridge can no longer trip over those specific mechanisms.

**This does not eliminate the need for `ocafStoreMutex()`.** A dedicated confirmation harness
(`Scripts/repro/371-getapplication-singleton-elimination/occt_371_private_app.cpp`) — private app
per thread/round, zero shared state, no serialization — found two previously-uncharacterized races
when run unguarded against the real TSan-instrumented kernel: `Resource_Manager::
Resource_Manager()` writes an unsynchronized file-scope global (`Debug`) on every construction, and
`Storage_Schema::ICurrentData()` is a process-wide mutable `Handle` every `Storage_Schema`
constructor nullifies and every (de)serialization call reads, also unsynchronized. Neither had ever
been caught by this project's prior TSan gates, because every prior investigation (and all of
production, until this change) shared one application instance — `Resources()`'s own per-instance
lazy-init mutex (from the #344 fix) accidentally serialized `Resource_Manager`/`Storage_Schema`
usage down to "runs once, ever, for the whole process." Moving to a private instance per caller is
what first makes them concurrent. Filed upstream as
[OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398); **fixed in the kernel in v1.15.18,
see the #374 section below.**

**`ocafStoreMutex()`'s coverage was expanded**, not removed: it now also wraps the six
`OCCTDocumentDefineFormatBin/BinL/Xml/XmlL/BinXCAF/XmlXCAF` functions and
`OCCTDocumentCreateWithFormat` (previously outside the lock — safe only because every document
shared one app instance, so `Resources()`'s per-instance guard covered them for free). Confirmed by
adding an equivalent mutex to a copy of the confirmation harness: 8×50 threads/rounds, zero TSan
warnings, matching the real bridge's coverage. Plain shape-format I/O (STEP/IGES/BREP/OBJ/glTF/PLY)
is unaffected — none of those paths touch `Resources()`/`Storage_Schema`.

The upstream kernel PRs for #344/#349/#353 ([OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390),
[#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394),
[#1397](https://github.com/Open-Cascade-SAS/OCCT/pull/1397)) remain open and are **not** withdrawn
by this change — they fix real bugs in the singleton pattern OCCT's own header still documents as
"the only valid method" to get an `XCAFApp_Application`, which every *other* OCCT consumer still
following that guidance is exposed to. Moving our own bridge off the singleton sidesteps our
exposure to those specific mechanisms; it doesn't make the bugs stop existing for anyone still
using the pattern.

### `Resource_Manager::Debug` / `Storage_Schema::ICurrentData()` races, fixed (issue #374)

The two races #371's confirmation harness found (previous section) are fixed in v1.15.18, filed
upstream as [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398). `Resource_Manager::
Debug` (a file-scope `static bool` written on every construction) becomes `std::atomic<bool>` — a
plain process-wide flag, not per-instance intent, so atomic is sufficient (unlike #341's
`theAutoNaming`, which needed a deeper per-instance redesign). `Storage_Schema::ICurrentData()` (a
function-local static `Handle` every constructor's `Clear()` nulls and `Write()`/`BindType()`/
`TypeBinding()`/`AddPersistent()`/`PersistentToAdd()`/`HasTypeBinding()` read or write) gets a new
`ICurrentDataMutex()` — a `std::recursive_mutex` (recursive because `Write()`'s own critical section
re-enters `BindType()`/`AddPersistent()`/`PersistentToAdd()` on the same thread via per-type
`Storage_CallBack::Write()` callbacks) guarding every one of those touch points, held for `Write()`'s
entire body rather than per-access, since one `Write()` call is a single atomic "session" against
that global. No public API changes; only the pinned `OCCT.xcframework` kernel binary changed
(`Scripts/patches/0016`) — `OCCTBridge.xcframework` was not rebuilt. Confirmed via a dedicated TSan
reproducer (`Scripts/repro/374-resource-manager-storage-schema-race/occt_374_stress.cpp`, the
"unguarded" variant of #371's own confirmation harness): 13 races + SIGABRT before the fix, 0/4
clean runs after (8×30, 8×50, 10×60, 8×40).

## ThreadSanitizer gate for concurrency-touching changes

Every thread-safety kernel bug this project has found and fixed (#298, #341, #344, #349, #353,
#374) — a chain where #371's move to a private `TDocStd_Application` per document first surfaced
#374's pair of races — was pinned down by the same protocol: a
minimal-module ThreadSanitizer build of the pinned
OCCT with all carried patches applied, plus a small standalone C++ stress harness for the
suspect usage pattern. `Scripts/tsan-stress.sh` formalizes that protocol as a routine gate,
because upstream OCCT runs no sanitizers in its CI at all: races we do not catch here are
caught by nobody.

### When running it is required

Run `Scripts/tsan-stress.sh run` (plus `swift`) before merging any change that:

1. adds or widens a concurrent path through the bridge (a new operation callable in
   parallel, a new async/worker entry point);
2. wraps a new OCCT subsystem that callers are expected to use from multiple threads;
3. removes or relaxes a serialization mutex (`OCCTSerial`, `meshCafMutex`,
   `ocafStoreMutex`, or any successor); or
4. adds or updates a carried kernel patch that touches shared state.

If the change introduces a genuinely new concurrent usage pattern, also add a gate
scenario: either a new mode in an existing harness under `Scripts/repro/` or a new
standalone harness, and register it in the `SCENARIOS` matrix at the top of
`Scripts/tsan-stress.sh`. The existing harnesses (`341-meshcaf`, `344-cdf-directory`,
`349-ocaf-driver-reentrancy`, `353-cdm-metadata-lookup-table`, `363-own-autonaming`,
`371-getapplication-singleton-elimination`, `374-resource-manager-storage-schema-race`) are the
templates.

**Writing the harness is not registering it.** `363-own-autonaming` existed from the day patch
`0011`'s redesign landed and was absent from the matrix until the v2.0.0 release check, so the one
scenario that tests the property the earlier mutex fix could not guarantee ran in no gate at all.
A harness under `Scripts/repro/` that is not in `SCENARIOS` is a file, not a gate.

### Commands

```bash
Scripts/tsan-stress.sh build   # one-time: TSan-instrumented OCCT into Libraries/occt-install-tsan
Scripts/tsan-stress.sh run     # compile + run every gate scenario; fails on unsuppressed races
Scripts/tsan-stress.sh swift   # swift test --sanitize=thread on the concurrency-focused suites
Scripts/tsan-stress.sh all     # build if the instrumented kernel does not match, then run + swift
```

`build` wipes `occt-build-tsan` and `occt-install-tsan` before configuring, and refuses to run at
all unless `Libraries/occt-src` is at the tag `build-occt.sh` names. `all` decides whether to
rebuild by comparing a stamp (`occt-install-tsan/.tsan-stamp`: the OCCT tag plus a digest of every
carried patch) against the current tree, not by asking whether an install directory exists.

All three of those are scar tissue from one release check. `all` used to accept any existing
install as current, and the one on the machine was from 3 August, predating four carried patches;
`build` had no tag check, unlike `build-occt.sh`; and because nothing was wiped, an incremental
build over that tree finished in 1m26s and installed 48 libraries wearing that day's timestamps.
A clean rebuild of the same thing takes about 15 minutes. Nothing in the fast result said which
libraries had actually been recompiled, and a race that fails to reproduce against the wrong kernel
looks exactly like a race that is fixed.

### Coverage model

- `run` is the kernel gate: the harnesses link the instrumented OCCT directly, so races
  wholly inside kernel code are visible. This is the mode that found `STATIC_SOLIDINDEX`
  (#298), `theAutoNaming` (#341), the CDF singleton family (#344), the storage-driver
  scratch state (#349), and `Resource_Manager`/`Storage_Schema`'s construction-time races
  (#374).
- `swift` instruments the Swift and OCCTBridge sources only; the prebuilt
  `OCCT.xcframework` is not instrumented, so kernel-internal races are invisible there.
  It exists to catch wrapper-level races (bridge caches, Swift concurrency misuse), not
  kernel ones.

### Suppressions

`Scripts/tsan.supp` may contain only (a) confirmed-benign races reviewed and documented,
or (b) already-filed open kernel findings, each with an issue link and a removal
condition (current example: the `CDM_Application` metadata-map race, #353, suppressed
until its patch is carried so the gate stays green for new code). An unsuppressed race is
a gate failure: fix it or file it first. When a suppressed finding's fix lands, remove
the suppression; the gate then verifies the fix.

## Performance

The mutex overhead is ~1µs per lock/unlock. Typical OCCT operations take 0.1ms-10s. The serialization cost is negligible for all practical workflows.

## What FreeCAD and CadQuery Do

- **FreeCAD**: Runs all OCCT operations on the main thread. Recomputes are sequential.
- **CadQuery**: Relies on Python's GIL for implicit serialization. Multi-processing (separate processes) works but multi-threading doesn't.

OCCTSwift follows the same model with an explicit opt-in lock rather than implicit serialization.

## RC5 Thread Safety Improvements

OCCT 8.0.0-rc5 improved thread safety in several areas:
- `BRepCheck_*` result classes now have mutex protection
- Foundation globals made thread-safe via `std::atomic`
- TKBool globals converted to `thread_local`

These reduce the risk of data races in validation and boolean operations but do **not** fix the fundamental BSpline adaptor cache issue.
