import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - Curve Split and Concatenate")
struct CurveSplitConcatTests {

    @Test func splitAtContinuity3D() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        if let curve = Curve3D.fit(points: points) {
            let segs = curve.splitAtContinuity()
            #expect(segs.count >= 1)
        }
    }

    @Test func concatenateCurvesG1() {
        let pts1 = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 5.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        let pts2 = [SIMD3(10.0, 0.0, 0.0), SIMD3(15.0, -5.0, 0.0), SIMD3(20.0, 0.0, 0.0)]
        if let c1 = Curve3D.fit(points: pts1),
            let c2 = Curve3D.fit(points: pts2)
        {
            let joined = Curve3D.concatenateG1(curves: [c1, c2])
            #expect(joined != nil)
        }
    }

    @Test func splitCurve2DAtContinuity() {
        let points = [SIMD2(0.0, 0.0), SIMD2(5.0, 5.0), SIMD2(10.0, 0.0)]
        if let curve = Curve2D.fit(through: points) {
            let segs = curve.splitAtContinuity()
            #expect(segs.count >= 1)
        }
    }
}
