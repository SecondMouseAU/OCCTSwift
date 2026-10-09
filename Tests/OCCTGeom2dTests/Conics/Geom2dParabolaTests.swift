import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: all five nested their assertions in `if let p`; focal and parameter asserted `> 0` and
// focus asserted nothing (`let _ = f`). The values are Geom2d_Parabola's
// (Scripts/repro/766-geom2d-conic-props-sine-lprop/).
//
// What `parabola(focus:direction:focalLength:)` calls the focus is the focus, and the parabola's own axis location is its VERTEX, which sits `focalLength` behind
// the focus along the direction: `OCCTCurve2DCreateParabola` builds the axis at
// `focus - unit(direction) * focalLength`. So the factory for focus (0, 0), direction (1, 0), focal 3
// builds the parabola with vertex (-3, 0), and the vertex is what `point(at: 0)` returns, which is
// how these tests read it without trusting the `focus` accessor to say so. OCCT's own
// Geom2d_Parabola_Test.cxx builds one at the origin with focal 4 and finds the focus at (4, 0).
// The last tests are the direction that is not a unit vector, where that subtraction was wrong (#3042).
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
        #expect(simd_distance(p.point(at: 0), SIMD2(-3, 0)) < 1e-12)
    }

    @Test func parabola2DFocus() throws {
        let p = try make()
        #expect(simd_length(p.parabolaProperties.focus) < 1e-12)
        // The vertex is the curve at u = 0, three behind the focus.
        #expect(simd_distance(p.point(at: 0), SIMD2(-3, 0)) < 1e-12)
    }

    @Test func parabola2DEccentricity() throws {
        let p = try make()
        #expect(abs(p.parabolaProperties.eccentricity - 1.0) < 1e-12)
    }

    @Test func parabola2DParameter() throws {
        // The distance from the focus to the directrix, which is the semi-latus rectum, 2 x focal.
        // The curve confirms it: the chord through the focus at right angles to the axis runs to
        // (0, +-6), and u is the local y coordinate, so that is the curve at u = +-parameter.
        let p = try make()
        #expect(abs(p.parabolaProperties.parameter - 6) < 1e-12)
        #expect(simd_distance(p.point(at: 6), SIMD2(0, 6)) < 1e-12)
        #expect(simd_distance(p.point(at: -6), SIMD2(0, -6)) < 1e-12)
    }

    @Test func parabola2DPlacedAndRotated() throws {
        // Focus (2, 3), axis pointing +y, focal 2: the vertex is (2, 1) and the parameter is 4,
        // so the chord through the focus ends at (2 -+ 4, 3). The left-hand end is at u = +4
        // because the local y axis is the axis direction turned a quarter turn anticlockwise.
        let p = try #require(
            Curve2D.parabola(focus: SIMD2(2, 3), direction: SIMD2(0, 1), focalLength: 2))
        #expect(simd_distance(p.parabolaProperties.focus, SIMD2(2, 3)) < 1e-12)
        #expect(simd_distance(p.point(at: 0), SIMD2(2, 1)) < 1e-12)
        #expect(abs(p.parabolaProperties.parameter - 4) < 1e-12)
        #expect(simd_distance(p.point(at: 4), SIMD2(-2, 3)) < 1e-12)
        #expect(simd_distance(p.point(at: -4), SIMD2(6, 3)) < 1e-12)
        // SetFocal(4) keeps the vertex and moves the focus along the axis to (2, 5).
        #expect(p.parabolaProperties.setFocal(4))
        #expect(simd_distance(p.point(at: 0), SIMD2(2, 1)) < 1e-12)
        #expect(simd_distance(p.parabolaProperties.focus, SIMD2(2, 5)) < 1e-12)
    }

    /// The focus is where it was asked for whatever the length of `direction` (#3042).
    ///
    /// `OCCTCurve2DCreateParabola` used to step back from the focus by `direction * focalLength`
    /// using the raw components and then give the same direction to `gp_Dir2d`, which
    /// normalises it. For direction (3, 4) the vertex landed 5 x 5 = 25 behind the focus instead
    /// of 5, so the focus that came back was (-11, -15) and not the (1, 1) that was asked for.
    /// The vertex has to sit `focalLength` behind the focus along the unit direction: (1, 1) minus
    /// 5 x (0.6, 0.8) is (-2, -3), and `parabolaFromCenterDir` places the same curve from that
    /// vertex through `gce_MakeParab2d`.
    @Test func parabola2DNonUnitDirectionPlacesTheFocusWhereAsked() throws {
        let unit = try #require(
            Curve2D.parabola(focus: SIMD2(1, 1), direction: SIMD2(0.6, 0.8), focalLength: 5))
        #expect(simd_distance(unit.parabolaProperties.focus, SIMD2(1, 1)) < 1e-9)
        #expect(simd_distance(unit.point(at: 0), SIMD2(-2, -3)) < 1e-9)

        let p = try #require(
            Curve2D.parabola(focus: SIMD2(1, 1), direction: SIMD2(3, 4), focalLength: 5))
        #expect(simd_distance(p.point(at: 0), SIMD2(-2, -3)) < 1e-9)
        #expect(simd_distance(p.parabolaProperties.focus, SIMD2(1, 1)) < 1e-9)
        #expect(abs(p.parabolaProperties.focal - 5) < 1e-9)

        // The second row of the issue: focus (2, 3), direction (0, 2), focal 1 used to put the
        // focus at (2, 2) and the vertex at (2, 1). The vertex is one behind the focus, (2, 2).
        let up = try #require(
            Curve2D.parabola(focus: SIMD2(2, 3), direction: SIMD2(0, 2), focalLength: 1))
        #expect(simd_distance(up.parabolaProperties.focus, SIMD2(2, 3)) < 1e-9)
        #expect(simd_distance(up.point(at: 0), SIMD2(2, 2)) < 1e-9)

        // A tiny direction is as good as a large one, and the curve is the same parabola.
        for scale in [1e-3, 0.5, 7.0, 1e4] {
            let scaled = try #require(
                Curve2D.parabola(
                    focus: SIMD2(1, 1), direction: SIMD2(0.6, 0.8) * scale, focalLength: 5))
            #expect(simd_distance(scaled.parabolaProperties.focus, SIMD2(1, 1)) < 1e-9, "x\(scale)")
            #expect(simd_distance(scaled.point(at: 3), unit.point(at: 3)) < 1e-9, "x\(scale)")
        }

        // An independent check on the geometry: every point of a parabola is as far from the
        // focus as from the directrix, which is `focal` behind the vertex, so the distance to the
        // focus is the coordinate along the axis from the vertex plus the focal length.
        let axis = SIMD2<Double>(0.6, 0.8)
        for u in [-6.0, -1.5, 0, 2.0, 9.0] {
            let q = p.point(at: u)
            let along = simd_dot(q - SIMD2(-2, -3), axis)
            #expect(abs(simd_distance(q, SIMD2(1, 1)) - (along + 5)) < 1e-9, "u = \(u)")
        }

        let center = try #require(
            Curve2D.parabolaFromCenterDir(center: SIMD2(1, 1), direction: SIMD2(3, 4), focal: 5))
        #expect(simd_distance(center.point(at: 0), SIMD2(1, 1)) < 1e-9)
        #expect(simd_distance(center.parabolaProperties.focus, SIMD2(4, 5)) < 1e-9)
        // The two factories agree on the same curve: the centre form from the vertex (-2, -3).
        let viaCenter = try #require(
            Curve2D.parabolaFromCenterDir(center: SIMD2(-2, -3), direction: SIMD2(3, 4), focal: 5))
        #expect(simd_distance(viaCenter.parabolaProperties.focus, SIMD2(1, 1)) < 1e-9)
        #expect(simd_distance(viaCenter.point(at: 3), p.point(at: 3)) < 1e-9)
    }

    @Test func arcOfParabolaNonUnitDirectionPlacesTheFocusWhereAsked() throws {
        // `OCCTCurve2DCreateArcOfParabola` held the same arithmetic as the factory above.
        let unit = try #require(
            Curve2D.arcOfParabola(
                focus: SIMD2(1, 1), direction: SIMD2(0.6, 0.8), focalLength: 5,
                startParam: -4, endParam: 4))
        let arc = try #require(
            Curve2D.arcOfParabola(
                focus: SIMD2(1, 1), direction: SIMD2(3, 4), focalLength: 5,
                startParam: -4, endParam: 4))
        // The vertex, at u = 0, is (-2, -3) either way, and the arc is the same curve.
        #expect(simd_distance(arc.point(at: 0), SIMD2(-2, -3)) < 1e-9)
        for u in [-4.0, -2.0, 0, 1.0, 4.0] {
            #expect(simd_distance(arc.point(at: u), unit.point(at: u)) < 1e-9, "u = \(u)")
        }
        // Distance to the focus (1, 1) is the axis coordinate from the vertex plus the focal length.
        let axis = SIMD2<Double>(0.6, 0.8)
        for u in [-4.0, 0, 2.5, 4.0] {
            let q = arc.point(at: u)
            let along = simd_dot(q - SIMD2(-2, -3), axis)
            #expect(abs(simd_distance(q, SIMD2(1, 1)) - (along + 5)) < 1e-9, "u = \(u)")
        }
    }

    @Test func parabolaRefusesAZeroDirection() {
        // gp_Dir2d throws on a zero vector; the bridge catches it and refuses.
        #expect(Curve2D.parabola(focus: SIMD2(1, 1), direction: .zero, focalLength: 5) == nil)
        #expect(
            Curve2D.arcOfParabola(
                focus: SIMD2(1, 1), direction: .zero, focalLength: 5, startParam: -1, endParam: 1)
                == nil)
    }
}
