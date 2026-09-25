import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema 2D") struct Extrema2dTests {
    @Test("Distance between parallel lines")
    func parallelLineDistance() throws {
        let (isParallel, results) = Extrema2d.distanceBetweenLines(
            line1Point: SIMD2(0, 0), line1Dir: SIMD2(1, 0),
            line2Point: SIMD2(0, 10), line2Dir: SIMD2(1, 0))
        #expect(isParallel)
        // #1979: `if let` let an empty result pass, and 0.1 of slack sat on an exact 10
        // (Extrema_ExtElC2d; Scripts/repro/766-geom2d-extrema-fillet2d/).
        let r = try #require(results.first)
        #expect(abs(r.distance - 10) < 1e-9)
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
    func lineCircleDistance() throws {
        let results = Extrema2d.distanceBetweenLineAndCircle(
            linePoint: SIMD2(0, 20), lineDir: SIMD2(1, 0),
            circleCenter: SIMD2(0, 0), circleRadius: 5)
        // #1979: `count >= 1` and 0.1 of slack. Extrema_ExtElC2d gives both extrema, 15 and 25.
        let ds = results.map(\.distance).sorted()
        try #require(ds.count == 2)
        #expect(abs(ds[0] - 15) < 1e-9)
        #expect(abs(ds[1] - 25) < 1e-9)
    }

    @Test("Closest point on circle to external point")
    func pointCircleDistance() throws {
        let results = Extrema2d.distanceFromPointToCircle(
            point: SIMD2(10, 0),
            circleCenter: SIMD2(0, 0), circleRadius: 5)
        // Closest point should be at distance 5 (10 - 5 = 5), farthest at 15. #1979: was
        // `count >= 1` with 0.1 of slack.
        let ds = results.map(\.distance).sorted()
        try #require(ds.count == 2)
        #expect(abs(ds[0] - 5) < 1e-9)
        #expect(abs(ds[1] - 15) < 1e-9)
    }

    @Test("Closest point on line to point")
    func pointLineDistance() throws {
        let results = Extrema2d.distanceFromPointToLine(
            point: SIMD2(5, 5),
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        // #1979: one extremum, the foot (5, 0) at distance 5.
        try #require(results.count == 1)
        #expect(abs(results[0].distance - 5) < 1e-9)
        #expect(simd_distance(results[0].point2, SIMD2(5, 0)) < 1e-9)
    }

    @Test("Distance between two curves")
    func curveCurveDistance() throws {
        let c1 = Curve2D.circle(center: SIMD2(0, 0), radius: 5)
        let c2 = Curve2D.circle(center: SIMD2(20, 0), radius: 5)
        // #1979: the check sat inside `if let` with 0.1 of slack. Extrema_ExtCC2d gives all four
        // extrema along the line of centres: 10, 20, 20 and 30.
        let a = try #require(c1)
        let b = try #require(c2)
        let d1 = a.domain
        let d2 = b.domain
        let results = Extrema2d.distanceBetweenCurves(
            a, first1: d1.lowerBound, last1: d1.upperBound,
            b, first2: d2.lowerBound, last2: d2.upperBound)
        let ds = results.map(\.distance).sorted()
        try #require(ds.count == 4)
        for (d, e) in zip(ds, [10.0, 20, 20, 30]) {
            #expect(abs(d - e) < 1e-9)
        }
    }
}
