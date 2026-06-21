---
title: Concurrency & Progress
parent: API Reference
---

# Concurrency & Progress

OCCTSwift provides two complementary concurrency utilities: `OCCTSerial`, a global recursive mutex that serializes multi-step OCCT workflows to prevent data races on shared geometry; and `ImportProgress`, a protocol for receiving progress callbacks and requesting cooperative cancellation during long-running STEP/IGES import operations. See also [`docs/thread-safety.md`](../thread-safety.md) for a detailed analysis of OCCT's thread-safety model and the rationale for these types.

## Topics

- [OCCTSerial](#occtserial) · [ImportProgress](#importprogress)

---

## OCCTSerial

`OCCTSerial` is a caseless `enum` namespace exposing a global recursive mutex backed by `std::recursive_mutex` in the C bridge. Use it to serialize any multi-step OCCT workflow that must be atomic — individual bridge calls are **not** auto-locked.

### `OCCTSerial.withLock(_:)`

Executes a block while holding the OCCT global lock, then releases it.

```swift
@inlinable
public static func withLock<T>(_ work: () throws -> T) rethrows -> T
```

The lock is recursive: nested `withLock` calls on the same thread will not deadlock. Prefer this over manual `lock()`/`unlock()` pairs — the `defer`-based release is guaranteed even when `work` throws.

- **Parameters:** `work` — the closure to execute under the lock.
- **Returns:** The value returned by `work`.
- **OCCT:** `std::recursive_mutex::lock` / `unlock` — exposed via `OCCTSerialLockAcquire()` / `OCCTSerialLockRelease()` in the bridge.
- **Example:**
  ```swift
  let drilled = OCCTSerial.withLock {
      let box = Shape.box(width: 10, height: 10, depth: 10)!
      let filleted = box.filleted(radius: 1)!
      return filleted.drilled(at: .zero, direction: SIMD3(0, 0, -1), radius: 3)
  }
  ```
- **Note:** For parallel geometry workflows, use `Shape.deepCopy()` to create independent shape graphs rather than serializing all threads through this lock.

---

### `OCCTSerial.lock()`

Acquires the OCCT global lock manually.

```swift
public static func lock()
```

You **must** call `unlock()` when done. Prefer `withLock {}` in almost all cases — it guarantees release even on early return or throw.

- **OCCT:** `OCCTSerialLockAcquire()` → `std::recursive_mutex::lock`.
- **Example:**
  ```swift
  OCCTSerial.lock()
  defer { OCCTSerial.unlock() }
  // Multiple OCCT operations that must be atomic
  let box = Shape.box(width: 5, height: 5, depth: 5)!
  let sphere = Shape.sphere(radius: 3)!
  ```

---

### `OCCTSerial.unlock()`

Releases the OCCT global lock.

```swift
public static func unlock()
```

Must be paired with a prior `lock()` call. Calling without a prior `lock()` is undefined behavior.

- **OCCT:** `OCCTSerialLockRelease()` → `std::recursive_mutex::unlock`.
- **Example:**
  ```swift
  OCCTSerial.lock()
  defer { OCCTSerial.unlock() }
  let result = Shape.box(width: 10, height: 5, depth: 2)!
  ```

---

## ImportProgress

`ImportProgress` is a reference-type protocol (`AnyObject & Sendable`) that provides a progress + cancellation channel for long-running OCCT import operations. Pass a conforming object to the `progress:` parameter on `Shape.load(from:)`, `Shape.loadSTEP(from:unitInMeters:)`, `Shape.loadIGES(from:)`, `Shape.loadIGESRobust(from:)`, `Document.load(from:)`, and `Document.loadSTEP(from:modes:)`.

The bridge implements this protocol via `BridgeProgressIndicator`, a subclass of `Message_ProgressIndicator` that forwards OCCT's `Show()` and `UserBreak()` callbacks to the Swift closures defined in `OCCTImportProgress` (the C struct bridged through `withImportProgress`).

### `ImportProgress.progress(fraction:step:)`

Called as the importer advances through its transfer phase.

```swift
func progress(fraction: Double, step: String)
```

`fraction` advances from `0.0` to `1.0` as entities are transferred. `step` is a human-readable name for the current sub-task (may be empty). Callbacks arrive on whatever thread the import runs on — hop to `@MainActor` for UI updates.

- **Parameters:**
  - `fraction` — progress in the range `0.0...1.0`.
  - `step` — name of the current sub-task; empty string if OCCT does not supply one.
- **OCCT:** `Message_ProgressIndicator::Show(theScope, isForce)` — called by `Message_ProgressScope` at each checkpoint during `STEPControl_Reader::TransferRoots` or `IGESControl_Reader::TransferRoots`.
- **Example:**
  ```swift
  final class MyProgress: ImportProgress {
      func progress(fraction: Double, step: String) {
          Task { @MainActor in
              progressBar.doubleValue = fraction
              statusLabel.stringValue = step.isEmpty ? "Importing…" : step
          }
      }
  }

  let tracker = MyProgress()
  if let shape = Shape.loadSTEP(from: url, progress: tracker) {
      // shape is ready
  }
  ```

---

### `ImportProgress.shouldCancel()`

Polled at each OCCT progress checkpoint; return `true` to cooperatively abort the import.

```swift
func shouldCancel() -> Bool
```

A default no-op implementation returning `false` is provided via a protocol extension, so conformers only need to override this when cancellation is required. When this returns `true`, the loader throws `ImportError.cancelled` on the next checkpoint boundary.

- **Returns:** `true` to request cancellation; `false` to continue (default).
- **OCCT:** `Message_ProgressIndicator::UserBreak()` — checked by the bridge's `BridgeProgressIndicator` subclass at each `Message_ProgressScope` step.
- **Example:**
  ```swift
  final class CancellableProgress: ImportProgress {
      private var _cancel = false
      func requestCancel() { _cancel = true }

      func progress(fraction: Double, step: String) {
          Task { @MainActor in progressBar.doubleValue = fraction }
      }

      func shouldCancel() -> Bool { _cancel }
  }

  let tracker = CancellableProgress()
  cancelButton.action = { tracker.requestCancel() }

  do {
      let shape = try Shape.loadSTEP(from: url, progress: tracker)
  } catch ImportError.cancelled {
      print("Import was cancelled")
  }
  ```
- **Note:** `shouldCancel()` is polled once per transferred entity in STEP/IGES — typically many times per second for large files. Keep the implementation cheap (e.g. read an atomic flag, not a lock).
