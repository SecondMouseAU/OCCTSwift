import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeBuild_Vertex

// #766: these asserted only `shapeType == .vertex` inside `if let`. Kernel (probe
// Scripts/repro/766-healing-shapebuild): the box's vertices[0] and [1] are (-5,-5,5) and
// (-5,-5,-5); CombineVertex puts the result midway, with a tolerance of half the distance plus
// the inputs' own, times tolFactor.
@Suite("ShapeBuild Vertex")
struct ShapeBuildVertexTests {
    private func boxVertices() throws -> [Shape] {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let vertices = box.subShapes(ofType: .vertex)
        try #require(vertices.count >= 2)
        return vertices
    }

    @Test("Combine two vertices")
    func combineVertices() throws {
        let v = try boxVertices()
        let combined = try #require(v[0].combineVertex(with: v[1]))
        #expect(combined.shapeType == .vertex)
        #expect(simd_distance(combined.vertexPoint, SIMD3(-5, -5, 0)) < 1e-9)
        #expect(abs(combined.vertexTolerance - 5.0005001) < 1e-6)
    }

    @Test("Combine vertices from points")
    func combineFromPoints() throws {
        let combined = try #require(
            Shape.combineVertices(
                point1: SIMD3(0, 0, 0), tol1: 0.01,
                point2: SIMD3(0.01, 0, 0), tol2: 0.01))
        #expect(simd_distance(combined.vertexPoint, SIMD3(0.005, 0, 0)) < 1e-12)
        #expect(abs(combined.vertexTolerance - 0.0150015) < 1e-9)
    }

    @Test("Combine vertices with custom tolerance factor")
    func combineWithTolFactor() throws {
        let v = try boxVertices()
        let combined = try #require(v[0].combineVertex(with: v[1], tolFactor: 1.5))
        #expect(simd_distance(combined.vertexPoint, SIMD3(-5, -5, 0)) < 1e-9)
        #expect(abs(combined.vertexTolerance - 7.50000015) < 1e-6)
    }
}
