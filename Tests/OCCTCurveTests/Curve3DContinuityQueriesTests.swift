import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.120.0: Final cleanup tests

@Suite("Curve3D Continuity Queries v0.120.0")
struct Curve3DContinuityQueriesTests {
    // Values are Geom_Curve's for the same line and Bezier
    // (Scripts/repro/766-curve-conic-continuity/transcript.txt). The earlier versions sat inside
    // `if let`, and three asserted bounds (`r > 0`, `md >= 25`) that a wrong value also meets (#766).
    private static func line() -> Curve3D? {
        let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
        if c == nil { Issue.record("line not built") }
        return c
    }

    @Test func lineContinuityClass() {
        guard let c = Self.line() else { return }
        do {
            // Geom_Line is analytic, so infinitely differentiable.
            #expect(c.continuityClass == .cN)
            #expect(c.continuityClass.satisfies(.c2))
        }
    }

    @Test func isCN() {
        // A line should have infinite continuity
        guard let c = Self.line() else { return }
        do {
            #expect(c.isCN(0))
            #expect(c.isCN(1))
            #expect(c.isCN(2))
        }
    }

    @Test func reversedParameter() {
        guard let c = Self.line() else { return }
        do {
            let u = 2.0
            let rp = c.reversedParameter(u)
            // For a line, reversed parameter is -u
            #expect(abs(rp + u) < 1e-10)
        }
    }

    @Test func parametricTransformation() {
        guard let c = Self.line() else { return }
        do {
            // Identity rotation, no translation
            let rotation = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
            let trans = SIMD3<Double>(0, 0, 0)
            let scale = c.parametricTransformation(rotation: rotation, translation: trans)
            #expect(abs(scale - 1.0) < 1e-10)
        }
    }

    @Test func bezierResolution() {
        // Create a simple Bezier curve via BSpline (degree 2 with 3 poles is a Bezier)
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0)]
        guard let c = Curve3D.bezier(poles: poles) else {
            Issue.record("Bezier not built")
            return
        }
        // Geom_BezierCurve::Resolution(0.01) on this curve.
        #expect(abs(c.bezierResolution(tolerance3d: 0.01) - 0.0025) < 1e-15)
    }

    @Test func bezierMaxDegree() {
        let md = Curve3D.bezierMaxDegree
        #expect(md == 25)  // Geom_BezierCurve::MaxDegree()
    }

    @Test func bsplineMaxDegree() {
        let md = Curve3D.bsplineMaxDegree
        #expect(md == 25)  // Geom_BSplineCurve::MaxDegree()
    }
}
