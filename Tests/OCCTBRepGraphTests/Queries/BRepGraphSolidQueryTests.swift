import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Solid Queries")
struct BRepGraphSolidQueryTests {
    @Test func solidCompSolidCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let count = graph.solidCompSolidCount(0)
                #expect(count == 0)  // standalone solid, not in comp-solid
            }
        }
    }
}
