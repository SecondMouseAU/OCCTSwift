import Foundation
import Testing

@testable import OCCTSwift

@Suite("BSplineSurface_Extras")
struct BSplineSurfaceExtrasTests {
    // The fixture (a 4x4 point-grid fit, z = (u+v) % 3) lives in `SurfaceTestFixtures.swift`
    // as `makeModThreeGridBSplineSurface()`; see #1254.
    // #766: each test used `if let s`, so a nil fixture passed silently. #2983: the setup is
    // required now, so a nil fixture fails the test by name. The fixture is a non-rational bicubic
    // on [0, 1] x [0, 1]; values below are Geom_BSplineSurface's own, see
    // Scripts/repro/766-bspline-extras-fill-iso/.
    func makeBSplineSurface() throws -> Surface {
        try #require(makeModThreeGridBSplineSurface(), "fixture surface")
    }

    @Test func resolution() throws {
        let s = try makeBSplineSurface()
        let (ur, vr) = s.bsplineResolution(tolerance3d: 0.01)
        // `> 0` passed swapped or rescaled values; the kernel gives distinct u and v figures.
        #expect(abs(ur - 7.0494451571408934e-05) < 1e-15)
        #expect(abs(vr - 6.3129090763518051e-05) < 1e-15)
    }

    @Test func getWeight() throws {
        let s = try makeBSplineSurface()
        let w = s.bsplineWeight(uIndex: 1, vIndex: 1)
        #expect(abs(w - 1.0) < 1e-10)
        // A non-rational surface reads 1 everywhere, so that alone cannot tell a weight getter
        // from a constant. The cylinder-derived rational surface (6 x 2 poles, measured) has
        // weights 1, 0.5, 1 down the first column and 1 at (1, 2), so the index order is pinned.
        let cyl = try #require(makeCylinderDerivedBSplineSurface(), "rational fixture")
        #expect(abs(cyl.bsplineWeight(uIndex: 1, vIndex: 1) - 1.0) < 1e-12)
        #expect(abs(cyl.bsplineWeight(uIndex: 2, vIndex: 1) - 0.5) < 1e-12)
        #expect(abs(cyl.bsplineWeight(uIndex: 2, vIndex: 2) - 0.5) < 1e-12)
        #expect(abs(cyl.bsplineWeight(uIndex: 3, vIndex: 1) - 1.0) < 1e-12)
    }

    @Test func setUPeriodic() throws {
        let s = try makeBSplineSurface()
        // Clearing periodicity on a non-periodic surface is a no-op the kernel accepts: true,
        // still non-periodic, geometry unchanged.
        let before = s.point(atU: 0.3, v: 0.6)
        #expect(s.bsplineSetUPeriodic(false))
        #expect(!s.isUPeriodic)
        #expect(s.point(atU: 0.3, v: 0.6) == before)
        #expect(
            vectorLength(
                before - SIMD3(2.4704944722029167, 5.4660517833716957, 0.4728327067804845))
                < 1e-12)
        // The control that the call does something: a periodic surface (the cylinder-derived
        // one is periodic in U, measured) is made non-periodic by the same call.
        let cyl = try #require(makeCylinderDerivedBSplineSurface(), "periodic fixture")
        #expect(cyl.isUPeriodic)
        #expect(cyl.bsplineSetUPeriodic(false))
        #expect(!cyl.isUPeriodic)
    }

    @Test func setVPeriodic() throws {
        let s = try makeBSplineSurface()
        let before = s.point(atU: 0.3, v: 0.6)
        #expect(s.bsplineSetVPeriodic(false))
        #expect(!s.isVPeriodic)
        #expect(s.point(atU: 0.3, v: 0.6) == before)
        #expect(
            vectorLength(
                before - SIMD3(2.4704944722029167, 5.4660517833716957, 0.4728327067804845))
                < 1e-12)
        // The control that the call does something: asking for V periodicity flips the flag
        // (measured: true, and the surface is re-parametrised, so the point at (0.3, 0.6) moves).
        let t = try makeBSplineSurface()
        #expect(t.bsplineSetVPeriodic(true))
        #expect(t.isVPeriodic)
        #expect(
            vectorLength(
                t.point(atU: 0.3, v: 0.6)
                    - SIMD3(2.4704944722029167, 3.5220517833716967, 0.4728327067804845)) < 1e-12)
    }
}
