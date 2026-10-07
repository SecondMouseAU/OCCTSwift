import Testing
import simd

@testable import OCCTSwift

@Suite("Surface to Bezier Patches")
struct SurfaceToBezierTests {
    @Test("BSpline surface to Bezier patches")
    func bsplineToBezier() {
        // #766: this converted an UNTRIMMED cylinder; GeomConvert refuses an infinite surface, so
        // toBSpline() was nil and the `if let` skipped the test. A cylinder trimmed to height 10
        // converts to a BSpline that splits into 3 x 1 Bezier patches
        // (Scripts/repro/766-surface-operations-pipe/).
        let cyl = Surface.trimmedCylinder(radius: 5, height: 10)
        #expect(cyl != nil)
        let bspline = cyl?.toBSpline()
        #expect(bspline != nil)
        if let bs = bspline {
            let patches = bs.toBezierPatches()
            #expect(patches.count > 0)
            #expect(patches.count == 3)
        }
    }

    @Test("Bezier surface to patches returns single patch")
    func bezierSinglePatch() {
        // A simple bezier surface should convert to itself (1 patch)
        // #766: same defect, an infinite plane that toBSpline() refused. Trimmed to [-5, 5]^2 it
        // is a single Bezier patch.
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let bspline = plane.trimmed(u1: -5, u2: 5, v1: -5, v2: 5)?.toBSpline()
        #expect(bspline != nil)
        if let bs = bspline {
            let patches = bs.toBezierPatches()
            // A plane BSpline should produce 1 Bezier patch
            #expect(patches.count >= 1)
            #expect(patches.count == 1)
        }
    }
}
