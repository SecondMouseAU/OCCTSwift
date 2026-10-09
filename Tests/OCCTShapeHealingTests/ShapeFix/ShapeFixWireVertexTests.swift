import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix WireVertex Tests")
struct ShapeFixWireVertexTests {
    @Test("Fix wire vertices on box")
    func fixWireVertices() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let fixed = box.fixWireVertices(precision: 1e-4)
        #expect(fixed >= 0)
    }
}
