import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2d_Hyperbola Properties")
struct Geom2dHyperbolaTests {
    @Test func hyperbola2DRadii() {
        if let h = Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3) {
            #expect(abs(h.hyperbolaProperties.majorRadius - 5) < 1e-6)
            #expect(abs(h.hyperbolaProperties.minorRadius - 3) < 1e-6)
        }
    }

    @Test func hyperbola2DEccentricity() {
        if let h = Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3) {
            #expect(h.hyperbolaProperties.eccentricity > 1)
        }
    }

    @Test func hyperbola2DFocal() {
        if let h = Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3) {
            #expect(h.hyperbolaProperties.focal > 0)
        }
    }

    @Test func hyperbola2DFocus1() {
        if let h = Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3) {
            let f = h.hyperbolaProperties.focus1
            #expect(f.x > 0)
        }
    }
}
