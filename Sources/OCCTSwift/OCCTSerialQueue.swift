//
//  OCCTSerialQueue.swift
//  OCCTSwift
//
//  Thread safety utilities for OCCT operations.
//
//  OCCT is not thread-safe for concurrent access to shared geometry.
//  BSpline adaptor caches, topology mutations, and various algorithms
//  have data races when called from multiple threads simultaneously.
//
//  Use `OCCTSerial.withLock { }` around any sequence of OCCT operations
//  that must be atomic. Most individual bridge calls are NOT auto-locked:
//  the lock is provided for users who need to protect multi-step
//  workflows from concurrent access.
//
//  THE ONE EXCEPTION, and it matters because this is the file you would check
//  before deciding whether you need the lock: the STEP and IGES surface IS
//  already serialized inside the bridge. Forty entry points across
//  OCCTBridge_IO_StepFormat.mm, OCCTBridge_IO_IgesFormat.mm and
//  OCCTBridge_Document_DocumentLifecycle.mm take a process-wide recursive
//  mutex for their whole body, so `Exporter.writeSTEP`, `Shape.load(from:)`,
//  `Document.loadSTEP` and their IGES counterparts do not need wrapping and
//  cannot be made concurrent by wrapping them.
//
//  That is not a courtesy, it is load-bearing. OCCT routes every data-exchange
//  operation through process-global state (`Interface_Static`'s parameter
//  table, a per-format singleton controller and its shared write actor), so
//  the serialization is what makes concurrent STEP/IGES calls safe at all.
//  See docs/thread-safety.md and issue #1403.
//
//  For parallel geometry workflows, use `Shape.deepCopy()` to create
//  independent shape graphs that can be safely processed on separate threads.
//

import Foundation
import OCCTBridge

/// Thread safety utilities for OCCT operations.
///
/// OCCT's BSpline evaluation caches, adaptor classes, and various algorithms
/// are not thread-safe. Use these utilities to serialize access when needed.
///
/// The STEP and IGES surface is the exception: it is already serialized inside
/// the bridge, so `Exporter.writeSTEP`, `Shape.load(from:)`, `Document.loadSTEP`
/// and their IGES counterparts neither need this lock nor gain concurrency from
/// it. See the note at the top of this file.
///
/// ```swift
/// // Protect a multi-step workflow:
/// OCCTSerial.withLock {
///     let box = Shape.box(width: 10, height: 10, depth: 10)!
///     let filleted = box.filleted(radius: 1)!
///     let drilled = filleted.drilled(at: .zero, direction: SIMD3(0,0,-1), radius: 3)!
/// }
///
/// // For parallel processing, deep-copy shapes first:
/// let original = Shape.box(width: 10, height: 10, depth: 10)!
/// let copy = original.deepCopy()!  // Independent geometry graph
/// // 'copy' can now be safely used on another thread
/// ```
public enum OCCTSerial {

    /// Execute a block while holding the OCCT global lock.
    ///
    /// Use this to protect multi-step OCCT workflows from concurrent access.
    /// The lock is recursive, so nested calls are safe.
    @inlinable
    public static func withLock<T>(_ work: () throws -> T) rethrows -> T {
        OCCTSerialLockAcquire()
        defer { OCCTSerialLockRelease() }
        return try work()
    }

    /// Acquire the OCCT global lock manually.
    ///
    /// You MUST call `unlock()` when done. Prefer `withLock {}` instead.
    public static func lock() {
        OCCTSerialLockAcquire()
    }

    /// Release the OCCT global lock.
    public static func unlock() {
        OCCTSerialLockRelease()
    }
}
