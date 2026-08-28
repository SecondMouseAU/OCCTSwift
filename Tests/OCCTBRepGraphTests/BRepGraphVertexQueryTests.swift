import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Vertex Queries")
struct BRepGraphVertexQueryTests {
    @Test func vertexEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let edges = graph.edges(of: 0)
                #expect(edges.count == 3)
            }
        }
    }
}
