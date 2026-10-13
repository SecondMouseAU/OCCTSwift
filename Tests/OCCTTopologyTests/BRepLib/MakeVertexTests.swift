import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("BRepLib_MakeVertex Tests")
struct MakeVertexTests {

    @Test func createVertex() throws {
        let v = try #require(Shape.makeVertex(at: SIMD3(1, 2, 3)))
        #expect(v.isValid)
        #expect(v.shapeType == .vertex)
        let points = v.vertices()
        #expect(points.count == 1)
        if points.count == 1 {
            #expect(vectorLength(points[0] - SIMD3(1, 2, 3)) < 1e-12)
        }
    }

    @Test func vertexAtOrigin() {
        let v = Shape.makeVertex(at: .zero)
        #expect(v != nil)
        if let v = v {
            let verts = v.vertices()
            #expect(verts.count == 1)
        }
    }
}
