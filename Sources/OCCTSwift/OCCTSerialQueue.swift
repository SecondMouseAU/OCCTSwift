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
//  that must be atomic. Individual bridge calls are NOT auto-locked —
//  the lock is provided for users who need to protect multi-step
//  workflows from concurrent access.
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
