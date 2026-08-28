import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder ValidateMutation")
struct BRepGraphBuilderValidateMutationTests {
    @Test func validateCleanGraph() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                // A freshly built graph should have valid mutation boundary
                let valid = graph.validateMutation()
                #expect(valid)
            }
        }
    }

    @Test func validateAfterAddVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                _ = graph.addVertex(x: 0, y: 0, z: 0, tolerance: 0.01)
                graph.commitMutation()
                let valid = graph.validateMutation()
                #expect(valid)
            }
        }
    }
}
