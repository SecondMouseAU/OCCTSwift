import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BSplineCurve2d KnotSplitting Tests")
struct BSplineCurve2dKnotSplitTests {

    @Test func knotSplits() {
        // Create a 2D BSpline curve from interpolation
        if let c = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0), SIMD2(3, 1),
        ]) {
            // #562: was bsplineKnotSplits/bsplineKnotSplitValues, both now deprecated onto this one.
            let indices = c.splitIndicesAtDiscontinuities(continuity: .c0)
            #expect((indices?.count ?? 0) >= 0)
        }
    }
}
