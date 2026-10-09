import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLib_MakeVertex Tests")
struct MakeVertexTests {

    @Test func createVertex() {
        let v = Shape.makeVertex(at: SIMD3(1, 2, 3))
        #expect(v != nil)
        if let v = v {
            #expect(v.isValid)
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
