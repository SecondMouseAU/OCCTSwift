import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Bisector_BisecAna") struct BisectorBisecAnaTests {
    @Test("Bisector between two lines")
    func curveCurveBisector() throws {
        // #1979: `!= nil` passed any curve at all, including the input line handed back. Pinned
        // to what Bisector_BisecAna returns (Scripts/repro/766-geom2d-batch-bisector/): a line
        // starting at the reference point (1, 1) along (-1, 1)/sqrt(2), the direction of the
        // y = -x bisector it gives for a reference point at the lines' common point.
        let l1 = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        let l2 = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(0, 1)))
        let bisector = try #require(
            l1.bisector(
                with: l2,
                referencePoint: SIMD2(1, 1),
                direction1: SIMD2(1, 0), direction2: SIMD2(0, 1)))
        #expect(simd_distance(bisector.point(at: 0), SIMD2(1, 1)) < 1e-9)
        #expect(simd_distance(bisector.point(at: 1), SIMD2(0.292893218813, 1.70710678119)) < 1e-9)
    }

    @Test("Bisector between two points")
    func pointPointBisector() throws {
        // #1979: `!= nil` passed a bisector of the wrong points. The perpendicular bisector of
        // (0, 0) and (10, 0) is x = 5, which Bisector_BisecAna parametrises from (5, 0) upward.
        let bisector = try #require(
            Curve2D.bisectorBetweenPoints(
                SIMD2(0, 0), SIMD2(10, 0),
                referencePoint: SIMD2(5, 0),
                direction1: SIMD2(1, 0), direction2: SIMD2(-1, 0)))
        #expect(simd_distance(bisector.point(at: 0), SIMD2(5, 0)) < 1e-9)
        #expect(simd_distance(bisector.point(at: 5), SIMD2(5, 5)) < 1e-9)
    }
}
