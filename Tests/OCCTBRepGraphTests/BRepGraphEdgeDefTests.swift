import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values pinned to the kernel probe (Scripts/repro/766-brepgraph-edge-def-geometry). The
// range checks these replaced (`start >= 0 && start < vertexCount`) passed swapped or shuffled
// vertices, and the sphere test's `if isEdgeClosed` loop asserted nothing when no edge reported
// closed (#1986).
@Suite("BRepGraph Edge Def Details")
struct BRepGraphEdgeDefTests {
    @Test func edgeStartEndVertex() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let starts = [0, 0, 2, 1, 4, 4, 6, 5, 0, 1, 2, 3]
        let ends = [1, 2, 3, 3, 5, 6, 7, 7, 4, 5, 6, 7]
        #expect(graph.edgeCount == 12)
        #expect((0..<graph.edgeCount).map { graph.edgeStartVertex($0) ?? -1 } == starts)
        #expect((0..<graph.edgeCount).map { graph.edgeEndVertex($0) ?? -1 } == ends)
    }

    @Test func edgeIsClosedOnBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Box edges are NOT closed (they are line segments)
        #expect(graph.edgeCount == 12)
        for i in 0..<graph.edgeCount {
            #expect(!graph.isEdgeClosed(i))
        }
    }

    @Test func edgeClosedConsistency() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let graph = try #require(BRepGraph(shape: sphere))
        // Two degenerate pole edges (0 and 2) are closed on a single vertex; the seam (1) runs
        // from vertex 1 to vertex 0 and is not closed.
        #expect(graph.edgeCount == 3)
        #expect((0..<3).map { graph.isEdgeClosed($0) } == [true, false, true])
        #expect((0..<3).map { graph.edgeStartVertex($0) ?? -1 } == [0, 1, 1])
        #expect((0..<3).map { graph.edgeEndVertex($0) ?? -1 } == [0, 0, 1])
        // For any closed edge, start == end vertex
        for i in 0..<graph.edgeCount where graph.isEdgeClosed(i) {
            #expect(graph.edgeStartVertex(i) == graph.edgeEndVertex(i))
        }
    }
}
