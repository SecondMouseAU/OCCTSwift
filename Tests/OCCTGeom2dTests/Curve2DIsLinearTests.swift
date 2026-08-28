import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D IsLinear Tests")
struct Curve2DIsLinearTests {
    @Test("Linear BSpline is detected as linear")
    func linearBSpline() {
        // Interpolate through collinear points → near-linear BSpline
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 10)]
        if let curve = Curve2D.interpolate(through: pts) {
            if let result = curve.isLinear(tolerance: 0.1) {
                #expect(result.isLinear)
            }
        }
    }

    @Test("Non-linear curve is detected as non-linear")
    func nonLinearCurve() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]
        if let curve = Curve2D.interpolate(through: pts) {
            if let result = curve.isLinear(tolerance: 1e-6) {
                #expect(!result.isLinear)
            }
        }
    }
}
