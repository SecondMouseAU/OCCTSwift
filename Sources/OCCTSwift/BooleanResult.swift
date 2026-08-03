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
