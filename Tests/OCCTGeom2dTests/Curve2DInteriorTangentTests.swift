import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Issue #38: Curve2D.interpolate with interior tangent constraints

// Every test requires its curve, checks that it passes through every point it was given, and
// pins the direction the curve takes where a tangent was asked for, sign included. A constraint
// that the data would have satisfied anyway pins nothing, so each fixture is checked against the
// same points interpolated without the constraint, which must answer differently there. The
// kernel's own answers for the same points and flags (`Geom2dAPI_Interpolate::Load`) are in
// `Scripts/repro/766-geom2d-interpolate-tangents-periodic/transcript.txt` and
// `Scripts/repro/766-geom2d-curve2d-cluster/transcript.txt`.
//
// An index outside `0..<points.count` is left unasserted on purpose: it is dropped without a
// signal today, which #3036 records.
@Suite("Curve2D Interior Tangent Interpolation Tests")
struct Curve2DInteriorTangentTests {

    /// The parameter each point is given, which is the cumulative chord length.
    private func knots(_ pts: [SIMD2<Double>]) -> [Double] {
        var out: [Double] = [0]
        for i in 1..<pts.count {
            out.append(out[i - 1] + simd_distance(pts[i], pts[i - 1]))
        }
        return out
    }

    /// Checks that `curve` passes through every point of `pts` at that point's own knot.
    private func expectInterpolates(_ curve: Curve2D, _ pts: [SIMD2<Double>]) {
        for (i, u) in knots(pts).enumerated() {
            let miss = simd_distance(curve.point(at: u), pts[i])
            #expect(miss < 1e-9, "point \(i) missed by \(miss) at u = \(u)")
        }
    }

