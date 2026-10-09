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
        // #766: pinned to GeomEval_TBezierCurve's own domain and D0 (Scripts/repro/766-tbezier-toptrans-typename/);
        // `isFinite` and `> 0` passed a curve built from the wrong poles.
        let domain = curve.domain
        #expect(domain.lowerBound == 0)
        #expect(abs(domain.upperBound - .pi) < 1e-15)
        // Evaluate at endpoints
        let start = curve.point(at: domain.lowerBound)
        let end = curve.point(at: domain.upperBound)
        // T-Bezier basis at t=0: {1, 0, 1} so start = P0 + P2
        #expect(simd_length(start - SIMD3(2, 0, 0)) < 1e-12)
        #expect(simd_length(end - SIMD3(-2, 0, 0)) < 1e-12)
        #expect(simd_length(curve.point(at: .pi / 2) - SIMD3(1, 1, 0)) < 1e-12)
    }

    @Test func rationalTBezier() {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0),
        ]
        let weights = [1.0, 2.0, 1.0]
        let curve = Curve3D.tBezierRational(poles: poles, weights: weights, alpha: 1.0)
        #expect(curve != nil)
        // #766: the weight must reach the kernel: (2/3, 2/3, 0) at pi/2, against (1, 1, 0) unweighted.
        if let curve {
            #expect(simd_length(curve.point(at: .pi / 2) - SIMD3(2.0 / 3, 2.0 / 3, 0)) < 1e-12)
        }
    }

    @Test func rejectsEvenPoleCount() {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0),
        ]
        let curve = Curve3D.tBezier(poles: poles, alpha: 1.0)
        #expect(curve == nil)
    }
}
