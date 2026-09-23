import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder RemoveNode")
struct BRepGraphBuilderRemoveNodeTests {
    @Test func removeVertex() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.vertexCount == 8)
        let vIdx = graph.vertexCount - 1
        #expect(!graph.isRemoved(nodeKind: .vertex, nodeIndex: vIdx))
        graph.removeNode(nodeKind: .vertex, nodeIndex: vIdx)
        #expect(graph.isRemoved(nodeKind: .vertex, nodeIndex: vIdx))
        #expect(graph.activeVertexCount == 7)
    }

    @Test func removeSubgraph() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.faceCount == 6)
        let fIdx = graph.faceCount - 1
        graph.removeSubgraph(nodeKind: .face, nodeIndex: fIdx)
        #expect(graph.isRemoved(nodeKind: .face, nodeIndex: fIdx))
        #expect(graph.activeFaceCount == 5)
    }
}
