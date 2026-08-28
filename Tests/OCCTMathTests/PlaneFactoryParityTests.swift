import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #421: plane factories are unified (delegate, not reimplement)

/// Four plane factories used to be four independent OCCT call paths for two operations:
/// `planeFromPoints`/`planeFrom3Points` (3-point) and `plane(origin:normal:)`/
/// `planeFromPointNormal` (point+normal). A ground-truth C++ test against the pinned OCCT headers
/// (`GC_MakePlane`, `gce_MakePln`) confirmed the two 3-point algorithm classes agree on every case
/// tried, well-separated points, collinear-but-distinct points (both evenly and unevenly
/// spaced), one coincident pair, and all three points coincident, and that `GC_MakePlane`'s
/// point+normal overload adds no check beyond `gp_Dir`'s own zero-length guard, matching the raw
/// `Geom_Plane` constructor exactly. `planeFrom3Points`/`plane(origin:normal:)` now delegate to
/// `planeFromPoints`/`planeFromPointNormal` instead of calling `gce_MakePln`/`new Geom_Plane`
/// independently, so this coverage is a regression guard, not a live bug fix. None of these four
/// degenerate-input cases had any test coverage before #421.
@Suite("Surface plane factory parity (#421)")
struct PlaneFactoryParityTests {

    private func expectSamePlane(_ a: Surface?, _ b: Surface?, _ comment: Comment? = nil) {
        #expect(a != nil, comment)
        #expect(b != nil, comment)
        guard let a, let b else { return }
        let pa = a.point(atU: 0, v: 0)
        let pb = b.point(atU: 0, v: 0)
        #expect(abs(pa.x - pb.x) < 1e-9, comment)
        #expect(abs(pa.y - pb.y) < 1e-9, comment)
        #expect(abs(pa.z - pb.z) < 1e-9, comment)
        let na = a.normal(atU: 0, v: 0)
        let nb = b.normal(atU: 0, v: 0)
        #expect(na != nil, comment)
        #expect(nb != nil, comment)
        if let na, let nb {
            // Plane normals may point in opposite senses depending on point winding /
            // algorithm internals; compare direction up to sign.
            let dot = na.x * nb.x + na.y * nb.y + na.z * nb.z
            #expect(abs(abs(dot) - 1.0) < 1e-9, comment)
        }
    }

    // MARK: 3-point pair: planeFromPoints (GC_MakePlane, canonical) vs planeFrom3Points (delegates)

    @Test("Well-separated points: both entry points agree")
    func threePointControlMatches() {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(0, 10, 0)
        expectSamePlane(
            Surface.planeFromPoints(p1, p2, p3),
            Surface.planeFrom3Points(p1: p1, p2: p2, p3: p3))
    }

    @Test("Collinear-but-distinct points: both entry points return nil")
    func threePointCollinearRejectedByBoth() {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(1, 0, 0)
        let p3 = SIMD3<Double>(2, 0, 0)
        #expect(Surface.planeFromPoints(p1, p2, p3) == nil)
        #expect(Surface.planeFrom3Points(p1: p1, p2: p2, p3: p3) == nil)
    }

    @Test("Collinear, unevenly spaced points: both entry points return nil")
    func threePointCollinearUnevenRejectedByBoth() {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(0.3, 0, 0)
        let p3 = SIMD3<Double>(5, 0, 0)
        #expect(Surface.planeFromPoints(p1, p2, p3) == nil)
        #expect(Surface.planeFrom3Points(p1: p1, p2: p2, p3: p3) == nil)
    }

    @Test("Two coincident points: both entry points return nil")
    func threePointTwoCoincidentRejectedByBoth() {
        let p1 = SIMD3<Double>(1, 1, 1)
        let p2 = SIMD3<Double>(1, 1, 1)
        let p3 = SIMD3<Double>(0, 1, 0)
        #expect(Surface.planeFromPoints(p1, p2, p3) == nil)
        #expect(Surface.planeFrom3Points(p1: p1, p2: p2, p3: p3) == nil)
    }

    @Test("All three points coincident: both entry points return nil")
    func threePointAllCoincidentRejectedByBoth() {
        let p = SIMD3<Double>(2, 2, 2)
        #expect(Surface.planeFromPoints(p, p, p) == nil)
        #expect(Surface.planeFrom3Points(p1: p, p2: p, p3: p) == nil)
    }

    // MARK: Point+normal pair: planeFromPointNormal (GC_MakePlane, canonical) vs plane (delegates)

    @Test("Valid normal: both entry points agree")
    func pointNormalControlMatches() {
        let origin = SIMD3<Double>(5, 5, 5)
        let normal = SIMD3<Double>(1, 1, 1)
        expectSamePlane(
            Surface.planeFromPointNormal(point: origin, normal: normal),
            Surface.plane(origin: origin, normal: normal))
    }

    @Test("Zero-length normal: both entry points return nil")
    func pointNormalZeroLengthRejectedByBoth() {
        let origin = SIMD3<Double>(0, 0, 0)
        let zero = SIMD3<Double>(0, 0, 0)
        #expect(Surface.planeFromPointNormal(point: origin, normal: zero) == nil)
        #expect(Surface.plane(origin: origin, normal: zero) == nil)
    }

    @Test("Near-zero-length normal: both entry points return nil")
    func pointNormalNearZeroLengthRejectedByBoth() {
        let origin = SIMD3<Double>(0, 0, 0)
        let tiny = SIMD3<Double>(1e-300, 0, 0)
        #expect(Surface.planeFromPointNormal(point: origin, normal: tiny) == nil)
        #expect(Surface.plane(origin: origin, normal: tiny) == nil)
    }
}

