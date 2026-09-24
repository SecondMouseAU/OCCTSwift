import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: these asserted `count >= 1` (one with 0.1 of slack on the radius, two inside `if let`),
// so a solver returning the wrong circles passed. Each now pins the solution set the GccAna /
// Geom2dGcc solver returns (Scripts/repro/766-geom2d-gccana-circ3tan-lines/).
@Suite("GccAna/Geom2dGcc Circle On-Constraint Solvers") struct GccCircleOnConstraintTests {

    @Test("Circle tangent to 2 lines center on line")
    func circ2TanOnLinLin() throws {
        let results = Curve2DGcc.circlesTangentToTwoLinesOnLine(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(0, 10), line2Dir: SIMD2(1, 0),
            centerOnPoint: SIMD2(5, 0), centerOnDir: SIMD2(0, 1))
        try #require(results.count == 1)
        #expect(abs(results[0].radius - 5) < 1e-9)
        #expect(simd_distance(results[0].center, SIMD2(5, 5)) < 1e-9)
    }

    @Test("Circle tangent to line center on line given radius")
    func circTanOnRadLin() {
        let results = Curve2DGcc.circlesTangentToLineOnLineWithRadius(
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            centerOnPoint: SIMD2(0, 0), centerOnDir: SIMD2(0, 1),
            radius: 5)
        // Centres (0, -+5).
        #expect(results.count == 2)
        #expect(results.map(\.center.y).sorted() == [-5, 5])
    }

    @Test("Geom2dGcc circle tangent to 2 curves center on curve")
    func geom2dCirc2TanOn() throws {
        let c1 = try #require(Curve2D.circle(center: SIMD2(0, 0), radius: 5))
        let c2 = try #require(Curve2D.circle(center: SIMD2(20, 0), radius: 5))
        let onCurve = try #require(Curve2D.line(through: SIMD2(10, 0), direction: SIMD2(0, 1)))
        let results = Curve2DGcc.circlesTangentToTwoCurvesOnCurve(
            c1, .unqualified, c2, .unqualified, centerOn: onCurve)
        // Both centred at (10, 0): radius 5 (outside both) and 15 (enclosing both).
        #expect(results.map(\.radius).sorted() == [5, 15])
        #expect(results.allSatisfy { simd_distance($0.center, SIMD2(10, 0)) < 1e-9 })
    }

    @Test("Geom2dGcc circle tangent to curve center on curve given radius")
    func geom2dCircTanOnRad() throws {
        let c1 = try #require(Curve2D.circle(center: SIMD2(0, 0), radius: 5))
        let onCurve = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(0, 1)))
        let results = Curve2DGcc.circlesTangentOnCurveWithRadius(
            c1, centerOn: onCurve, radius: 3)
        // Centres on x = 0 at y = +-2 (inside) and +-8 (outside).
        let ys = results.map(\.center.y).sorted()
        try #require(ys.count == 4)
        for (y, e) in zip(ys, [-8.0, -2, 2, 8]) {
            #expect(abs(y - e) < 1e-9)
        }
    }
}
