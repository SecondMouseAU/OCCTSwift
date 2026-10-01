import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AddCompSolid")
struct BRepGraphBuilderAddCompSolidTests {
    // The add is required, not optional: an `if let` around it let a builder that always
    // failed pass (#1986). Index and count pinned to the kernel probe.
    @Test func addCompSolidFromSolids() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let origCS = graph.compSolidCount
        #expect(origCS == 0)
        #expect(graph.solidCount == 1)
        let csIdx = try #require(graph.addCompSolid(solidIndices: [0]))
        #expect(csIdx == 0)
        #expect(graph.compSolidCount == origCS + 1)
    }
}
