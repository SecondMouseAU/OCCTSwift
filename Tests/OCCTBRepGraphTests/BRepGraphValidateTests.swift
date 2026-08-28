import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Validate")
struct BRepGraphValidateTests {
    @Test func boxIsValid() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.isValid)
                let result = graph.validate()
                #expect(result.isValid)
                #expect(result.errorCount == 0)
            }
        }
    }
}
