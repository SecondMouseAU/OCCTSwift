import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test nested its assertions in `if let e`; eccentricity and focal asserted `> 0`, and
// focus1 asserted nothing (`let _ = f`). Values from Geom2d_Ellipse for 10 x 5
// (Scripts/repro/766-geom2d-gtrsf-circle-ellipse-spiral/).
@Suite("Geom2d_Ellipse Properties")
struct Geom2dEllipseTests {
    private func make() throws -> Curve2D {
        try #require(Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5))
    }

    @Test func ellipse2DRadii() throws {
        let e = try make()
        #expect(abs(e.ellipseProperties.majorRadius - 10) < 1e-12)
        #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-12)
    }

    @Test func ellipse2DSetRadii() throws {
        let e = try make()
        #expect(e.ellipseProperties.setMajorRadius(20))
        #expect(abs(e.ellipseProperties.majorRadius - 20) < 1e-12)
        #expect(e.ellipseProperties.setMinorRadius(8))
        #expect(abs(e.ellipseProperties.minorRadius - 8) < 1e-12)
    }

    @Test func ellipse2DEccentricity() throws {
        // sqrt(1 - b^2/a^2) = sqrt(0.75).
        let e = try make()
        #expect(abs(e.ellipseProperties.eccentricity - 0.75.squareRoot()) < 1e-12)
    }

    @Test func ellipse2DFocal() throws {
        // Distance between the foci: 2 sqrt(a^2 - b^2) = 2 sqrt 75.
        let e = try make()
        #expect(abs(e.ellipseProperties.focal - 2 * 75.0.squareRoot()) < 1e-9)
    }

    @Test func ellipse2DFocus1() throws {
        // Focus should be along major axis, at +sqrt 75.
        let e = try make()
        let f = e.ellipseProperties.focus1
        #expect(simd_distance(f, SIMD2(75.0.squareRoot(), 0)) < 1e-9)
    }
}
