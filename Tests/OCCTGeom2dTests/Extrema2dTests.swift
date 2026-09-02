import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema 2D") struct Extrema2dTests {
    @Test("Distance between parallel lines")
    func parallelLineDistance() {
        let (isParallel, results) = Extrema2d.distanceBetweenLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(0, 10), line2Dir: SIMD2(1, 0))
        #expect(isParallel)
        if let r = results.first {
            #expect(abs(r.distance - 10) < 0.1)
        }
    }

    /// #1494: the parallel-lines branch used to echo each line's raw input origin as the
    /// "closest" point pair, which only happens to be a genuine matched pair when the offset
    /// between the lines is already perpendicular to their shared direction (as
    /// `parallelLineDistance` above is). This fixture's offset is NOT perpendicular to the shared
    /// direction, so the origins (0,0)/(5,3) are 5.83 apart while the reported distance is 3 --
    /// the exact mismatch the issue reports. Every returned point pair must actually be that far
    /// apart, not just report a `squareDistance` that happens to be correct.
    @Test("Parallel line matched points actually achieve the reported distance (#1494)")
    func parallelLineMatchedPointsAchieveReportedDistance() {
        let (isParallel, results) = Extrema2d.distanceBetweenLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(5, 3), line2Dir: SIMD2(1, 0))
        #expect(isParallel)
        guard let r = results.first else {
            Issue.record("Expected at least one extremum for parallel lines")
            return
        }
        #expect(abs(r.distance - 3) < 1e-9)
        let actualDistance = simd_distance(r.point1, r.point2)
        #expect(abs(actualDistance - r.distance) < 1e-9)
    }

    @Test("Distance between line and circle")
    func lineCircleDistance() {
        let results = Extrema2d.distanceBetweenLineAndCircle(
            linePoint: SIMD2(0, 20), lineDir: SIMD2(1, 0),
            circleCenter: SIMD2(0, 0), circleRadius: 5)
        #expect(results.count >= 1)
        if let r = results.first {
            #expect(abs(r.distance - 15) < 0.1)
        }
    }

    @Test("Closest point on circle to external point")
    func pointCircleDistance() {
        let results = Extrema2d.distanceFromPointToCircle(
            point: SIMD2(10, 0),
            circleCenter: SIMD2(0, 0), circleRadius: 5)
        #expect(results.count >= 1)
        // Closest point should be at distance 5 (10 - 5 = 5)
        let minDist = results.map(\.distance).min() ?? 999
        #expect(abs(minDist - 5) < 0.1)
    }

    @Test("Closest point on line to point")
    func pointLineDistance() {
        let results = Extrema2d.distanceFromPointToLine(
            point: SIMD2(5, 5),
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(results.count >= 1)
        if let r = results.first {
            #expect(abs(r.distance - 5) < 0.1)
        }
    }

    @Test("Distance between two curves")
    func curveCurveDistance() {
        let c1 = Curve2D.circle(center: SIMD2(0, 0), radius: 5)
        let c2 = Curve2D.circle(center: SIMD2(20, 0), radius: 5)
        if let c1, let c2 {
            let d1 = c1.domain
            let d2 = c2.domain
            let results = Extrema2d.distanceBetweenCurves(
                c1, first1: d1.lowerBound, last1: d1.upperBound,
                c2, first2: d2.lowerBound, last2: d2.upperBound)
            #expect(results.count >= 1)
            let minDist = results.map(\.distance).min() ?? 999
            #expect(abs(minDist - 10) < 0.1)
        }
    }
}
