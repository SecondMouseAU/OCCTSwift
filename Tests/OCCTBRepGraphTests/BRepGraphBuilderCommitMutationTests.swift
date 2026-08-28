import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder CommitMutation")
struct BRepGraphBuilderCommitMutationTests {
    @Test func commitAfterAdd() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                _ = graph.addVertex(x: 0, y: 0, z: 0, tolerance: 0.01)
                graph.commitMutation()
                // Should not crash
                #expect(graph.vertexCount > 0)
            }
        }
    }
}
