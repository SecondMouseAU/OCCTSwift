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

    // #1542: isLinear() is documented to return nil for a curve that isn't a BSpline. The bridge
    // used to return `false` for both "not a BSpline" and "genuinely non-linear", so the doc's
    // nil-path could never actually happen -- a non-BSpline curve silently read back as
    // `(isLinear: false, deviation: 0.0)`, indistinguishable from a measured, non-linear BSpline.
    @Test("Non-BSpline curve returns nil, not a false result")
    func nonBSplineCurveReturnsNil() {
        let circle = Curve2D.circle(center: SIMD2(0, 0), radius: 5)
        #expect(circle != nil)
        if let circle {
            #expect(circle.isLinear(tolerance: 1e-6) == nil)
        }

        let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))
        #expect(segment != nil)
        if let segment {
            #expect(segment.isLinear(tolerance: 1e-6) == nil)
        }
    }
}
