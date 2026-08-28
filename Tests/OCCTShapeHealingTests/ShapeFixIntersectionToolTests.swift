import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix IntersectionTool Tests")
struct ShapeFixIntersectionToolTests {

    @Test func fixIntersectingWires() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let fixed = box.fixIntersectingWires(faceIndex: 0)
        #expect(!fixed)
    }
}
