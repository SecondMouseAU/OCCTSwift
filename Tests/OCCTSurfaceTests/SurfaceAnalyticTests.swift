import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Surface Tests (v0.20.0)

@Suite("Surface Analytic Primitives")
struct SurfaceAnalyticTests {
    @Test("Create plane and evaluate point")
    func planeEvaluation() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let dom = plane.domain
        // Plane is infinite, domain should be very large
        #expect(dom.uMin < -1e5)

        // Evaluate at (0, 0) should give origin
        let p = plane.point(atU: 0, v: 0)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y) < 1e-10)
        #expect(abs(p.z) < 1e-10)
    }

    @Test("Plane normal is consistent")
    func planeNormal() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let n = plane.normal(atU: 0, v: 0)
        #expect(n != nil)
        if let n = n {
            #expect(abs(abs(n.z) - 1.0) < 1e-10)
        }
    }

    @Test("Create sphere and check properties")
    func sphereProperties() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        // Sphere is U-periodic (wraps around) and V-closed (pole to pole)
        #expect(sphere.isUPeriodic == true)
        let period = sphere.uPeriod
        #expect(period != nil)
        if let period = period {
            #expect(abs(period - 2 * .pi) < 1e-10)
        }
    }

    @Test("Sphere point evaluation")
    func sphereEvaluation() {
        let r: Double = 5
        let sphere = Surface.sphere(center: .zero, radius: r)!
        // At u=0, v=0 → should be on equator at (r, 0, 0) in standard parametrization
        let p = sphere.point(atU: 0, v: 0)
        let dist = simd_length(p)
        #expect(abs(dist - r) < 1e-10)
    }

    @Test("Create cylinder")
    func cylinderCreation() {
        let cyl = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 3)
        #expect(cyl != nil)
        if let cyl = cyl {
            #expect(cyl.isUPeriodic == true)
            let p = cyl.point(atU: 0, v: 0)
            // At u=0, v=0 should be at radius distance from Z axis
            let rDist = sqrt(p.x * p.x + p.y * p.y)
            #expect(abs(rDist - 3.0) < 1e-10)
        }
    }

    @Test("Create cone")
    func coneCreation() {
        let cone = Surface.cone(
            origin: .zero, axis: SIMD3(0, 0, 1),
            radius: 5, semiAngle: .pi / 6)
        #expect(cone != nil)
    }

    @Test("Create torus")
    func torusCreation() {
        let torus = Surface.torus(
            origin: .zero, axis: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 3)
        #expect(torus != nil)
        if let torus = torus {
            #expect(torus.isUPeriodic == true)
            #expect(torus.isVPeriodic == true)
        }
    }

    @Test("Sphere Gaussian curvature = 1/r²")
    func sphereGaussianCurvature() {
        let r: Double = 5
        let sphere = Surface.sphere(center: .zero, radius: r)!
        let gc = sphere.gaussianCurvature(atU: 0.5, v: 0.3)
        let expected: Double = 1.0 / (r * r)
        if let gc { #expect(abs(gc - expected) < 1e-10) } else { Issue.record("no curvature") }
    }

    @Test("Sphere mean curvature = 1/r")
    func sphereMeanCurvature() {
        let r: Double = 5
        let sphere = Surface.sphere(center: .zero, radius: r)!
        let mc = sphere.meanCurvature(atU: 0.5, v: 0.3)
        let expected: Double = 1.0 / r
        if let mc { #expect(abs(abs(mc) - expected) < 1e-10) } else { Issue.record("no curvature") }
    }

    @Test("Plane Gaussian curvature = 0")
    func planeGaussianCurvature() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        // #595: a plane's Gaussian curvature is 0 and defined, so this asserts a reported 0, not nil.
        let gc = plane.gaussianCurvature(atU: 0, v: 0)
        if let gc {
            #expect(abs(gc) < 1e-10)
        } else {
            Issue.record("a plane has Gaussian curvature 0")
        }
    }

    @Test("Cylinder principal curvatures = (0, 1/r)")
    func cylinderPrincipalCurvatures() {
        let r: Double = 4.0
        let cyl = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: r)!
        let pc = cyl.principalCurvatures(atU: 0.5, v: 1.0)
        #expect(pc != nil)
        if let pc = pc {
            let minK = min(abs(pc.kMin), abs(pc.kMax))
            let maxK = max(abs(pc.kMin), abs(pc.kMax))
            #expect(abs(minK) < 1e-10)  // 0 along axis
            #expect(abs(maxK - 1.0 / r) < 1e-10)  // 1/r around circumference
        }
    }
}
