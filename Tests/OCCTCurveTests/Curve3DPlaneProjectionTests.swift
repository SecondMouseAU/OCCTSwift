import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D Plane Projection Tests")
struct Curve3DPlaneProjectionTests {

    @Test("Project segment onto XY plane along Z direction")
    func projectSegmentOntoXYPlane() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 5), to: SIMD3(10, 7, 5))!

        let projected = seg.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(0, 0, 1)
        )
        #expect(projected != nil)
        if let c = projected {
            // Projected curve should lie in z=0 plane
            let start = c.point(at: c.domain.lowerBound)
            let end = c.point(at: c.domain.upperBound)
            #expect(abs(start.z) < 1e-6)
            #expect(abs(end.z) < 1e-6)
            // X and Y should match the original
            #expect(abs(start.x - 0.0) < 1e-6)
            #expect(abs(start.y - 0.0) < 1e-6)
            #expect(abs(end.x - 10.0) < 1e-6)
            #expect(abs(end.y - 7.0) < 1e-6)
        }
    }

    @Test("Project circle onto XY plane preserves shape")
    func projectCircleOntoXYPlane() {
        // Circle at z=10 in XY plane
        let circle = Curve3D.circle(
            center: SIMD3(0, 0, 10),
            normal: SIMD3(0, 0, 1), radius: 5)!

        let projected = circle.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(0, 0, 1)
        )
        #expect(projected != nil)
        if let c = projected {
            // Should still be a circle of radius 5 at z=0
            let pt = c.point(at: c.domain.lowerBound)
            #expect(abs(pt.z) < 1e-6)
            let dist = sqrt(pt.x * pt.x + pt.y * pt.y)
            #expect(abs(dist - 5.0) < 0.1)
        }
    }

    @Test("Project arc onto tilted plane")
    func projectArcOntoTiltedPlane() {
        let arc = Curve3D.arcOfCircle(
            start: SIMD3(5, 0, 0),
            interior: SIMD3(0, 5, 0),
            end: SIMD3(-5, 0, 0)
        )!

        // Project onto XZ plane along Y direction
        let projected = arc.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 1, 0),
            direction: SIMD3(0, 1, 0)
        )
        #expect(projected != nil)
        if let c = projected {
            // All Y coordinates should be zero
            let mid = c.point(at: (c.domain.lowerBound + c.domain.upperBound) / 2.0)
            #expect(abs(mid.y) < 1e-6)
        }
    }

    @Test("Project BSpline onto plane")
    func projectBSplineOntoPlane() {
        let spline = Curve3D.interpolate(points: [
            SIMD3(0, 0, 1),
            SIMD3(3, 5, 2),
            SIMD3(7, 2, 4),
            SIMD3(10, 8, 3),
        ])!

        let projected = spline.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(0, 0, 1)
        )
        #expect(projected != nil)
        if let c = projected {
            // All Z coordinates should be zero
            let pts = c.drawUniform(pointCount: 10)
            for pt in pts {
                #expect(abs(pt.z) < 1e-6)
            }
        }
    }

    @Test("Projected curve preserves parametric consistency")
    func projectedCurveParametricConsistency() {
        let seg = Curve3D.segment(from: SIMD3(2, 3, 8), to: SIMD3(12, 3, 8))!

        let projected = seg.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(0, 0, 1)
        )
        #expect(projected != nil)
        if let c = projected {
            // Start and end should correspond
            let start = c.point(at: c.domain.lowerBound)
            let end = c.point(at: c.domain.upperBound)
            #expect(abs(start.x - 2.0) < 1e-6)
            #expect(abs(end.x - 12.0) < 1e-6)
        }
    }

    @Test("Project segment along oblique direction")
    func projectSegmentObliqueDirection() {
        // Segment at height z=10
        let seg = Curve3D.segment(from: SIMD3(0, 0, 10), to: SIMD3(10, 0, 10))!

        // Project onto z=0 plane at 45-degree angle
        let projected = seg.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(1, 0, 1)  // 45 degrees from vertical
        )
        #expect(projected != nil)
        if let c = projected {
            // Projected curve should be shifted in X due to oblique projection
            let start = c.point(at: c.domain.lowerBound)
            #expect(abs(start.z) < 1e-6)
            // The X shift should be -10 (projected from z=10 along (1,0,1) to z=0)
            #expect(abs(start.x - (-10.0)) < 1e-3)
        }
    }

    @Test("Project onto plane with near-parallel direction returns nil or valid curve")
    func projectNearParallelDirection() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        // Direction nearly in the plane, this may fail gracefully
        // Just ensure no crash
        let _ = seg.projectedOnPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            direction: SIMD3(1, 0, 0.001)
        )
    }
}
