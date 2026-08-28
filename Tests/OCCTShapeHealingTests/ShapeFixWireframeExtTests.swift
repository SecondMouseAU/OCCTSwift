import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix_Wireframe Extension Tests")
struct ShapeFixWireframeExtTests {

    @Test func fixWireGapsReturnsShape() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else {
            return
        }
        if let fixed = box.fixWireGaps(tolerance: 1e-7) {
            #expect(fixed.isValid)
        }
    }

    @Test func fixSmallEdgesDropMode() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else {
            return
        }
        if let fixed = box.fixSmallEdges(tolerance: 1e-7, dropSmall: true, limitAngle: -1) {
            #expect(fixed.isValid)
        }
    }

    @Test func fixSmallEdgesMergeMode() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else {
            return
        }
        if let fixed = box.fixSmallEdges(tolerance: 1e-7, dropSmall: false, limitAngle: 0.01) {
            #expect(fixed.isValid)
        }
    }
}
