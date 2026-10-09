import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("LProp3dSurface")
struct LProp3dSurfaceTests {
    @Test func sphereCurvatures() {
        // Sphere of radius R: Gaussian = 1/R^2, Mean = 1/R
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 10.0)
        if let s = sphere {
            let curvs = s.localCurvatures(u: 0.0, v: 0.5)
            #expect(curvs != nil)
            if let c = curvs {
                #expect(abs(c.gaussian - 1.0 / 100.0) < 1e-4)
                #expect(abs(abs(c.mean) - 1.0 / 10.0) < 1e-4)
            }
        }
    }

    @Test func cylinderCurvatures() {
        // Cylinder of radius R: Gaussian = 0, one principal curvature = 1/R, other = 0
        let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5.0)
        if let s = cyl {
            let curvs = s.localCurvatures(u: 0.0, v: 0.0)
            #expect(curvs != nil)
            if let c = curvs {
                #expect(abs(c.gaussian) < 1e-6)  // Gaussian = 0 for cylinder
            }
        }
    }

    @Test func curvatureDirections() {
        // Cylinder should have non-umbilic curvature directions
        let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5.0)
        if let s = cyl {
            let dirs = s.localCurvatureDirections(u: 0.0, v: 0.0)
            #expect(dirs != nil)
        }
    }
}
