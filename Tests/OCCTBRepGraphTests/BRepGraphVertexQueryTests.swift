import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Vertex Queries")
struct BRepGraphVertexQueryTests {
    @Test func vertexEdges() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let edges = graph.edges(of: 0)
        #expect(edges.count == 3)
    }
}
