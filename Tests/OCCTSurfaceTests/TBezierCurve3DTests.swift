import Testing
import simd

@testable import OCCTSwift

@Suite("GeomEval TBezier 3D Curve")
struct TBezierCurve3DTests {

    @Test func createAndEval() {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0),
        ]
        guard let curve = Curve3D.tBezier(poles: poles, alpha: 1.0) else {
            #expect(Bool(false), "Failed to create TBezier curve")
            return
        }
        let domain = curve.domain
        #expect(domain.lowerBound >= 0)
        #expect(domain.upperBound > 0)
        // Evaluate at endpoints
        let start = curve.point(at: domain.lowerBound)
        let end = curve.point(at: domain.upperBound)
        // T-Bezier basis at t=0: {1, 0, 1} so start = P0 + P2
        #expect(start.x.isFinite)
        #expect(end.x.isFinite)
    }

    @Test func rationalTBezier() {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0),
        ]
        let weights = [1.0, 2.0, 1.0]
        let curve = Curve3D.tBezierRational(poles: poles, weights: weights, alpha: 1.0)
        #expect(curve != nil)
    }

    @Test func rejectsEvenPoleCount() {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0),
        ]
        let curve = Curve3D.tBezier(poles: poles, alpha: 1.0)
        #expect(curve == nil)
    }
}
