import Foundation
import simd
import OCCTBridge

/// A builder for sewing shapes together.
public final class SewingBuilder: @unchecked Sendable {
    private let ref: OCCTSewingRef

    /// Create a sewing builder with the given tolerance.
    public init?(tolerance: Double = 1e-6) {
        guard let r = OCCTSewingCreate(tolerance) else { return nil }
        self.ref = r
    }

    deinit {
        OCCTSewingRelease(ref)
    }

    /// Add a shape to be sewn.
    public func add(_ shape: Shape) {
        OCCTSewingAdd(ref, shape.handle)
    }

    /// Perform the sewing operation.
    public func perform() {
        OCCTSewingPerform(ref)
    }

    /// Get the result shape.
    public var result: Shape? {
        guard let r = OCCTSewingResult(ref) else { return nil }
        return Shape(handle: r)
    }

    /// Number of free edges.
    public var nbFreeEdges: Int { Int(OCCTSewingNbFreeEdges(ref)) }

    /// Number of contiguous edges.
    public var nbContigousEdges: Int { Int(OCCTSewingNbContigousEdges(ref)) }

    /// Number of degenerated shapes.
    public var nbDegeneratedShapes: Int { Int(OCCTSewingNbDegeneratedShapes(ref)) }
}

extension SewingBuilder {
    /// Number of multiple edges (edges shared by more than two faces).
    public var multipleEdgeCount: Int {
        Int(OCCTSewingNbMultipleEdges(ref))
    }

    /// Get a multiple edge by index (1-based).
    public func multipleEdge(at index: Int) -> Shape? {
        var outEdge: OCCTShapeRef?
        if OCCTSewingIsMultipleEdge(ref, Int32(index), &outEdge), let edge = outEdge {
            return Shape(handle: edge)
        }
        return nil
    }
}

extension SewingBuilder {
    /// Number of deleted faces after sewing.
    public var nbDeletedFaces: Int { Int(OCCTSewingNbDeletedFaces(ref)) }

    /// Get a deleted face by index (1-based).
    public func deletedFace(at index: Int) -> Shape? {
        guard let r = OCCTSewingDeletedFace(ref, Int32(index)) else { return nil }
        return Shape(handle: r)
    }

    /// Check if a sub-shape was modified by sewing.
    public func isModified(_ shape: Shape) -> Bool {
        OCCTSewingIsModified(ref, shape.handle)
    }

    /// Get the modified version of a shape.
    public func modified(_ shape: Shape) -> Shape? {
        guard let r = OCCTSewingModified(ref, shape.handle) else { return nil }
        return Shape(handle: r)
    }

    /// Check if a shape is degenerated.
    public func isDegenerated(_ shape: Shape) -> Bool {
        OCCTSewingIsDegenerated(ref, shape.handle)
    }

    /// Check if an edge is a section bound.
    public func isSectionBound(_ edge: Shape) -> Bool {
        OCCTSewingIsSectionBound(ref, edge.handle)
    }

    /// Get the face that contains the given edge (after sewing).
    public func whichFace(_ edge: Shape) -> Shape? {
        guard let r = OCCTSewingWhichFace(ref, edge.handle) else { return nil }
        return Shape(handle: r)
    }

    /// Load a base shape context for sewing.
    public func load(_ shape: Shape) {
        OCCTSewingLoad(ref, shape.handle)
    }

    /// Set non-manifold mode.
    public func setNonManifoldMode(_ enabled: Bool) {
        OCCTSewingSetNonManifoldMode(ref, enabled)
    }

    /// Set face mode (controls face analysis).
    public func setFaceMode(_ enabled: Bool) {
        OCCTSewingSetFaceMode(ref, enabled)
    }

    /// Set floating edges mode.
    public func setFloatingEdgesMode(_ enabled: Bool) {
        OCCTSewingSetFloatingEdgesMode(ref, enabled)
    }

    /// Set minimum tolerance.
    public func setMinTolerance(_ tolerance: Double) {
        OCCTSewingSetMinTolerance(ref, tolerance)
    }

    /// Set maximum tolerance.
    public func setMaxTolerance(_ tolerance: Double) {
        OCCTSewingSetMaxTolerance(ref, tolerance)
    }
}
