import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Validate")
struct BRepGraphValidateTests {
    @Test func boxIsValid() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.isValid)
        let result = graph.validate()
        #expect(result.isValid)
        #expect(result.errorCount == 0)
    }
}
