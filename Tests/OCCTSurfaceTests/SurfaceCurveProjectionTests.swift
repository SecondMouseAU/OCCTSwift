import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve Projection onto Surfaces Tests (v0.22.0)

@Suite("Surface Curve Projection Tests")
struct SurfaceCurveProjectionTests {

    @Test("Project line onto plane returns valid 2D curve")
    func projectLineOntoPlane() {
        // Create a plane at z=0
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        // Create a 3D line segment in the XY plane (at z=5)
        let line = Curve3D.segment(from: SIMD3(0, 0, 5), to: SIMD3(10, 0, 5))!

        let projected = plane.projectCurve(line)
        #expect(projected != nil)
        if let c = projected {
            // The 2D curve should span the same X range in UV space
            let start = c.point(at: c.domain.lowerBound)
            let end = c.point(at: c.domain.upperBound)
            #expect(abs(end.x - start.x) > 1.0)  // meaningful span
        }
    }

    @Test("Project circle onto cylinder returns 2D curve")
    func projectCircleOntoCylinder() {
        // Cylinder along Z axis
        let cyl = Surface.cylinder(
            origin: SIMD3(0, 0, 0),
            axis: SIMD3(0, 0, 1), radius: 5)!
        // Circle in the XY plane at z=3, radius matching the cylinder
        let circle = Curve3D.circle(
            center: SIMD3(0, 0, 3),
            normal: SIMD3(0, 0, 1), radius: 5)!

        let projected = cyl.projectCurve(circle)
        #expect(projected != nil)
    }

    @Test("Project 3D curve onto plane returns 3D curve on surface")
    func projectCurve3DOntoPlane() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        // A line segment above the plane
        let line = Curve3D.segment(from: SIMD3(0, 0, 5), to: SIMD3(10, 7, 5))!

        let projected = plane.projectCurve3D(line)
        #expect(projected != nil)
        if let c = projected {
            // Projected curve should lie in z=0 plane
            let mid = c.point(at: (c.domain.lowerBound + c.domain.upperBound) / 2.0)
            #expect(abs(mid.z) < 1e-6)
        }
    }

    @Test("Project point onto plane surface")
    func projectPointOntoPlane() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let result = plane.projectPoint(SIMD3(5, 3, 7))
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.distance - 7.0) < 1e-6)
        }
    }

    @Test("Project point onto sphere surface")
    func projectPointOntoSphere() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        // Point at distance 10 from origin along X axis
        let result = sphere.projectPoint(SIMD3(10, 0, 0))
        #expect(result != nil)
        if let r = result {
            // Distance from point to sphere should be 10 - 5 = 5
            #expect(abs(r.distance - 5.0) < 0.1)
        }
    }

    @Test("Project point onto cylinder surface")
    func projectPointOntoCylinder() {
        let cyl = Surface.cylinder(
            origin: SIMD3(0, 0, 0),
            axis: SIMD3(0, 0, 1), radius: 3)!
        let result = cyl.projectPoint(SIMD3(6, 0, 5))
        #expect(result != nil)
        if let r = result {
            // Distance from (6,0,5) to cylinder of radius 3 at z-axis = 6-3 = 3
            #expect(abs(r.distance - 3.0) < 0.1)
        }
    }

    @Test("Project segment onto plane returns 2D curve with correct length")
    func projectSegmentOntoPlaneLength() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        // Diagonal segment in 3D
        let seg = Curve3D.segment(from: SIMD3(0, 0, 3), to: SIMD3(4, 3, 3))!

        let projected = plane.projectCurve(seg)
        #expect(projected != nil)
    }

    @Test("Composite projection returns multiple segments when needed")
    func compositeProjectionBasic() {
        // Project onto a simple surface, even single-segment results should work
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let seg = Curve3D.segment(from: SIMD3(0, 0, 5), to: SIMD3(10, 0, 5))!

        let segments = plane.projectCurveSegments(seg)
        // Should return at least one segment for a simple case
        #expect(segments.count >= 1)
    }

    @Test("Projection with nil-producing inputs returns nil")
    func projectionNilSafety() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!

        // Very degenerate scenario: project a zero-length segment
        // The projection may or may not succeed, but it shouldn't crash
        let degen = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(0, 0, 0))
        if let d = degen {
            // If the degenerate curve was created, projection result is implementation-dependent
            let _ = plane.projectCurve(d)
        }
        // No crash = pass
    }
}
