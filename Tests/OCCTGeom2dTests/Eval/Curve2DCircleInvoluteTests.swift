import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: the point tests checked only u = 0, where the involute term R * u * (sin u, -cos u)
// vanishes, so a defect in it passed; the mirrored-flank test compared only signs, and its comment
// placed the mirrored C(0) at (2, 0) where the kernel puts it at (-2, 0); the edge test counted
// edges, which an edge of any length satisfies. Values from Geom2dEval_CircleInvoluteCurve and
// BRepLib_MakeEdge2d (Scripts/repro/766-geom2d-circle-involute/): C(u) = O + R (cos u + u sin u,
// sin u - u cos u) in the placement's frame, so C(1) = (2.76354658135, 0.60233735788) for R = 2.
@Suite("Curve2D — Circle Involute")
struct Curve2DCircleInvoluteTests {
    private static let c1 = SIMD2<Double>(2.76354658135, 0.60233735788)

    @Test func createCircleInvolute() throws {
        let curve = try #require(
            Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: 2.0))
        #expect(curve.isPeriodic == false)  // Involute is not periodic
        #expect(curve.isClosed == false)  // Involute is not closed
        #expect(abs(curve.domain.lowerBound) < 1e-12)
    }

    @Test func createCircleInvoluteRejectsZeroRadius() {
        let curve = Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: 0)
        #expect(curve == nil)
    }

    @Test func createCircleInvoluteRejectsNegativeRadius() {
        let curve = Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: -1.0)
        #expect(curve == nil)
    }

    @Test func circleInvolutePointAtZero() throws {
        let curve = try #require(
            Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: 2.0))
        let first = curve.domain.lowerBound
        let p = curve.point(at: first)
        // At first parameter (0), C(0) = R*(1, 0) = (2, 0)
        #expect(abs(p.x - 2.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
        #expect(simd_distance(curve.point(at: 1), Self.c1) < 1e-9)
    }

    @Test func circleInvoluteTranslated() throws {
        let curve = try #require(
            Curve2D.circleInvolute(origin: SIMD2(10, 20), direction: SIMD2(1, 0), radius: 2.0))
        let first = curve.domain.lowerBound
        let p = curve.point(at: first)
        // C(0) = (10, 20) + 2*(1, 0) = (12, 20)
        #expect(abs(p.x - 12.0) < 1e-10)
        #expect(abs(p.y - 20.0) < 1e-10)
        #expect(simd_distance(curve.point(at: 1), SIMD2(10, 20) + Self.c1) < 1e-9)
    }

    @Test func circleInvoluteRotated() throws {
        let angle = Double.pi / 2
        let dir = SIMD2(cos(angle), sin(angle))
        let curve = try #require(Curve2D.circleInvolute(origin: .zero, direction: dir, radius: 2.0))
        let first = curve.domain.lowerBound
        let p = curve.point(at: first)
        // C(0) = O + R*(0, 1) = (0, 2)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y - 2.0) < 1e-10)
        // Rotating the placement by 90 degrees rotates C(1) the same way.
        #expect(simd_distance(curve.point(at: 1), SIMD2(-Self.c1.y, Self.c1.x)) < 1e-9)
    }

    @Test func circleInvoluteMirroredFlank() throws {
        // A mirrored flank uses a negated X direction (direction = (-1, 0) gives YDir = (0, -1)).
        let standardCurve = try #require(
            Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: 2.0))
        let mirroredCurve = try #require(
            Curve2D.circleInvolute(origin: .zero, direction: SIMD2(-1, 0), radius: 2.0))
        // The mirrored placement is the standard one turned by 180 degrees: C(0) = (-2, 0) and
        // C(1) = -(standard C(1)).
        #expect(simd_distance(standardCurve.point(at: 0), SIMD2(2, 0)) < 1e-9)
        #expect(simd_distance(mirroredCurve.point(at: 0), SIMD2(-2, 0)) < 1e-9)
        let pStandardU = standardCurve.point(at: 1)
        let pMirroredU = mirroredCurve.point(at: 1)
        #expect(pStandardU.y > 0)  // Standard flank goes positive Y
        #expect(pMirroredU.y < 0)  // Mirrored flank goes negative Y
        #expect(simd_distance(pMirroredU, -Self.c1) < 1e-9)
    }

    @Test func circleInvoluteCanBuildEdge() throws {
        let curve = try #require(
            Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: 2.0))
        // Build an edge from the curve
        let first = curve.domain.lowerBound
        let last = curve.domain.upperBound
        let u1 = first
        let u2 = min(first + 2.0, last)
        let e = try #require(Shape.edge2dFromCurve(curve, u1: u1, u2: u2))
        let edges = e.edges()
        try #require(edges.count == 1)
        // The involute's arc length from 0 to u is R u^2 / 2: 4 for R = 2, u = 2.
        #expect(abs(edges[0].length - 4) < 1e-6)
    }

    @Test func createCircleInvoluteRejectsZeroLengthDirection() {
        let curve = Curve2D.circleInvolute(origin: .zero, direction: SIMD2(0, 0), radius: 2.0)
        #expect(curve == nil)
    }

    @Test func createCircleInvoluteRejectsNearZeroLengthDirection() {
        let curve = Curve2D.circleInvolute(
            origin: .zero, direction: SIMD2(1e-15, 1e-15), radius: 2.0)
        #expect(curve == nil)
    }

    // The refusal is `nil` now, not the origin (#1646). These two asserted the old spelling, and
    // the origin is a point the involute legitimately returns at u = 0, so what they proved was
    // "either refused or evaluated at the base point" rather than "refused".
    @Test func circleInvoluteD0WithPlacementRejectsZeroLengthDirection() {
        let p = Geom2dEval.circleInvoluteD0(
            origin: .zero, direction: SIMD2(0, 0), radius: 2.0, u: 1.0)
        #expect(p == nil)
    }

    @Test func circleInvoluteD1WithPlacementRejectsZeroLengthDirection() {
        let r = Geom2dEval.circleInvoluteD1(
            origin: .zero, direction: SIMD2(0, 0), radius: 2.0, u: 1.0)
        #expect(r == nil)
    }
}
