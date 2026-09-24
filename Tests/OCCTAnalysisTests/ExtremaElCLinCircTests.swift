import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElC Line-Circle")
struct ExtremaElCLinCircTests {
    /// A line 10 above the circle's plane, crossing over its centre. `Extrema_ExtElC` reports
    /// four extrema: the two minima above (+-5, 0), squared distance 10^2 = 100, and the two
    /// stationary points above (0, +-5), 10^2 + 5^2 = 125. Probed in
    /// `Scripts/repro/766-extrema-elc-lin-circ/transcript.txt`. The earlier form asserted only
    /// `count > 0`, which any wrong distance satisfied (#766).
    @Test func lineCircleDistance() {
        let results = ExtremaElC.lineToCircle(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(1, 0, 0),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count == 4)
        let squares = results.map(\.squareDistance).sorted()
        #expect(squares.count == 4)
        for (got, want) in zip(squares, [100.0, 100.0, 125.0, 125.0]) {
            #expect(abs(got - want) < 1e-9)
        }
        // Each result pairs a line point with the circle point directly beneath it.
        for r in results {
            #expect(abs(r.point1.z - 10) < 1e-9)
            #expect(abs(r.point2.z) < 1e-9)
            #expect(abs(simd_length(r.point2) - 5) < 1e-9)
            #expect(abs(simd_distance_squared(r.point1, r.point2) - r.squareDistance) < 1e-9)
        }
    }

    /// A line in the circle's own plane, 10 from its centre: the near extremum is 5 away
    /// (squared 25) at (5, 0, 0) and the far one 15 away (squared 225) at (-5, 0, 0).
    @Test func lineCircleCoplanar() {
        let results = ExtremaElC.lineToCircle(
            linePoint: SIMD3(10, 0, 0), lineDir: SIMD3(0, 1, 0),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count == 2)
        let nearest = results.min { $0.squareDistance < $1.squareDistance }
        let farthest = results.max { $0.squareDistance < $1.squareDistance }
        guard let nearest, let farthest else {
            Issue.record("a coplanar line and circle have extrema")
            return
        }
        #expect(abs(nearest.squareDistance - 25) < 1e-9)
        #expect(simd_distance(nearest.point1, SIMD3(10, 0, 0)) < 1e-9)
        #expect(simd_distance(nearest.point2, SIMD3(5, 0, 0)) < 1e-9)
        #expect(abs(farthest.squareDistance - 225) < 1e-9)
        #expect(simd_distance(farthest.point1, SIMD3(10, 0, 0)) < 1e-9)
        #expect(simd_distance(farthest.point2, SIMD3(-5, 0, 0)) < 1e-9)
    }

    /// A line coincident with the circle's own axis (#1501): `Extrema_ExtElC` reports
    /// `IsParallel()`, a degenerate case with a well-defined constant distance (the circle's own
    /// radius), which the bridge used to discard and return an empty array for.
    @Test func lineOnCircleAxisReturnsRadius() {
        let results = ExtremaElC.lineToCircle(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(0, 0, 1),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count == 1)
        if let first = results.first {
            #expect(abs(first.squareDistance - 25) < 1e-6)
            #expect(abs(first.squareDistance.squareRoot() - 5) < 1e-6)
        }
    }
}
