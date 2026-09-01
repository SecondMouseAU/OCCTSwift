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
        // Sphere is U-periodic (wraps around). It is NOT V-closed in OCCT's own technical sense
        // (`Geom_SphericalSurface::IsVClosed()` returns False, per its own header comment): the
        // poles at V = -pi/2 and V = +pi/2 are DEGENERATE points, not a matching pair of points at
        // the two ends of the V range the way `IsVClosed()` tests for. #815 found and corrected
        // this comment: it previously said "V-closed (pole to pole)", describing the poles'
        // degeneracy in the colloquial sense of "closed", not the `IsVClosed()` predicate the
        // sibling `isVClosed` property below actually calls.
        #expect(sphere.isUPeriodic == true)
        let period = sphere.uPeriod
        #expect(period != nil)
        if let period = period {
            #expect(abs(period - 2 * .pi) < 1e-10)
        }
    }

    // #815: `isUClosed`/`isVClosed` had no test anywhere in the tree, unlike their siblings
    // `isUPeriodic`/`isVPeriodic` (tested throughout this file) and `isUClosedSA`/`isVClosedSA`
    // (tested elsewhere). Values below are the pinned kernel's own header comments on
    // `Geom_Plane`/`Geom_CylindricalSurface`/`Geom_SphericalSurface`/`Geom_ToroidalSurface`
    // (`IsUClosed`/`IsVClosed`, each documented as an unconditional `Returns True.`/`Returns
    // False.`), not values measured from this bridge.
    @Test("Closure flags (isUClosed/isVClosed) match each analytic surface's own documented answer")
    func closureFlags() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        #expect(plane.isUClosed == false)
        #expect(plane.isVClosed == false)

        if let cyl = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 3) {
            #expect(cyl.isUClosed == true)
            #expect(cyl.isVClosed == false)
        }

        let sphere = Surface.sphere(center: .zero, radius: 5)!
        #expect(sphere.isUClosed == true)
        #expect(sphere.isVClosed == false)

        if let torus = Surface.torus(
            origin: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 3)
        {
            #expect(torus.isUClosed == true)
            #expect(torus.isVClosed == true)
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

    /// #1437: `OCCTSurfaceGetPrincipalCurvatures` had the identical dirMin/dirMax transposition as
    /// its sibling `OCCTFaceGetPrincipalCurvatures` (`OCCTBridge_Properties.mm`), both pairing the
    /// first `CurvatureDirections` output with the wrong curvature. `cylinderPrincipalCurvatures`
    /// above only asserts magnitudes, never directions, so the swap went uncaught here too.
    ///
    /// The cylinder's axis is explicitly `(0, 0, 1)`, so: the minimum-curvature direction (~0,
    /// along the axis) must be near-parallel to Z, and the maximum-curvature direction (~1/r,
    /// circumferential) must lie near the XY plane (Z ~ 0).
    @Test("Cylinder principal curvature directions are not transposed")
    func cylinderPrincipalCurvatureDirectionsNotTransposed() throws {
        let r: Double = 4.0
        let cyl = try #require(Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: r))
        let pc = try #require(cyl.principalCurvatures(atU: 0.5, v: 1.0))

        #expect(
            abs(abs(pc.dirMin.z) - 1.0) < 1e-10,
            "dirMin should be the axial direction (|z| ~ 1), got \(pc.dirMin)"
        )
        #expect(
            abs(pc.dirMax.z) < 1e-10,
            "dirMax should be the circumferential direction (z ~ 0), got \(pc.dirMax)"
        )
    }
}
