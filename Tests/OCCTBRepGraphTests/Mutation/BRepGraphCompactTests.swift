import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Compact")
struct BRepGraphCompactTests {
    @Test func compactBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let result = graph.compact()
                #expect(result.nodesAfter > 0)
            }
        }
    }
}
