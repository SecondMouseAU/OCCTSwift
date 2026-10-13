import OCCTBridge
import OCCTPlatform

/// Traces ancestry of edges in an offset wire back to original edges.
///
/// ``create(face:offset:joinType:)`` runs the offset and keeps it; ``offsetWire`` hands out the
/// offset wire it computed, whose edges are the ones ``hasAncestor(_:)`` and ``ancestor(of:)``
/// answer for.
///
/// ```swift
/// let rect = Wire.rectangle(width: 10, height: 10)!
/// let face = Shape.face(from: rect)!
/// if let ancestors = OffsetAncestors.create(face: face, offset: 1.0),
///     let offset = ancestors.offsetWire
/// {
///     for edge in offset.subShapes(ofType: .edge) {
///         let original = ancestors.ancestor(of: edge)  // the face edge it was offset from
///         _ = original
///     }
/// }
/// ```
public final class OffsetAncestors: @unchecked Sendable {
    let handle: OCCTOffsetAncestorsRef

    init(handle: OCCTOffsetAncestorsRef) {
        self.handle = handle
    }

    deinit {
        OCCTBRepFillOffsetAncestorsRelease(handle)
    }

    /// Create offset ancestors from a face with given offset distance.
    ///
    /// The sign follows ``Shape/offsetWire(face:offset:)`` and `BRepOffsetAPI_MakeOffset`:
    /// a positive offset is outward, a negative one inward (#3364).
    ///
    /// - Parameters:
    ///   - face: The planar face to offset.
    ///   - offset: Signed offset distance (positive outward, negative inward).
    ///   - joinType: 0=Arc, 1=Tangent, 2=Intersection
    /// - Returns: The ancestry, or nil if the input is not a face or not finite.
    public static func create(face: Shape, offset: Double, joinType: Int = 0) -> OffsetAncestors? {
        guard let ref = OCCTBRepFillOffsetAncestorsCreate(face.handle, offset, Int32(joinType))
        else { return nil }
        return OffsetAncestors(handle: ref)
    }

    /// Whether the offset and ancestry computation succeeded.
    public var isDone: Bool {
        OCCTBRepFillOffsetAncestorsIsDone(handle)
    }

    /// The offset wire the ancestry was computed on, or nil when the offset was not done.
    ///
    /// Its edges are the keys ``hasAncestor(_:)`` and ``ancestor(of:)`` take. It is the wire
    /// ``Shape/offsetWire(face:offset:)`` returns for the same face and offset (#3366).
    public var offsetWire: Shape? {
        guard let ref = OCCTBRepFillOffsetAncestorsOffsetWire(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Check if an edge of the offset wire has an ancestor in the original wire.
    ///
    /// `edge` is an edge of ``offsetWire``; an edge of the original face is not one, so it has
    /// no ancestor.
    public func hasAncestor(_ edge: Shape) -> Bool {
        OCCTBRepFillOffsetAncestorsHasAncestor(handle, edge.handle)
    }

    /// Get the ancestor shape of an offset edge.
    ///
    /// `edge` is an edge of ``offsetWire``. The ancestor is an edge or vertex of the face the
    /// offset was computed from.
    public func ancestor(of edge: Shape) -> Shape? {
        guard let ref = OCCTBRepFillOffsetAncestorsGetAncestor(handle, edge.handle) else {
            return nil
        }
        return Shape(handle: ref)
    }
}
