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
