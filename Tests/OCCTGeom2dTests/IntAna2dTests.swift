import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: the line-line test allowed 0.1 of slack on an exact (5, 5) inside `if let`; the other two
// only counted points. Each now pins the points IntAna2d_AnaIntersection returns
// (Scripts/repro/766-geom2d-curveset-intana-misc/).
@Suite("IntAna2d Analytical Intersections") struct IntAna2dTests {

    @Test("Intersection of two lines")
    func lineLineIntersection() throws {
        let results = IntAna2d.intersectLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 1),
            line2Point: SIMD2(10, 0), line2Dir: SIMD2(-1, 1))
        try #require(results.count == 1)
        #expect(simd_distance(results[0].point, SIMD2(5, 5)) < 1e-9)
    }

    @Test("Intersection of line and circle")
    func lineCircleIntersection() {
        let results = IntAna2d.intersectLineCircle(
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            circleCenter: SIMD2(5, 3), circleRadius: 5)
        #expect(results.count == 2)
        // y = 0 meets the circle at x = 5 -+ 4.
        let xs = results.map(\.point.x).sorted()
        #expect(xs.count == 2 && abs(xs[0] - 1) < 1e-9 && abs(xs[1] - 9) < 1e-9)
    }

    @Test("Intersection of two circles")
    func circleCircleIntersection() {
        let results = IntAna2d.intersectCircles(
            center1: SIMD2(0, 0), radius1: 5,
            center2: SIMD2(7, 0), radius2: 5)
        #expect(results.count == 2)
        // x = 3.5, y = -+sqrt(25 - 12.25).
        #expect(results.allSatisfy { abs($0.point.x - 3.5) < 1e-9 && abs(abs($0.point.y) - 12.75.squareRoot()) < 1e-9 })
    }
}
