import Foundation
import Testing
import simd

@testable import OCCTSwift

// PointSetLib suites removed in v1.0.0, module dropped from OCCT 8.0.0 GA.

@Suite("ExtremaPC, Point to Curve Distance")
struct ExtremaPCTests {

    @Test func pointToCircle() {
        guard let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        else { return }
        let results = circ.extrema(from: SIMD3(10, 0, 0))
        #expect(!results.isEmpty)
        if let closest = results.min(by: { $0.distance < $1.distance }) {
            #expect(abs(closest.distance - 5.0) < 1e-6)
        }
    }

    @Test func pointToLine() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            return
        }
        let results = line.extrema(from: SIMD3(5, 3, 0), uMin: 0, uMax: 100)
        #expect(!results.isEmpty)
        if let closest = results.min(by: { $0.distance < $1.distance }) {
            #expect(abs(closest.distance - 3.0) < 1e-6)
            #expect(abs(closest.point.x - 5.0) < 1e-6)
        }
    }

    @Test func minimumDistanceConvenience() {
        guard let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        else { return }
        if let d = circ.minimumDistance(from: SIMD3(10, 0, 0)) {
            #expect(abs(d - 5.0) < 1e-6)
        }
    }

    @Test func pointToCircleOppositeStart() {
        // #1456: `occtExtremaPCCurveImpl`'s whole-curve path always searched the
        // degenerate [0,0] parameter domain instead of the curve's natural range
        // (a ternary that can't actually pick between the 3-arg ranged constructor and
        // the 1-arg natural-range constructor). `pointToCircle` above doesn't catch this:
        // its query point's true closest point happens to sit at parameter 0, which is
        // the one point the [0,0] domain can ever "find". This probes a query point
        // diametrically opposite the u=0 point instead. With the bug, the search finds
        // only the u=0 point -- here the FARTHEST point (distance 20) -- and reports it
        // as the (and only) result, so `results.min(by: distance)` silently returns 20
        // instead of the true closest distance of 0. Ground-truth verified directly
        // against the pinned kernel (ExtremaPC_Curve's two Geom_Curve constructors).
        guard
            let circ = Curve3D.circle(
                center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10.0)
        else { return }
        let results = circ.extrema(from: SIMD3(-10, 0, 0))
        #expect(results.count == 2)
        if let closest = results.min(by: { $0.distance < $1.distance }) {
            #expect(closest.distance < 1e-6)
        }
        if let farthest = results.max(by: { $0.distance < $1.distance }) {
            #expect(abs(farthest.distance - 20.0) < 1e-6)
        }
    }

    @Test func pointToHelix() {
        guard let helix = Curve3D.circularHelix(radius: 5.0, pitch: 10.0) else { return }
        // Point at center of helix, all points on helix are equidistant at radius 5
        // (in the XY plane). This is an infinite solutions case but the API may
        // return some extrema or handle it gracefully.
        let d = helix.minimumDistance(from: SIMD3(0, 0, 0))
        // Minimum distance should be at least close to the radius
        if let d = d {
            #expect(d >= 4.9)
        }
    }
}
