import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1863-#1866: every test here used to sit inside `if let p = Surface.plane(...)`, so a nil plane
// passed all four, and `planeUIso`/`planeVIso` asserted nothing at all (`let _ = iso.domain`). The
// fixture was also the plane through the origin, where the coefficient D is 0 and a bridge that
// never wrote D could not be told from a correct one. The plane below is z = 2 instead, and every
// expected value is the one Geom_Plane reports for it, measured in
// Scripts/repro/766-geom-plane-3d/transcript.txt.

@Suite("Geom_Plane Properties")
struct GeomPlane3DTests {
    /// The plane z = 2: location (0, 0, 2), normal +Z, so its XDirection is +X and YDirection +Y.
    private static func planeZ2() -> Surface? {
        Surface.plane(origin: SIMD3(0, 0, 2), normal: SIMD3(0, 0, 1))
    }

    @Test func planeCoefficients() throws {
        let p = try #require(Self.planeZ2())
        let c = p.planeProperties.coefficients
        // 0x + 0y + 1z - 2 = 0
        #expect(abs(c.a) < 1e-12)
        #expect(abs(c.b) < 1e-12)
        #expect(abs(c.c - 1.0) < 1e-12)
        #expect(abs(c.d - -2.0) < 1e-12)
    }

    @Test func planeUIso() throws {
        let p = try #require(Self.planeZ2())
        let iso = try #require(p.planeProperties.uIso(3))
        // U iso at u = 3: the line through (3, 0, 2) along the plane's YDirection, parameterised by v.
        let p0 = iso.point(at: 0)
        let p1 = iso.point(at: 1)
        #expect(simd_length(p0 - SIMD3(3, 0, 2)) < 1e-12)
        #expect(simd_length((p1 - p0) - SIMD3(0, 1, 0)) < 1e-12)
    }

    @Test func planeVIso() throws {
        let p = try #require(Self.planeZ2())
        let iso = try #require(p.planeProperties.vIso(3))
        // V iso at v = 3: the line through (0, 3, 2) along the plane's XDirection, parameterised by u.
        let p0 = iso.point(at: 0)
        let p1 = iso.point(at: 1)
        #expect(simd_length(p0 - SIMD3(0, 3, 2)) < 1e-12)
        #expect(simd_length((p1 - p0) - SIMD3(1, 0, 0)) < 1e-12)
    }

    @Test func planePln() throws {
        let p = try #require(Self.planeZ2())
        let pln = p.planeProperties.pln
        #expect(simd_length(pln.origin - SIMD3(0, 0, 2)) < 1e-12)
        #expect(simd_length(pln.normal - SIMD3(0, 0, 1)) < 1e-12)
    }
}
