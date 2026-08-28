import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepClass FClassifier Tests")
struct BRepClassFClassifierTests {

    @Test func classifyPoint2DInside() {
        // Box face UV bounds depend on which face, use a broad test
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else {
            return
        }
        // Point far outside UV bounds should definitely be OUT
        let stateOut = box.classifyPoint2D(faceIndex: 0, u: 1000, v: 1000)
        #expect(stateOut == .outside)
    }

    @Test func classifyPoint2DOutside() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else {
            return
        }
        let state = box.classifyPoint2D(faceIndex: 0, u: 100, v: 100)
        #expect(state == .outside)
    }
}
