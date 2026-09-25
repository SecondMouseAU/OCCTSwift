import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder ValidateMutation")
struct BRepGraphBuilderValidateMutationTests {
    @Test func validateCleanGraph() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // A freshly built graph should have valid mutation boundary
        let valid = graph.validateMutation()
        #expect(valid)
    }

    @Test func validateAfterAddVertex() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let v = graph.addVertex(x: 0, y: 0, z: 0, tolerance: 0.01)
        #expect(v == 8)
        graph.commitMutation()
        let valid = graph.validateMutation()
        #expect(valid)
    }
}
