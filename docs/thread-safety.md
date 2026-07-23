---
title: Thread Safety
nav_order: 9
---

# Thread Safety in OCCTSwift

## TL;DR

OCCT is **not thread-safe** for concurrent access to shared geometry. Use `OCCTSerial.withLock { }` to serialize multi-step workflows, or `shape.deepCopy()` to create independent geometry for parallel processing.

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

### Shape.deepCopy() — Independent Geometry for Parallelism

For parallel geometry workflows, create independent copies:

```swift
let original = Shape.box(width: 10, height: 10, depth: 10)!

// Create 4 independent copies for parallel processing
let copies = (0..<4).map { _ in original.deepCopy()! }

// Process each copy on a different thread. Independence protects against the
// shared-geometry races (items 1–4); the `filleted` call is safe because the
// fillet path is reentrant as of v1.12.3 (item 5, issue #298).
DispatchQueue.concurrentPerform(iterations: 4) { i in
    let result = copies[i].filleted(radius: Double(i + 1))
    // Use result...
}
```

`deepCopy()` uses `BRepBuilderAPI_Copy` with `copyGeom: true` to create a fully independent shape graph — new geometry handles, new TShapes, no shared caches.

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
is a separate issue (#349): `CDF_Application::WriterFromFormat`/`ReaderFromFormat` cache
one storage/retrieval driver instance per format and reuse it for every call, but the
driver's own `Write()`/`Read()` isn't reentrant — its instance-level scratch state (e.g.
`BinLDrivers_DocumentStorageDriver`'s `myRelocTable`) corrupts under two concurrent
callers. **v1.15.6 ships an interim bridge-side mitigation** (`ocafStoreMutex()` in
`OCCTBridge_Document.mm`, serializing all three OCAF save/load bridge calls) — the same
"bridge mitigation, then kernel fix" pattern as #298/#341 above. The underlying OCCT
non-reentrancy is **not yet fixed in the kernel**; that needs its own dedicated TSan
investigation, tracked separately in #349. Plain shape-format I/O (STEP/IGES/BREP/OBJ/
glTF) is unaffected — this only covers the three OCAF (`.bcaf`/`.xcaf`-style binary/XML
document) persistence entry points.

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

## ThreadSanitizer gate for concurrency-touching changes

Every thread-safety kernel bug this project has found and fixed (#298, #341, #344, #349)
was pinned down by the same protocol: a minimal-module ThreadSanitizer build of the pinned
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
`349-ocaf-driver-reentrancy`) are the templates.

### Commands

```bash
Scripts/tsan-stress.sh build   # one-time: TSan-instrumented OCCT into Libraries/occt-install-tsan
Scripts/tsan-stress.sh run     # compile + run every gate scenario; fails on unsuppressed races
Scripts/tsan-stress.sh swift   # swift test --sanitize=thread on the concurrency-focused suites
Scripts/tsan-stress.sh all     # build if needed, then run + swift
```

### Coverage model

- `run` is the kernel gate: the harnesses link the instrumented OCCT directly, so races
  wholly inside kernel code are visible. This is the mode that found `STATIC_SOLIDINDEX`
  (#298), `theAutoNaming` (#341), the CDF singleton family (#344) and the storage-driver
  scratch state (#349).
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
