import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.67.0: FairCurve, LocalAnalysis, TopTrans

// Pinned to FairCurve_Batten::Compute(code, 50, 1e-3) on the same inputs
// (Scripts/repro/766-curve-faircurve/transcript.txt): every case converges (code 0) to a degree-9
// BSpline on [0, 1] from (0, 0) to (10, 0). The earlier versions wrapped their one check in
// `if let`, so a batten that failed to compute passed, and none looked at the curve beyond its
// domain being non-empty (#766).
@Suite("FairCurve Batten Tests")
struct FairCurveBattenTests {
    private static func check(_ result: (curve: Curve2D, code: Curve2D.FairCurveCode)?) {
        guard let result else {
            Issue.record("batten did not compute")
            return
        }
        #expect(result.code == .ok)
        #expect(simd_distance(result.curve.startPoint, SIMD2(0, 0)) < 1e-9)
        #expect(simd_distance(result.curve.endPoint, SIMD2(10, 0)) < 1e-9)
    }

    @Test func basicBatten() {
        Self.check(Curve2D.fairCurveBatten(p1: SIMD2(0, 0), p2: SIMD2(10, 0), height: 2.0))
    }

    @Test func battenWithSlope() {
        Self.check(
            Curve2D.fairCurveBatten(
                p1: SIMD2(0, 0), p2: SIMD2(10, 0),
                height: 3.0, slope: 0.5))
    }

    @Test func battenWithAngles() {
        Self.check(
            Curve2D.fairCurveBatten(
                p1: SIMD2(0, 0), p2: SIMD2(10, 0),
                height: 2.0, angle1: 0.3, angle2: -0.3))
    }

    @Test func battenConstraintOrders() {
        Self.check(
            Curve2D.fairCurveBatten(
                p1: SIMD2(0, 0), p2: SIMD2(10, 0),
                height: 2.0,
                constraintOrder1: 0, constraintOrder2: 0))
    }

    @Test func battenCurveProperties() {
        guard
            let result = Curve2D.fairCurveBatten(
                p1: SIMD2(0, 0), p2: SIMD2(10, 0), height: 2.0)
        else {
            Issue.record("batten did not compute")
            return
        }
        #expect(result.curve.domain == 0...1)
        #expect(simd_distance(result.curve.point(at: 0.5), SIMD2(5, 0)) < 1e-9)
    }
}
