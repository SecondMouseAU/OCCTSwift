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
