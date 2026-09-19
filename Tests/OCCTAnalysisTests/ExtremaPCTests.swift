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

/// #1633: `Curve3D.extrema` and `minimumDistance` take the domain's ends into account.
///
/// The bridge called `ExtremaPC_Curve::Perform`, the interior solve, where the question asks for
/// `PerformWithEndpoints`. A query point with no perpendicular foot on the curve, which is every
/// point past the end of a bounded one, got `[]` and `nil` where the answer exists.
///
/// Ground truth for every figure below is `Scripts/repro/1633/probe.mm`, run against the pinned
/// 8.0.1 xcframework.
@Suite("Issue 1633: point-curve extrema include the domain's ends")
struct Issue1633PointCurveEndpoints {

    /// The exact case #1633 names: a segment `[0, 10]` along +X queried from `(20, 0, 0)`.
    /// The true minimum is 10, at the end. `Perform` reports `NbExt() == 0`.
    @Test func segmentQueriedPastItsEnd() {
        guard let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("Curve3D.segment returned nil")
            return
        }

        let d = seg.minimumDistance(from: SIMD3(20, 0, 0))
        #expect(d != nil)
        if let d { #expect(abs(d - 10.0) < 1e-9) }

        // Both ends are reported: the near one at distance 10, the far one at 20.
        let results = seg.extrema(from: SIMD3(20, 0, 0))
        #expect(results.count == 2)
        if let near = results.min(by: { $0.distance < $1.distance }) {
            #expect(abs(near.distance - 10.0) < 1e-9)
            #expect(abs(near.point.x - 10.0) < 1e-9)
            #expect(abs(near.point.y) < 1e-9)
            #expect(abs(near.point.z) < 1e-9)
        }
        if let far = results.max(by: { $0.distance < $1.distance }) {
            #expect(abs(far.distance - 20.0) < 1e-9)
            #expect(abs(far.point.x) < 1e-9)
        }
    }

    /// The mirror case, past the START of the same segment. `(-4, 3, 0)` is 5 from `(0, 0, 0)`.
    @Test func segmentQueriedPastItsStart() {
        guard let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("Curve3D.segment returned nil")
            return
        }
        let d = seg.minimumDistance(from: SIMD3(-4, 3, 0))
        #expect(d != nil)
        if let d { #expect(abs(d - 5.0) < 1e-9) }
    }

    /// A query point that DOES have a perpendicular foot keeps that foot as the minimum. The two
    /// ends join the array (3 results, not 1) but neither of them wins.
    @Test func interiorFootStillWinsAndIsStillReported() {
        guard let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("Curve3D.segment returned nil")
            return
        }
        let results = seg.extrema(from: SIMD3(5, 3, 0))
        #expect(results.count == 3)

        let foot = results.first { abs($0.point.x - 5.0) < 1e-9 }
        #expect(foot != nil)
        if let foot { #expect(abs(foot.distance - 3.0) < 1e-9) }

        // sqrt(25 + 9) from either end.
        let ends = results.filter { abs($0.point.x - 5.0) >= 1e-9 }
        #expect(ends.count == 2)
        for e in ends { #expect(abs(e.distance - (34.0).squareRoot()) < 1e-9) }

        let d = seg.minimumDistance(from: SIMD3(5, 3, 0))
        if let d { #expect(abs(d - 3.0) < 1e-9) }
    }

    /// The #580 shape of the defect, on a curve rather than an edge: the interior solve's only
    /// extremum is a MAXIMUM, so the reported minimum was the far side of the arc.
    ///
    /// Half circle of radius 5 in the XY plane, queried from `(0, -6, 0)`. The interior solve
    /// finds one extremum, `(0, 5, 0)` at distance 11. The true minimum is either end,
    /// `(±5, 0, 0)`, at `sqrt(61)` = 7.8102.
    @Test func arcEndBeatsTheInteriorMaximum() {
        guard
            let arc = Curve3D.arcOfCircle(
                start: SIMD3(5, 0, 0), interior: SIMD3(0, 5, 0), end: SIMD3(-5, 0, 0))
        else {
            Issue.record("Curve3D.arcOfCircle returned nil")
            return
        }
        let expected = (61.0).squareRoot()

        let d = arc.minimumDistance(from: SIMD3(0, -6, 0))
        #expect(d != nil)
        if let d { #expect(abs(d - expected) < 1e-9) }

        let results = arc.extrema(from: SIMD3(0, -6, 0))
        #expect(results.count == 3)
        if let near = results.min(by: { $0.distance < $1.distance }) {
            #expect(abs(near.distance - expected) < 1e-9)
            #expect(abs(abs(near.point.x) - 5.0) < 1e-9)
            #expect(abs(near.point.y) < 1e-9)
        }
        // The interior extremum is still there, and is still the far point at 11.
        if let far = results.max(by: { $0.distance < $1.distance }) {
            #expect(abs(far.distance - 11.0) < 1e-9)
            #expect(abs(far.point.y - 5.0) < 1e-9)
        }
    }

    /// A closed curve has no ends to add, so its answer is byte-for-byte the one `Perform` gave.
    /// This is the control: the fix must not invent extrema where the domain has no boundary.
    @Test func fullCircleIsUnchanged() {
        guard let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5)
        else {
            Issue.record("Curve3D.circle returned nil")
            return
        }
        let results = circ.extrema(from: SIMD3(0, 10, 0))
        #expect(results.count == 2)
        if let near = results.min(by: { $0.distance < $1.distance }) {
            #expect(abs(near.distance - 5.0) < 1e-9)
        }
        if let far = results.max(by: { $0.distance < $1.distance }) {
            #expect(abs(far.distance - 15.0) < 1e-9)
        }
        if let d = circ.minimumDistance(from: SIMD3(0, 10, 0)) {
            #expect(abs(d - 5.0) < 1e-9)
        }
    }

    /// An unbounded curve has no ends either. A line queried from `(20, 3, 0)` answers 3 whether
    /// or not the endpoints are consulted.
    @Test func unboundedLineIsUnchanged() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            Issue.record("Curve3D.line returned nil")
            return
        }
        let results = line.extrema(from: SIMD3(20, 3, 0))
        #expect(results.count == 1)
        if let only = results.first {
            #expect(abs(only.distance - 3.0) < 1e-9)
            #expect(abs(only.point.x - 20.0) < 1e-9)
        }
    }

