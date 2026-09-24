import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Every expected box here is the analytic extent of the conic or cone.
///
/// Each matches what `BndLib::Add` returns for the same inputs at tolerance 0
/// (`Scripts/repro/766-bndlib-extra/`). Five of the six tests used to assert only
/// `max >= min` on one or two axes, which a box shifted, scaled or swollen to any size also
/// satisfies (#1749 to #1753).
@Suite("BndLib Extra Tests")
struct BndLibExtraTests {

    /// All six coordinates, within 1e-9, of the box BndLib returned.
    private func expectBounds(
        _ b: AnalyticBounds, min: SIMD3<Double>, max: SIMD3<Double>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            simd_distance(b.min, min) < 1e-9, "min \(b.min), expected \(min)",
            sourceLocation: sourceLocation)
        #expect(
            simd_distance(b.max, max) < 1e-9, "max \(b.max), expected \(max)",
            sourceLocation: sourceLocation)
    }

    @Test func ellipseBounds() {
        let b = BndLib.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            majorRadius: 10, minorRadius: 5)
        expectBounds(b, min: SIMD3(-10, -5, 0), max: SIMD3(10, 5, 0))
    }

    /// Reference radius 5 at v = 0, half-angle 30 degrees, v along the generatrix to 10: the top
    /// circle has radius 5 + 10 sin 30 = 10 at height 10 cos 30.
    @Test func coneBounds() {
        let b = BndLib.cone(
            center: .zero, axis: SIMD3(0, 0, 1),
            semiAngle: .pi / 6, refRadius: 5, vmin: 0, vmax: 10)
        expectBounds(b, min: SIMD3(-10, -10, 0), max: SIMD3(10, 10, 10 * cos(Double.pi / 6)))
    }

    /// The first quadrant of a radius-5 circle.
    @Test func circleArcBounds() {
        let b = BndLib.circleArc(
            center: .zero, normal: SIMD3(0, 0, 1),
            radius: 5, u1: 0, u2: .pi / 2)
        expectBounds(b, min: SIMD3(0, 0, 0), max: SIMD3(5, 5, 0))
    }

    /// The first quadrant of a 10 x 5 ellipse.
    @Test func ellipseArcBounds() {
        let b = BndLib.ellipseArc(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            majorRadius: 10, minorRadius: 5, u1: 0, u2: .pi / 2)
        expectBounds(b, min: SIMD3(0, 0, 0), max: SIMD3(10, 5, 0))
    }

    /// gp_Parab's point at u is (u^2 / 4f, u): for f = 2 and u in [-1, 1], x runs 0 to 1/8.
    @Test func parabolaArcBounds() {
        let b = BndLib.parabolaArc(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            focalDistance: 2, u1: -1, u2: 1)
        expectBounds(b, min: SIMD3(0, -1, 0), max: SIMD3(0.125, 1, 0))
    }

    /// gp_Hypr's point at u is (a cosh u, b sinh u): x from a at u = 0 to a cosh 1, y to +-b sinh 1.
    @Test func hyperbolaArcBounds() {
        let b = BndLib.hyperbolaArc(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            majorRadius: 5, minorRadius: 3, u1: -1, u2: 1)
        expectBounds(
            b, min: SIMD3(5, -3 * sinh(1.0), 0), max: SIMD3(5 * cosh(1.0), 3 * sinh(1.0), 0))
    }
}
