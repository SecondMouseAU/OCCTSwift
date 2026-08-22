import Foundation
import OCCTBridge
import simd

/// Attribute ID filter for OCAF document operations.
public final class IDFilter: @unchecked Sendable {
    internal let ref: OCCTIDFilterRef

    /// Create an ID filter.
    /// - Parameter ignoreAll: If true, all IDs are ignored except those explicitly kept.
    ///   If false, all IDs are kept except those explicitly ignored.
    public init?(ignoreAll: Bool = true) {
        guard let ref = OCCTIDFilterCreate(ignoreAll) else { return nil }
        self.ref = ref
    }

    deinit {
        OCCTIDFilterRelease(ref)
    }

    /// Whether the filter is in ignore-all mode.
    public var isIgnoreAll: Bool {
        get { OCCTIDFilterIgnoreAll(ref) }
        set { OCCTIDFilterSetIgnoreAll(ref, newValue) }
    }

    /// Mark a GUID as kept (relevant in ignore-all mode).
    public func keep(_ guidString: String) {
        OCCTIDFilterKeep(ref, guidString)
    }

    /// Mark a GUID as ignored (relevant in keep-all mode).
    public func ignore(_ guidString: String) {
        OCCTIDFilterIgnore(ref, guidString)
    }

    /// Check if a GUID is kept by the filter.
    public func isKept(_ guidString: String) -> Bool {
        OCCTIDFilterIsKept(ref, guidString)
    }

    /// Check if a GUID is ignored by the filter.
    public func isIgnored(_ guidString: String) -> Bool {
        OCCTIDFilterIsIgnored(ref, guidString)
    }
}
