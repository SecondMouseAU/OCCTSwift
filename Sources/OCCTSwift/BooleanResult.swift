import Foundation
import simd
import OCCTBridge

/// Result of a boolean operation with shape tracking.
public struct BooleanResult: Sendable {
    /// The result shape
    public let shape: Shape
    /// Shapes in the result that are modifications of faces from the first operand
    public let modifiedFaces: [Shape]
}

/// Per-input-subshape history for a boolean operation: which output
/// sub-shapes the input was modified into, which output sub-shapes were
/// generated FROM it, and whether it was deleted with no replacement.
///
/// ## Finding a declined fillet edge (#639)
///
/// ``Shape/filletedWithFullHistory(radius:edges:)`` skips an edge OCCT declines to fillet (a
/// free-boundary edge of an open shell, most commonly) rather than rejecting the whole call, and
/// this record is how a caller finds out which requested edges those were: check `!isDeleted &&
/// generated.isEmpty` for each one. An edge OCCT actually filleted is always deleted, with the new
/// fillet-boundary edges in `generated` (measured: 12/12 on the fixture below). Do **not** test
/// `modified.isEmpty` alone: a declined edge can still show up with one `modified` entry when an
/// *accepted* neighbour's fillet trims its shared endpoint, so `modified` is not empty on a
/// declined edge in general, only `generated`/`isDeleted` are the reliable signal.
///
/// ```swift
/// let box = Shape.box(width: 10, height: 10, depth: 10)!
/// let faces = box.faces().dropFirst().compactMap { Shape.fromFace($0) }
/// let shell = Shape.sew(shapes: Array(faces))!
/// let edgeShapes = shell.subShapes(ofType: .edge)
/// if let (_, history) = shell.filletedWithFullHistory(radius: 1.0, edges: Array(0..<edgeShapes.count)) {
///     let declined = edgeShapes.indices.filter {
///         let record = history.record(of: edgeShapes[$0])
///         return !record.isDeleted && record.generated.isEmpty
///     }
///     print(declined)   // e.g. [6, 9, 10, 11]
/// }
/// ```
public struct ShapeHistoryRecord: Sendable {
    /// Output sub-shapes that are modifications of the input (1:1 or 1:N).
    /// Example: a face split by a boolean cut → multiple modified faces.
    public let modified: [Shape]
    /// Output sub-shapes generated FROM the input but not replacing it.
    /// Example: filleting an edge generates new fillet faces from that edge,
    /// while the edge itself is deleted.
    public let generated: [Shape]
    /// True if the input was deleted with no replacement.
    public let isDeleted: Bool
}

/// Retained handle to a boolean operation's builder, queryable for per-input
/// history after the operation completes. Used by tools that need to track
/// selection IDs across boolean / split mutations (e.g. OCCTMCP's
/// `remap_selection`, parametric editors that want feature replay).
public final class ShapeHistoryRef: @unchecked Sendable {
    // internal, not fileprivate: BRepGraph.add(_:absorbing:inputRoots:operationName:)
    // in BRepGraph.swift needs it to synthesize a BRepTools_History (issue #290).
    let handle: OCCTBooleanHistoryRef

    init(_ handle: OCCTBooleanHistoryRef) {
        self.handle = handle
    }

    deinit {
        OCCTBooleanHistoryRelease(handle)
    }

    /// Look up the post-mutation history of one input sub-shape (any face,
    /// edge, or vertex from the original input shape).
    public func record(of inputSubShape: Shape) -> ShapeHistoryRecord {
        ShapeHistoryRecord(
            modified: collect { buf, max in
                OCCTBooleanHistoryModified(handle, inputSubShape.handle, buf, max)
            },
            generated: collect { buf, max in
                OCCTBooleanHistoryGenerated(handle, inputSubShape.handle, buf, max)
            },
            isDeleted: OCCTBooleanHistoryIsDeleted(handle, inputSubShape.handle)
        )
    }

    private func collect(_ fill: (UnsafeMutablePointer<OCCTShapeRef?>?, Int32) -> Int32) -> [Shape] {
        // Probe with a max=0 call to get the count, then size the buffer exactly.
        let count = fill(nil, 0)
        guard count > 0 else { return [] }
        var refs = [OCCTShapeRef?](repeating: nil, count: Int(count))
        _ = refs.withUnsafeMutableBufferPointer { buf in
            fill(buf.baseAddress, count)
        }
        return refs.compactMap { ref in ref.map(Shape.init(handle:)) }
    }
}
