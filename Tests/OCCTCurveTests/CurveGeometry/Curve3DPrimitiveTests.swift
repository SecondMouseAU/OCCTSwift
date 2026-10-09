import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve3D Tests (v0.19.0)

@Suite("Curve3D Primitive Tests")
struct Curve3DPrimitiveTests {

    @Test("Create segment and verify endpoints")
    func createSegment() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 5, 3))
        #expect(seg != nil)
        if let seg = seg {
            let start = seg.startPoint
            let end = seg.endPoint
            #expect(abs(start.x) < 1e-10)
            #expect(abs(start.y) < 1e-10)
            #expect(abs(start.z) < 1e-10)
            #expect(abs(end.x - 10) < 1e-10)
            #expect(abs(end.y - 5) < 1e-10)
            #expect(abs(end.z - 3) < 1e-10)
        }
    }

    @Test("Degenerate segment returns nil")
    func degenerateSegment() {
        let seg = Curve3D.segment(from: SIMD3(5, 5, 5), to: SIMD3(5, 5, 5))
        #expect(seg == nil)
    }

    @Test("Create circle and verify closed/periodic")
    func createCircle() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)
        #expect(circle != nil)
        if let circle = circle {
            #expect(circle.isClosed)
            #expect(circle.isPeriodic)
            #expect(circle.period != nil)
        }
    }

    @Test("Circle zero radius returns nil")
    func circleZeroRadius() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 0)
        #expect(circle == nil)
    }

    @Test("Circle point at 0 and pi/2")
    func circlePoints() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let p0 = circle.point(at: 0)
        let pHalfPi = circle.point(at: .pi / 2)
        #expect(abs(p0.x - 5) < 1e-10)
        #expect(abs(p0.y) < 1e-10)
        #expect(abs(pHalfPi.x) < 1e-10)
        #expect(abs(pHalfPi.y - 5) < 1e-10)
    }

    @Test("Arc through three points")
    func arcThreePoints() {
        let arc = Curve3D.arcOfCircle(
            start: SIMD3(5, 0, 0),
            interior: SIMD3(0, 5, 0),
            end: SIMD3(-5, 0, 0))
        #expect(arc != nil)
        if let arc = arc {
            #expect(!arc.isClosed)
            let start = arc.startPoint
            #expect(abs(start.x - 5) < 0.01)
        }
    }

    @Test("Create ellipse")
    func createEllipse() {
        let ellipse = Curve3D.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 5)
        #expect(ellipse != nil)
        if let e = ellipse {
            #expect(e.isClosed)
            #expect(e.isPeriodic)
        }
    }

    @Test("Invalid ellipse returns nil")
    func invalidEllipse() {
        // Minor > major is invalid
        let e = Curve3D.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1),
            majorRadius: 5, minorRadius: 10)
        #expect(e == nil)
    }

    @Test("Create line and verify infinite domain")
    func createLine() {
        let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))
        #expect(line != nil)
        if let line = line {
            let d = line.domain
            // Line domain should be very large (practically infinite)
            #expect(d.upperBound - d.lowerBound > 1e10)
        }
    }

    @Test("Evaluate segment midpoint")
    func evaluateSegmentMidpoint() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let d = seg.domain
        let mid = (d.lowerBound + d.upperBound) / 2
        let p = seg.point(at: mid)
        #expect(abs(p.x - 5) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test("D1 returns non-zero tangent")
    func d1Tangent() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 5, 3))!
        let result = seg.d1(at: seg.domain.lowerBound)
        let len = simd_length(result.tangent)
        #expect(len > 0)
    }

    // #815: `d2(at:)` had no test anywhere in the tree (its sibling `d1(at:)`, immediately above,
    // does). For a circle centered at the origin, parametrized by angle u, `P(u) = R*(cos u, sin
    // u, 0)` in the circle's own plane, so `d2(u) = -R*(cos u, sin u, 0) = -P(u)` for EVERY u,
    // independent of which in-plane direction OCCT picks as the circle's own parametric origin.
    // That makes it a genuine, exact, refman-groundable check rather than a magic-number pin.
    @Test("D2 second derivative of a circle points from the curve back to its own center")
    func d2SecondDerivative() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let u = circle.domain.lowerBound
        let result = circle.d2(at: u)
        #expect(abs(result.d2.x - (-result.point.x)) < 1e-9)
        #expect(abs(result.d2.y - (-result.point.y)) < 1e-9)
        #expect(abs(result.d2.z - (-result.point.z)) < 1e-9)
    }
}
