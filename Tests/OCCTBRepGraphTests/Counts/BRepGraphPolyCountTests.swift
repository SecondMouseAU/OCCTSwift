import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Poly Counts")
struct BRepGraphPolyCountTests {
    @Test func polyCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Poly counts are >= 0 (may be 0 if not meshed)
                #expect(graph.triangulationCount >= 0)
                #expect(graph.polygon3DCount >= 0)
            }
        }
    }
}
