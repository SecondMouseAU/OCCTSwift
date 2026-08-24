import Testing
import simd

@testable import OCCTSwift

/// #398: `Curve3D.ContinuityOrder` stopped at `c2`, which made every order it could express a
/// no-op for the query it exists to answer. Sharing `ParametricContinuity` with the other
/// continuity-floor APIs makes `.c3` reachable, and `.c3` is the order that actually finds
/// interior breaks on an ordinary cubic.
@Suite("BSpline knot splitting continuity range (#398)")
struct Issue398KnotSplittingTests {

    /// A cubic BSpline interpolated through points that force interior knots.
    private func cubicWithInteriorKnots() -> Curve3D? {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 5, 0), SIMD3(20, -5, 0), SIMD3(30, 5, 0),
            SIMD3(40, -5, 0), SIMD3(50, 5, 0), SIMD3(60, -3, 0), SIMD3(70, 0, 0),
        ]
        return Curve3D.interpolate(points: points)?.toBSpline()
    }

    @Test("Third-derivative order is reachable and reports interior knots")
    func thirdDerivativeOrderReportsInteriorKnots() {
        guard let bspline = cubicWithInteriorKnots() else {
            Issue.record("could not build the test BSpline")
            return
        }

        // Interior knots of a cubic interpolation have multiplicity 1, so the curve is already
        // C2 there. Nothing below C3 has anything to report beyond the two end knots, which is
        // why the old c0...c2 range could never answer this question.
        let atC2 = bspline.continuityBreaks(minContinuity: .c2)
        let atC3 = bspline.continuityBreaks(minContinuity: .c3)

        #expect(atC2 != nil)
        #expect(atC3 != nil)
        if let atC2, let atC3 {
            #expect(atC2.count == 2)
            #expect(atC3.count > atC2.count)
        }
    }

    @Test("More than 256 splits are returned in full, not silently truncated")
    func largeSplitCountSurvivesTheBuffer() {
        // continuityBreaks used a fixed 256-entry buffer while the bridge returns the true,
        // unclamped split count, so anything past the 256th was dropped without a signal. The
        // old c0...c2 range could not report interior knots at all on a cubic, which kept that
        // out of reach; .c3 can, so this now needs the retry path. 400 points is comfortably
        // past the old ceiling.
        let points: [SIMD3<Double>] = (0..<400).map { i in
            let t = Double(i) / 399.0 * 12.0 * .pi
            return SIMD3(Double(i) * 0.25, sin(t) * 5.0, cos(t * 0.5) * 2.0)
        }
        guard let bspline = Curve3D.interpolate(points: points)?.toBSpline() else {
            Issue.record("could not build the 400-point BSpline")
            return
        }

        guard let splits = bspline.continuityBreaks(minContinuity: .c3) else {
            Issue.record("continuityBreaks returned nil for a BSpline")
            return
        }
        #expect(splits.count > 256)

        // The retry must return the whole set, not a second truncated window. Count alone
        // cannot tell those apart; the end parameters can, since a truncated result stops
        // short of the curve's final knot. This also pins the `- Returns:` promise that the
        // result is bounded by the curve's own end knots.
        let domain = bspline.domain
        if let first = splits.first, let last = splits.last {
            #expect(abs(first - domain.lowerBound) < 1e-9)
            #expect(abs(last - domain.upperBound) < 1e-9)
        }

        // Strictly ascending: these are distinct knot values, which is the other half of the
        // ordering guarantee that same line promises.
        #expect(zip(splits, splits.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("Requesting more continuity never reports fewer split parameters")
    func higherOrdersAreMonotonic() {
        guard let bspline = cubicWithInteriorKnots() else {
            Issue.record("could not build the test BSpline")
            return
        }
        let counts = ParametricContinuity.allCases.compactMap {
            bspline.continuityBreaks(minContinuity: $0)?.count
        }
        #expect(counts.count == ParametricContinuity.allCases.count)
        #expect(counts == counts.sorted())
        // Every order at least brackets the curve with its own end knots.
        #expect(counts.allSatisfy { $0 >= 2 })
    }
}
