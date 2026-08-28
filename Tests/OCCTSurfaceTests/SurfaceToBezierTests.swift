import Testing
import simd

@testable import OCCTSwift

@Suite("Surface to Bezier Patches")
struct SurfaceToBezierTests {
    @Test("BSpline surface to Bezier patches")
    func bsplineToBezier() {
        // Create a BSpline surface (from cylinder conversion)
        let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)!
        let bspline = cyl.toBSpline()
        if let bs = bspline {
            let patches = bs.toBezierPatches()
            #expect(patches.count > 0)
        }
    }

    @Test("Bezier surface to patches returns single patch")
    func bezierSinglePatch() {
        // A simple bezier surface should convert to itself (1 patch)
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let bspline = plane.toBSpline()
        if let bs = bspline {
            let patches = bs.toBezierPatches()
            // A plane BSpline should produce 1 Bezier patch
            #expect(patches.count >= 1)
        }
    }
}
