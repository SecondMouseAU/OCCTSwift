import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D Analysis Tests")
struct Curve2DAnalysisTests {

    @Test("Line-circle intersection finds 2 points")
    func lineCircleIntersection() {
        let line = Curve2D.segment(from: SIMD2(-10, 0), to: SIMD2(10, 0))!
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let ints = line.intersections(with: circle)
        #expect(ints.count == 2)
    }

    @Test("Non-intersecting curves return empty")
    func noIntersection() {
        let seg1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let seg2 = Curve2D.segment(from: SIMD2(0, 5), to: SIMD2(10, 5))!
        let ints = seg1.intersections(with: seg2)
        #expect(ints.isEmpty)
    }

    @Test("Project point onto segment")
    func projectOnSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let proj = seg.project(point: SIMD2(5, 3))
        #expect(proj != nil)
        if let proj = proj {
            #expect(abs(proj.point.x - 5) < 1e-6)
            #expect(abs(proj.point.y - 0) < 1e-6)
            #expect(abs(proj.distance - 3) < 1e-6)
        }
    }

    @Test("Project point onto circle")
    func projectOnCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let proj = circle.project(point: SIMD2(10, 0))
        #expect(proj != nil)
        if let proj = proj {
            #expect(abs(proj.point.x - 5) < 1e-6)
            #expect(abs(proj.distance - 5) < 1e-6)
        }
    }

    @Test("Min distance between circle and point-like segment")
    func minDistanceCircleSegment() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let seg = Curve2D.segment(from: SIMD2(10, -1), to: SIMD2(10, 1))!
        let result = circle.minDistance(to: seg)
        #expect(result != nil)
        if let result = result {
            #expect(abs(result.distance - 5) < 0.5)
        }
    }

    @Test("Convert circle to BSpline")
    func circleToBSpline() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let bsp = circle.toBSpline()
        #expect(bsp != nil)
        if let bsp = bsp {
            #expect(bsp.poleCount != nil)
            #expect(bsp.degree != nil)
        }
    }

    @Test("Split BSpline to Beziers")
    func bsplineToBeziers() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let bsp = circle.toBSpline()!
        let beziers = bsp.toBezierSegments()
        #expect(beziers != nil)
        if let beziers = beziers {
            #expect(beziers.count >= 2)
        }
    }

    @Test("Join segments into BSpline")
    func joinSegments() {
        let seg1 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(5, 5))!
        let seg2 = Curve2D.segment(from: SIMD2(5, 5), to: SIMD2(10, 0))!
        let joined = Curve2D.join([seg1, seg2])
        #expect(joined != nil)
        if let joined = joined {
            let start = joined.startPoint
            let end = joined.endPoint
            #expect(abs(start.x - 0) < 1e-6)
            #expect(abs(end.x - 10) < 1e-6)
        }
    }

    @Test("All projections of point onto ellipse")
    func allProjectionsEllipse() {
        let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)!
        // A point at origin projects to multiple points on the ellipse
        let projs = ellipse.allProjections(of: SIMD2(0, 0))
        // At minimum there should be nearest and farthest projections
        #expect(projs.count >= 1)
        for p in projs {
            #expect(p.distance > 0)
        }
    }
}
