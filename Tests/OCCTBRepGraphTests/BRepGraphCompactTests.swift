import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Compact")
struct BRepGraphCompactTests {
    // `nodesAfter > 0` held for any result (#1986). Pinned to BRepGraph_Compact::Perform in
    // the kernel probe (Scripts/repro/766-brepgraph-compact-copy-count): a clean box keeps
    // all 58 nodes; after removing one vertex, compaction drops exactly that vertex.
    @Test func compactBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let result = graph.compact()
        #expect(result.removedVertices == 0)
        #expect(result.removedEdges == 0)
        #expect(result.removedFaces == 0)
        #expect(result.nodesAfter == 58)

        let other = try #require(BRepGraph(shape: box))
        other.removeNode(nodeKind: .vertex, nodeIndex: 7)
        let after = other.compact()
        #expect(after.removedVertices == 1)
        #expect(after.nodesAfter == 57)
        #expect(other.vertexCount == 7)
    }
}
