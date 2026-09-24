import Testing
import simd

@testable import OCCTSwift

@Suite("BSplineSurface_Extras")
struct BSplineSurfaceExtrasTests {
    // The fixture (a 4x4 point-grid fit, z = (u+v) % 3) lives in `SurfaceTestFixtures.swift`
    // as `makeModThreeGridBSplineSurface()`; see #1254.
    func makeBSplineSurface() -> Surface? {
        let s = makeModThreeGridBSplineSurface()
        // #766: each test used `if let s`, so a nil fixture passed silently; this records an
        // issue instead. The fixture is a non-rational bicubic on [0, 1] x [0, 1]; values below are
        // Geom_BSplineSurface's own, see Scripts/repro/766-bspline-extras-fill-iso/.
        #expect(s != nil, "fixture surface")
        return s
    }

    @Test func resolution() {
        if let s = makeBSplineSurface() {
            let (ur, vr) = s.bsplineResolution(tolerance3d: 0.01)
            // `> 0` passed swapped or rescaled values; the kernel gives distinct u and v figures.
            #expect(abs(ur - 7.0494451571408934e-05) < 1e-15)
            #expect(abs(vr - 6.3129090763518051e-05) < 1e-15)
        }
    }

    @Test func getWeight() {
        if let s = makeBSplineSurface() {
            let w = s.bsplineWeight(uIndex: 1, vIndex: 1)
            #expect(abs(w - 1.0) < 1e-10)
        }
    }

    @Test func setUPeriodic() {
        if let s = makeBSplineSurface() {
            // May or may not succeed depending on surface structure
            // Was `#expect(true)`. Clearing periodicity on a non-periodic surface is a no-op the
            // kernel accepts: true, still non-periodic, geometry unchanged.
            let before = s.point(atU: 0.3, v: 0.6)
            #expect(s.bsplineSetUPeriodic(false))
            #expect(!s.isUPeriodic)
            #expect(s.point(atU: 0.3, v: 0.6) == before)
            #expect(simd_length(before - SIMD3(2.4704944722029167, 5.4660517833716957, 0.4728327067804845)) < 1e-12)
        }
    }

    @Test func setVPeriodic() {
        if let s = makeBSplineSurface() {
            let before = s.point(atU: 0.3, v: 0.6)
            #expect(s.bsplineSetVPeriodic(false))
            #expect(!s.isVPeriodic)
            #expect(s.point(atU: 0.3, v: 0.6) == before)
        }
    }
}
