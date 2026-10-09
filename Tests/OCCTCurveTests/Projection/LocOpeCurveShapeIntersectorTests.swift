import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe CurveShapeIntersector")
struct LocOpeCurveShapeIntersectorTests {
    @Test("Line intersects box")
    func lineIntersectsBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let params = box.curveShapeIntersect(
            origin: SIMD3(5, 5, -10),
            direction: SIMD3(0, 0, 1)
        )
        #expect(params != nil)
        if let params = params {
            #expect(params.count >= 2)
        }
    }
}
