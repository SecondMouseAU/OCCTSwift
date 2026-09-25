import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Tests

// #1979: several constructors were checked only for `!= nil` or a closed/open flag, inside
// `if let`s that also let a nil curve pass, and the draw tests asserted lower bounds (`>= 10`,
// `>= 4`, `>= 2`, `>= 3`) that most wrong samplers meet. Each now pins what the kernel gives:
// GCE2d / Geom2d constructions, D1, and the GCPnts_TangentialDeflection (0.1, 0.01) and
// GCPnts_UniformDeflection (0.1) point counts (Scripts/repro/766-geom2d-curve2d-basics/).

@Suite("Curve2D Tests")
struct Curve2DTests {

    @Test("Create segment and verify endpoints")
    func createSegment() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5)))
        let start = seg.startPoint
        let end = seg.endPoint
        #expect(abs(start.x - 0) < 1e-10)
        #expect(abs(start.y - 0) < 1e-10)
        #expect(abs(end.x - 10) < 1e-10)
        #expect(abs(end.y - 5) < 1e-10)
    }

    @Test("Segment degenerate returns nil")
    func segmentDegenerate() {
        let seg = Curve2D.segment(from: SIMD2(5, 5), to: SIMD2(5, 5))
        #expect(seg == nil)
    }

    @Test("Create circle and verify closed/periodic")
    func createCircle() throws {
        let circle = try #require(Curve2D.circle(center: .zero, radius: 5))
        #expect(circle.isClosed)
        #expect(circle.isPeriodic)
        let period = try #require(circle.period)
        #expect(abs(period - 2 * .pi) < 1e-12)
    }

    @Test("Circle zero radius returns nil")
    func circleZeroRadius() {
        let circle = Curve2D.circle(center: .zero, radius: 0)
        #expect(circle == nil)
        let circleNeg = Curve2D.circle(center: .zero, radius: -1)
        #expect(circleNeg == nil)
    }

    @Test("Arc of circle is not closed")
    func arcOfCircle() throws {
        let arc = try #require(
            Curve2D.arcOfCircle(
                center: .zero, radius: 5,
                startAngle: 0, endAngle: .pi / 2))
        #expect(!arc.isClosed)
        #expect(simd_distance(arc.startPoint, SIMD2(5, 0)) < 1e-12)
        #expect(simd_distance(arc.endPoint, SIMD2(0, 5)) < 1e-12)
    }

    @Test("Arc through 3 points")
    func arcThrough() throws {
        let arc = try #require(Curve2D.arcThrough(SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)))
        let start = arc.startPoint
        #expect(abs(start.x - 0) < 1e-6)
        #expect(abs(start.y - 0) < 1e-6)
        // The half circle through the three points: ends at (10, 0), passes (5, 5) at mid-domain.
        #expect(simd_distance(arc.endPoint, SIMD2(10, 0)) < 1e-9)
        #expect(simd_distance(arc.point(at: (arc.domain.lowerBound + arc.domain.upperBound) / 2), SIMD2(5, 5)) < 1e-9)
    }

    @Test("Create ellipse and verify closed")
    func createEllipse() throws {
        let ell = try #require(Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5))
        #expect(ell.isClosed)
        #expect(ell.isPeriodic)
        #expect(simd_distance(ell.point(at: 0), SIMD2(10, 0)) < 1e-12)
        #expect(simd_distance(ell.point(at: .pi / 2), SIMD2(0, 5)) < 1e-12)
    }

    @Test("Ellipse minor > major returns nil")
    func ellipseInvalid() {
        let ell = Curve2D.ellipse(center: .zero, majorRadius: 5, minorRadius: 10)
        #expect(ell == nil)
    }

    @Test("Infinite line")
    func infiniteLine() throws {
        let line = try #require(Curve2D.line(through: .zero, direction: SIMD2(1, 0)))
        #expect(!line.isClosed)
        #expect(simd_distance(line.point(at: 3), SIMD2(3, 0)) < 1e-12)
    }

    @Test("Parabola creation")
    func createParabola() throws {
        let p = try #require(Curve2D.parabola(focus: SIMD2(1, 0), direction: SIMD2(1, 0), focalLength: 1))
        #expect(abs(p.parabolaProperties.focal - 1) < 1e-12)
        #expect(simd_distance(p.parabolaProperties.focus, SIMD2(1, 0)) < 1e-12)
    }

    @Test("Hyperbola creation")
    func createHyperbola() throws {
        let h = try #require(Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3))
        #expect(abs(h.hyperbolaProperties.majorRadius - 5) < 1e-12)
        #expect(simd_distance(h.point(at: 0), SIMD2(5, 0)) < 1e-12)
    }

    @Test("Evaluate segment midpoint")
    func evaluateSegmentMidpoint() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let domain = seg.domain
        let mid = (domain.lowerBound + domain.upperBound) / 2
        let p = seg.point(at: mid)
        #expect(abs(p.x - 5) < 1e-10)
        #expect(abs(p.y - 0) < 1e-10)
    }

    @Test("Circle point at 0 and pi/2")
    func circlePoints() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let p0 = circle.point(at: 0)
        let pHalfPi = circle.point(at: .pi / 2)
        #expect(abs(p0.x - 5) < 1e-10)
        #expect(abs(p0.y - 0) < 1e-10)
        #expect(abs(pHalfPi.x - 0) < 1e-10)
        #expect(abs(pHalfPi.y - 5) < 1e-10)
    }

    @Test("D1 returns non-zero tangent")
    func d1Tangent() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))!
        let result = seg.d1(at: seg.domain.lowerBound)
        let tangentLen = sqrt(
            result.tangent.x * result.tangent.x + result.tangent.y * result.tangent.y)
        #expect(tangentLen > 0)
        // The segment is parameterised by length, so D1 is the unit direction (10, 5) / sqrt 125.
        #expect(simd_distance(result.tangent, SIMD2(10, 5) / 125.0.squareRoot()) < 1e-12)
    }

    // #815: `d2(at:)` had no test anywhere in the tree (its sibling `d1(at:)`, immediately above,
    // does). For a circle centered at the origin, parametrized by angle u, `P(u) = R*(cos u, sin
    // u)`, so `d2(u) = -R*(cos u, sin u) = -P(u)` for EVERY u, independent of which direction OCCT
    // picks as the circle's own parametric origin: an exact, refman-groundable relationship
    // rather than a magic-number pin.
    @Test("D2 second derivative of a circle points from the curve back to its own center")
    func d2SecondDerivative() {
        let circle = Curve2D.circle(center: SIMD2(0, 0), radius: 5)!
        let u = circle.domain.lowerBound
        let result = circle.d2(at: u)
        #expect(abs(result.d2.x - (-result.point.x)) < 1e-9)
        #expect(abs(result.d2.y - (-result.point.y)) < 1e-9)
    }

    @Test("Adaptive draw on circle produces at least 10 points")
    func adaptiveDrawCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let points = circle.drawAdaptive()
        #expect(points.count >= 10)
        #expect(points.count == 64)  // GCPnts_TangentialDeflection(0.1, 0.01)
    }

    @Test("Uniform draw produces exact count")
    func uniformDraw() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let points = circle.drawUniform(pointCount: 32)
        #expect(points.count == 32)
    }

    /// #501: `GCPnts_UniformAbscissa` sizes its own array at `nbPoints + 5` and can report more
    /// points than were asked for: one more, on a 1e6 x 1e-3 ellipse, for 22 of the first 59
    /// counts. `outXY` only holds `pointCount` pairs, so the surplus used to be written past its
    /// end; the surplus point is the curve's end parameter, so it is the last slot that keeps it.
    @Test("Uniform draw stays within the requested count on an overshooting ellipse")
    func uniformDrawRespectsCount() {
        guard let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 1e6, minorRadius: 1e-3)
        else {
            Issue.record("could not build the high-aspect-ratio ellipse")
            return
        }
        let endPoint = ellipse.point(at: ellipse.domain.upperBound)
        for count in [4, 5, 8, 12, 14, 18, 20, 22, 25, 26, 31, 33, 34, 35, 39, 40] {
            let points = ellipse.drawUniform(pointCount: count)
            #expect(points.count == count)
            if let last = points.last {
                #expect(distance(last, endPoint) < 1e-6)
            }
        }
    }

    @Test("Uniform draw rejects counts below two")
    func uniformDrawRejectsCountsBelowTwo() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        for count in [0, 1] {
            #expect(circle.drawUniform(pointCount: count).isEmpty)
        }
    }

    @Test("Deflection draw produces points")
    func deflectionDraw() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let points = circle.drawDeflection(deflection: 0.1)
        #expect(points.count >= 4)
        #expect(points.count == 17)  // GCPnts_UniformDeflection(0.1)
    }

    @Test("Adaptive draw on segment produces at least 2 points")
    func adaptiveDrawSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))!
        let points = seg.drawAdaptive()
        #expect(points.count == 2)  // a straight segment needs only its ends
    }

    @Test("Draw arc of ellipse")
    func drawArcOfEllipse() throws {
        let arc = Curve2D.arcOfEllipse(
            center: .zero, majorRadius: 10, minorRadius: 5,
            startAngle: 0, endAngle: .pi)
        let a = try #require(arc)  // #1979: was `if let`
        let points = a.drawAdaptive()
        #expect(points.count == 43)  // GCPnts_TangentialDeflection(0.1, 0.01)
        if let first = points.first, let last = points.last {
            #expect(simd_distance(first, SIMD2(10, 0)) < 1e-9)
            #expect(simd_distance(last, SIMD2(-10, 0)) < 1e-9)
        }
    }
}
