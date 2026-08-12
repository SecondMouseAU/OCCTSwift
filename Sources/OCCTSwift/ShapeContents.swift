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
/// `OCCTShapeContentsExtended` with 21 further fields. This internal type is the single place
/// that the two structs' first 9 fields are the same fact Swift-side: both ``Shape/contents``
/// and ``Shape/contentsExtended()`` build their first 9 values through ``shapeContentsCore(nbSolids:nbShells:nbFaces:nbWires:nbEdges:nbVertices:nbFreeEdges:nbFreeWires:nbFreeFaces:)``
/// below, rather than each duplicating 9 field reads. That means there is exactly one mapping from
/// `nbXxx` (C field) to `xxx` (Swift property) in the whole codebase — a transposed pair (e.g.
/// `freeEdges`/`freeWires` swapped) can only be wrong for both C structs identically, not silently
/// diverge between them, and adding, removing or reordering a stored property here still forces
/// every caller to be updated to satisfy Swift's "all stored properties must be initialized" rule
/// (#855).
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
}

/// Builds ``ShapeContentsCore`` from the 9 raw `Int32` counts either bridge struct exposes — the
/// one mapping from `nbXxx` (C field) to `xxx` (Swift property), shared by ``Shape/contents`` and
/// ``Shape/contentsExtended()`` (see ``ShapeContentsCore``'s own doc comment). A plain function
/// over the 9 values directly, rather than a protocol conformed to by both `OCCTShapeContents` and
/// `OCCTShapeContentsExtended` plus a generic initializer reading through it — same one-mapping
/// guarantee, three fewer declarations (PR #870 aggregate review).
func shapeContentsCore(
    nbSolids: Int32, nbShells: Int32, nbFaces: Int32, nbWires: Int32, nbEdges: Int32,
    nbVertices: Int32, nbFreeEdges: Int32, nbFreeWires: Int32, nbFreeFaces: Int32
) -> ShapeContentsCore {
    ShapeContentsCore(
        solids: Int(nbSolids), shells: Int(nbShells), faces: Int(nbFaces), wires: Int(nbWires),
        edges: Int(nbEdges), vertices: Int(nbVertices), freeEdges: Int(nbFreeEdges),
        freeWires: Int(nbFreeWires), freeFaces: Int(nbFreeFaces)
    )
}
