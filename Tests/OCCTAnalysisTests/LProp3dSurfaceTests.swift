import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values pinned to GeomLProp_SLProps at Precision::Confusion(), the resolution the bridge uses;
// see Scripts/repro/766-lprop-surface-analytic/transcript.txt. OCCT's curvatures are signed
// against the surface normal, which points outward on both fixtures, so a convex surface has
// negative curvature.
@Suite("LProp3dSurface")
struct LProp3dSurfaceTests {
    @Test func sphereCurvatures() throws {
        // Sphere of radius R: Gaussian = 1/R^2, both principal curvatures -1/R, so Mean = -1/R.
        let s = try #require(Surface.sphere(center: SIMD3(0, 0, 0), radius: 10.0))
        let c = try #require(s.localCurvatures(u: 0.0, v: 0.5))
        #expect(abs(c.gaussian - 1.0 / 100.0) < 1e-12)
        #expect(abs(c.mean + 1.0 / 10.0) < 1e-12)
        #expect(abs(c.maxCurvature + 1.0 / 10.0) < 1e-12)
        #expect(abs(c.minCurvature + 1.0 / 10.0) < 1e-12)
    }

    @Test func cylinderCurvatures() throws {
        // Cylinder of radius R: Gaussian = 0, principal curvatures 0 (along the axis) and -1/R
        // (around it), Mean = -1/(2R).
        let s = try #require(
            Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5.0))
        let c = try #require(s.localCurvatures(u: 0.0, v: 0.0))
        #expect(abs(c.gaussian) < 1e-12)
        #expect(abs(c.mean + 0.1) < 1e-12)
        #expect(abs(c.maxCurvature) < 1e-12)
        #expect(abs(c.minCurvature + 0.2) < 1e-12)
    }

    @Test func curvatureDirections() throws {
        // A cylinder is not umbilic: the max-curvature (0) direction runs along the axis and the
        // min-curvature (-1/R) direction wraps around it, +Y at u = 0.
        let s = try #require(
            Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5.0))
        let d = try #require(s.localCurvatureDirections(u: 0.0, v: 0.0))
        #expect(simd_distance(d.maxDirection, SIMD3(0, 0, 1)) < 1e-12)
        #expect(simd_distance(d.minDirection, SIMD3(0, 1, 0)) < 1e-12)
    }
}
