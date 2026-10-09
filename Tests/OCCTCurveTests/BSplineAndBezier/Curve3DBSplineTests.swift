import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D BSpline Tests")
struct Curve3DBSplineTests {

    @Test("Create quadratic Bezier")
    func quadraticBezier() {
        let bez = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(5, 10, 0), SIMD3(10, 0, 0)])
        #expect(bez != nil)
        if let bez = bez {
            #expect(bez.degree == 2)
            #expect(bez.poleCount == 3)
        }
    }

    @Test("Poles roundtrip")
    func polesRoundtrip() {
        let original: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(5, 10, 5), SIMD3(10, 0, 0)]
        let bez = Curve3D.bezier(poles: original)!
        let retrieved = bez.poles!
        #expect(retrieved.count == 3)
        for i in 0..<3 {
            #expect(abs(retrieved[i].x - original[i].x) < 1e-10)
            #expect(abs(retrieved[i].y - original[i].y) < 1e-10)
            #expect(abs(retrieved[i].z - original[i].z) < 1e-10)
        }
    }

    @Test("Interpolate through points")
    func interpolate() {
        let pts: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(3, 5, 1), SIMD3(7, 2, 3), SIMD3(10, 0, 0),
        ]
        let curve = Curve3D.interpolate(points: pts)
        #expect(curve != nil)
        if let c = curve {
            let start = c.startPoint
            let end = c.endPoint
            #expect(abs(start.x) < 0.01)
            #expect(abs(end.x - 10) < 0.01)
        }
    }

    @Test("Interpolate with tangents")
    func interpolateWithTangents() {
        let pts: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(5, 5, 5), SIMD3(10, 0, 0)]
        let curve = Curve3D.interpolate(
            points: pts,
            startTangent: SIMD3(1, 1, 1),
            endTangent: SIMD3(1, -1, -1))
        #expect(curve != nil)
    }

    @Test("Fit points to BSpline")
    func fitPoints() {
        let pts: [SIMD3<Double>] = (0..<20).map { i in
            let t = Double(i) / 19.0 * .pi * 2
            return SIMD3(cos(t) * 5, sin(t) * 5, Double(i) * 0.5)
        }
        let curve = Curve3D.fit(points: pts)
        #expect(curve != nil)
        if let c = curve {
            let start = c.startPoint
            #expect(abs(start.x - pts[0].x) < 0.5)
        }
    }

    @Test("Create BSpline with explicit knots")
    func createBSpline() {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(3, 5, 1), SIMD3(7, 3, 2), SIMD3(10, 0, 0),
        ]
        let knots: [Double] = [0, 1]
        let mults: [Int32] = [4, 4]
        let bsp = Curve3D.bspline(poles: poles, knots: knots, multiplicities: mults, degree: 3)
        #expect(bsp != nil)
        if let b = bsp {
            #expect(b.degree == 3)
            #expect(b.poleCount == 4)
        }
    }
}
