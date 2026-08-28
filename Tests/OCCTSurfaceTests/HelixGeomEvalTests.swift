import Foundation
import Testing

@testable import OCCTSwift

@Suite("HelixGeom Evaluate")
struct HelixGeomEvalTests {
    @Test func helixCurveEval() {
        let p = Helix.evaluate(parameterRange: 0...(4 * .pi), pitch: 5.0, radius: 10.0, at: 0.0)
        #expect(abs(p.x - 10.0) < 1.0)  // near radius at t=0
    }

    @Test func helixCurveD1() {
        let (point, tangent) = Helix.evaluateD1(
            parameterRange: 0...(4 * .pi), pitch: 5.0, radius: 10.0, at: 0.0)
        #expect(point.x > 0)
        let mag = sqrt(tangent.x * tangent.x + tangent.y * tangent.y + tangent.z * tangent.z)
        #expect(mag > 0)
    }

    @Test func helixCurveD2() {
        let (_, _, d2) = Helix.evaluateD2(
            parameterRange: 0...(4 * .pi), pitch: 5.0, radius: 10.0, at: .pi)
        let mag = sqrt(d2.x * d2.x + d2.y * d2.y + d2.z * d2.z)
        #expect(mag > 0)
    }

    @Test func helixApproxToBSpline() {
        let result = Helix.approximateToBSpline(
            parameterRange: 0...(4 * .pi), pitch: 5.0, radius: 10.0)
        #expect(result != nil)
        if let r = result { #expect(r.maxError < 0.01) }
    }
}
