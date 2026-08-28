import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AddCompSolid")
struct BRepGraphBuilderAddCompSolidTests {
    @Test func addCompSolidFromSolids() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origCS = graph.compSolidCount
                if graph.solidCount > 0 {
                    if let csIdx = graph.addCompSolid(solidIndices: [0]) {
                        #expect(csIdx >= 0)
                        #expect(graph.compSolidCount == origCS + 1)
                    }
                }
            }
        }
    }
}
