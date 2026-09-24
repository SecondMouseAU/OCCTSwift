import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Issue #38: Curve2D.interpolate with interior tangent constraints

// #1979: these nested their assertions in `if let`, compared end points to 0.01 or 0.1, and never
// checked that a tangent constraint was applied where it was asked for: the interior-tangent test
// asserted only `poleCount != nil`, the closed test "may or may not succeed", and the 2-point test
// only `!= nil`. Each now pins what Geom2dAPI_Interpolate::Load gives for the same points and flags
// (Scripts/repro/766-geom2d-interpolate-tangents-periodic/).
@Suite("Curve2D Interior Tangent Interpolation Tests")
struct Curve2DInteriorTangentTests {

    @Test("Interpolate with no tangent constraints matches basic interpolate")
    func noTangentConstraints() throws {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(5, 3), SIMD2(10, 0),
        ]
        let b = try #require(Curve2D.interpolate(through: pts))
        let w = try #require(Curve2D.interpolate(through: pts, tangents: [:]))
        // An empty tangent map is the plain interpolation: same domain and the same curve.
        #expect(abs(w.domain.upperBound - b.domain.upperBound) < 1e-12)
        #expect(abs(w.domain.upperBound - 11.6619037897) < 1e-9)
        let mid = (w.domain.lowerBound + w.domain.upperBound) / 2
        #expect(simd_distance(w.point(at: mid), b.point(at: mid)) < 1e-12)
        #expect(simd_distance(w.point(at: mid), SIMD2(5, 3)) < 1e-9)
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
        let startPt = c.point(at: c.domain.lowerBound)
        let endPt = c.point(at: c.domain.upperBound)
        #expect(simd_distance(startPt, SIMD2(0, 0)) < 1e-9)
        #expect(simd_distance(endPt, SIMD2(10, 0)) < 1e-9)
        // Exactly horizontal, not approximately: D1 at the start is (2.1213, 0).
        let tan = try #require(c.tangentDirection(at: c.domain.lowerBound))
        #expect(abs(tan.y) < 1e-9)
        #expect(c.poleCount == 5)
    }

    @Test("Tangent constraint at interior point")
    func tangentAtInteriorPoint() throws {
        // Five points; force tangent at index 2 (middle) to be horizontal
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(2, 3), SIMD2(5, 2), SIMD2(8, 3), SIMD2(10, 0),
        ]
        let tangents: [Int: SIMD2<Double>] = [2: SIMD2(1, 0)]
        let c = try #require(Curve2D.interpolate(through: pts, tangents: tangents))
        // The curve passes (5, 2) at its third knot, u = 6.76782893563, and is horizontal there.
        let u = 6.76782893563
        #expect(simd_distance(c.point(at: u), SIMD2(5, 2)) < 1e-9)
        let tan = try #require(c.tangentDirection(at: u))
        #expect(abs(tan.y) < 1e-9)
        #expect(c.poleCount == 8)
    }

    @Test("Closed curve with interior tangent constraint")
    func closedCurveWithTangent() throws {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0), SIMD2(5, -5),
        ]
        let tangents: [Int: SIMD2<Double>] = [1: SIMD2(1, 0)]
        // Geom2dAPI_Interpolate succeeds here: a periodic curve on [0, 28.28] with 6 poles.
        let c = try #require(Curve2D.interpolate(through: pts, tangents: tangents, closed: true))
        #expect(c.isClosed)
        #expect(c.isPeriodic)
        #expect(c.poleCount == 6)
    }

    @Test("Minimum 2-point interpolation with tangent constraints")
    func twoPointInterpolation() throws {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        let tangents: [Int: SIMD2<Double>] = [0: SIMD2(1, 0), 1: SIMD2(1, 0)]
        // A cubic with 4 poles, running straight along x.
        let c = try #require(Curve2D.interpolate(through: pts, tangents: tangents))
        #expect(c.poleCount == 4)
        #expect(simd_distance(c.point(at: 5), SIMD2(5, 0)) < 1e-9)
    }
}
