import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna2d Analytical Intersections") struct IntAna2dTests {
    @Test("Intersection of two lines")
    func lineLineIntersection() {
        let results = IntAna2d.intersectLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 1),
            line2Point: SIMD2(10, 0), line2Dir: SIMD2(-1, 1))
        #expect(results.count == 1)
        if let pt = results.first {
            #expect(abs(pt.point.x - 5) < 0.1)
            #expect(abs(pt.point.y - 5) < 0.1)
        }
    }

    @Test("Intersection of line and circle")
    func lineCircleIntersection() {
        let results = IntAna2d.intersectLineCircle(
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            circleCenter: SIMD2(5, 3), circleRadius: 5)
        #expect(results.count == 2)
    }

    @Test("Intersection of two circles")
    func circleCircleIntersection() {
        let results = IntAna2d.intersectCircles(
            center1: SIMD2(0, 0), radius1: 5,
            center2: SIMD2(7, 0), radius2: 5)
        #expect(results.count == 2)
    }
}
