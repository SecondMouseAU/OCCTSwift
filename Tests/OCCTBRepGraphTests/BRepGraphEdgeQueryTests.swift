import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values pinned to the kernel probe (Scripts/repro/766-brepgraph-edge-query-sampling). A
// closed box has no boundary and no non-manifold edge, so a query answering a constant passed
// the box loops; the face lifted out by `copyFace(0)` supplies the opposite case, four
// boundary edges that are not manifold (#1986).
@Suite("BRepGraph Edge Queries")
struct BRepGraphEdgeQueryTests {
    @Test func edgeFaceCount() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.faceCount(of: 0) == 2)
    }

    @Test func edgeFaces() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.faces(of: 0) == [0, 2])
    }

    @Test func noBoundaryEdges() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeCount == 12)
        for i in 0..<graph.edgeCount {
            #expect(!graph.isBoundaryEdge(i))
        }
        let face = try #require(graph.copyFace(0))
        #expect(face.edgeCount == 4)
        for i in 0..<face.edgeCount {
            #expect(face.isBoundaryEdge(i))
        }
    }

    @Test func allManifoldEdges() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeCount == 12)
        for i in 0..<graph.edgeCount {
            #expect(graph.isManifoldEdge(i))
        }
        let face = try #require(graph.copyFace(0))
        #expect(face.edgeCount == 4)
        for i in 0..<face.edgeCount {
            #expect(!face.isManifoldEdge(i))
        }
    }

    @Test func edgeAdjacency() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Edge 0 runs vertex 0 -> 1; each end meets two more edges.
        #expect(graph.adjacentEdges(of: 0) == [1, 3, 8, 9])
    }
}
