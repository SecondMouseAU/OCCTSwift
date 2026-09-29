#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    #if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif
#endif

/// The lock the Swift layer's internal mutable state uses, chosen per platform.
///
/// **Apple platforms keep `NSLock`, unchanged.** `PlatformLock` is a typealias there, so the
/// generated code, the locking semantics and the performance are exactly what they were before this
/// type existed. That is deliberate: the wasm work has no business altering a concurrency primitive
/// on a platform it does not run on.
///
/// The reason a typealias is needed at all is that `NSLock` is not in `FoundationEssentials`, and
/// the wasm build cannot import full `Foundation`: doing so in even one linked file pulls
/// Foundation's internationalisation data back into the module, which is about 10 MB brotli and the
/// whole point of #2761.
#if canImport(FoundationEssentials)
    public typealias PlatformLock = SingleThreadedLock
#else
    public typealias PlatformLock = NSLock
#endif

#if canImport(FoundationEssentials)

    /// `NSLock`'s shape for `wasm32-unknown-wasip1` in the **non-threads** configuration, where the
    /// lock has nothing to exclude.
    ///
    /// `lock()` and `unlock()` do nothing, and on this target that is correct rather than a
    /// shortcut: the module has exactly one thread and one linear memory, so no second execution
    /// context exists to contend with. #2169 chose that configuration deliberately, because the
    /// `wasip1-threads` variant left swift.org at 6.3 and a shared-memory module forces COOP/COEP
    /// cross-origin isolation onto the browser consumer.
    ///
    /// **If that decision is ever revisited, this type must be revisited with it.** On a threads
    /// build these no-ops would be silently wrong, which is the worst failure a lock can have, so
    /// the tie to #2169 is stated here rather than left for someone to infer. `Synchronization.Mutex`
    /// is available on this target and is the replacement, at the cost of reshaping the call sites,
    /// since it is scoped (`withLock`) rather than paired.
    ///
    /// It is a `final class` rather than a struct so that `let lock = PlatformLock()` has reference
    /// semantics on both platforms and the call sites read identically.
    public final class SingleThreadedLock: @unchecked Sendable {
        public init() {}

        @inlinable
        public func lock() {}

        @inlinable
        public func unlock() {}
    }

#endif
