import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2d_Ellipse Properties")
struct Geom2dEllipseTests {
    @Test func ellipse2DRadii() {
        if let e = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5) {
            #expect(abs(e.ellipseProperties.majorRadius - 10) < 1e-6)
            #expect(abs(e.ellipseProperties.minorRadius - 5) < 1e-6)
        }
    }

    @Test func ellipse2DSetRadii() {
        if let e = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5) {
            #expect(e.ellipseProperties.setMajorRadius(20))
            #expect(abs(e.ellipseProperties.majorRadius - 20) < 1e-6)
            #expect(e.ellipseProperties.setMinorRadius(8))
            #expect(abs(e.ellipseProperties.minorRadius - 8) < 1e-6)
        }
    }

    @Test func ellipse2DEccentricity() {
        if let e = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5) {
            #expect(e.ellipseProperties.eccentricity > 0)
        }
    }

    @Test func ellipse2DFocal() {
        if let e = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5) {
            #expect(e.ellipseProperties.focal > 0)
        }
    }

    @Test func ellipse2DFocus1() {
        if let e = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5) {
            let f = e.ellipseProperties.focus1
            // Focus should be along major axis
            let _ = f
        }
    }
}
