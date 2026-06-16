---
title: Thread Safety
nav_order: 8
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

## What IS Thread-Safe

- **Handle reference counting** (`occ::handle<T>`) — atomic `std::atomic_int` refcount
- **Reading shape topology** — immutable once built
- **Completely independent shapes** — shapes with no shared TShapes or geometry handles
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

// Process each copy on a different thread — safe because they share nothing
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
