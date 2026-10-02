import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElC Line-Circle")
struct ExtremaElCLinCircTests {
    /// #1916: the only assertion used to be `results.count > 0`, which any wrong distance passed.
    ///
    /// The line is the x axis raised to z = 10; the circle has radius 5 in the z = 0 plane about
    /// the origin. The squared distance from the line point `(t, 0, 10)` to the circle point
    /// `(5 cos u, 5 sin u, 0)` is `(t - 5 cos u)^2 + 25 sin^2 u + 100`. Stationary in `t` at
    /// `t = 5 cos u`, which leaves `25 sin^2 u + 100`, stationary in `u` at `sin u = 0` and at
    /// `cos u = 0`. So four extrema: `(±5, 0, 0)` beneath `(±5, 0, 10)` at 100, and `(0, ±5, 0)`
    /// beneath `(0, 0, 10)` at 125.
    @Test func lineCircleDistance() throws {
        let results = ExtremaElC.lineToCircle(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(1, 0, 0),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count == 4)
        let squares = results.map(\.squareDistance).sorted()
        for (got, want) in zip(squares, [100.0, 100.0, 125.0, 125.0]) {
            #expect(abs(got - want) < 1e-9, "square distances \(squares)")
        }
        // Each result pairs a point on the line with the circle point directly beneath it, and
        // the square distance it reports is the one between that pair. This configuration is not
        // parallel, so both witnesses are present: a `nil` here is a failure, not a skip (#2993).
        for r in results {
            #expect(!r.isParallel)
            let p1 = try #require(r.point1, "a non-parallel extremum has a point on the line")
            let p2 = try #require(r.point2, "a non-parallel extremum has a point on the circle")
            #expect(abs(p1.z - 10) < 1e-9, "p1 \(p1)")
            #expect(abs(p1.y) < 1e-9, "p1 \(p1)")
            #expect(abs(p2.z) < 1e-9, "p2 \(p2)")
            #expect(abs(simd_length(p2) - 5) < 1e-9, "p2 \(p2)")
            #expect(abs(simd_distance_squared(p1, p2) - r.squareDistance) < 1e-9)
        }
    }

    /// #1917: the assertion used to be `results.count > 0` and `abs(first.squareDistance - 25) < 1`,
    /// a tolerance of 1 on 25 read off whichever extremum the kernel happened to append first.
    ///
    /// A line in the circle's own plane, 10 from its centre. Minimising
    /// `(10 - 5 cos u)^2 + (s - 5 sin u)^2` over the line parameter `s` leaves `(10 - 5 cos u)^2`,
    /// stationary only at `sin u = 0`: the near extremum is `(5, 0, 0)`, squared 25, and the far
    /// one `(-5, 0, 0)`, squared 225. The line point is `(10, 0, 0)` for both.
    @Test func lineCircleCoplanar() throws {
        let results = ExtremaElC.lineToCircle(
            linePoint: SIMD3(10, 0, 0), lineDir: SIMD3(0, 1, 0),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count == 2)
        let nearest = try #require(results.min(by: { $0.squareDistance < $1.squareDistance }))
        let farthest = try #require(results.max(by: { $0.squareDistance < $1.squareDistance }))
        #expect(abs(nearest.squareDistance - 25) < 1e-9)
        #expect(simd_distance(try #require(nearest.point1), SIMD3(10, 0, 0)) < 1e-9)
        #expect(simd_distance(try #require(nearest.point2), SIMD3(5, 0, 0)) < 1e-9)
        #expect(abs(farthest.squareDistance - 225) < 1e-9)
        #expect(simd_distance(try #require(farthest.point1), SIMD3(10, 0, 0)) < 1e-9)
        #expect(simd_distance(try #require(farthest.point2), SIMD3(-5, 0, 0)) < 1e-9)
    }

    /// A line coincident with the circle's own axis (#1501): `Extrema_ExtElC` reports
    /// `IsParallel()`, a degenerate case with a well-defined constant distance (the circle's own
    /// radius), which the bridge used to discard and return an empty array for.
    ///
    /// The distance is kept because OCCT's own caller keeps it: `Extrema_ExtCC::PrepareResults`
    /// hands `AlgExt.SquareDistance()` to `PrepareParallelResult` and reads nothing else
    /// (`Extrema_ExtCC.cxx:845-852`). The witnesses are `nil` because OCCT never computes them:
    /// the constructor sets `mySqDist[0]` and `myNbExt = 1` and leaves `myPoint`
    /// default-constructed, so `Points(1, ...)` hands back `(0, 0, 0)`, which here is the
    /// circle's **centre**, a point 5 from every point of the circle. Until #2993 that reached
    /// Swift as a `SIMD3` indistinguishable from a measurement. Measured in
    /// `Scripts/repro/2993-extremaelc-parallel-witnesses/`.
    @Test func lineOnCircleAxisReturnsRadius() throws {
        let results = ExtremaElC.lineToCircle(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(0, 0, 1),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count == 1)
        let first = try #require(results.first)
        #expect(abs(first.squareDistance - 25) < 1e-6)
        #expect(abs(first.squareDistance.squareRoot() - 5) < 1e-6)
        #expect(first.isParallel, "a line on the circle's own axis is the degenerate branch")
        // Not `== nil` as a courtesy: the old value was the circle's centre, and the assertion
        // that would have caught it is this one.
        #expect(first.point1 == nil, "point1 is \(String(describing: first.point1))")
        #expect(first.point2 == nil, "point2 is \(String(describing: first.point2))")
    }
}
