import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: all five nested their assertions in `if let p`; focal and parameter asserted `> 0` and
// focus asserted nothing (`let _ = f`). The values are Geom2d_Parabola's
// (Scripts/repro/766-geom2d-conic-props-sine-lprop/).
//
// What `parabola(focus:direction:focalLength:)` calls the focus is the focus, for a unit
// direction, and the parabola's own axis location is its VERTEX, which sits `focalLength` behind
// the focus along the direction: `OCCTCurve2DCreateParabola` builds the axis at
// `focus - direction * focalLength`. So the factory for focus (0, 0), direction (1, 0), focal 3
// builds the parabola with vertex (-3, 0), and the vertex is what `point(at: 0)` returns, which is
// how these tests read it without trusting the `focus` accessor to say so. OCCT's own
// Geom2d_Parabola_Test.cxx builds one at the origin with focal 4 and finds the focus at (4, 0).
// The last test is the direction that is not a unit vector, where that subtraction is wrong.
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

    /// The factory is right for a unit direction and wrong for any other (#3042).
    ///
    /// `OCCTCurve2DCreateParabola` steps back from the focus by `direction * focalLength` using
    /// the raw components, and then gives the same direction to `gp_Dir2d`, which normalises it.
    /// For direction (3, 4) the vertex lands 5 x 5 = 25 behind the focus instead of 5, so the
    /// focus of the parabola that comes back is (-11, -15) and not the (1, 1) that was asked for.
    /// The unit direction (0.6, 0.8) is the control: the same call is right, the vertex is
    /// (-2, -3), and `parabolaFromCenterDir` is right for either spelling because it goes through
    /// `gce_MakeParab2d`. Today's answer is pinned exactly, and the focus that was asked for is
    /// held in a `withKnownIssue`, so fixing the bridge turns this red until the marker is removed.
    @Test func parabola2DNonUnitDirectionMislocatesTheFocus() throws {
        let unit = try #require(
            Curve2D.parabola(focus: SIMD2(1, 1), direction: SIMD2(0.6, 0.8), focalLength: 5))
        #expect(simd_distance(unit.parabolaProperties.focus, SIMD2(1, 1)) < 1e-9)
        #expect(simd_distance(unit.point(at: 0), SIMD2(-2, -3)) < 1e-9)

        let p = try #require(
            Curve2D.parabola(focus: SIMD2(1, 1), direction: SIMD2(3, 4), focalLength: 5))
        #expect(simd_distance(p.point(at: 0), SIMD2(-14, -19)) < 1e-9)
        #expect(simd_distance(p.parabolaProperties.focus, SIMD2(-11, -15)) < 1e-9)
        withKnownIssue("#3042: the vertex is placed with the unnormalised direction") {
            #expect(simd_distance(p.parabolaProperties.focus, SIMD2(1, 1)) < 1e-9)
        }

        let center = try #require(
            Curve2D.parabolaFromCenterDir(center: SIMD2(1, 1), direction: SIMD2(3, 4), focal: 5))
        #expect(simd_distance(center.point(at: 0), SIMD2(1, 1)) < 1e-9)
        #expect(simd_distance(center.parabolaProperties.focus, SIMD2(4, 5)) < 1e-9)
    }
}
