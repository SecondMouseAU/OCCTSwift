import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe CurveShapeIntersector")
struct LocOpeCurveShapeIntersectorTests {
    @Test("Line intersects box")
    func lineIntersectsBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build the box")  // #766: was a silent return
            return
        }
        let params = box.curveShapeIntersect(
            origin: SIMD3(5, 5, -10),
            direction: SIMD3(0, 0, 1)
        )
        #expect(params != nil)
        if let params = params {
            #expect(params.count >= 2)
            // #766: `>= 2` held for any pair. The centred box spans z -5...5, so the line from
            // z = -10 enters at parameter 5 and leaves at 15 (LocOpe_CurveShapeIntersector agrees).
            #expect(params.sorted() == [5, 15], "\(params)")
        }
    }
}
