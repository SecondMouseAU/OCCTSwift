import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.95.0 Tests

// The earlier versions checked only `!= nil` (#766). Each now checks that the converted BSpline
// starts and ends where Convert_*ToBSplineCurve puts it and that its samples satisfy the conic's
// own equation (Scripts/repro/766-curve-comp-conic-deflection/transcript.txt).
@Suite("Convert Conic Curves Tests")
struct ConvertConicCurvesTests {
    private static func samples(_ c: Curve2D) -> [SIMD2<Double>] {
        let d = c.domain
        return (0...8).map { c.point(at: d.lowerBound + (d.upperBound - d.lowerBound) * Double($0) / 8) }
    }

    @Test func ellipseArc() {
        guard
            let curve = Curve2D.fromEllipseArc(
                centerX: 0, centerY: 0, majorRadius: 20, minorRadius: 10, u1: 0, u2: .pi)
        else {
            Issue.record("ellipse arc not converted")
            return
        }
        #expect(simd_distance(curve.startPoint, SIMD2(20, 0)) < 1e-12)
        #expect(simd_distance(curve.endPoint, SIMD2(-20, 0)) < 1e-12)
        for p in Self.samples(curve) {
            #expect(abs(p.x * p.x / 400 + p.y * p.y / 100 - 1) < 1e-9)
        }
    }

    @Test func hyperbolaArc() {
        guard
            let curve = Curve2D.fromHyperbolaArc(
                centerX: 0, centerY: 0, majorRadius: 10, minorRadius: 5, u1: -1, u2: 1)
        else {
            Issue.record("hyperbola arc not converted")
            return
        }
        // (10 cosh u, 5 sinh u) for u in [-1, 1].
        #expect(simd_distance(curve.startPoint, SIMD2(10 * cosh(-1.0), 5 * sinh(-1.0))) < 1e-9)
        #expect(simd_distance(curve.endPoint, SIMD2(10 * cosh(1.0), 5 * sinh(1.0))) < 1e-9)
        for p in Self.samples(curve) {
            #expect(abs(p.x * p.x / 100 - p.y * p.y / 25 - 1) < 1e-9)
        }
    }

    @Test func parabolaArc() {
        guard let curve = Curve2D.fromParabolaArc(centerX: 0, centerY: 0, focal: 5, u1: -2, u2: 2)
        else {
            Issue.record("parabola arc not converted")
            return
        }
        // gp_Parab2d with focal length 5: y^2 = 20 x, parameter u = y.
        #expect(simd_distance(curve.startPoint, SIMD2(0.2, -2)) < 1e-12)
        #expect(simd_distance(curve.endPoint, SIMD2(0.2, 2)) < 1e-12)
        for p in Self.samples(curve) {
            #expect(abs(p.y * p.y - 20 * p.x) < 1e-9)
        }
    }
}
