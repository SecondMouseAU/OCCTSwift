import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Vertex Geometry")
struct BRepGraphVertexGeometryTests {
    @Test func vertexPoint() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let graph = try #require(BRepGraph(shape: box))
        let pt = graph.vertexPoint(0)
        // Kernel: BRepGraph_Tool::Vertex::Pnt(0) is the (-w/2, -h/2, -d/2) corner. Finiteness
        // alone passed a point with its coordinates swapped.
        #expect(abs(pt.x - -5) < 1e-9)
        #expect(abs(pt.y - -10) < 1e-9)
        #expect(abs(pt.z - -15) < 1e-9)
    }

    @Test func vertexTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let tol = graph.vertexTolerance(0)
        // Kernel: BRepGraph_Tool::Vertex::Tolerance(0) is 1e-7 (Precision::Confusion()).
        // "Between 0 and 1" passed a tolerance ten million times too large.
        #expect(abs(tol - 1e-7) < 1e-12)
    }
}
