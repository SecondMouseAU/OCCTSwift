import Foundation
import Testing
import simd

@testable import OCCTSwift

/// All six coordinates of an ``AnalyticBounds``, against the analytically derived box.
///
/// The `OCCTBndLib*` bridge functions return `void` and write their six out-parameters, so one
/// that refuses (null handle) or catches leaves the caller's zeroed box untouched and `BndLib`
/// hands back `(0,0,0)-(0,0,0)`. `max >= min` is true of that box and of every box OCCT can
/// build, which is why the whole-box comparison is the assertion and not a per-axis ordering one.
///
/// File-private, and duplicated in `BndLibTests.swift` rather than shared on purpose: a helper
/// living in the other file would leave every test here reading as assertion-free, both to a
/// reader and to `census-766-weak-assertions.py`, which inlines only same-file helpers.
private func expectAnalyticBounds(
    _ b: AnalyticBounds, min: SIMD3<Double>, max: SIMD3<Double>, tolerance: Double = 1e-9,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        simd_distance(b.min, min) < tolerance, "min \(b.min), expected \(min)",
        sourceLocation: sourceLocation)
    #expect(
        simd_distance(b.max, max) < tolerance, "max \(b.max), expected \(max)",
        sourceLocation: sourceLocation)
}

/// Every expected box here is the analytic extent of the conic or cone, derived from OCCT's own
/// parametrisation of the primitive, and confirmed against `BndLib::Add` at tolerance 0 by
/// `Scripts/repro/766-bndlib-extra/`.
///
/// Five of the six tests used to assert only `max >= min` on one or two axes. That holds of every
/// `Bnd_Box` OCCT can construct, and it also holds of the all-zero box each `OCCTBndLib*` bridge
/// function writes when it catches (#1749 to #1753), so those five could not fail on a wrong
/// value at all. `ellipseBounds` pinned four of six coordinates at 0.1 (#1748).
@Suite("BndLib Extra Tests")
struct BndLibExtraTests {

    @Test func ellipseBounds() {
        let b = BndLib.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            majorRadius: 10, minorRadius: 5)
        expectAnalyticBounds(b, min: SIMD3(-10, -5, 0), max: SIMD3(10, 5, 0))
    }

    /// The cone segment's analytic extent from v = 0 to v = 10.
    ///
    /// `gp_Cone`'s point at (u, v) is `loc + (R + v sin a) (cos u X + sin u Y) + v cos a Z`, so a
    /// reference radius of 5 at v = 0 with a half-angle of 30 degrees gives a top circle of
    /// radius 5 + 10 sin 30 = 10, at height 10 cos 30.
    @Test func coneBounds() {
        let b = BndLib.cone(
            center: .zero, axis: SIMD3(0, 0, 1),
            semiAngle: .pi / 6, refRadius: 5, vmin: 0, vmax: 10)
        expectAnalyticBounds(
            b, min: SIMD3(-10, -10, 0), max: SIMD3(10, 10, 10 * cos(Double.pi / 6)))
    }

    /// The first quadrant of a radius-5 circle, so the box is the quadrant's own square.
    @Test func circleArcBounds() {
        let b = BndLib.circleArc(
            center: .zero, normal: SIMD3(0, 0, 1),
            radius: 5, u1: 0, u2: .pi / 2)
        expectAnalyticBounds(b, min: SIMD3(0, 0, 0), max: SIMD3(5, 5, 0))
    }

    /// The first quadrant of a 10 x 5 ellipse.
    @Test func ellipseArcBounds() {
        let b = BndLib.ellipseArc(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            majorRadius: 10, minorRadius: 5, u1: 0, u2: .pi / 2)
        expectAnalyticBounds(b, min: SIMD3(0, 0, 0), max: SIMD3(10, 5, 0))
    }

    /// The parabola arc's analytic extent over u in [-1, 1].
    ///
    /// `gp_Parab`'s point at u is `(u^2 / 4f, u)`, so for f = 2 the x extent runs from 0, at the
    /// apex u = 0 that the range contains, to 1/8, and y is the parameter itself.
    @Test func parabolaArcBounds() {
        let b = BndLib.parabolaArc(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            focalDistance: 2, u1: -1, u2: 1)
        expectAnalyticBounds(b, min: SIMD3(0, -1, 0), max: SIMD3(0.125, 1, 0))
    }

    /// The hyperbola branch's analytic extent over u in [-1, 1].
    ///
    /// `gp_Hypr`'s point at u is `(a cosh u, b sinh u)`, so x runs from a at u = 0 to a cosh 1,
    /// and y from -b sinh 1 to b sinh 1.
    @Test func hyperbolaArcBounds() {
        let b = BndLib.hyperbolaArc(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            majorRadius: 5, minorRadius: 3, u1: -1, u2: 1)
        expectAnalyticBounds(
            b, min: SIMD3(5, -3 * sinh(1.0), 0), max: SIMD3(5 * cosh(1.0), 3 * sinh(1.0), 0))
    }
}