    /// The bounded overload's own `uMin`/`uMax` are the ends that get reported. An infinite line
    /// restricted to `[0, 10]` and queried from `(20, 0, 0)` answers 10, the same as the trimmed
    /// segment above.
    @Test func boundedOverloadReportsItsOwnBounds() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            Issue.record("Curve3D.line returned nil")
            return
        }
        let results = line.extrema(from: SIMD3(20, 0, 0), uMin: 0, uMax: 10)
        #expect(results.count == 2)
        if let near = results.min(by: { $0.distance < $1.distance }) {
            #expect(abs(near.distance - 10.0) < 1e-9)
            #expect(abs(near.point.x - 10.0) < 1e-9)
        }

        // A narrower window moves the answer with it: [0, 4] puts the near end at x = 4.
        let narrow = line.extrema(from: SIMD3(20, 0, 0), uMin: 0, uMax: 4)
        #expect(narrow.count == 2)
        if let near = narrow.min(by: { $0.distance < $1.distance }) {
            #expect(abs(near.distance - 16.0) < 1e-9)
            #expect(abs(near.point.x - 4.0) < 1e-9)
        }
    }

    /// The numeric evaluators, where `Perform` did not merely report zero extrema: it reported
    /// `IsDone() == false` on a past-the-end query, and `PerformWithEndpoints` reports the end.
    /// A Bezier over poles ending at `(10, 0, 0)`, queried from `(30, 0, 0)`, answers 20.
    @Test func bezierQueriedPastItsEnd() {
        guard
            let bez = Curve3D.bezier(poles: [
                SIMD3(0, 0, 0), SIMD3(3, 4, 0), SIMD3(7, 4, 0), SIMD3(10, 0, 0),
            ])
        else {
            Issue.record("Curve3D.bezier returned nil")
            return
        }
        let d = bez.minimumDistance(from: SIMD3(30, 0, 0))
        #expect(d != nil)
        if let d { #expect(abs(d - 20.0) < 1e-6) }

        let results = bez.extrema(from: SIMD3(30, 0, 0))
        #expect(results.count == 2)
        if let near = results.min(by: { $0.distance < $1.distance }) {
            #expect(abs(near.point.x - 10.0) < 1e-6)
        }
    }

    /// Same for a B-spline. `interpolate` passes through its points, so the curve ends at
    /// `(10, 0, 0)` and `(30, 0, 0)` is 20 away from it.
    @Test func bsplineQueriedPastItsEnd() {
        guard
            let bs = Curve3D.interpolate(points: [
                SIMD3(0, 0, 0), SIMD3(3, 4, 0), SIMD3(7, 4, 0), SIMD3(10, 0, 0),
            ])
        else {
            Issue.record("Curve3D.interpolate returned nil")
            return
        }
        let d = bs.minimumDistance(from: SIMD3(30, 0, 0))
        #expect(d != nil)
        if let d { #expect(abs(d - 20.0) < 1e-6) }
    }

    /// `minimumDistance(from:)` and `extrema(from:)` must agree: the documented way to read a
    /// minimum out of the array is to take its smallest `distance`, and before the fix the two
    /// consulted different solves.
    @Test func minimumDistanceAgreesWithTheExtremaArray() {
        let queries: [SIMD3<Double>] = [
            SIMD3(20, 0, 0), SIMD3(-4, 3, 0), SIMD3(5, 3, 0), SIMD3(0, 0, 0), SIMD3(10, 7, 2),
        ]
        guard let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("Curve3D.segment returned nil")
            return
        }
        for q in queries {
            let fromArray = seg.extrema(from: q).map(\.distance).min()
            let direct = seg.minimumDistance(from: q)
            #expect(fromArray != nil)
            #expect(direct != nil)
            if let a = fromArray, let b = direct { #expect(abs(a - b) < 1e-9) }
        }
    }
}
