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
        // #766: ShapeAnalysis_Surface finds exactly the two poles.
        #expect(sphere.singularityCount() == 2)
    }

    @Test("Cylinder has no singularities")
    func cylinderSingularities() {
        let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)!
        #expect(!cyl.hasSingularities())
        #expect(cyl.singularityCount() == 0)
    }

    @Test("Degeneration check at sphere pole")
    func degenerationAtPole() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        // North pole
        let isDeg = sphere.isDegenerated(at: SIMD3(0, 0, 5), tolerance: 0.1)
        // #766: was `_ = isDeg`, asserting nothing. ShapeAnalysis_Surface::IsDegenerated reports
        // the north pole degenerate; a point on the equator is not.
        #expect(isDeg)
        #expect(!sphere.isDegenerated(at: SIMD3(5, 0, 0), tolerance: 0.1))
    }
}
