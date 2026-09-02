import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #1492: seven functions in `OCCTBridge_Topology_Adjacency.mm` dereferenced the `OCCTShapeRef`
/// wrapper pointer (`shape->shape`) with no null guard, unlike dozens of sibling functions in the
/// same file which all open with `if (!shape) return ...;`. Dereferencing a null C++ pointer's
/// member is undefined behavior -- an uncatchable OS signal, not a thrown exception -- so the
/// enclosing `catch (...)` cannot intercept it, the same class of defect this project has fixed
/// repeatedly (#478, #556, #618, #1026, #1035, #1424).
///
/// `Shape.handle` (`Sources/OCCTSwift/Shape.swift`) is a non-optional `let`, populated only via
/// `guard let handle = ... else { return nil }` in every initializer, so Swift's type system
/// prevents passing `nil` for any of these `_Nonnull` parameters through the public API -- none of
/// these seven sites is reachable today. `unsafeBitCast` synthesizes an `OCCTShapeRef`/pointer that
/// type-checks as non-optional but is a genuine null pointer at the ABI level, the same technique
/// Issue #1424's `Issue1424BndLibFaceNullGuardTests` used for the identical shape of defect, and
/// the only way to exercise these guards from Swift at all.
@Suite("Issue #1492: Topology_Adjacency.mm null-handle guards")
struct Issue1492TopologyAdjacencyNullGuardTests {

    /// A genuinely-null `OCCTShapeRef`: a real pointer type that type-checks as non-optional, but
    /// is a zero bit pattern at the ABI level -- exactly what none of these seven functions could
    /// previously survive.
    private static var nullShape: OCCTShapeRef {
        unsafeBitCast(UInt(0), to: OCCTShapeRef.self)
    }

    private static var nullInt32Ptr: UnsafeMutablePointer<Int32> {
        unsafeBitCast(UInt(0), to: UnsafeMutablePointer<Int32>.self)
    }

    // MARK: OCCTEdgeFaceAdjacency / OCCTVertexEdgeAdjacency (shape only)

    @Test("OCCTEdgeFaceAdjacency: a null shape returns 0, not a crash")
    func edgeFaceAdjacencyNullShape() {
        #expect(OCCTEdgeFaceAdjacency(Self.nullShape, nil) == 0)
    }

    @Test("OCCTVertexEdgeAdjacency: a null shape returns 0, not a crash")
    func vertexEdgeAdjacencyNullShape() {
        #expect(OCCTVertexEdgeAdjacency(Self.nullShape, nil) == 0)
    }

    // MARK: OCCTEdgeAdjacentFaces (shape, edge, and output buffer)

    @Test("OCCTEdgeAdjacentFaces: a null shape returns 0, not a crash")
    func edgeAdjacentFacesNullShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.subShapes(ofType: .edge).first)
        var indices = [Int32](repeating: -1, count: 64)
        let count = indices.withUnsafeMutableBufferPointer { buf in
            OCCTEdgeAdjacentFaces(Self.nullShape, edge.handle, buf.baseAddress!, 64)
        }
        #expect(count == 0)
    }

    @Test("OCCTEdgeAdjacentFaces: a null edge returns 0, not a crash")
    func edgeAdjacentFacesNullEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        var indices = [Int32](repeating: -1, count: 64)
        let count = indices.withUnsafeMutableBufferPointer { buf in
            OCCTEdgeAdjacentFaces(box.handle, Self.nullShape, buf.baseAddress!, 64)
        }
        #expect(count == 0)
    }

    @Test("OCCTEdgeAdjacentFaces: a null output buffer returns 0, not a crash")
    func edgeAdjacentFacesNullBuffer() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.subShapes(ofType: .edge).first)
        #expect(OCCTEdgeAdjacentFaces(box.handle, edge.handle, Self.nullInt32Ptr, 64) == 0)
    }

    @Test("OCCTEdgeAdjacentFaces: ordinary inputs are unaffected")
    func edgeAdjacentFacesUnaffected() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.subShapes(ofType: .edge).first)
        let adjacent = box.adjacentFaces(forEdge: edge)
        #expect(adjacent.count == 2)
    }

    // MARK: OCCTVertexAdjacentEdges (shape, vertex, and output buffer)

    @Test("OCCTVertexAdjacentEdges: a null shape returns 0, not a crash")
    func vertexAdjacentEdgesNullShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let vertex = try #require(box.subShapes(ofType: .vertex).first)
        var indices = [Int32](repeating: -1, count: 64)
        let count = indices.withUnsafeMutableBufferPointer { buf in
            OCCTVertexAdjacentEdges(Self.nullShape, vertex.handle, buf.baseAddress!, 64)
        }
        #expect(count == 0)
    }

    @Test("OCCTVertexAdjacentEdges: a null vertex returns 0, not a crash")
    func vertexAdjacentEdgesNullVertex() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        var indices = [Int32](repeating: -1, count: 64)
        let count = indices.withUnsafeMutableBufferPointer { buf in
            OCCTVertexAdjacentEdges(box.handle, Self.nullShape, buf.baseAddress!, 64)
        }
        #expect(count == 0)
    }

    @Test("OCCTVertexAdjacentEdges: a null output buffer returns 0, not a crash")
    func vertexAdjacentEdgesNullBuffer() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let vertex = try #require(box.subShapes(ofType: .vertex).first)
        #expect(OCCTVertexAdjacentEdges(box.handle, vertex.handle, Self.nullInt32Ptr, 64) == 0)
    }

    @Test("OCCTVertexAdjacentEdges: ordinary inputs are unaffected")
    func vertexAdjacentEdgesUnaffected() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let vertex = try #require(box.subShapes(ofType: .vertex).first)
        let adjacent = box.adjacentEdges(forVertex: vertex)
        #expect(adjacent.count == 3)  // a box vertex meets 3 edges
    }

    // MARK: OCCTWireExplorerOrientations / OCCTWireExplorerVertices (wire only -- `face` is
    // already `_Nullable` and legitimately optional, see the file's own `if (face) {...}`)

    @Test("OCCTWireExplorerOrientations: a null wire returns 0, not a crash")
    func wireExplorerOrientationsNullWire() {
        #expect(OCCTWireExplorerOrientations(Self.nullShape, nil, nil) == 0)
    }

    @Test("OCCTWireExplorerVertices: a null wire returns 0, not a crash")
    func wireExplorerVerticesNullWire() {
        #expect(OCCTWireExplorerVertices(Self.nullShape, nil, nil, nil, nil) == 0)
    }

    @Test("OCCTWireExplorerOrientations / OCCTWireExplorerVertices: ordinary inputs are unaffected")
    func wireExplorerUnaffected() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.subShapes(ofType: .face).first)
        let wire = try #require(face.subShapes(ofType: .wire).first)
        #expect(wire.wireEdgeOrientations(face: face).count == 4)
        #expect(wire.wireExplorerVertices(face: face).count == 4)
    }

    // MARK: OCCTShapeTransformIsNegative (the one where the null check has to come before the
    // existing `IsNull()` read, which already dereferences the wrapper pointer)

    @Test("OCCTShapeTransformIsNegative: a null shape returns false, not a crash")
    func transformIsNegativeNullShape() {
        #expect(OCCTShapeTransformIsNegative(Self.nullShape) == false)
    }

    @Test("OCCTShapeTransformIsNegative: an ordinary shape is unaffected")
    func transformIsNegativeUnaffected() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.isTransformNegative == false)
    }
}
