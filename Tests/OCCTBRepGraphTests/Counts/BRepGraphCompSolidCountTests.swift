import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph CompSolid Count")
struct BRepGraphCompSolidCountTests {
    @Test func compSolidCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.compSolidCount == 0)
            }
        }
    }
}
