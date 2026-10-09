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
            // Each patch's corners lie on the radius-5 cylinder (measured: (5, 0, 0) to
            // (-2.5, 4.33, 10) for the first), so a rebuilt radius is caught, not only the count.
            for patch in patches {
                let d = patch.domain
                let a = patch.point(atU: d.uMin, v: d.vMin)
                let b = patch.point(atU: d.uMax, v: d.vMax)
                #expect(abs(simd_length(SIMD2(a.x, a.y)) - 5) < 1e-9)
                #expect(abs(simd_length(SIMD2(b.x, b.y)) - 5) < 1e-9)
            }
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
            // The one patch spans the trim: its corners are (-5, -5, 0) and (5, 5, 0).
            if let patch = patches.first {
                let d = patch.domain
                #expect(
                    simd_length(patch.point(atU: d.uMin, v: d.vMin) - SIMD3(-5, -5, 0)) < 1e-9)
                #expect(simd_length(patch.point(atU: d.uMax, v: d.vMax) - SIMD3(5, 5, 0)) < 1e-9)
            }
        }
    }
}
