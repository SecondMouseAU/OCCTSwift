import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Occurrences")
struct BRepGraphOccurrenceTests {
    // `== 0` alone passes a counter stuck at 0 (#1986). Linking the solid into a product
    // creates its one occurrence (Scripts/repro/766-brepgraph-products-refs).
    @Test func occurrenceCountForPrimitive() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.occurrenceCount == 0)
        _ = graph.linkProductToTopology(shapeRootKind: 0 /* Solid */, shapeRootIndex: 0)
        #expect(graph.occurrenceCount == 1)
    }
}
