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
        // #766: pinned to GeomEval_AHTBezierCurve's own FirstParameter/LastParameter and D0, see
        // Scripts/repro/766-aht-bezier/. `domain > 0` and a finite x passed a curve built from the
        // wrong poles. The AHT basis at alpha = beta = 1 is not a partition of unity, so the
        // point lies outside the poles' convex hull; that is the kernel's value, not a slip.
        let domain = curve.domain
        #expect(domain.lowerBound == 0)
        #expect(domain.upperBound == 1)
        let pt = curve.point(at: 0.5)
        #expect(simd_length(pt - SIMD3(7.7249540992806089, 1.1276259652063807, 0)) < 1e-9)
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
        // #766: the weight of 2 on the middle pole must reach the kernel. Unweighted, the same
        // poles give (7.7249540992806089, 1.1276259652063807, 0) at u = 0.5 (see createAndEval),
        // which `curve != nil` alone could not tell apart. Kernel value from
        // Scripts/repro/766-aht-bezier/.
        if let c = curve {
            #expect(simd_length(c.point(at: 0.5) - SIMD3(1.9441876464157528, 0.43933290852097595, 0)) < 1e-9)
        }
    }
}
