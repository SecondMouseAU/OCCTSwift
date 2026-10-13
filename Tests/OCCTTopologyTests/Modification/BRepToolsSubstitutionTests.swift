import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("BRepTools Substitution Tests")
struct BRepToolsSubstitutionTests {
    @Test("Substitution bridge function is callable")
    func substituteCallable() throws {
        // BRepTools_Substitution works with topological sub-shapes extracted from the same
        // parent shape. A standalone vertex does not share topology with the box, so it is
        // refused with nil.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let foreign = try #require(Shape.vertex(at: SIMD3(0, 0, 0)))
        let other = try #require(Shape.vertex(at: SIMD3(1, 0, 0)))
        #expect(box.substituted(replacing: foreign, with: other) == nil)

        // Control: a real corner of the box is accepted. The result keeps 8 vertices and 12
        // edges, with the replaced corner (-5,-5,-5) moved to the new vertex (-5,-5,6), and
        // the receiver is untouched (still the valid, original box).
        let corners = box.subShapes(ofType: .vertex)
        let corner = try #require(
            corners.first { vectorDistance($0.vertexPoint, SIMD3(-5, -5, -5)) < 1e-9 })
        let moved = try #require(Shape.vertex(at: SIMD3(-5, -5, 6)))
        let result = try #require(box.substituted(replacing: corner, with: moved))
        let points = result.subShapes(ofType: .vertex).map(\.vertexPoint)
        #expect(points.count == 8)
        #expect(points.contains { vectorDistance($0, SIMD3(-5, -5, 6)) < 1e-9 })
        #expect(!points.contains { vectorDistance($0, SIMD3(-5, -5, -5)) < 1e-9 })
        #expect(result.edgeCount == 12)
        #expect(box.isValid)
        #expect(
            box.subShapes(ofType: .vertex).contains {
                vectorDistance($0.vertexPoint, SIMD3(-5, -5, -5)) < 1e-9
            })
    }
}
