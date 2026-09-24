import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Extrema Tests")
struct SurfaceExtremaTests {

    @Test("Sphere surfaces distance")
    func sphereDistance() {
        // Two spheres separated by known distance
        // Sphere1 at origin radius 3, Sphere2 at (20,0,0) radius 5
        // Min distance = 20 - 3 - 5 = 12
        guard let sphere1 = Surface.sphere(center: SIMD3(0, 0, 0), radius: 3),
            let sphere2 = Surface.sphere(center: SIMD3(20, 0, 0), radius: 5)
        else {
            Issue.record("could not build the spheres")
            return
        }
        guard
            let result = sphere1.extrema(
                to: sphere2,
                uvBounds1: (uMin: 0, uMax: 2 * .pi, vMin: -.pi / 2, vMax: .pi / 2),
                uvBounds2: (uMin: 0, uMax: 2 * .pi, vMin: -.pi / 2, vMax: .pi / 2)
            )
        else {
            Issue.record("two disjoint spheres have a nearest pair")
            return
        }
        // Probed: 12.000000001961356, p1 = (3, ~2e-5, ~4e-6), p2 = (15, ~1e-4, ~4e-5).
        // GeomAPI_ExtremaSurfaceSurface converges numerically on spheres, which is where the
        // 1e-3 point tolerance comes from; it is still two orders tighter than the 0.5 this
        // test used before #766, and it now checks y and z as well as x.
        #expect(abs(result.distance - 12.0) < 1e-6, "expected 12, got \(result.distance)")
        #expect(simd_distance(result.point1, SIMD3(3, 0, 0)) < 1e-3, "p1: expected (3,0,0), got \(result.point1)")
        #expect(simd_distance(result.point2, SIMD3(15, 0, 0)) < 1e-3, "p2: expected (15,0,0), got \(result.point2)")
    }

    @Test("Extrema returns nearest points and UV")
    func nearestPointsAndUV() {
        // Two spheres along X, known nearest points
        guard let sphere1 = Surface.sphere(center: SIMD3(0, 0, 0), radius: 4),
            let sphere2 = Surface.sphere(center: SIMD3(30, 0, 0), radius: 6)
        else {
            Issue.record("could not build the spheres")
            return
        }
        guard
            let result = sphere1.extrema(
                to: sphere2,
                uvBounds1: (uMin: 0, uMax: 2 * .pi, vMin: -.pi / 2, vMax: .pi / 2),
                uvBounds2: (uMin: 0, uMax: 2 * .pi, vMin: -.pi / 2, vMax: .pi / 2)
            )
        else {
            Issue.record("two disjoint spheres have a nearest pair")
            return
        }
        // Distance = 30 - 4 - 6 = 20 (probed 20.000000002303583).
        #expect(abs(result.distance - 20.0) < 1e-6, "expected 20, got \(result.distance)")
        #expect(simd_distance(result.point1, SIMD3(4, 0, 0)) < 1e-3, "p1: expected (4,0,0), got \(result.point1)")
        #expect(simd_distance(result.point2, SIMD3(24, 0, 0)) < 1e-3, "p2: expected (24,0,0), got \(result.point2)")

        // The title promises UV and the test before #766 never read it. The near point of
        // sphere1 faces +X, which is u = 0 on the sphere's seam; the search box is [0, 2pi] and
        // the kernel lands on the 2pi alias (probed u1 = 6.28317990...), so compare modulo 2pi.
        // Sphere2's near point faces -X, u = pi. Both lie on the equator, v = 0.
        let u1Wrapped = result.uv1.x.truncatingRemainder(dividingBy: 2 * .pi)
        let u1SeamDistance = min(abs(u1Wrapped), abs(2 * .pi - u1Wrapped))
        #expect(u1SeamDistance < 1e-4, "u1: expected 0 (mod 2pi), got \(result.uv1.x)")
        #expect(abs(result.uv1.y) < 1e-4, "v1: expected 0, got \(result.uv1.y)")
        #expect(abs(result.uv2.x - .pi) < 1e-4, "u2: expected pi, got \(result.uv2.x)")
        #expect(abs(result.uv2.y) < 1e-4, "v2: expected 0, got \(result.uv2.y)")
    }

    @Test("Extrema with nil bounds uses each surface's own full domain (#1543)")
    func nilBoundsUsesFullDomain() {
        // Same geometry as `sphereDistance` above, but with NO uvBounds1/uvBounds2 supplied,
        // exercising the "Uses full surface bounds if nil" fallback the doc comment promises.
        // A full sphere's real domain is u in [0, 2*pi], v in [-pi/2, pi/2], nothing like
        // [0,1]x[0,1]: the true nearest point (toward +X) sits at u ~= 0 (or its periodic
        // alias u ~= 2*pi), which a hardcoded [0,1]x[0,1] fallback can still miss because the
        // algorithm only searches the box it is given. Ground-truthed directly against
        // GeomAPI_ExtremaSurfaceSurface: the correct fallback gives distance 12.0 at
        // p1=(3,0,0)/p2=(15,0,0); the old hardcoded (0,1,0,1) fallback gives distance ~24.29 at
        // completely different points.
        let sphere1 = Surface.sphere(center: SIMD3(0, 0, 0), radius: 3)
        let sphere2 = Surface.sphere(center: SIMD3(20, 0, 0), radius: 5)
        #expect(sphere1 != nil)
        #expect(sphere2 != nil)

        if let sphere1, let sphere2 {
            let result = sphere1.extrema(to: sphere2)
            #expect(result != nil)
            if let result {
                #expect(abs(result.distance - 12.0) < 0.5)
                #expect(abs(result.point1.x - 3.0) < 0.5)
                #expect(abs(result.point2.x - 15.0) < 0.5)
            }
        }
    }

    @Test("Cylinder and sphere distance")
    func cylinderSphereDistance() {
        guard let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5),
            let sphere = Surface.sphere(center: SIMD3(20, 0, 0), radius: 3)
        else {
            Issue.record("could not build the cylinder or the sphere")
            return
        }
        guard
            let result = cyl.extrema(
                to: sphere,
                uvBounds1: (uMin: 0, uMax: 2 * .pi, vMin: 0, vMax: 10),
                uvBounds2: (uMin: 0, uMax: 2 * .pi, vMin: -.pi / 2, vMax: .pi / 2)
            )
        else {
            Issue.record("a cylinder and a disjoint sphere have a nearest pair")
            return
        }
        // Distance = 20 - 5 - 3 = 12, probed exactly 12, at p1 = (5, 0, 0) on the cylinder and
        // p2 = (17, 0, 0) on the sphere. The test before #766 checked only the distance, to 0.5.
        #expect(abs(result.distance - 12.0) < 1e-6, "expected 12, got \(result.distance)")
        #expect(simd_distance(result.point1, SIMD3(5, 0, 0)) < 1e-6, "p1: expected (5,0,0), got \(result.point1)")
        #expect(simd_distance(result.point2, SIMD3(17, 0, 0)) < 1e-6, "p2: expected (17,0,0), got \(result.point2)")
    }
}
