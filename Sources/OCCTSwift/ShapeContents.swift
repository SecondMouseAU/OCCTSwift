import Foundation
import OCCTBridge
import simd

/// Census of sub-shape counts in a shape.
///
/// These are **occurrence** counts, not the distinct-sub-shape counts ``Shape/faceCount``,.
/// ``Shape/edgeCount`` and ``Shape/subShapeCount(ofType:)`` report.
///
/// See ``Shape/contents`` for.
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

/// The 9 Int32 fields OCCTShapeContents and OCCTShapeContentsExtended both start with, in.
/// the order `ShapeAnalysis_ShapeContents::Perform()` produces them.
///
/// The two bridge structs are otherwise different C types (OCCTShapeGetContents (backing).
/// ``Shape/contents``) returns OCCTShapeContents, OCCTShapeGetContentsExtended (backing.
/// ``Shape/contentsExtended()``) returns OCCTShapeContentsExtended with 21 further fields (but).
/// this protocol lets ``shapeContentsCore(_:)`` read either one through the exact same field list,
/// rather than each call site copying out all 9 values by hand (PR #875 review, #870's own.
/// aggregate review before it).
///
/// Conforming a C struct to a protocol costs one line each; there is.
/// no separate generic type or initializer here for the protocol to serve, unlike the design PR.
/// #870 flagged as more machinery than the duplication it removed.
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
/// Built by ``shapeContentsCore(_:)`` from either `ShapeContentsCFields`-conforming bridge
/// struct.
///
/// Both ``Shape/contents`` and ``Shape/contentsExtended()`` go through that one function,.
/// so there is exactly one mapping from nbXxx (C field) to xxx (Swift property) in the whole.
/// codebase. (a transposed pair (e.g. freeEdges/freeWires swapped) can only be wrong once, not).
/// silently diverge between the two call sites, and adding, removing or reordering a stored.
/// property here still forces every caller to be updated to satisfy Swift's "all stored properties.
/// must be initialized" rule (#855).
///
/// This does not reduce OCCT-side work (each bridge function still performs its own).
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

/// Builds `ShapeContentsCore` from either bridge struct's shared 9 fields (the one mapping).
/// from nbXxx (C field) to xxx (Swift property), shared by ``Shape/contents`` and.
/// ``Shape/contentsExtended()`` (see `ShapeContentsCore`'s own doc comment).
///
/// Generic over.
/// `ShapeContentsCFields` rather than a 9-Int32-parameter free function, so each call site.
/// passes the bridge struct itself. (`shapeContentsCore(c)` (instead of re-spelling all 9 field)).
/// names, which is what let the 9-argument block drift into 4 duplicated copies (PR #875 review).
func shapeContentsCore(_ c: some ShapeContentsCFields) -> ShapeContentsCore {
    ShapeContentsCore(
        solids: Int(c.nbSolids), shells: Int(c.nbShells), faces: Int(c.nbFaces),
        wires: Int(c.nbWires),
        edges: Int(c.nbEdges), vertices: Int(c.nbVertices), freeEdges: Int(c.nbFreeEdges),
        freeWires: Int(c.nbFreeWires), freeFaces: Int(c.nbFreeFaces)
    )
}
