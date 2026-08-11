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

/// The 9 `int32_t` fields `ShapeAnalysis_ShapeContents::Perform()` produces, shared verbatim by
/// `OCCTShapeContents` and `OCCTShapeContentsExtended` (same names, same order, same type) — see
/// the two conformances just below. Conforming pins that fact at the C-struct declaration itself:
/// if either bridge header ever renamed, reordered, or retyped one of the 9, the conformance
/// fails to compile, not just ``ShapeContentsCore``'s reads of it.
protocol ShapeContentsCFields {
    var nbSolids: Int32 { get }
    var nbShells: Int32 { get }
    var nbFaces: Int32 { get }
    var nbWires: Int32 { get }
    var nbEdges: Int32 { get }
    var nbVertices: Int32 { get }
    var nbFreeEdges: Int32 { get }
    var nbFreeWires: Int32 { get }
    var nbFreeFaces: Int32 { get }
}

extension OCCTShapeContents: ShapeContentsCFields {}
extension OCCTShapeContentsExtended: ShapeContentsCFields {}

/// The 9 counts `ShapeAnalysis_ShapeContents::Perform()` produces, read in one canonical order.
///
/// Two bridge functions expose this same OCCT walk on two otherwise-different C structs:
/// `OCCTShapeGetContents` (backing ``Shape/contents``) returns `OCCTShapeContents`, and
/// `OCCTShapeGetContentsExtended` (backing ``Shape/contentsExtended()``) returns
/// `OCCTShapeContentsExtended` with 21 further fields. This internal type is the single place
/// that the two structs' first 9 fields are the same fact Swift-side: both ``Shape/contents``
/// and ``Shape/contentsExtended()`` build their first 9 values through the one generic
/// initializer below, over ``ShapeContentsCFields``, rather than each duplicating 9 field reads.
/// That means there is exactly one mapping from `nbXxx` (C field) to `xxx` (Swift property) in
/// the whole codebase — a transposed pair (e.g. `freeEdges`/`freeWires` swapped) can only be
/// wrong for both C structs identically, not silently diverge between them, and adding, removing
/// or reordering a stored property here still forces every caller to be updated to satisfy
/// Swift's "all stored properties must be initialized" rule (#855).
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

    init(_ c: some ShapeContentsCFields) {
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
