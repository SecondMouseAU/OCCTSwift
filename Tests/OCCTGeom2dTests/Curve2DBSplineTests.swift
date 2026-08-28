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
    func cubicBSpline() {
        let bsp = Curve2D.bspline(
            poles: [SIMD2(0, 0), SIMD2(2, 5), SIMD2(5, 5), SIMD2(8, 2), SIMD2(10, 0)],
            knots: [0, 1, 2, 3],
            multiplicities: [3, 1, 1, 3],
            degree: 2
        )
        #expect(bsp != nil)
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
        }
    }

    @Test("Interpolate with end tangents")
    func interpolateWithTangents() {
        let curve = Curve2D.interpolate(
            through: [
                SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0),
            ], startTangent: SIMD2(1, 1), endTangent: SIMD2(1, -1))
        #expect(curve != nil)
    }

    @Test("Fit points with tolerance")
    func fitPoints() {
        let pts: [SIMD2<Double>] = (0..<20).map { i in
            let t = Double(i) / 19.0 * 10.0
            return SIMD2(t, sin(t))
        }
        let curve = Curve2D.fit(through: pts)
        #expect(curve != nil)
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
    func drawInterpolated() {
        let curve = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0),
        ])!
        let points = curve.drawAdaptive()
        #expect(points.count >= 3)
    }
}
