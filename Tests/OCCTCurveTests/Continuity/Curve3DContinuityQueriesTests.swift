import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.120.0: Final cleanup tests

@Suite("Curve3D Continuity Queries v0.120.0")
struct Curve3DContinuityQueriesTests {

    @Test func lineContinuityClass() {
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            // Geom_Line is analytic, so infinitely differentiable.
            #expect(c.continuityClass == .cN)
            #expect(c.continuityClass.satisfies(.c2))
        }
    }

    @Test func isCN() {
        // A line should have infinite continuity
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            #expect(c.isCN(0))
            #expect(c.isCN(1))
            #expect(c.isCN(2))
        }
    }

    @Test func reversedParameter() {
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let u = 2.0
            let rp = c.reversedParameter(u)
            // For a line, reversed parameter is -u
            #expect(abs(rp + u) < 1e-10)
        }
    }

    @Test func parametricTransformation() {
        if let c = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
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
        if let c = Curve3D.bezier(poles: poles) {
            let r = c.bezierResolution(tolerance3d: 0.01)
            #expect(r > 0)
        }
    }

    @Test func bezierMaxDegree() {
        let md = Curve3D.bezierMaxDegree
        #expect(md >= 25)  // OCCT typically allows at least 25
    }

    @Test func bsplineMaxDegree() {
        let md = Curve3D.bsplineMaxDegree
        #expect(md >= 25)
    }
}
