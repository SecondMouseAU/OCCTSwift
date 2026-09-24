import Testing
import simd

@testable import OCCTSwift

@Suite("GeomPlate BuildAveragePlane")
struct GeomPlateBuildAveragePlaneTests {
    @Test func planarPoints() {
        let result = Surface.averagePlane(
            points: [
                SIMD3(0, 0, 0), SIMD3(1, 0, 0.1),
                SIMD3(0, 1, 0), SIMD3(1, 1, 0.1),
                SIMD3(0.5, 0.5, 0.05),
            ])
        #expect(result != nil)
        // #766: `umax > umin` passed a uv box whose bounds came back in the wrong order, and the
        // plane itself was never checked. GeomPlate_BuildAveragePlane gives normal
        // (-0.0995, 0, 0.995) through (0.5, 0.5, 0.05) and uv box
        // [-0.502493781056, 0.502493781056] x [-0.5, 0.5], see Scripts/repro/766-offset-plate-helix/.
        if let r = result {
            #expect(r.isPlane)
            #expect(r.uvBox.umax > r.uvBox.umin)
            #expect(simd_length(r.normal - SIMD3(-0.099503719021, 0, 0.99503719021)) < 1e-9)
            #expect(simd_length(r.origin - SIMD3(0.5, 0.5, 0.05)) < 1e-9)
            #expect(abs(r.uvBox.umin + 0.502493781056) < 1e-9 && abs(r.uvBox.umax - 0.502493781056) < 1e-9)
            #expect(abs(r.uvBox.vmin + 0.5) < 1e-9 && abs(r.uvBox.vmax - 0.5) < 1e-9)
        }
    }

    @Test func collinearPoints() {
        let result = Surface.averagePlane(
            points: [SIMD3(0, 0, 0), SIMD3(1, 1, 1), SIMD3(2, 2, 2)])
        // #766: this was `#expect(result != nil || result == nil)`, it could not fail. The kernel
        // does not report three collinear points as a line here: GeomPlate_BuildAveragePlane with
        // nbBound = 3 and tolerance 1e-3 reports IsPlane, normal (-0.408, 0.816, -0.408) through
        // (1, 1, 1), which contains the line. Pinned as the kernel gives it, see Scripts/repro/766-offset-plate-helix/.
        #expect(result != nil)
        if let r = result {
            #expect(r.isPlane && !r.isLine)
            #expect(simd_length(r.normal - SIMD3(-0.408248290464, 0.816496580928, -0.408248290464)) < 1e-9)
            #expect(simd_length(r.origin - SIMD3(1, 1, 1)) < 1e-9)
        }
    }
}
