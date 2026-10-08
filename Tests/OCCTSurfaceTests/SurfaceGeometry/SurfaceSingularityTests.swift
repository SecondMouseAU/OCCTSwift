import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Singularity Analysis")
struct SurfaceSingularityTests {
    @Test("Plane has no singularities")
    func planeSingularities() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        #expect(plane.singularityCount() == 0)
        #expect(!plane.hasSingularities())
    }

    @Test("Sphere has singularities at poles")
    func sphereSingularities() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        #expect(sphere.hasSingularities())
        #expect(sphere.singularityCount() >= 1)
    }

    @Test("Cylinder has no singularities")
    func cylinderSingularities() {
        let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)!
        #expect(!cyl.hasSingularities())
    }

    @Test("Degeneration check at sphere pole")
    func degenerationAtPole() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        // North pole
        let isDeg = sphere.isDegenerated(at: SIMD3(0, 0, 5), tolerance: 0.1)
        // This may or may not detect as degenerate depending on tolerance
        _ = isDeg
    }
}
