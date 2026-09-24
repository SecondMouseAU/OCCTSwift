import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.40.0: BSpline Knot Splitting

// Pinned to GeomConvert_BSplineCurveKnotSplitting on the same curve
// (Scripts/repro/766-curve-bspline-misc/transcript.txt). The earlier curveBreaks accepted any
// count >= 2 inside nested `if let`s, so splitting at a stricter continuity (every interior knot)
// passed (#766).
@Suite("BSpline Knot Splitting")
struct BSplineKnotSplittingTests {
    @Test("BSpline curve continuity breaks")
    func curveBreaks() {
        let points = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(10, 5, 0),
            SIMD3<Double>(20, -5, 0),
            SIMD3<Double>(30, 10, 0),
            SIMD3<Double>(40, -10, 0),
            SIMD3<Double>(50, 3, 0),
            SIMD3<Double>(60, -3, 0),
            SIMD3<Double>(70, 0, 0),
        ]
        guard let curve = Curve3D.interpolate(points: points), let bspline = curve.toBSpline()
        else {
            Issue.record("BSpline not built")
            return
        }
        // A C2 interpolant has no C0 break inside: only its two end knots.
        guard let c0Breaks = bspline.continuityBreaks(minContinuity: ParametricContinuity.c0) else {
            Issue.record("continuityBreaks returned nil for a BSpline")
            return
        }
        #expect(c0Breaks.count == 2)
        #expect(abs((c0Breaks.first ?? -1) - 0) < 1e-9)
        #expect(abs((c0Breaks.last ?? -1) - 104.21434142900561) < 1e-9)
    }

    @Test("Non-BSpline returns nil")
    func nonBSplineReturnsNil() {
        // A line segment is not a BSpline curve
        guard let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("segment not built")
            return
        }
        #expect(line.continuityBreaks() == nil)
    }
}
