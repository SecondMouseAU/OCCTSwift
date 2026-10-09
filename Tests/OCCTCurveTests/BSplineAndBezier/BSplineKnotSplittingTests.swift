import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.40.0: BSpline Knot Splitting

@Suite("BSpline Knot Splitting")
struct BSplineKnotSplittingTests {
    @Test("BSpline curve continuity breaks")
    func curveBreaks() {
        // Create a BSpline curve through several points
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
        let curve = Curve3D.interpolate(points: points)
        #expect(curve != nil)
        if let curve {
            let bspline = curve.toBSpline()
            #expect(bspline != nil)
            if let bspline {
                // C0 breaks, should at least have first and last
                let c0Breaks = bspline.continuityBreaks(minContinuity: ParametricContinuity.c0)
                #expect(c0Breaks != nil)
                if let c0Breaks {
                    #expect(c0Breaks.count >= 2)  // At minimum first/last knot
                }
            }
        }
    }

    @Test("Non-BSpline returns nil")
    func nonBSplineReturnsNil() {
        // A line segment is not a BSpline curve
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        #expect(line != nil)
        if let line {
            let breaks = line.continuityBreaks()
            #expect(breaks == nil)
        }
    }
}
