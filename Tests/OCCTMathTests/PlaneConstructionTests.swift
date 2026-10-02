import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `GC_MakePlane`, asserted on the plane it produced rather than on the handle.
///
/// Both tests used to end at `#expect(surf.handle != nil)`, always true for a non-optional
/// `OCCTSurfaceRef` (#3018). A plane's content is its equation, so each test now evaluates
/// `Ax + By + Cz + D` at the points that defined it, **and** at one point deliberately off the
/// plane. The off-plane control is what rules out the degenerate pass: an all-zero coefficient
/// tuple satisfies every on-plane check and nothing else.
@Suite("GC_MakePlane")
struct PlaneConstructionTests {

    /// Distance from `point` to the plane, using the normalised `(A, B, C, D)` OCCT returns.
    private func distance(from point: SIMD3<Double>, to surface: Surface) -> Double {
        let c = surface.planeProperties.coefficients
        return abs(c.a * point.x + c.b * point.y + c.c * point.z + c.d)
    }

    @Test("Plane from 3 points")
    func fromPoints() throws {
        let p1 = SIMD3(0.0, 0.0, 0.0)
        let p2 = SIMD3(10.0, 0.0, 0.0)
        let p3 = SIMD3(0.0, 10.0, 0.0)
        let surf = try #require(Surface.planeFromPoints(p1, p2, p3))
        #expect(surf.isPlane)
        #expect(distance(from: p1, to: surf) < 1e-9)
        #expect(distance(from: p2, to: surf) < 1e-9)
        #expect(distance(from: p3, to: surf) < 1e-9)
        // The control: a point 7 above the z = 0 plane is 7 away from it.
        #expect(abs(distance(from: SIMD3(0, 0, 7), to: surf) - 7) < 1e-9)
        // Three points in the z = 0 plane can only produce a plane normal to Z.
        #expect(abs(abs(simd_dot(surf.planeProperties.pln.normal, SIMD3(0, 0, 1))) - 1) < 1e-9)
    }

    @Test("Plane from point and normal")
    func fromPointNormal() throws {
        let origin = SIMD3(5.0, 5.0, 5.0)
        let normal = SIMD3(1.0, 1.0, 1.0)
        let surf = try #require(Surface.planeFromPointNormal(point: origin, normal: normal))
        #expect(surf.isPlane)
        #expect(simd_length(surf.planeProperties.pln.origin - origin) < 1e-9)
        // OCCT normalises the direction it was handed.
        #expect(simd_length(surf.planeProperties.pln.normal - simd_normalize(normal)) < 1e-9)
        #expect(distance(from: origin, to: surf) < 1e-9)
        // The control: 2 along the unit normal is 2 off the plane, and 2 across it is still on.
        let unit = simd_normalize(normal)
        #expect(abs(distance(from: origin + 2 * unit, to: surf) - 2) < 1e-9)
        let across = simd_normalize(simd_cross(unit, SIMD3(0.0, 0.0, 1.0)))
        #expect(distance(from: origin + 2 * across, to: surf) < 1e-9)
    }
}
