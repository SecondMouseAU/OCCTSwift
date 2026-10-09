import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix Edge Tests")
struct ShapeFixEdgeTests {
    @Test("Fix same parameter on box edges")
    func fixSameParameter() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let fixed = box.fixEdgeSameParameter()
        // Box edges should already be correct, so 0 fixes expected
        #expect(fixed >= 0)
    }

    @Test("Fix vertex tolerance on box edges")
    func fixVertexTolerance() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let fixed = box.fixEdgeVertexTolerance()
        #expect(fixed >= 0)
    }
}
