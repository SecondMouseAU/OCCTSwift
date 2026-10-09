import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Solid Queries")
struct BRepGraphSolidQueryTests {
    @Test func solidCompSolidCount() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let count = graph.solidCompSolidCount(0)
        #expect(count == 0)  // standalone solid, not in comp-solid
    }
}
