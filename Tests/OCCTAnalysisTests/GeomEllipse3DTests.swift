import Foundation
import Testing
import simd

@testable import OCCTSwift

// Every expected value below is Geom_Ellipse's own answer for gp_Ax2(origin, +Z), major 10,
// minor 5, measured by Scripts/repro/766-geom-ellipse3d/probe.mm (transcript.txt beside it).
// The construction is `try #require`d rather than `if let`: a nil ellipse used to skip every
// assertion and pass (#1722-#1728).
@Suite("Geom_Ellipse Properties")
struct GeomEllipse3DTests {
    private func makeEllipse() throws -> Curve3D {
        try #require(
            Curve3D.ellipse(
                center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5))
    }

    @Test func ellipseRadii() throws {
        let e = try makeEllipse()
        #expect(abs(e.ellipseProperties.majorRadius - 10) < 1e-6)
        #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-6)
    }

    @Test func ellipseSetRadii() throws {
        let e = try makeEllipse()
        #expect(e.ellipseProperties.setMajorRadius(20))
        #expect(abs(e.ellipseProperties.majorRadius - 20) < 1e-6)
        #expect(e.ellipseProperties.setMinorRadius(8))
        #expect(abs(e.ellipseProperties.minorRadius - 8) < 1e-6)
    }

    @Test func ellipseEccentricity() throws {
        let e = try makeEllipse()
        // sqrt(1 - (5/10)^2); a range check (0 < e < 1) accepted minor/major = 0.5 as well.
        #expect(abs(e.ellipseProperties.eccentricity - 0.86602540378443871) < 1e-9)
    }

    @Test func ellipseFocal() throws {
        let e = try makeEllipse()
        // 2 * sqrt(10^2 - 5^2), the distance between the foci.
        #expect(abs(e.ellipseProperties.focal - 17.320508075688775) < 1e-9)
    }

    @Test func ellipseFoci() throws {
        let e = try makeEllipse()
        let f1 = e.ellipseProperties.focus1
        let f2 = e.ellipseProperties.focus2
        // Focus1 on the positive XAxis, Focus2 its mirror. A symmetry check alone
        // (f1.x + f2.x == 0) accepted two foci both at the origin.
        #expect(abs(f1.x - 8.6602540378443873) < 1e-9)
        #expect(abs(f1.y) < 1e-9)
        #expect(abs(f1.z) < 1e-9)
        #expect(abs(f2.x + 8.6602540378443873) < 1e-9)
        #expect(abs(f2.y) < 1e-9)
        #expect(abs(f2.z) < 1e-9)
    }

    @Test func ellipseParameter() throws {
        let e = try makeEllipse()
        // Semi-latus rectum minor^2 / major = 25 / 10.
        #expect(abs(e.ellipseProperties.parameter - 2.5) < 1e-9)
    }

    @Test func ellipseDirectrix1() throws {
        let e = try makeEllipse()
        let d = e.ellipseProperties.directrix1
        // Directrix1 is the line normal to the XAxis, at distance majorRadius/eccentricity
        // (10 / 0.866..., 11.547...) from the center, on the positive side of the XAxis; its
        // own direction is the ellipse's YAxis (occt-refman Geom_Ellipse::Directrix1). Pinned
        // to the probed value rather than recomputed through the wrapper under test.
        #expect(abs(d.position.x - 11.547005383792515) < 1e-9)
        #expect(abs(d.position.y) < 1e-6)
        #expect(abs(d.position.z) < 1e-6)
        #expect(abs(d.direction.x) < 1e-6)
        #expect(abs(d.direction.y - 1) < 1e-6)
        #expect(abs(d.direction.z) < 1e-6)
    }
}
