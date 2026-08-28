import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeneralTransform2D")
struct GeneralTransform2DTests {
    @Test func affinity() {
        let gt = GeneralTransform2D.affinity(
            axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        #expect(gt.matrix.count == 4)
    }

    @Test func multiply() {
        let a = GeneralTransform2D.affinity(
            axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        let b = GeneralTransform2D.affinity(
            axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 0.5)
        let _ = a.multiplied(by: b)
    }

    @Test func invert() {
        let gt = GeneralTransform2D.affinity(
            axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        #expect(gt.inverted() != nil)
    }

    @Test func transformPoint() {
        let gt = GeneralTransform2D.affinity(
            axisOrigin: .zero, axisDirection: SIMD2(1, 0), ratio: 2.0)
        let p = gt.transformPoint(SIMD2(1.0, 1.0))
        #expect(abs(p.x - 1.0) < 1e-10)  // x unchanged
    }
}
