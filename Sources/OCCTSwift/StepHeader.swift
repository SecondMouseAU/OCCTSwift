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

/// A STEP file header manager for reading and writing header fields
/// (name, timestamp, author, organization, preprocessor version, originating system).
public final class StepHeader: @unchecked Sendable {
    let handle: OCCTStepHeaderRef

    /// Create a STEP header with the given filename.
    public init?(filename: String) {
        guard let ref = OCCTStepHeaderCreate(filename) else { return nil }
        self.handle = ref
    }

    deinit {
        OCCTStepHeaderRelease(handle)
    }

    /// Whether the header is fully defined.
    public var isDone: Bool { OCCTStepHeaderIsDone(handle) }

    /// The file name field.
    public var name: String? {
        get {
            guard let ptr = OCCTStepHeaderGetName(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetName(handle, v) }
        }
    }

    /// The timestamp field.
    public var timeStamp: String? {
        get {
            guard let ptr = OCCTStepHeaderGetTimeStamp(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetTimeStamp(handle, v) }
        }
    }

    /// The first author field.
    public var author: String? {
        get {
            guard let ptr = OCCTStepHeaderGetAuthor(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetAuthor(handle, v) }
        }
    }

    /// The first organization field.
    public var organization: String? {
        get {
            guard let ptr = OCCTStepHeaderGetOrganization(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetOrganization(handle, v) }
        }
    }

    /// The preprocessor version field.
    public var preprocessorVersion: String? {
        get {
            guard let ptr = OCCTStepHeaderGetPreprocessorVersion(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetPreprocessorVersion(handle, v) }
        }
    }

    /// The originating system field.
    public var originatingSystem: String? {
        get {
            guard let ptr = OCCTStepHeaderGetOriginatingSystem(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetOriginatingSystem(handle, v) }
        }
    }
}
