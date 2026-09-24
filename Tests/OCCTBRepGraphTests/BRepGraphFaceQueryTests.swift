import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values pinned to the kernel probe (Scripts/repro/766-brepgraph-face-history).
@Suite("BRepGraph Face Queries")
struct BRepGraphFaceQueryTests {
    @Test func faceAdjacency() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let graph = try #require(BRepGraph(shape: box))
        // Face 0 touches every face but itself and its opposite (face 1).
        #expect(graph.adjacentFaces(of: 0) == [2, 3, 4, 5])
    }

    @Test func sharedEdges() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let graph = try #require(BRepGraph(shape: box))
        // The `if adj.count > 0` guard skipped the assertion on an empty adjacency (#1986).
        let adj = graph.adjacentFaces(of: 0)
        let first = try #require(adj.first)
        #expect(first == 2)
        #expect(graph.sharedEdges(between: 0, and: first) == [0])
    }

    @Test func outerWire() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Each face's outer wire is the wire of the same index; `>= 0` accepted any wire.
        #expect((0..<graph.faceCount).map { graph.outerWire(of: $0) } == [0, 1, 2, 3, 4, 5])
    }
}
