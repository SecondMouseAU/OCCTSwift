import Foundation
import OCCTBridge
import simd

/// Ascendant-descendant relationship tracker for shapes.
public final class AsDesTracker: @unchecked Sendable {
    internal let handle: OCCTAsDesRef

    public init() {
        self.handle = OCCTAsDesCreate()
    }

    deinit { OCCTAsDesRelease(handle) }

    /// Add a parent-child relationship.
    public func add(parent: Shape, child: Shape) {
        OCCTAsDesAdd(handle, parent.handle, child.handle)
    }

    /// Check if a shape has descendants.
    public func hasDescendant(_ shape: Shape) -> Bool {
        OCCTAsDesHasDescendant(handle, shape.handle)
    }

    /// Get number of descendants for a shape.
    public func descendantCount(_ shape: Shape) -> Int {
        Int(OCCTAsDesDescendantCount(handle, shape.handle))
    }
}
