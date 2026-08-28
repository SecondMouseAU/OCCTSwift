import Testing
import simd

@testable import OCCTSwift

@Suite("GeomEval AHTBezier 3D Curve")
struct AHTBezierCurve3DTests {

    @Test func createAndEval() {
        // algDeg=0, alpha=1.0, beta=1.0 => 5 poles needed
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(2, 1, 0),
            SIMD3(3, 0, 0), SIMD3(4, 0, 0),
        ]
        guard let curve = Curve3D.ahtBezier(poles: poles, algDegree: 0, alpha: 1.0, beta: 1.0)
        else {
            #expect(Bool(false), "Failed to create AHTBezier curve")
            return
        }
        let domain = curve.domain
        #expect(domain.lowerBound >= 0)
        #expect(domain.upperBound > 0)
        let pt = curve.point(at: 0.5)
        #expect(pt.x.isFinite)
    }

    @Test func rationalAHTBezier() {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(2, 1, 0),
            SIMD3(3, 0, 0), SIMD3(4, 0, 0),
        ]
        let weights = [1.0, 1.0, 2.0, 1.0, 1.0]
        let curve = Curve3D.ahtBezierRational(
            poles: poles, weights: weights,
            algDegree: 0, alpha: 1.0, beta: 1.0)
        #expect(curve != nil)
    }
}
