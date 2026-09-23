import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Every expectation is pinned to the value `Geom_Hyperbola` itself reports for A = 5, B = 3 in
/// the XY plane (`Scripts/repro/766-geom-hyperbola/transcript.txt`), where c = sqrt(A^2 + B^2) =
/// sqrt(34). The earlier eccentricity, focal and focus tests asserted only a sign (`> 1`, `> 0`,
/// `x > 0`), which a wrong formula such as `Focal = 2A` satisfies, and every test sat inside
/// `if let`, so a factory returning nil passed them all (#766).
@Suite("Geom_Hyperbola Properties")
struct GeomHyperbola3DTests {
    private static let c = (34.0).squareRoot()

    private func makeHyperbola() -> Curve3D? {
        let h = Curve3D.hyperbola(
            center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 5, minorRadius: 3)
        if h == nil { Issue.record("a 5/3 hyperbola in the XY plane builds") }
        return h
    }

    @Test func hyperbolaRadii() {
        guard let h = makeHyperbola() else { return }
        #expect(abs(h.hyperbolaProperties.majorRadius - 5) < 1e-6)
        #expect(abs(h.hyperbolaProperties.minorRadius - 3) < 1e-6)
    }

    @Test func hyperbolaSetRadii() {
        guard let h = makeHyperbola() else { return }
        #expect(h.hyperbolaProperties.setMajorRadius(8))
        #expect(abs(h.hyperbolaProperties.majorRadius - 8) < 1e-6)
        #expect(h.hyperbolaProperties.setMinorRadius(4))
        #expect(abs(h.hyperbolaProperties.minorRadius - 4) < 1e-6)
    }

    /// e = c / A = sqrt(34) / 5 = 1.16619...
    @Test func hyperbolaEccentricity() {
        guard let h = makeHyperbola() else { return }
        #expect(abs(h.hyperbolaProperties.eccentricity - Self.c / 5) < 1e-12)
    }

    /// `Geom_Hyperbola::Focal` is the distance between the two foci, 2c = 11.6619..., not c.
    @Test func hyperbolaFocal() {
        guard let h = makeHyperbola() else { return }
        #expect(abs(h.hyperbolaProperties.focal - 2 * Self.c) < 1e-12)
    }

    /// The first focus sits on the major axis, +X here, at distance c from the centre.
    @Test func hyperbolaFocus1() {
        guard let h = makeHyperbola() else { return }
        let f = h.hyperbolaProperties.focus1
        #expect(abs(f.x - Self.c) < 1e-12)
        #expect(abs(f.y) < 1e-12)
        #expect(abs(f.z) < 1e-12)
    }

    @Test func hyperbolaAsymptote1() {
        guard let h = makeHyperbola() else { return }
        let a = h.hyperbolaProperties.asymptote1
        // The asymptote passes through the hyperbola's own center, with direction
        // normalize(majorRadius, minorRadius, 0) in the local frame (Y = (B/A)*X).
        #expect(abs(a.position.x) < 1e-6)
        #expect(abs(a.position.y) < 1e-6)
        #expect(abs(a.position.z) < 1e-6)
        let expected = simd_normalize(SIMD3<Double>(5, 3, 0))
        #expect(abs(a.direction.x - expected.x) < 1e-6)
        #expect(abs(a.direction.y - expected.y) < 1e-6)
        #expect(abs(a.direction.z) < 1e-6)
    }
}
