import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Convert Circle Tests")
struct ConvertCircleTests {
    // The earlier version checked only `!= nil` (#766). Convert_CircleToBSplineCurve gives a
    // degree-2 rational BSpline over [0, pi] whose points all lie on the radius-10 circle, from
    // (10, 0) to (-10, 0) (Scripts/repro/766-curve-comp-conic-deflection/transcript.txt).
    @Test func circleArcToBSpline() {
        guard let curve = Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 10, u1: 0, u2: .pi)
        else {
            Issue.record("circle arc not converted")
            return
        }
        #expect(simd_distance(curve.startPoint, SIMD2(10, 0)) < 1e-12)
        #expect(simd_distance(curve.endPoint, SIMD2(-10, 0)) < 1e-12)
        let d = curve.domain
        for i in 0...8 {
            let p = curve.point(at: d.lowerBound + (d.upperBound - d.lowerBound) * Double(i) / 8)
            #expect(abs(simd_length(p) - 10) < 1e-9)
        }
    }
}
