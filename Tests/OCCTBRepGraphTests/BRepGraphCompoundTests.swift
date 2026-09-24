import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Compound Queries")
struct BRepGraphCompoundTests {
    // `compoundCount >= 1` and `childCount >= 2` accepted a miscount (#1986). Pinned to the
    // kernel probe: one root compound, two solid children, no parent compounds.
    @Test func compoundQueriesOnCompound() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10))
        let compound = try #require(Shape.compound([box1, box2]))
        let graph = try #require(BRepGraph(shape: compound))
        #expect(graph.compoundCount == 1)
        #expect(graph.solidCount == 2)
        #expect(graph.compoundChildCount(0) == 2)
        // Root compound has no parents
        #expect(graph.compoundParentCount(0) == 0)
    }
}
