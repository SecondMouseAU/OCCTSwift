import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AddCompound")
struct BRepGraphBuilderAddCompoundTests {
    // The add is required, not optional: an `if let` around it let a builder that always
    // failed pass (#1986). Index and count pinned to the kernel probe.
    @Test func addCompoundFromSolids() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let origCompoundCount = graph.compoundCount
        #expect(origCompoundCount == 0)
        #expect(graph.solidCount == 1)
        let children: [(kind: BRepGraph.NodeKind, index: Int)] = [
            (.solid, 0)
        ]
        let cidx = try #require(graph.addCompound(children: children))
        #expect(cidx == 0)
        #expect(graph.compoundCount == origCompoundCount + 1)
    }
}
