import Foundation
import Testing
import simd

@testable import OCCTSwift

// Every expectation below is derived in closed form from the one ellipse this suite builds,
// `gp_Ax2(origin, +Z)` with major 10 and minor 5, and then confirmed against Geom_Ellipse's own
// answers by Scripts/repro/766-geom-ellipse3d/probe.mm (transcript.txt beside it):
//
//   c            = sqrt(major^2 - minor^2) = sqrt(75) = 8.6602540378443873  (centre to focus)
//   eccentricity = c / major                          = 0.86602540378443871
//   focal        = 2 * c                              = 17.320508075688775
//   focus1       = (+c, 0, 0),  focus2 = (-c, 0, 0)
//   parameter    = minor^2 / major                    = 2.5  (the semi-latus rectum)
//   directrix1   = the line x = major / eccentricity  = 11.547005383792515, along +Y
//
// The construction is `try #require`d rather than `if let`, because a nil ellipse used to skip
// every assertion in the file and leave all seven tests green (#1722-#1728).
@Suite("Geom_Ellipse Properties")
struct GeomEllipse3DTests {
    private static let major = 10.0
    private static let minor = 5.0
    /// Centre-to-focus distance, sqrt(major^2 - minor^2) = sqrt(75).
    private static let focusOffset = (major * major - minor * minor).squareRoot()

    private func makeEllipse() throws -> Curve3D {
        try #require(
            Curve3D.ellipse(
                center: .zero, normal: SIMD3(0, 0, 1),
                majorRadius: Self.major, minorRadius: Self.minor),
            "Curve3D.ellipse returned nil for major 10, minor 5 about +Z")
    }

    @Test func ellipseRadii() throws {
        let e = try makeEllipse()
        #expect(abs(e.ellipseProperties.majorRadius - 10) < 1e-12)
        #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-12)
    }

    @Test func ellipseSetRadii() throws {
        let e = try makeEllipse()
        #expect(e.ellipseProperties.setMajorRadius(20))
        #expect(abs(e.ellipseProperties.majorRadius - 20) < 1e-12)
        // The minor radius is untouched by the major setter.
        #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-12)
        #expect(e.ellipseProperties.setMinorRadius(8))
        #expect(abs(e.ellipseProperties.minorRadius - 8) < 1e-12)
        #expect(abs(e.ellipseProperties.majorRadius - 20) < 1e-12)
    }

    @Test func ellipseEccentricity() throws {
        let e = try makeEllipse()
        // c / major = sqrt(1 - (5/10)^2) = sqrt(3)/2. The old range check (0 < ecc < 1) also
        // accepted minor / major = 0.5, which is a different quantity entirely.
        let expected = Self.focusOffset / Self.major
        #expect(abs(expected - 0.86602540378443871) < 1e-15, "closed form drifted: \(expected)")
        #expect(abs(e.ellipseProperties.eccentricity - expected) < 1e-9)
    }

    @Test func ellipseFocal() throws {
        let e = try makeEllipse()
        // Focal is the distance between the two foci, 2c, not the centre-to-focus distance.
        // The old `> 0` check also accepted Parameter() (2.5) and Eccentricity() (0.866).
        let expected = 2 * Self.focusOffset
        #expect(abs(expected - 17.320508075688775) < 1e-14, "closed form drifted: \(expected)")
        #expect(abs(e.ellipseProperties.focal - expected) < 1e-9)
    }

    @Test func ellipseFoci() throws {
        let e = try makeEllipse()
        let f1 = e.ellipseProperties.focus1
        let f2 = e.ellipseProperties.focus2
        // Focus1 sits on the positive XAxis at +c, Focus2 is its mirror. The old symmetry check
        // (f1.x + f2.x == 0) was equally happy with both foci at the origin.
        #expect(simd_length(f1 - SIMD3(Self.focusOffset, 0, 0)) < 1e-9, "focus1 \(f1)")
        #expect(simd_length(f2 - SIMD3(-Self.focusOffset, 0, 0)) < 1e-9, "focus2 \(f2)")
        // The defining property of the foci, checked against the curve itself: the sum of the
        // distances to a point on the ellipse is 2 * major. Taken at the end of the minor axis,
        // where two foci collapsed onto the origin would give 2 * minor instead.
        let p = e.point(at: .pi / 2)
        #expect(simd_length(p - SIMD3(0, Self.minor, 0)) < 1e-9, "minor-axis point \(p)")
        let sum = simd_length(p - f1) + simd_length(p - f2)
        #expect(abs(sum - 2 * Self.major) < 1e-9, "focal sum \(sum)")
    }

    @Test func ellipseParameter() throws {
        let e = try makeEllipse()
        // The semi-latus rectum, minor^2 / major = 25 / 10. The old `> 0` check also accepted
        // Eccentricity() in its place.
        let expected = Self.minor * Self.minor / Self.major
        #expect(abs(expected - 2.5) < 1e-15, "closed form drifted: \(expected)")
        #expect(abs(e.ellipseProperties.parameter - expected) < 1e-9)
    }

    @Test func ellipseDirectrix1() throws {
        let e = try makeEllipse()
        let d = e.ellipseProperties.directrix1
        // Directrix1 is the line normal to the XAxis at distance major / eccentricity
        // (= major^2 / c = 11.547005383792515) from the centre, on the positive side of the
        // XAxis; its own direction is the ellipse's YAxis (occt-refman Geom_Ellipse::Directrix1).
        // Pinned to the closed form rather than to `majorRadius / eccentricity` read back through
        // the same wrapper pair under test, which turned an eccentricity defect into a directrix
        // failure and would have passed a matched pair of them.
        let expectedX = Self.major * Self.major / Self.focusOffset
        #expect(abs(expectedX - 11.547005383792515) < 1e-14, "closed form drifted: \(expectedX)")
        #expect(abs(d.position.x - expectedX) < 1e-9)
        #expect(abs(d.position.y) < 1e-9)
        #expect(abs(d.position.z) < 1e-9)
        #expect(abs(d.direction.x) < 1e-9)
        #expect(abs(d.direction.y - 1) < 1e-9)
        #expect(abs(d.direction.z) < 1e-9)
    }
}
