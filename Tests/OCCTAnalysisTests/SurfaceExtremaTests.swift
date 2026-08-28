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
