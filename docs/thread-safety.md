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

5. **Non-reentrant statics in the 3D fillet/chamfer solver (issue #298)** — `BRepFilletAPI_MakeFillet`'s constant- and evolutive-radius blend functions (`BlendFunc_ConstRad`, `BlendFunc_EvolRad`) and the shared `ChFi3d_Builder` curve checker keep their geometric work variables in function-local `static`s ("to avoid systematic reallocation"). This is **process-global** state, not per-object: two threads running *any two* fillet/chamfer builds at once — even on completely independent shapes — interleave writes to the same statics. The solver then converges on a corrupted surface and returns a **wrong-but-plausible solid** (one solid, positive volume) that fails `BRepCheck` — silent bad geometry, not a crash and not a thrown error. This is distinct from items 1–4: no geometry is shared at the Swift level, yet the operation still races. Reproduced in pure OCCT with no wrapper involved. The bridge now serialises these builds internally (see below), so consumers are protected transparently.

## What IS Thread-Safe

- **Handle reference counting** (`occ::handle<T>`) — atomic `std::atomic_int` refcount
- **Reading shape topology** — immutable once built
- **Completely independent shapes** — shapes with no shared TShapes or geometry handles — **with one exception:** 3D fillet and chamfer builds are not safe to run concurrently even on independent shapes, because of the process-global statics in item 5. The bridge serialises them for you (see [3D fillet/chamfer serialization](#3d-filletchamfer-serialization-issue-298)); you get correct geometry, just no parallel speedup on those specific ops.
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
// shared-geometry races (items 1–4); the `filleted` call is *additionally* safe
// because the bridge serialises fillet builds internally (item 5, issue #298).
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

### 3D fillet/chamfer serialization (issue #298)

The problem in item 5 above cannot be solved by `deepCopy()` or by the caller
holding `OCCTSerial` — the racing state lives in OCCT's own function-local
statics, not in any shape the caller can see or copy. So the bridge serialises it
at the source: **every 3D fillet and chamfer build runs under a dedicated
recursive mutex** (`occtFilletMutex` in the C bridge), separate from `OCCTSerial`.

What this means for you:

- **Fillet/chamfer are always safe to call concurrently**, with no lock on your
  side and no `deepCopy()` required. `Shape.filleted`, `Shape.chamfered`, the
  fillet/chamfer builders, and `SheetMetal.Builder.build` (which fillets internally)
  all go through the guarded path.
- **Only fillet/chamfer builds serialise against each other.** Booleans, meshing,
  extrudes, sweeps, and everything else stay fully parallel. Filleting on thread A
  does not block a boolean on thread B.
- **2D fillets/chamfers (`BRepFilletAPI_MakeFillet2d`) are not affected** — they use
  the separate analytic `ChFi2d` toolkit, which has no such statics, and are not
  serialised.

This is a mitigation for an upstream OCCT defect. The permanent fix de-statics the
work variables in `BlendFunc_ConstRad`/`BlendFunc_EvolRad` (carried as an `occt-src`
patch); once that ships in the pinned kernel the bridge lock can be dropped and
fillet/chamfer become genuinely parallel.

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
