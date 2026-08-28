import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2d_Parabola Properties")
struct Geom2dParabolaTests {
    @Test func parabola2DFocal() {
        if let p = Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 3) {
            #expect(p.parabolaProperties.focal > 0)
        }
    }

    @Test func parabola2DSetFocal() {
        if let p = Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 3) {
            #expect(p.parabolaProperties.setFocal(5))
            #expect(abs(p.parabolaProperties.focal - 5) < 1e-6)
        }
    }

    @Test func parabola2DFocus() {
        if let p = Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 3) {
            let f = p.parabolaProperties.focus
            let _ = f
        }
    }

    @Test func parabola2DEccentricity() {
        if let p = Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 3) {
            #expect(abs(p.parabolaProperties.eccentricity - 1.0) < 1e-6)
        }
    }

    @Test func parabola2DParameter() {
        if let p = Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 3) {
            #expect(p.parabolaProperties.parameter > 0)
        }
    }
}
