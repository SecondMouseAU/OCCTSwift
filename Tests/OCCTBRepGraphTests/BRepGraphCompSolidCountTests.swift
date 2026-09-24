import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph CompSolid Count")
struct BRepGraphCompSolidCountTests {
    // `== 0` alone passes a counter that always answers 0 (#1986), so the count is also read
    // after a comp-solid is added.
    @Test func compSolidCount() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.compSolidCount == 0)
        _ = try #require(graph.addCompSolid(solidIndices: [0]))
        #expect(graph.compSolidCount == 1)
    }
}
