import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Stats")
struct BRepGraphStatsTests {
    @Test func boxStats() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let s = graph.stats
        #expect(s.faces == 6)
        #expect(s.edges == 12)
        #expect(s.vertices == 8)
        #expect(s.solids == 1)
        #expect(s.shells == 1)
        #expect(s.wires == 6)
        #expect(s.coedges == 24)
        #expect(s.surfaces == 6)
        #expect(s.curves3D == 12)
        #expect(s.compounds == 0)
        #expect(s.curves2D == 24)
        // Kernel: TopoView::Gen().NbNodes() is 58 for this box (1+1+6+6+12+8+24).
        #expect(s.totalNodes == 58)
    }
}
