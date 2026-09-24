import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - BRepGraph Builder (v0.135.0)

@Suite("BRepGraph Builder AddVertex")
struct BRepGraphBuilderAddVertexTests {
    // The add is required, not optional: an `if let` around it let a builder that always
    // failed pass (#1986). The box has vertices 0-7, so the new one is 8 (kernel probe).
    @Test func addVertexToGraph() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let origVertexCount = graph.vertexCount
        #expect(origVertexCount == 8)
        let vidx = try #require(graph.addVertex(x: 5.0, y: 5.0, z: 5.0, tolerance: 1e-7))
        #expect(vidx == 8)
        #expect(graph.vertexCount == origVertexCount + 1)
        let pt = graph.vertexPoint(vidx)
        #expect(abs(pt.x - 5.0) < 1e-6)
        #expect(abs(pt.y - 5.0) < 1e-6)
        #expect(abs(pt.z - 5.0) < 1e-6)
        #expect(abs(graph.vertexTolerance(vidx) - 1e-7) < 1e-10)
    }

    @Test func addMultipleVertices() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let orig = graph.vertexCount
        let v1 = try #require(graph.addVertex(x: 0, y: 0, z: 0, tolerance: 0.01))
        let v2 = try #require(graph.addVertex(x: 1, y: 2, z: 3, tolerance: 0.02))
        #expect(v1 == 8)
        #expect(v2 == 9)
        #expect(graph.vertexCount == orig + 2)
    }
}
