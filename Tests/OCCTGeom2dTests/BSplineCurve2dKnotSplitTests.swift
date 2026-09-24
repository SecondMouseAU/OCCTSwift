import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BSplineCurve2d KnotSplitting Tests")
struct BSplineCurve2dKnotSplitTests {

    @Test func knotSplits() throws {
        // Create a 2D BSpline curve from interpolation
        let c = try #require(
            Curve2D.interpolate(through: [
                SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0), SIMD2(3, 1),
            ]))
        // #562: was bsplineKnotSplits/bsplineKnotSplitValues, both now deprecated onto this one.
        // #1979: `(indices?.count ?? 0) >= 0` held for every result, nil included. The
        // interpolant has knots mults [4, 1, 1, 4], cubic, so it is C2 at the two interior knots:
        // Geom2dConvert_BSplineCurveKnotSplitting splits only the ends at C0 and all four at C3
        // (Scripts/repro/766-geom2d-bspline-completions/).
        #expect(c.splitIndicesAtDiscontinuities(continuity: .c0) == [1, 4])
        #expect(c.splitIndicesAtDiscontinuities(continuity: .c3) == [1, 2, 3, 4])
    }
}
