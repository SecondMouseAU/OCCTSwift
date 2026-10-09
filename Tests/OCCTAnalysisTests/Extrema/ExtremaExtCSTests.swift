import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtCS Tests")
struct ExtremaExtCSTests {
    @Test func curveSurfaceParallel() {
        // Line parallel to plane
        if let line = Curve3D.line(through: SIMD3(0, 0, 10), direction: SIMD3(1, 0, 0)),
            let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        {
            let result = line.extremaCS(range: -10...10, surface: plane)
            #expect(result.isDone)
            #expect(result.isParallel)
        }
    }

    @Test func curveSurfaceDistance() {
        // Line near a sphere
        if let line = Curve3D.line(through: SIMD3(10, 0, 0), direction: SIMD3(0, 0, 1)),
            let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        {
            let result = line.extremaCS(range: -5...5, surface: sphere)
            #expect(result.isDone)
            if !result.isParallel && result.count >= 1 {
                let pp = line.extremaCSPoint(range: -5...5, surface: sphere, index: 1)
                let dist = pp.squareDistance.squareRoot()
                #expect(dist > 4.0)  // At least 5 away from surface
            }
        }
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
