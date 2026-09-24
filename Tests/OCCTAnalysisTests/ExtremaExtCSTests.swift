import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtCS Tests")
struct ExtremaExtCSTests {
    @Test func curveSurfaceParallel() {
        // Line parallel to plane
        guard let line = Curve3D.line(through: SIMD3(0, 0, 10), direction: SIMD3(1, 0, 0)),
            let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        else {
            Issue.record("fixture construction failed")
            return
        }
        let result = line.extremaCS(range: -10...10, surface: plane)
        #expect(result.isDone)
        #expect(result.isParallel)
        // A parallel result carries no point extrema: the bridge leaves the count at 0 there.
        #expect(
            result.count == 0, "a parallel result reports no point extrema, got \(result.count)")
    }

    /// Both line-sphere extrema, pinned to the kernel values.
    ///
    /// The version of this test before #1817 asserted its distance only inside
    /// `if !result.isParallel && result.count >= 1`, so a bridge reporting no extrema passed, and
    /// `dist > 4.0` accepted the far extremum as readily as the near one. The line x = 10 along Z
    /// has two extrema against the r = 5 sphere, both at the line's t = 0: the near point
    /// (5, 0, 0) at distance 5 and the far point (-5, 0, 0) at distance 15, in that order
    /// (Scripts/repro/766-extrema-extcs-tests/transcript.txt).
    @Test func curveSurfaceDistance() {
        guard let line = Curve3D.line(through: SIMD3(10, 0, 0), direction: SIMD3(0, 0, 1)),
            let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        else {
            Issue.record("fixture construction failed")
            return
        }
        let result = line.extremaCS(range: -5...5, surface: sphere)
        #expect(result.isDone)
        #expect(!result.isParallel)
        #expect(result.count == 2, "line-sphere has a near and a far extremum, got \(result.count)")

        let near = line.extremaCSPoint(range: -5...5, surface: sphere, index: 1)
        #expect(
            abs(near.squareDistance - 25) < 1e-9,
            "near extremum at distance 5, got \(near.squareDistance.squareRoot())")
        #expect(simd_distance(near.point1, SIMD3(10, 0, 0)) < 1e-9)
        #expect(simd_distance(near.point2, SIMD3(5, 0, 0)) < 1e-9)

        let far = line.extremaCSPoint(range: -5...5, surface: sphere, index: 2)
        #expect(
            abs(far.squareDistance - 225) < 1e-9,
            "far extremum at distance 15, got \(far.squareDistance.squareRoot())")
        #expect(simd_distance(far.point2, SIMD3(-5, 0, 0)) < 1e-9)
    }

    /// The surface-side point carries both its parameters (#1514).
    ///
    /// The fixture is chosen so neither parameter is zero: a line through (6, 6, 6) along
    /// (1, -1, 0) has its closest approach to the origin at (6, 6, 6) itself, so the nearest
    /// point on a sphere of radius 5 sits at latitude asin(1/sqrt(3)) and longitude pi/4. A
    /// v that was dropped rather than read would reconstruct a point on the equator instead.
    @Test func curveSurfacePointCarriesBothSurfaceParameters() {
        guard
            let line = Curve3D.line(through: SIMD3(6, 6, 6), direction: SIMD3(1, -1, 0)),
            let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        else {
            Issue.record("fixture construction failed")
            return
        }
        let result = line.extremaCS(range: -5...5, surface: sphere)
        #expect(result.isDone)
        guard result.isDone, !result.isParallel, result.count >= 1 else {
            Issue.record("no extremum to read: isDone \(result.isDone), count \(result.count)")
            return
        }

        let pp = line.extremaCSPoint(range: -5...5, surface: sphere, index: 1)

        // Both parameters are genuinely nonzero for this fixture, so a dropped one is visible.
        #expect(abs(pp.u2) > 1e-6)
        #expect(abs(pp.v2) > 1e-6)

        // The parameters are the ones that produce the reported point, which is the whole claim.
        let reconstructed = sphere.point(atU: pp.u2, v: pp.v2)
        #expect(simd_distance(reconstructed, pp.point2) < 1e-6)

        // And the point itself is the expected nearest point, radius 5 along (1, 1, 1).
        let expected = simd_normalize(SIMD3<Double>(1, 1, 1)) * 5.0
        #expect(simd_distance(pp.point2, expected) < 1e-6)
    }
}
