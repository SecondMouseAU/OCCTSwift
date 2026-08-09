import Foundation
import simd
import OCCTBridge

/// Census of sub-shape counts in a shape.
///
/// These are **occurrence** counts, not the distinct-sub-shape counts ``Shape/faceCount``,
/// ``Shape/edgeCount`` and ``Shape/subShapeCount(ofType:)`` report. See ``Shape/contents`` for
/// what that difference means and when the two disagree.
public struct ShapeContents: Sendable {
    public let solids: Int
    public let shells: Int
    public let faces: Int
    public let wires: Int
    public let edges: Int
    public let vertices: Int
    public let freeEdges: Int
    public let freeWires: Int
    public let freeFaces: Int
}
