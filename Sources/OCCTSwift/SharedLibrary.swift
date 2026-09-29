import Foundation
import OCCTBridge
import simd

// The platform C library, named because this file uses it directly (free, sin, cos, sqrt and
// the like). `import Foundation` happens to re-export it on Apple platforms, so these were in
// scope by accident rather than by declaration; FoundationEssentials does not, which is how
// #2761 found them. Naming it here is correct independently of that work.
#if canImport(Darwin)
    import Darwin
#elseif canImport(WASILibc)
    import WASILibc
#elseif canImport(Glibc)
    import Glibc
#endif

/// Shared library (dynamic library) handle.
///
/// `@unchecked Sendable` reflects that `ref` is a plain bridge handle, not that concurrent use of
/// one instance is safe, it isn't: `open()`/`close()` load/unload the underlying OS dynamic
/// library in place with no lock, an OS-level side effect, not just a data race in a C++ object.
/// Serialize access with `OCCTSerial.withLock { }`.
public final class SharedLibrary: @unchecked Sendable {
    private let ref: OCCTSharedLibRef

    /// Create a shared library handle for the given name/path.
    public init?(name: String) {
        guard let r = OCCTSharedLibCreate(name) else { return nil }
        ref = r
    }

    deinit {
        OCCTSharedLibRelease(ref)
    }

    /// Open (load) the shared library.
    @discardableResult
    public func open() -> Bool {
        OCCTSharedLibOpen(ref)
    }

    /// Close (unload) the shared library.
    public func close() {
        OCCTSharedLibClose(ref)
    }

    /// Get the name of the shared library.
    public var name: String? {
        guard let cstr = OCCTSharedLibName(ref) else { return nil }
        let result = String(cString: cstr)
        free(cstr)
        return result
    }
}
