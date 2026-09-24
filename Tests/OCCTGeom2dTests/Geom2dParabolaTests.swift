import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: all five nested their assertions in `if let p`; focal and parameter asserted `> 0` and
// focus asserted nothing (`let _ = f`). Values from Geom2d_Parabola
// (Scripts/repro/766-geom2d-conic-props-sine-lprop/).
@Suite("Geom2d_Parabola Properties")
struct Geom2dParabolaTests {
    private func make() throws -> Curve2D {
        try #require(Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 3))
    }

    @Test func parabola2DFocal() throws {
        let p = try make()
        #expect(abs(p.parabolaProperties.focal - 3) < 1e-12)
    }

    @Test func parabola2DSetFocal() throws {
        // SetFocal keeps the vertex (-3, 0), so the focus moves to (2, 0).
        let p = try make()
        #expect(p.parabolaProperties.setFocal(5))
        #expect(abs(p.parabolaProperties.focal - 5) < 1e-12)
        #expect(simd_distance(p.parabolaProperties.focus, SIMD2(2, 0)) < 1e-12)
    }

    @Test func parabola2DFocus() throws {
        let p = try make()
        #expect(simd_length(p.parabolaProperties.focus) < 1e-12)
    }

    @Test func parabola2DEccentricity() throws {
        let p = try make()
        #expect(abs(p.parabolaProperties.eccentricity - 1.0) < 1e-12)
    }

    @Test func parabola2DParameter() throws {
        // The semi-latus rectum, 2 x focal.
        let p = try make()
        #expect(abs(p.parabolaProperties.parameter - 6) < 1e-12)
    }
}
