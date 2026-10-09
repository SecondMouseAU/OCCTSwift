import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix SplitCommonVertex Tests")
struct ShapeFixSplitCommonVertexTests {
    @Test("Split common vertices on box")
    func splitVertices() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.splitCommonVertices()
        #expect(result != nil, "Should return a result")
        if let r = result {
            #expect(r.isValid)
        }
    }
}
