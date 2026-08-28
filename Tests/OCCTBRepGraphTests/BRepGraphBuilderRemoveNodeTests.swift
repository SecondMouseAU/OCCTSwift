import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder RemoveNode")
struct BRepGraphBuilderRemoveNodeTests {
    @Test func removeVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                if graph.vertexCount > 0 {
                    let vIdx = graph.vertexCount - 1
                    #expect(!graph.isRemoved(nodeKind: .vertex, nodeIndex: vIdx))
                    graph.removeNode(nodeKind: .vertex, nodeIndex: vIdx)
                    #expect(graph.isRemoved(nodeKind: .vertex, nodeIndex: vIdx))
                }
            }
        }
    }

    @Test func removeSubgraph() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                if graph.faceCount > 0 {
                    let fIdx = graph.faceCount - 1
                    graph.removeSubgraph(nodeKind: .face, nodeIndex: fIdx)
                    #expect(graph.isRemoved(nodeKind: .face, nodeIndex: fIdx))
                }
            }
        }
    }
}
