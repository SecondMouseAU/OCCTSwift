import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Surface-Surface Intersection")
struct SurfaceSurfaceIntersectTests {
    @Test("Plane-plane intersection produces line")
    func planePlaneIntersection() {
        // Two planes intersecting at 90 degrees
        let plane1 = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let plane2 = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0))!
        let curves = plane1.intersectionCurves(with: plane2)
        #expect(curves.count == 1)
    }

    @Test("Cylinder-plane intersection produces curves")
    func cylinderPlaneIntersection() {
        let cylinder = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)!
        let plane = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))!
        let curves = cylinder.intersectionCurves(with: plane)
        #expect(curves.count >= 1)
    }

    @Test("Non-intersecting surfaces produce no curves")
    func noIntersection() {
        // Two parallel planes
        let plane1 = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let plane2 = Surface.plane(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1))!
        let curves = plane1.intersectionCurves(with: plane2)
        #expect(curves.isEmpty)
    }

    @Test("Sphere-plane intersection")
    func spherePlaneIntersection() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        let plane = Surface.plane(origin: SIMD3(0, 0, 3), normal: SIMD3(0, 0, 1))!
        let curves = sphere.intersectionCurves(with: plane)
        #expect(curves.count >= 1)
    }
}
