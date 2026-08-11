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

/// The 9 counts `ShapeAnalysis_ShapeContents::Perform()` produces, read in one canonical order.
///
/// Two bridge functions expose this same OCCT walk on two otherwise-different C structs:
/// `OCCTShapeGetContents` (backing ``Shape/contents``) returns `OCCTShapeContents`, and
/// `OCCTShapeGetContentsExtended` (backing ``Shape/contentsExtended()``) returns
/// `OCCTShapeContentsExtended` with 21 further fields. Their first 9 fields share the same
/// names, order and `int32_t` type — this internal type is the single place that fact lives
/// Swift-side. Both ``Shape/contents`` and ``Shape/contentsExtended()`` build their first 9
/// values through one of the two initializers below rather than duplicating 9 field reads each;
/// adding, removing or reordering a stored property here forces both initializers to be updated
/// to satisfy Swift's "all stored properties must be initialized" rule, so the two public field
/// lists cannot silently drift apart in count or order (#855).
///
/// This does not reduce OCCT-side work — each bridge function still performs its own
/// `Perform()` walk over the shape; only the Swift-side field list is shared.
struct ShapeContentsCore {
    let solids: Int
    let shells: Int
    let faces: Int
    let wires: Int
    let edges: Int
    let vertices: Int
    let freeEdges: Int
    let freeWires: Int
    let freeFaces: Int

    init(_ c: OCCTShapeContents) {
        solids = Int(c.nbSolids)
        shells = Int(c.nbShells)
        faces = Int(c.nbFaces)
        wires = Int(c.nbWires)
        edges = Int(c.nbEdges)
        vertices = Int(c.nbVertices)
        freeEdges = Int(c.nbFreeEdges)
        freeWires = Int(c.nbFreeWires)
        freeFaces = Int(c.nbFreeFaces)
    }

    init(_ c: OCCTShapeContentsExtended) {
        solids = Int(c.nbSolids)
        shells = Int(c.nbShells)
        faces = Int(c.nbFaces)
        wires = Int(c.nbWires)
        edges = Int(c.nbEdges)
        vertices = Int(c.nbVertices)
        freeEdges = Int(c.nbFreeEdges)
        freeWires = Int(c.nbFreeWires)
        freeFaces = Int(c.nbFreeFaces)
    }
}
