import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElC Circle-Circle")
struct ExtremaElCCircCircTests {
    /// Two radius-5 circles 20 apart on the X axis: `Extrema_ExtElC` reports four extrema, the
    /// pairs of points on the X axis, at square distances 100, 400, 400 and 900
    /// (`Scripts/repro/766-edge-distance-elc/`). `count > 0` passed any wrong distance.
    @Test func coplanarCircles() throws {
        let results = ExtremaElC.circleToCircle(
            center1: SIMD3(0, 0, 0), normal1: SIMD3(0, 0, 1), radius1: 5,
            center2: SIMD3(20, 0, 0), normal2: SIMD3(0, 0, 1), radius2: 5
        )
        #expect(results.count == 4)
        let sq = results.map(\.squareDistance).sorted()
        let expected: [Double] = [100, 400, 400, 900]
        if sq.count == expected.count {
            for (a, b) in zip(sq, expected) { #expect(abs(a - b) < 1e-9) }
        }
        let near = try #require(results.min(by: { $0.squareDistance < $1.squareDistance }))
        // Two separated circles are not the degenerate branch, so both witnesses are present
        // (#2993): a `nil` here is a failure rather than a case to skip.
        #expect(!near.isParallel)
        #expect(abs(try #require(near.point1).x - 5) < 1e-9)
        #expect(abs(try #require(near.point2).x - 15) < 1e-9)
    }

    /// Coaxial, coplanar (concentric) circles (#1501): `Extrema_ExtElC` reports `IsParallel()`, a
    /// degenerate case with a well-defined constant distance (the radii's absolute difference),
    /// which the bridge used to discard and return an empty array for.
    ///
    /// Every point of the inner circle is 2 from the point of the outer one beside it, so no pair
    /// is the extremum and OCCT computes none: `myPoint` is left default-constructed and the
    /// bridge used to report that as `(0, 0, 0)`, a point 5 and 3 from the two circles rather
    /// than 2 from either. Since #2993 both witnesses are `nil` and ``ExtremaResult/isParallel``
    /// says why.
    @Test func coaxialCirclesReturnRadiusDifference() throws {
        let results = ExtremaElC.circleToCircle(
            center1: SIMD3(0, 0, 0), normal1: SIMD3(0, 0, 1), radius1: 5,
            center2: SIMD3(0, 0, 0), normal2: SIMD3(0, 0, 1), radius2: 3
        )
        #expect(results.count == 1)
        let first = try #require(results.first)
        #expect(abs(first.squareDistance - 4) < 1e-6)
        #expect(abs(first.squareDistance.squareRoot() - 2) < 1e-6)
        #expect(first.isParallel, "two coaxial circles are the degenerate branch")
        #expect(first.point1 == nil, "point1 is \(String(describing: first.point1))")
        #expect(first.point2 == nil, "point2 is \(String(describing: first.point2))")
    }
}
