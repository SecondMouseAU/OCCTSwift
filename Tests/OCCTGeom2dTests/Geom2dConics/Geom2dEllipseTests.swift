import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test nested its assertions in `if let e`; eccentricity and focal asserted `> 0`, and
// focus1 asserted nothing (`let _ = f`). Every value follows from the radii alone, so each is
// derived here and cross-checked against Geom2d_Ellipse for 10 x 5
// (Scripts/repro/766-geom2d-gtrsf-circle-ellipse-spiral/).
//
// Two of the readings are easy to take for something else. `focal` is the distance BETWEEN the
// foci, 2 sqrt(a^2 - b^2), although the header comment on `Geom2d_Ellipse::Focal` says "between
// the center and a focus": the code returns the doubled value and OCCT's own
// Geom2d_Ellipse_Test.cxx pins it ("Focal distance = sqrt(a^2 - b^2) * 2"). And `focus1` is the
// focus on the positive side of the ellipse's own X axis, not a fixed corner of the plane.
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
        // Setting one radius leaves the other alone.
        #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-12)
        #expect(e.ellipseProperties.setMinorRadius(8))
        #expect(abs(e.ellipseProperties.minorRadius - 8) < 1e-12)
        #expect(abs(e.ellipseProperties.majorRadius - 20) < 1e-12)
        // And everything derived from the radii follows them: a = 20, b = 8.
        let eccentricity = (1.0 - 64.0 / 400.0).squareRoot()
        let halfFocal = (400.0 - 64.0).squareRoot()
        #expect(abs(e.ellipseProperties.eccentricity - eccentricity) < 1e-12)
        #expect(abs(e.ellipseProperties.focal - 2 * halfFocal) < 1e-9)
        #expect(simd_distance(e.ellipseProperties.focus1, SIMD2(halfFocal, 0)) < 1e-9)
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

    @Test func ellipse2DPlacedAndRotated() throws {
        // The same 10 x 5 ellipse centred on (3, 4) with its major axis turned to +y. The foci
        // move with the frame, so focus1 is (3, 4 + sqrt 75), and the curve itself says which end
        // is which: u = 0 is the major vertex (3, 14), u = pi/2 the minor vertex on the left of
        // the major axis (3 - 5, 4). focus1 lies on the segment from the centre to the major
        // vertex, sqrt 75 from the centre.
        let e = try #require(
            Curve2D.ellipse(center: SIMD2(3, 4), majorRadius: 10, minorRadius: 5, rotation: .pi / 2)
        )
        #expect(simd_distance(e.point(at: 0), SIMD2(3, 14)) < 1e-9)
        #expect(simd_distance(e.point(at: .pi / 2), SIMD2(-2, 4)) < 1e-9)
        let focus = e.ellipseProperties.focus1
        #expect(simd_distance(focus, SIMD2(3, 4 + 75.0.squareRoot())) < 1e-9)
        #expect(abs(simd_distance(focus, SIMD2(3, 4)) - 75.0.squareRoot()) < 1e-9)
        #expect(abs(e.ellipseProperties.majorRadius - 10) < 1e-12)
        #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-12)
        #expect(abs(e.ellipseProperties.eccentricity - 0.75.squareRoot()) < 1e-12)
        #expect(abs(e.ellipseProperties.focal - 2 * 75.0.squareRoot()) < 1e-9)
    }
}