    @Test("Interpolate with no tangent constraints matches basic interpolate")
    func noTangentConstraints() throws {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(5, 3), SIMD2(10, 0),
        ]
        let b = try #require(Curve2D.interpolate(through: pts))
        let w = try #require(Curve2D.interpolate(through: pts, tangents: [:]))
        // An empty tangent map is the plain interpolation: same domain and the same curve. The
        // parameter is the chord length, 2 * sqrt(34) for these points.
        let length: Double = 2.0 * Double(34).squareRoot()
        #expect(abs(w.domain.upperBound - b.domain.upperBound) < 1e-12)
        #expect(abs(w.domain.upperBound - length) < 1e-9)
        for i in 0...4 {
            let u = w.domain.upperBound * Double(i) / 4
            #expect(simd_distance(w.point(at: u), b.point(at: u)) < 1e-12, "u = \(u)")
        }
        expectInterpolates(w, pts)
    }

    @Test("Tangent constraint at start and end")
    func tangentsAtStartAndEnd() throws {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0),
        ]
        // Horizontal tangent at start and end (railway tangent point convention)
        let tangents: [Int: SIMD2<Double>] = [
            0: SIMD2(1, 0),
            2: SIMD2(1, 0),
        ]
        let c = try #require(Curve2D.interpolate(through: pts, tangents: tangents))
        expectInterpolates(c, pts)
        // Exactly horizontal at both ends, pointing along +x: a reversed end tangent is a
        // different curve. The derivative at the start is (2.1213, 0).
        let start = try #require(c.tangentDirection(at: c.domain.lowerBound))
        let end = try #require(c.tangentDirection(at: c.domain.upperBound))
        #expect(simd_distance(start, SIMD2(1, 0)) < 1e-9)
        #expect(simd_distance(end, SIMD2(1, 0)) < 1e-9)
        #expect(c.poleCount == 5)

        // The control: the same points with no constraint leave the arch rising steeply, so the
        // horizontal start is the constraint's doing.
        let plain = try #require(Curve2D.interpolate(through: pts))
        let natural = try #require(plain.tangentDirection(at: plain.domain.lowerBound))
        #expect(natural.y > 0.5, "unconstrained start tangent \(natural)")
    }

    @Test("Tangent constraint at interior point")
    func tangentAtInteriorPoint() throws {
        // Five points; force the tangent at index 2 (the middle) to run along (1, 2). These points
        // are symmetric about x = 5, so with no constraint the curve is horizontal at (5, 2) and a
        // horizontal constraint would pin nothing, which is why the direction asked for is not.
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 3), SIMD2(5, 2), SIMD2(8, 3), SIMD2(10, 0),
        ]
        let tangents: [Int: SIMD2<Double>] = [2: SIMD2(1, 2)]
        let c = try #require(Curve2D.interpolate(through: pts, tangents: tangents))
        expectInterpolates(c, pts)

        // The curve passes (5, 2) at its third knot, u = sqrt(13) + sqrt(10) = 6.76782893563, and
        // runs along (1, 2) / sqrt(5) there.
        let u = knots(pts)[2]
        #expect(abs(u - 6.76782893563) < 1e-9)
        let tan = try #require(c.tangentDirection(at: u))
        let wanted = SIMD2<Double>(1, 2) / Double(5).squareRoot()
        #expect(simd_distance(tan, wanted) < 1e-9)
        #expect(c.poleCount == 8)

        // The control: unconstrained, the same curve is horizontal at that knot.
        let plain = try #require(Curve2D.interpolate(through: pts))
        let natural = try #require(plain.tangentDirection(at: u))
        #expect(simd_distance(natural, wanted) > 0.5, "unconstrained tangent \(natural)")
    }

    @Test("Closed curve with interior tangent constraint")
    func closedCurveWithTangent() throws {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(6, 2), SIMD2(10, 8), SIMD2(3, 6),
        ]
        let tangents: [Int: SIMD2<Double>] = [1: SIMD2(1, 0)]
        // Geom2dAPI_Interpolate succeeds here: a periodic curve with 6 poles whose period is the
        // perimeter of the polygon through the points, closing chord included.
        let c = try #require(Curve2D.interpolate(through: pts, tangents: tangents, closed: true))
        #expect(c.isClosed)
        #expect(c.isPeriodic)
        #expect(c.poleCount == 6)
        // The squared chords are |(6, 2)|^2 = 40, |(4, 6)|^2 = 52, |(-7, -2)|^2 = 53 and
        // |(-3, -6)|^2 = 45.
        let squaredChords: [Double] = [40, 52, 53, 45]
        let perimeter: Double = squaredChords.map { $0.squareRoot() }.reduce(0, +)
        #expect(abs(c.domain.upperBound - c.domain.lowerBound - perimeter) < 1e-9)
        expectInterpolates(c, pts)

        // Horizontal at the second point, along +x.
        let u = knots(pts)[1]
        let tan = try #require(c.tangentDirection(at: u))
        #expect(simd_distance(tan, SIMD2(1, 0)) < 1e-9)

        // The control: without the constraint the loop climbs through that point.
        let plain = try #require(Curve2D.interpolate(through: pts, closed: true))
        #expect(plain.isPeriodic)
        let natural = try #require(plain.tangentDirection(at: u))
        #expect(natural.y > 0.3, "unconstrained tangent \(natural)")
    }

    @Test("Minimum 2-point interpolation with tangent constraints")
    func twoPointInterpolation() throws {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        let tangents: [Int: SIMD2<Double>] = [0: SIMD2(1, 0), 1: SIMD2(1, 0)]
        // A cubic with 4 poles, running straight along x. Two points alone give a line with 2
        // poles, so the pole count is what shows both constraints were applied.
        let c = try #require(Curve2D.interpolate(through: pts, tangents: tangents))
        #expect(c.poleCount == 4)
        expectInterpolates(c, pts)
        #expect(simd_distance(c.point(at: 5), SIMD2(5, 0)) < 1e-9)
        let plain = try #require(Curve2D.interpolate(through: pts))
        #expect(plain.poleCount == 2)
    }

    @Test("Two points with both tangents turned up make an S through the midpoint")
    func twoPointSCurve() throws {
        // Both tangents point along +y while the points are 10 apart along x: a cubic that leaves
        // (0, 0) upwards, arrives at (10, 0) upwards, and by the symmetry of its Hermite form
        // crosses the midpoint (5, 0) at the middle of the parameter.
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        let tangents: [Int: SIMD2<Double>] = [0: SIMD2(0, 1), 1: SIMD2(0, 1)]
        let c = try #require(Curve2D.interpolate(through: pts, tangents: tangents))
        expectInterpolates(c, pts)
        let start = try #require(c.tangentDirection(at: c.domain.lowerBound))
        let end = try #require(c.tangentDirection(at: c.domain.upperBound))
        #expect(simd_distance(start, SIMD2(0, 1)) < 1e-9)
        #expect(simd_distance(end, SIMD2(0, 1)) < 1e-9)
        #expect(simd_distance(c.point(at: 5), SIMD2(5, 0)) < 1e-9)
        // A quarter of the way along, the cubic Hermite form with end derivatives (0, 1) over a
        // parameter span of 10 is at t = 1/4: x = 10 (3 t^2 - 2 t^3) = 1.5625 and
        // y = 10 (2 t^3 - 3 t^2 + t) = 0.9375, so the curve has left the x axis. The kernel keeps
        // the unit derivative the caller gave (`Scripts/repro/766-geom2d-curve2d-cluster/`).
        #expect(simd_distance(c.point(at: 2.5), SIMD2(1.5625, 0.9375)) < 1e-9)
    }
}
