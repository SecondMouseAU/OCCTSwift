import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Bisector_BisecAna") struct BisectorBisecAnaTests {
    @Test("Bisector between two lines")
    func curveCurveBisector() {
        let l1 = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))
        let l2 = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(0, 1))
        if let l1, let l2 {
            let bisector = l1.bisector(
                with: l2,
                referencePoint: SIMD2(1, 1),
                direction1: SIMD2(1, 0), direction2: SIMD2(0, 1))
            #expect(bisector != nil)
        }
    }

    @Test("Bisector between two points")
    func pointPointBisector() {
        let bisector = Curve2D.bisectorBetweenPoints(
            SIMD2(0, 0), SIMD2(10, 0),
            referencePoint: SIMD2(5, 0),
            direction1: SIMD2(1, 0), direction2: SIMD2(-1, 0))
        #expect(bisector != nil)
    }
}
