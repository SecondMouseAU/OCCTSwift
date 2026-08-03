import Foundation
import simd
import OCCTBridge

/// Shared library (dynamic library) handle.
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
