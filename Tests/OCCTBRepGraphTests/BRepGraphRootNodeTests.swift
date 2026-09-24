import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Root Nodes")
struct BRepGraphRootNodeTests {
    @Test func hasRoots() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // OCCT 8.0 reshaped root iteration to Products only, wrap the
        // box's solid root in a Product to expose it as a graph root.
        #expect(graph.rootNodes.isEmpty)
        _ = graph.linkProductToTopology(shapeRootKind: 0 /* Solid */, shapeRootIndex: 0)
        let roots = graph.rootNodes
        // `roots.count > 0` accepted duplicates (#1986): exactly the one product.
        #expect(roots.count == 1)
        #expect(roots.first?.kind == .product)
        #expect(roots.first?.index == 0)
    }
}
