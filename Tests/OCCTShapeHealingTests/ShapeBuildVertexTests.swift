import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeBuild_Vertex

@Suite("ShapeBuild Vertex")
struct ShapeBuildVertexTests {
    @Test("Combine two vertices")
    func combineVertices() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let vertices = box.subShapes(ofType: .vertex)
        guard vertices.count >= 2 else { return }
        if let combined = vertices[0].combineVertex(with: vertices[1]) {
            #expect(combined.shapeType == .vertex)
        }
    }

    @Test("Combine vertices from points")
    func combineFromPoints() {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(0.01, 0, 0)
        if let combined = Shape.combineVertices(
            point1: p1, tol1: 0.01,
            point2: p2, tol2: 0.01)
        {
            #expect(combined.shapeType == .vertex)
        }
    }

    @Test("Combine vertices with custom tolerance factor")
    func combineWithTolFactor() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let vertices = box.subShapes(ofType: .vertex)
        guard vertices.count >= 2 else { return }
        if let combined = vertices[0].combineVertex(with: vertices[1], tolFactor: 1.5) {
            #expect(combined.shapeType == .vertex)
        }
    }
}
