import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D Convert Extras Tests

// #1979: all three asserted only non-nil results (`degree != nil`, `indices != nil`,
// `count >= 1`), each inside `if let`. Pinned to what Geom2dConvert_ApproxCurve,
// Geom2dConvert_BSplineCurveKnotSplitting and Geom2dConvert_ApproxArcsSegments return for the same
// inputs (Scripts/repro/766-geom2d-continuity-convert/).
@Suite("Curve2D Convert Extras Tests")
struct Curve2DConvertExtrasTests {
    @Test("Approximate circle as BSpline")
    func approximateCircle() throws {
        let circle = try #require(Curve2D.circle(center: .zero, radius: 5))
        let approx = try #require(circle.approximated(tolerance: 1e-3))
        // Should be a BSpline after approximation: degree 7 with 13 poles at this tolerance.
        #expect(approx.degree == 7)
        #expect(approx.poleCount == 13)
    }

    @Test("Split BSpline at discontinuities")
    func splitAtDiscontinuities() throws {
        // Joining two line segments gives a degree-1 BSpline with a multiplicity-1 corner knot,
        // so it is only C0 there: C2 splits at all three knots, C0 only at the two ends.
        let seg1 = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(5, 5)))
        let seg2 = try #require(Curve2D.segment(from: SIMD2(5, 5), to: SIMD2(10, 0)))
        let joined = try #require(Curve2D.join([seg1, seg2]))
        #expect(joined.splitIndicesAtDiscontinuities(continuity: .c2) == [1, 2, 3])
        #expect(joined.splitIndicesAtDiscontinuities(continuity: .c0) == [1, 3])
    }

    @Test("Convert to arcs and segments")
    func toArcsAndSegments() throws {
        // Circle should decompose into arc segments: two, at these tolerances.
        let circle = try #require(Curve2D.circle(center: .zero, radius: 5))
        let result = try #require(circle.toArcsAndSegments(tolerance: 0.1, angleTolerance: 0.1))
        #expect(result.count == 2)
    }
}
