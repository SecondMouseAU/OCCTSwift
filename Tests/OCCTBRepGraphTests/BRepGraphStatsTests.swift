import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Stats")
struct BRepGraphStatsTests {
    @Test func boxStats() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
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
                #expect(s.totalNodes > 0)
            }
        }
    }
}
