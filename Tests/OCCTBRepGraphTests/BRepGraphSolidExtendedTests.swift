import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Solid Extended")
struct BRepGraphSolidExtendedTests {
    @Test func solidCompoundCount() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.solidCount == 1)
        for i in 0..<graph.solidCount {
            #expect(graph.solidCompoundCount(i) == 0)
        }
    }
}
