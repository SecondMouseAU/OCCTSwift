import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Solid Extended")
struct BRepGraphSolidExtendedTests {
    @Test func solidCompoundCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.solidCount {
                    #expect(graph.solidCompoundCount(i) == 0)
                }
            }
        }
    }
}
