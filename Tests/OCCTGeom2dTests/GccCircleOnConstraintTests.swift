import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GccAna/Geom2dGcc Circle On-Constraint Solvers") struct GccCircleOnConstraintTests {
    @Test("Circle tangent to 2 lines center on line")
    func circ2TanOnLinLin() {
        let results = Curve2DGcc.circlesTangentToTwoLinesOnLine(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(0, 10), line2Dir: SIMD2(1, 0),
            centerOnPoint: SIMD2(5, 0), centerOnDir: SIMD2(0, 1))
        #expect(results.count >= 1)
        if let sol = results.first {
            #expect(abs(sol.radius - 5) < 0.1)
        }
    }

    @Test("Circle tangent to line center on line given radius")
    func circTanOnRadLin() {
        let results = Curve2DGcc.circlesTangentToLineOnLineWithRadius(
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            centerOnPoint: SIMD2(0, 0), centerOnDir: SIMD2(0, 1),
            radius: 5)
        #expect(results.count >= 1)
    }

    @Test("Geom2dGcc circle tangent to 2 curves center on curve")
    func geom2dCirc2TanOn() {
        let c1 = Curve2D.circle(center: SIMD2(0, 0), radius: 5)
        let c2 = Curve2D.circle(center: SIMD2(20, 0), radius: 5)
        let onCurve = Curve2D.line(through: SIMD2(10, 0), direction: SIMD2(0, 1))
        if let c1, let c2, let onCurve {
            let results = Curve2DGcc.circlesTangentToTwoCurvesOnCurve(
                c1, .unqualified, c2, .unqualified, centerOn: onCurve)
            #expect(results.count >= 1)
        }
    }

    @Test("Geom2dGcc circle tangent to curve center on curve given radius")
    func geom2dCircTanOnRad() {
        let c1 = Curve2D.circle(center: SIMD2(0, 0), radius: 5)
        let onCurve = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(0, 1))
        if let c1, let onCurve {
            let results = Curve2DGcc.circlesTangentOnCurveWithRadius(
                c1, centerOn: onCurve, radius: 3)
            #expect(results.count >= 1)
        }
    }
}
