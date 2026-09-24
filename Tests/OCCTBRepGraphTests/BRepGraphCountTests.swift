import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Counts")
struct BRepGraphCountTests {
    @Test func activeCounts() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.activeFaceCount == 6)
        #expect(graph.activeEdgeCount == 12)
        #expect(graph.activeVertexCount == 8)
    }

    // The 2D count was `> 0`, which accepted any miscount (#1986). A box has one pcurve per
    // coedge, 24, per NbCoEdgeCurves2D in the kernel probe.
    @Test func geometryCounts() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.surfaceCount == 6)
        #expect(graph.curve3DCount == 12)
        #expect(graph.curve2DCount == 24)
    }

    @Test func coedgeCounts() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.coedgeCount == 24)
    }
}
