import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D BSpline Tests")
struct Curve2DBSplineTests {

    @Test("Create quadratic Bezier")
    func quadraticBezier() {
        let bez = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)])
        #expect(bez != nil)
        if let bez = bez {
            #expect(bez.degree == 2)
            #expect(bez.poleCount == 3)
        }
    }

    @Test("Create cubic BSpline")
    func cubicBSpline() throws {
        let bsp = Curve2D.bspline(
            poles: [SIMD2(0, 0), SIMD2(2, 5), SIMD2(5, 5), SIMD2(8, 2), SIMD2(10, 0)],
            knots: [0, 1, 2, 3],
            multiplicities: [3, 1, 1, 3],
            degree: 2
        )
        // #1979: `!= nil` passed a curve built from the wrong knots or poles. Geom2d_BSplineCurve
        // gives the domain [0, 3] and (5, 4.625) at u = 1.5
        // (Scripts/repro/766-geom2d-bspline-local-and-factories/).
        let c = try #require(bsp)
        #expect(abs(c.domain.upperBound - 3) < 1e-12)
        #expect(simd_distance(c.point(at: 1.5), SIMD2(5, 4.625)) < 1e-9)
    }

    @Test("Interpolate through points")
    func interpolate() {
        let curve = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(6, 1), SIMD2(10, 5),
        ])
        #expect(curve != nil)
        if let curve = curve {
            // Should pass through the first point
            let start = curve.startPoint
            #expect(abs(start.x - 0) < 1e-6)
            #expect(abs(start.y - 0) < 1e-6)
            // #1979: the start point alone passed a curve that missed every other point. It also
            // passes through (3, 4) at its second knot, u = 5, and ends at (10, 5).
            #expect(simd_distance(curve.point(at: 5), SIMD2(3, 4)) < 1e-9)
            #expect(simd_distance(curve.endPoint, SIMD2(10, 5)) < 1e-9)
        }
    }

    @Test("Interpolate with end tangents")
    func interpolateWithTangents() throws {
        let curve = Curve2D.interpolate(
            through: [
                SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0),
            ], startTangent: SIMD2(1, 1), endTangent: SIMD2(1, -1))
        // #1979: `!= nil` passed a curve that ignored the tangents. Geom2dAPI_Interpolate::Load
        // scales them to (1.0607, 1.0607) and (1.0607, -1.0607) at the ends.
        let c = try #require(curve)
        let d = c.domain
        #expect(simd_distance(c.d1(at: d.lowerBound).tangent, SIMD2(1.06066017178, 1.06066017178)) < 1e-9)
        #expect(simd_distance(c.d1(at: d.upperBound).tangent, SIMD2(1.06066017178, -1.06066017178)) < 1e-9)
    }

    @Test("Fit points with tolerance")
    func fitPoints() throws {
        let pts: [SIMD2<Double>] = (0..<20).map { i in
            let t = Double(i) / 19.0 * 10.0
            return SIMD2(t, sin(t))
        }
        let curve = Curve2D.fit(through: pts)
        // #1979: `!= nil` passed any fit. Geom2dAPI_PointsToBSpline gives a cubic with 22 poles
        // ending at (10, sin 10).
        let c = try #require(curve)
        #expect(c.degree == 3)
        #expect(c.poleCount == 22)
        #expect(simd_distance(c.endPoint, SIMD2(10, sin(10.0))) < 1e-9)
    }

    @Test("Pole count query")
    func poleCountQuery() {
        let bez = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 5), SIMD2(15, 0)])!
        #expect(bez.poleCount == 4)
        #expect(bez.degree == 3)
    }

    @Test("Poles roundtrip")
    func polesRoundtrip() {
        let original: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]
        let bez = Curve2D.bezier(poles: original)!
        let retrieved = bez.poles!
        #expect(retrieved.count == 3)
        for i in 0..<3 {
            #expect(abs(retrieved[i].x - original[i].x) < 1e-10)
            #expect(abs(retrieved[i].y - original[i].y) < 1e-10)
        }
    }

    @Test("Draw interpolated curve")
    func drawInterpolated() throws {
        let curve = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0),
        ])!
        let points = curve.drawAdaptive()
        // #1979: `count >= 3` passed a sampler that returned almost nothing. GCPnts_TangentialDeflection
        // at the default (0.1, 0.01) gives 30 points from (0, 0) to (10, 0).
        try #require(points.count == 30)
        #expect(simd_distance(points[0], SIMD2(0, 0)) < 1e-9)
        #expect(simd_distance(points[29], SIMD2(10, 0)) < 1e-9)
    }
}
