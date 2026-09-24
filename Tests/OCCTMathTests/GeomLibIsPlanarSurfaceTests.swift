import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomLib IsPlanarSurface Tests")
struct GeomLibIsPlanarSurfaceTests {
    @Test("plane is planar")
    func planeIsPlanar() {
        let plane = try #require(Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)))
        #expect(plane.isPlanar())
    }

    @Test("get plane from planar surface")
    func getPlane() {
        let plane = try #require(Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)))
        let result = try #require(plane.planarPlane())
        #expect(abs(result.origin.z - 3.0) < 1e-6)
        #expect(abs(result.normal.z) > 0.99)
    }

    @Test("cylinder is not planar")
    func cylinderNotPlanar() {
        let cyl = try #require(Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5))
        #expect(!cyl.isPlanar())
    }
}

