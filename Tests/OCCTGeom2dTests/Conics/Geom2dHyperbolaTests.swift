import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: all four nested their assertions in `if let h`; eccentricity asserted `> 1`, focal `> 0`
// and focus1 `x > 0`, which a wrong hyperbola satisfies. Values from Geom2d_Hyperbola for a = 5,
// b = 3: c = sqrt 34 (Scripts/repro/766-geom2d-conic-props-sine-lprop/).
@Suite("Geom2d_Hyperbola Properties")
struct Geom2dHyperbolaTests {
    private func make() throws -> Curve2D {
        try #require(Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3))
    }

    @Test func hyperbola2DRadii() throws {
        let h = try make()
        #expect(abs(h.hyperbolaProperties.majorRadius - 5) < 1e-12)
        #expect(abs(h.hyperbolaProperties.minorRadius - 3) < 1e-12)
    }

    @Test func hyperbola2DEccentricity() throws {
        let h = try make()
        #expect(abs(h.hyperbolaProperties.eccentricity - 34.0.squareRoot() / 5) < 1e-12)
    }

    @Test func hyperbola2DFocal() throws {
        let h = try make()
        #expect(abs(h.hyperbolaProperties.focal - 2 * 34.0.squareRoot()) < 1e-9)
    }

    @Test func hyperbola2DFocus1() throws {
        let h = try make()
        let f = h.hyperbolaProperties.focus1
        #expect(simd_distance(f, SIMD2(34.0.squareRoot(), 0)) < 1e-9)
    }
}
