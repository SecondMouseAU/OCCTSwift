import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - BRepGraph Assembly & Refs (v0.134.0)

// A primitive's graph has no products (the bridge builds with CreateAutoProduct = false), so
// every `if graph.productCount > 0` block and every loop over the root indices never ran, and
// `productCount >= 0` held for any Int (#1986). Each test now links the solid into a product
// and checks what the kernel reports for it (Scripts/repro/766-brepgraph-products-refs).
@Suite("BRepGraph Products")
struct BRepGraphProductTests {
    @Test func productCountForPrimitive() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.productCount == 0)
        #expect(graph.occurrenceCount == 0)
        #expect(graph.rootProductCount == 0)
        let pid = graph.linkProductToTopology(shapeRootKind: 0 /* Solid */, shapeRootIndex: 0)
        #expect(pid == 0)
        #expect(graph.productCount == 1)
        // The linked product is a part, not an assembly
        #expect(graph.productIsPart(0))
        #expect(!graph.productIsAssembly(0))
        let root = try #require(graph.productShapeRoot(0))
        #expect(root.kind == .solid)
        #expect(root.index == 0)
        #expect(graph.rootProductCount == graph.productCount)
    }

    @Test func productQueriesOnSphere() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let graph = try #require(BRepGraph(shape: sphere))
        #expect(graph.productCount == 0)
        #expect(graph.occurrenceCount == 0)
        _ = graph.linkProductToTopology(shapeRootKind: 0 /* Solid */, shapeRootIndex: 0)
        #expect(graph.productCount == 1)
        #expect(graph.productIsPart(0))
        // The removed `== 0` assumed a part has no components; the kernel's
        // Products().NbComponents reports the part's own occurrence, 1.
        #expect(graph.productComponentCount(0) == 1)
    }

    // #418: rootProductIndices had zero test coverage anywhere; only its
    // sibling rootProductCount was exercised (productCountForPrimitive above).
    @Test func rootProductIndices() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.rootProductIndices.isEmpty)
        _ = graph.linkProductToTopology(shapeRootKind: 0 /* Solid */, shapeRootIndex: 0)
        let indices = graph.rootProductIndices
        #expect(indices == [0])
        #expect(indices.count == graph.rootProductCount)
    }
}
