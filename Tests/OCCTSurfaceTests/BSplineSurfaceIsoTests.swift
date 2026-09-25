import Testing
import simd

@testable import OCCTSwift

@Suite("BSplineSurface Iso Curves")
struct BSplineSurfaceIsoTests {

    // #766: both tests asserted only non-nil inside `if let bs`, so a missing BSpline or the
    // wrong iso direction passed. An iso curve must trace the surface: GeomConvert's sphere BSpline
    // gives UIso(pi)(0.3) = S(pi, 0.3) = (-4.7994720789928271, ~0, 1.401808746929577) and
    // VIso(0)(1.0) = S(1.0, 0) = (2.7218159535591542, 4.194248194247792, 0), see
    // Scripts/repro/766-bspline-extras-fill-iso/.
    @Test("UIso returns curve")
    func uIso() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        let bs = sphere?.toBSpline()
        #expect(bs != nil)
        if let bs {
            let bounds = bs.bsplineBounds
            let uMid = (bounds.u1 + bounds.u2) / 2.0
            let iso = bs.bsplineUIso(u: uMid)
            #expect(iso != nil)
            if let iso {
                #expect(simd_length(iso.point(at: 0.3) - bs.point(atU: uMid, v: 0.3)) < 1e-12)
                #expect(simd_length(iso.point(at: 0.3) - SIMD3(-4.7994720789928271, 0, 1.401808746929577)) < 1e-12)
            }
        }
    }

    @Test("VIso returns curve")
    func vIso() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        let bs = sphere?.toBSpline()
        #expect(bs != nil)
        if let bs {
            let bounds = bs.bsplineBounds
            let vMid = (bounds.v1 + bounds.v2) / 2.0
            let iso = bs.bsplineVIso(v: vMid)
            #expect(iso != nil)
            if let iso {
                #expect(simd_length(iso.point(at: 1.0) - bs.point(atU: 1.0, v: vMid)) < 1e-12)
                #expect(simd_length(iso.point(at: 1.0) - SIMD3(2.7218159535591542, 4.194248194247792, 0)) < 1e-12)
            }
        }
    }
}
