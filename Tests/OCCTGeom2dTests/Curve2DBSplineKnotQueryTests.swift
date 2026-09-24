import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test here nested its assertions in `if let c`, so a nil curve passed, and most
// asserted a range (`fk > 0`, `k.isFinite`, `d >= 0 && d <= 3`, `m > 0`, `cont >= 0`) that a
// wrong answer satisfies. The interpolant through (0,0), (1,1), (2,0) is a single quadratic
// Bezier span: knots [0, 2 sqrt 2] with multiplicities [3, 3] and poles (0,0), (1,2), (2,0).
// Values from Geom2d_BSplineCurve (Scripts/repro/766-geom2d-bspline-knot-query/).
@Suite("Curve2D BSpline Knot Queries")
struct Curve2DBSplineKnotQueryTests {
    private func makeCurve() throws -> Curve2D {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        return try #require(Curve2D.interpolate(through: pts))
    }

    @Test("FirstUKnotIndex and LastUKnotIndex")
    func knotIndices() throws {
        let c = try makeCurve()
        #expect(c.bsplineFirstUKnotIndex == 1)
        #expect(c.bsplineLastUKnotIndex == 2)
    }

    @Test("Knot value by index")
    func knotValue() throws {
        let c = try makeCurve()
        #expect(abs(c.bsplineKnot(index: 1)) < 1e-12)
        #expect(abs(c.bsplineKnot(index: 2) - 2 * 2.0.squareRoot()) < 1e-12)
    }

    @Test("KnotDistribution")
    func knotDistribution() throws {
        // 3 = GeomAbs_PiecewiseBezier: one span with full end multiplicities.
        let c = try makeCurve()
        #expect(c.bsplineKnotDistribution == 3)
    }

    @Test("Multiplicity by index")
    func multiplicity() throws {
        let c = try makeCurve()
        #expect(c.bsplineMultiplicity(index: 1) == 3)
    }

    @Test("GetMultiplicities bulk")
    func multiplicities() throws {
        let c = try makeCurve()
        #expect(c.bsplineMultiplicities == [3, 3])
    }

    @Test("StartPoint and EndPoint")
    func startEndPoint() throws {
        let c = try makeCurve()
        let sp = c.bsplineStartPoint
        let ep = c.bsplineEndPoint
        #expect(abs(sp.x - 0) < 1e-6)
        #expect(abs(sp.y - 0) < 1e-6)
        #expect(abs(ep.x - 2) < 1e-6)
        #expect(abs(ep.y - 0) < 1e-6)
    }

    @Test("GetPoles bulk")
    func poles() throws {
        let c = try makeCurve()
        let poles = c.bsplinePoles
        let expected: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0)]
        try #require(poles.count == expected.count)
        #expect(c.poleCount == 3)
        #expect(zip(poles, expected).allSatisfy { simd_distance($0, $1) < 1e-9 })
    }

    @Test("IsClosed and IsPeriodic")
    func closedPeriodic() throws {
        let c = try makeCurve()
        #expect(!c.bsplineIsClosed)
        #expect(!c.bsplineIsPeriodic)
    }

    @Test("Continuity and IsCN")
    func continuity() throws {
        // A single span is infinitely differentiable: GeomAbs_CN (6), and IsCN holds at every order.
        let c = try makeCurve()
        #expect(c.bsplineContinuity == 6)
        #expect(c.bsplineIsCN(0))
        #expect(c.bsplineIsCN(4))
    }
}
