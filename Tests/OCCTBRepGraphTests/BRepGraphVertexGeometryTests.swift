import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Vertex Geometry")
struct BRepGraphVertexGeometryTests {
    @Test func vertexPoint() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let pt = graph.vertexPoint(0)
                // Vertex should be a finite point
                #expect(pt.x.isFinite)
                #expect(pt.y.isFinite)
                #expect(pt.z.isFinite)
            }
        }
    }

    @Test func vertexTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let tol = graph.vertexTolerance(0)
                #expect(tol > 0)
                #expect(tol < 1.0)  // should be a small value
            }
        }
    }
}
