import Foundation
import simd
import OCCTBridge

/// Value-type wrapper for XCAFDoc_AssemblyItemId (represented as a string path).
public struct AssemblyItemId: Sendable {
    /// The string representation (e.g. "0:1:1:1/0:1:1:2")
    public let path: String

    public init(_ path: String) {
        self.path = path
    }

    /// Whether this item ID is valid (non-null).
    public var isValid: Bool {
        OCCTAssemblyItemIdIsValid(path)
    }

    /// Number of path entries.
    public var pathCount: Int32 {
        OCCTAssemblyItemIdPathCount(path)
    }

    /// Check equality with another item ID.
    public func isEqual(to other: AssemblyItemId) -> Bool {
        OCCTAssemblyItemIdIsEqual(path, other.path)
    }
}
