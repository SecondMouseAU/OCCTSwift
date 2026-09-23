import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to Geom_BezierCurve, GeomAPI_Interpolate and GeomAPI_PointsToBSpline on the same inputs
// (Scripts/repro/766-curve-arc-bezier-bspline/transcript.txt). The earlier versions checked
// `!= nil`, or end points to 0.01 or 0.5, so an interpolant that missed its interior points, or
// ignored its tangents, passed (#766). polesRoundtrip also force-unwrapped its fixtures.
@Suite("Curve3D BSpline Tests")
struct Curve3DBSplineTests {
    @Test("Create quadratic Bezier")
    func quadraticBezier() {
        guard let bez = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(5, 10, 0), SIMD3(10, 0, 0)])
        else {
            Issue.record("Bezier not built")
            return
        }
        #expect(bez.degree == 2)
        #expect(bez.poleCount == 3)
    }

    @Test("Poles roundtrip")
    func polesRoundtrip() {
        let original: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(5, 10, 5), SIMD3(10, 0, 0)]
        guard let bez = Curve3D.bezier(poles: original) else {
            Issue.record("Bezier not built")
            return
        }
        #expect(bez.poles == original)
    }

    @Test("Interpolate through points")
    func interpolate() {
        let pts: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(3, 5, 1), SIMD3(7, 2, 3), SIMD3(10, 0, 0),
        ]
        guard let c = Curve3D.interpolate(points: pts) else {
            Issue.record("interpolation failed")
            return
        }
        // Chord-length parameters: knots 0, 5.916..., 11.301..., 15.991...; the curve passes
        // through every input point at its knot.
        let knots = [0, 5.9160797830996161, 11.30124459023412, 15.99166035005755]
        for (k, p) in zip(knots, pts) {
            #expect(simd_distance(c.point(at: k), p) < 1e-9)
        }
    }

    @Test("Interpolate with tangents")
    func interpolateWithTangents() {
        let pts: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(5, 5, 5), SIMD3(10, 0, 0)]
        guard
            let curve = Curve3D.interpolate(
                points: pts,
                startTangent: SIMD3(1, 1, 1),
                endTangent: SIMD3(1, -1, -1))
        else {
            Issue.record("interpolation with tangents failed")
            return
        }
        #expect(simd_distance(curve.startPoint, pts[0]) < 1e-9)
        #expect(simd_distance(curve.endPoint, pts[2]) < 1e-9)
        // GeomAPI_Interpolate scales the tangents but keeps their directions.
        let d = curve.domain
        let t0 = simd_normalize(curve.evalD1(at: d.lowerBound).d1)
        let t1 = simd_normalize(curve.evalD1(at: d.upperBound).d1)
        #expect(simd_distance(t0, simd_normalize(SIMD3(1, 1, 1))) < 1e-9)
        #expect(simd_distance(t1, simd_normalize(SIMD3(1, -1, -1))) < 1e-9)
    }

    @Test("Fit points to BSpline")
    func fitPoints() {
        let pts: [SIMD3<Double>] = (0..<20).map { i in
            let t = Double(i) / 19.0 * .pi * 2
            return SIMD3(cos(t) * 5, sin(t) * 5, Double(i) * 0.5)
        }
        guard let c = Curve3D.fit(points: pts) else {
            Issue.record("fit failed")
            return
        }
        // GeomAPI_PointsToBSpline(3, 8, C2, 1e-3): degree 6, 11 poles, ends on the end points.
        #expect(c.degree == 6)
        #expect(c.poleCount == 11)
        #expect(simd_distance(c.startPoint, pts[0]) < 1e-9)
        #expect(simd_distance(c.endPoint, pts[19]) < 1e-9)
    }

    @Test("Create BSpline with explicit knots")
    func createBSpline() {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(3, 5, 1), SIMD3(7, 3, 2), SIMD3(10, 0, 0),
        ]
        let knots: [Double] = [0, 1]
        let mults: [Int32] = [4, 4]
        guard let b = Curve3D.bspline(poles: poles, knots: knots, multiplicities: mults, degree: 3)
        else {
            Issue.record("BSpline not built")
            return
        }
        #expect(b.degree == 3)
        #expect(b.poleCount == 4)
        #expect(b.poles == poles)
    }
}
