import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElC Point-Ellipse")
struct ExtremaExtPElCElipsTests {
    /// #1767: the only assertion used to be `results.count > 0`, which a bridge reporting one
    /// extremum, or the right count at the wrong distances, passed.
    ///
    /// The answer is closed form rather than a recorded kernel output. For the query point
    /// `(10, 0, 0)` and the `a = 5`, `b = 3` ellipse in the z = 0 plane, the squared distance to
    /// the ellipse point `(5 cos t, 3 sin t, 0)` is `(5 cos t - 10)^2 + 9 sin^2 t`, whose
    /// derivative is `sin t * (100 - 32 cos t)`. The right-hand factor is positive for every `t`,
    /// so the stationary points are exactly `t = 0` and `t = pi`: the near vertex `(5, 0, 0)` at
    /// distance 5, and the far vertex `(-5, 0, 0)` at distance 15. Two extrema, 25 and 225.
    @Test func pointToEllipse() throws {
        let results = ExtremaPointCurve.pointToEllipse(
            point: SIMD3(10, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            majorRadius: 5, minorRadius: 3
        )
        #expect(results.count == 2)
        let sorted = results.sorted { $0.squareDistance < $1.squareDistance }
        let nearest = try #require(sorted.first)
        let farthest = try #require(sorted.last)
        // Nearest: the near vertex (5, 0, 0), distance 5.
        #expect(abs(nearest.squareDistance - 25) < 1e-9)
        #expect(simd_distance(nearest.point2, SIMD3(5, 0, 0)) < 1e-9)
        // Farthest: the far vertex (-5, 0, 0), distance 15.
        #expect(abs(farthest.squareDistance - 225) < 1e-9)
        #expect(simd_distance(farthest.point2, SIMD3(-5, 0, 0)) < 1e-9)
        // point1 is the query point on every result, and the reported square distance is the one
        // between the pair the same result reports, not a number arriving beside them.
        for r in sorted {
            #expect(simd_distance(r.point1, SIMD3(10, 0, 0)) < 1e-12)
            #expect(abs(simd_distance_squared(r.point1, r.point2) - r.squareDistance) < 1e-9)
        }
    }
}
