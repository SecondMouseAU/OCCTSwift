import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to the kernel values in Scripts/repro/766-math-geomlib-interp-planar-tool/transcript.txt
// (planeIsPlanar: IsPlanar=1, getPlane: origin (1, 2, 3), normal (0, 0, 1), x (1, 0, 0),
// cylinderNotPlanar: IsPlanar=0). Every setup and result is required, not nested in `if let`:
// a nil surface or a nil plane must fail the test rather than skip its assertions.
@Suite("GeomLib IsPlanarSurface Tests")
struct GeomLibIsPlanarSurfaceTests {
    @Test("plane is planar")
    func planeIsPlanar() throws {
        let plane = try #require(Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)))
        #expect(plane.isPlanar())
    }

    @Test("get plane from planar surface")
    func getPlane() throws {
        let plane = try #require(Surface.plane(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1)))
        let result = try #require(plane.planarPlane())
        #expect(simd_length(result.origin - SIMD3(1, 2, 3)) < 1e-9)
        #expect(simd_length(result.normal - SIMD3(0, 0, 1)) < 1e-9)
        #expect(simd_length(result.xDirection - SIMD3(1, 0, 0)) < 1e-9)
    }

    @Test("cylinder is not planar")
    func cylinderNotPlanar() throws {
        let cyl = try #require(
            Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5))
        #expect(!cyl.isPlanar())
    }
}
