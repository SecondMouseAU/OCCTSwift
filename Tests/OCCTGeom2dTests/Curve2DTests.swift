import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Tests

@Suite("Curve2D Tests")
struct Curve2DTests {

    @Test("Create segment and verify endpoints")
    func createSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))
        #expect(seg != nil)
        if let seg = seg {
            let start = seg.startPoint
            let end = seg.endPoint
            #expect(abs(start.x - 0) < 1e-10)
            #expect(abs(start.y - 0) < 1e-10)
            #expect(abs(end.x - 10) < 1e-10)
            #expect(abs(end.y - 5) < 1e-10)
        }
    }

    @Test("Segment degenerate returns nil")
    func segmentDegenerate() {
        let seg = Curve2D.segment(from: SIMD2(5, 5), to: SIMD2(5, 5))
        #expect(seg == nil)
    }

    @Test("Create circle and verify closed/periodic")
    func createCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)
        #expect(circle != nil)
        if let circle = circle {
            #expect(circle.isClosed)
            #expect(circle.isPeriodic)
            #expect(circle.period != nil)
        }
    }

    @Test("Circle zero radius returns nil")
    func circleZeroRadius() {
        let circle = Curve2D.circle(center: .zero, radius: 0)
        #expect(circle == nil)
        let circleNeg = Curve2D.circle(center: .zero, radius: -1)
        #expect(circleNeg == nil)
    }

    @Test("Arc of circle is not closed")
    func arcOfCircle() {
        let arc = Curve2D.arcOfCircle(
            center: .zero, radius: 5,
            startAngle: 0, endAngle: .pi / 2)
        #expect(arc != nil)
        if let arc = arc {
            #expect(!arc.isClosed)
        }
    }

    @Test("Arc through 3 points")
    func arcThrough() {
        let arc = Curve2D.arcThrough(SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0))
        #expect(arc != nil)
        if let arc = arc {
            let start = arc.startPoint
            #expect(abs(start.x - 0) < 1e-6)
            #expect(abs(start.y - 0) < 1e-6)
        }
    }

    @Test("Create ellipse and verify closed")
    func createEllipse() {
        let ell = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)
        #expect(ell != nil)
        if let ell = ell {
            #expect(ell.isClosed)
            #expect(ell.isPeriodic)
        }
    }

    @Test("Ellipse minor > major returns nil")
    func ellipseInvalid() {
        let ell = Curve2D.ellipse(center: .zero, majorRadius: 5, minorRadius: 10)
        #expect(ell == nil)
    }

    @Test("Infinite line")
    func infiniteLine() {
        let line = Curve2D.line(through: .zero, direction: SIMD2(1, 0))
        #expect(line != nil)
        if let line = line {
            #expect(!line.isClosed)
        }
    }

    @Test("Parabola creation")
    func createParabola() {
        let p = Curve2D.parabola(focus: SIMD2(1, 0), direction: SIMD2(1, 0), focalLength: 1)
        #expect(p != nil)
    }

    @Test("Hyperbola creation")
    func createHyperbola() {
        let h = Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3)
        #expect(h != nil)
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
    }

    @Test("Adaptive draw on circle produces at least 10 points")
    func adaptiveDrawCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let points = circle.drawAdaptive()
        #expect(points.count >= 10)
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
    }

    @Test("Adaptive draw on segment produces at least 2 points")
    func adaptiveDrawSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))!
        let points = seg.drawAdaptive()
        #expect(points.count >= 2)
    }

    @Test("Draw arc of ellipse")
    func drawArcOfEllipse() {
        let arc = Curve2D.arcOfEllipse(
            center: .zero, majorRadius: 10, minorRadius: 5,
            startAngle: 0, endAngle: .pi)
        #expect(arc != nil)
        if let arc = arc {
            let points = arc.drawAdaptive()
            #expect(points.count >= 3)
        }
    }
}
