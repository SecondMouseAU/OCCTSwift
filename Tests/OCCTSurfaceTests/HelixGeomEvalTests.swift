import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("HelixGeom Evaluate")
struct HelixGeomEvalTests {
    @Test func helixCurveEval() {
        let p = Helix.evaluate(parameterRange: 0...(4 * .pi), pitch: 5.0, radius: 10.0, at: 0.0)
        // #766: `within 1.0 of 10` passed a radius of 10.5. HelixGeom_HelixCurve gives exactly
        // (10, 0, 0), see Scripts/repro/766-offset-plate-helix/.
        #expect(simd_length(p - SIMD3(10, 0, 0)) < 1e-9)
    }

    @Test func helixCurveD1() {
        let (point, tangent) = Helix.evaluateD1(
            parameterRange: 0...(4 * .pi), pitch: 5.0, radius: 10.0, at: 0.0)
        #expect(point.x > 0)
        let mag = sqrt(tangent.x * tangent.x + tangent.y * tangent.y + tangent.z * tangent.z)
        #expect(mag > 0)
        // #766: `x > 0` and `|d1| > 0` passed a wrong radius. The kernel's D1 at 0 is point
        // (10, 0, 0), d1 (0, -10, 0.795774715459), see Scripts/repro/766-offset-plate-helix/.
        #expect(simd_length(point - SIMD3(10, 0, 0)) < 1e-9)
        #expect(simd_length(tangent - SIMD3(0, -10, 0.795774715459)) < 1e-9)
    }

    @Test func helixCurveD2() {
        let (point, d1, d2) = Helix.evaluateD2(
            parameterRange: 0...(4 * .pi), pitch: 5.0, radius: 10.0, at: .pi)
        let mag = sqrt(d2.x * d2.x + d2.y * d2.y + d2.z * d2.z)
        #expect(mag > 0)
        // #766: `|d2| > 0` passed any curvature. The kernel's D2 at pi is point (-10, 0, 2.5),
        // d1 (0, 10, 0.796), d2 (10, 0, 0), see Scripts/repro/766-offset-plate-helix/.
        #expect(simd_length(point - SIMD3(-10, 0, 2.5)) < 1e-9)
        #expect(simd_length(d1 - SIMD3(0, 10, 0.795774715459)) < 1e-9)
        #expect(simd_length(d2 - SIMD3(10, 0, 0)) < 1e-9)
    }

    @Test func helixApproxToBSpline() {
        let result = Helix.approximateToBSpline(
            parameterRange: 0...(4 * .pi), pitch: 5.0, radius: 10.0)
        #expect(result != nil)
        // #766: `< 0.01` passed an approximation built at 5x the tolerance.
        // HelixGeom_Tools::ApprHelix at 1e-3 reports 0.000676011, see Scripts/repro/766-offset-plate-helix/.
        if let r = result {
            #expect(r.maxError < 0.01)
            #expect(abs(r.maxError - 0.000676011) < 1e-8)
        }
    }
}
