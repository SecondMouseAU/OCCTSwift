import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder Deferred")
struct BRepGraphBuilderDeferredTests {
    @Test func deferredModeToggle() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                #expect(!graph.isDeferredMode)
                graph.beginDeferredInvalidation()
                #expect(graph.isDeferredMode)
                graph.endDeferredInvalidation()
                #expect(!graph.isDeferredMode)
            }
        }
    }

    @Test func deferredModeWithMutations() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                graph.beginDeferredInvalidation()
                _ = graph.addVertex(x: 1, y: 2, z: 3, tolerance: 0.001)
                _ = graph.addVertex(x: 4, y: 5, z: 6, tolerance: 0.001)
                graph.endDeferredInvalidation()
                graph.commitMutation()
                #expect(!graph.isDeferredMode)
            }
        }
    }
}
