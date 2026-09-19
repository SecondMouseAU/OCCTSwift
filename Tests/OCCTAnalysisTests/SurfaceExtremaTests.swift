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
        let sphere1 = Surface.sphere(center: SIMD3(0, 0, 0), radius: 3)
        let sphere2 = Surface.sphere(center: SIMD3(20, 0, 0), radius: 5)
        #expect(sphere1 != nil)
        #expect(sphere2 != nil)

        if let sphere1, let sphere2 {
            let result = sphere1.extrema(
                to: sphere2,
                uvBounds1: (uMin: 0, uMax: 2 * .pi, vMin: -.pi / 2, vMax: .pi / 2),
                uvBounds2: (uMin: 0, uMax: 2 * .pi, vMin: -.pi / 2, vMax: .pi / 2)
            )
            #expect(result != nil)
            if let result {
                #expect(abs(result.distance - 12.0) < 0.5)
                // Nearest point on sphere1 should be at X~3
                #expect(abs(result.point1.x - 3.0) < 0.5)
                // Nearest point on sphere2 should be at X~15
                #expect(abs(result.point2.x - 15.0) < 0.5)
            }
        }
    }

    @Test("Extrema returns nearest points and UV")
    func nearestPointsAndUV() {
        // Two spheres along X, known nearest points
        let sphere1 = Surface.sphere(center: SIMD3(0, 0, 0), radius: 4)
        let sphere2 = Surface.sphere(center: SIMD3(30, 0, 0), radius: 6)
        #expect(sphere1 != nil)
        #expect(sphere2 != nil)

        if let sphere1, let sphere2 {
            let result = sphere1.extrema(
                to: sphere2,
                uvBounds1: (uMin: 0, uMax: 2 * .pi, vMin: -.pi / 2, vMax: .pi / 2),
                uvBounds2: (uMin: 0, uMax: 2 * .pi, vMin: -.pi / 2, vMax: .pi / 2)
            )
            #expect(result != nil)
            if let result {
                // Distance = 30 - 4 - 6 = 20
                #expect(abs(result.distance - 20.0) < 0.5)
                // Nearest point on sphere1 should be at X~4
                #expect(abs(result.point1.x - 4.0) < 0.5)
                // Nearest point on sphere2 should be at X~24
                #expect(abs(result.point2.x - 24.0) < 0.5)
            }
        }
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
        let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)
        let sphere = Surface.sphere(center: SIMD3(20, 0, 0), radius: 3)
        #expect(cyl != nil)
        #expect(sphere != nil)

        if let cyl, let sphere {
            let result = cyl.extrema(
                to: sphere,
                uvBounds1: (uMin: 0, uMax: 2 * .pi, vMin: 0, vMax: 10),
                uvBounds2: (uMin: 0, uMax: 2 * .pi, vMin: -.pi / 2, vMax: .pi / 2)
            )
            #expect(result != nil)
            if let result {
                // Distance = 20 - 5 - 3 = 12
                #expect(abs(result.distance - 12.0) < 0.5)
            }
        }
    }
}
