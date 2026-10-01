import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D Analysis Tests")
struct Curve2DAnalysisTests {

    @Test("Line-circle intersection finds 2 points")
    func lineCircleIntersection() throws {
        let line = Curve2D.segment(from: SIMD2(-10, 0), to: SIMD2(10, 0))!
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let ints = line.intersections(with: circle)
        // #1979: the count alone passed two wrong points. Geom2dAPI_InterCurveCurve gives (-5, 0)
        // and (5, 0) (Scripts/repro/766-geom2d-curve2d-analysis/).
        try #require(ints.count == 2)
        let xs = ints.map(\.point.x).sorted()
        #expect(abs(xs[0] + 5) < 1e-9)
        #expect(abs(xs[1] - 5) < 1e-9)
        #expect(ints.allSatisfy { abs($0.point.y) < 1e-9 })
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
    func minDistanceCircleSegment() throws {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let seg = Curve2D.segment(from: SIMD2(10, -1), to: SIMD2(10, 1))!
        // #1979: a 0.5 tolerance passed a distance that was off by 0.3. Geom2dAPI_ExtremaCurveCurve
        // gives exactly 5, between (5, 0) and (10, 0) (Scripts/repro/766-geom2d-curve2d-analysis/).
        let result = try #require(circle.minDistance(to: seg))
        #expect(abs(result.distance - 5) < 1e-9)
    }

    @Test("Convert circle to BSpline")
    func circleToBSpline() throws {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        // #1979: `!= nil` passed any parameterisation. The default, tangentHalfAngle
        // (Convert_TgtThetaOver2), gives a rational quadratic with 6 poles for a full circle.
        let bsp = try #require(circle.toBSpline())
        #expect(bsp.poleCount == 6)
        #expect(bsp.degree == 2)
    }

    @Test("Split BSpline to Beziers")
    func bsplineToBeziers() throws {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
        let bsp = circle.toBSpline()!
        // #1979: `count >= 2` passed a split that dropped one of the three arcs
        // Geom2dConvert_BSplineCurveToBezierCurve gives for this curve.
        let beziers = try #require(bsp.toBezierSegments())
        #expect(beziers.count == 3)
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
            // The corner (5, 5) sits at the middle of the joined parameter range.
            let d = joined.domain
            let mid = joined.point(at: (d.lowerBound + d.upperBound) / 2)
            #expect(simd_distance(mid, SIMD2(5, 5)) < 1e-9)
        }
    }

    @Test("All projections of point onto ellipse")
    func allProjectionsEllipse() throws {
        let ellipse = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)!
        // A point at origin projects to multiple points on the ellipse
        let projs = ellipse.allProjections(of: SIMD2(0, 0))
        // #1979: `count >= 1` passed a result missing three of the four normals from the centre.
        // Geom2dAPI_ProjectPointOnCurve gives the four axis ends: distances 5, 5, 10, 10.
        let distances = projs.map(\.distance).sorted()
        try #require(distances.count == 4)
        #expect(abs(distances[0] - 5) < 1e-9)
        #expect(abs(distances[1] - 5) < 1e-9)
        #expect(abs(distances[2] - 10) < 1e-9)
        #expect(abs(distances[3] - 10) < 1e-9)
    }
}
