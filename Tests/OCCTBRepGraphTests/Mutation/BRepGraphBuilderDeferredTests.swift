import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder Deferred")
struct BRepGraphBuilderDeferredTests {
    @Test func deferredModeToggle() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(!graph.isDeferredMode)
        graph.beginDeferredInvalidation()
        #expect(graph.isDeferredMode)
        graph.endDeferredInvalidation()
        #expect(!graph.isDeferredMode)
    }

    // Asserted only the final `!isDeferredMode`, which a begin that never entered deferred
    // mode also satisfies (#1986). Now also checks the mode was entered and that the adds
    // made inside it landed (kernel probe: indices 8 and 9, 10 vertices).
    @Test func deferredModeWithMutations() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        graph.beginDeferredInvalidation()
        #expect(graph.isDeferredMode)
        let a = graph.addVertex(x: 1, y: 2, z: 3, tolerance: 0.001)
        let b = graph.addVertex(x: 4, y: 5, z: 6, tolerance: 0.001)
        graph.endDeferredInvalidation()
        graph.commitMutation()
        #expect(!graph.isDeferredMode)
        #expect(a == 8)
        #expect(b == 9)
        #expect(graph.vertexCount == 10)
        let p = graph.vertexPoint(9)
        #expect(p.x == 4 && p.y == 5 && p.z == 6)
    }
}
