import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder CommitMutation")
struct BRepGraphBuilderCommitMutationTests {
    // `vertexCount > 0` held for the box's own 8 vertices whatever the add or the commit did
    // (#1986). Pinned to the kernel probe: the added vertex is index 8, the graph holds 9
    // vertices, all active, and the commit leaves the editor out of deferred mode.
    @Test func commitAfterAdd() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let v = graph.addVertex(x: 0, y: 0, z: 0, tolerance: 0.01)
        graph.commitMutation()
        #expect(v == 8)
        #expect(graph.vertexCount == 9)
        #expect(graph.activeVertexCount == 9)
        #expect(!graph.isDeferredMode)
    }
}
