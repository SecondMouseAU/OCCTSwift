import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomLib IsPlanarSurface Tests")
struct GeomLibIsPlanarSurfaceTests {
    @Test("plane is planar")
    func planeIsPlanar() {
        if let plane = Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)) {
            #expect(plane.isPlanar())
        }
    }

    @Test("get plane from planar surface")
    func getPlane() {
        if let plane = Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)) {
            let result = plane.planarPlane()
            if let r = result {
                #expect(abs(r.origin.z - 3.0) < 1e-6)
                #expect(abs(r.normal.z) > 0.99)
            }
        }
    }

    @Test("cylinder is not planar")
    func cylinderNotPlanar() {
        if let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5) {
            #expect(!cyl.isPlanar())
        }
    }
}

