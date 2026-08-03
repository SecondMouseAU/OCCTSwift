import Foundation
import simd
import OCCTBridge

/// Traces ancestry of edges in an offset wire back to original edges.
public final class OffsetAncestors: @unchecked Sendable {
    let handle: OCCTOffsetAncestorsRef

    init(handle: OCCTOffsetAncestorsRef) {
        self.handle = handle
    }

    deinit {
        OCCTBRepFillOffsetAncestorsRelease(handle)
    }

    /// Create offset ancestors from a face with given offset distance.
    /// joinType: 0=Arc, 1=Tangent, 2=Intersection
    public static func create(face: Shape, offset: Double, joinType: Int = 0) -> OffsetAncestors? {
        guard let ref = OCCTBRepFillOffsetAncestorsCreate(face.handle, offset, Int32(joinType)) else { return nil }
        return OffsetAncestors(handle: ref)
    }

    /// Whether the offset and ancestry computation succeeded.
    public var isDone: Bool {
        OCCTBRepFillOffsetAncestorsIsDone(handle)
    }

    /// Check if an edge has an ancestor in the original wire.
    public func hasAncestor(_ edge: Shape) -> Bool {
        OCCTBRepFillOffsetAncestorsHasAncestor(handle, edge.handle)
    }

    /// Get the ancestor shape of an offset edge.
    public func ancestor(of edge: Shape) -> Shape? {
        guard let ref = OCCTBRepFillOffsetAncestorsGetAncestor(handle, edge.handle) else { return nil }
        return Shape(handle: ref)
    }
}
