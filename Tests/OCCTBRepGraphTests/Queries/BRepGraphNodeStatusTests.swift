import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Node Status")
struct BRepGraphNodeStatusTests {
    // A fresh box has nothing removed, which a query answering a constant `false` also
    // satisfies (#1986); a removed face must then report removed.
    @Test func noRemovedNodes() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.faceCount == 6)
        for i in 0..<graph.faceCount {
            #expect(!graph.isRemoved(nodeKind: .face, nodeIndex: i))
        }
        graph.removeNode(nodeKind: .face, nodeIndex: 5)
        #expect(graph.isRemoved(nodeKind: .face, nodeIndex: 5))
    }
}
