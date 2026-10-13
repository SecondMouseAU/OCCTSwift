import Foundation
import Testing

@testable import OCCTSwift

/// #486 unified Curve2D's three batch-evaluation spellings (`evaluateGrid`/`evaluateGridD1`,
/// v0.28.0's `Geom2dGridEval_Curve`; the v0.110.0 `evalBatchD0`/`D1`; and the v0.111.0
/// `gridEvalD0`/`D1`) onto the first.
///
/// The two forwarding spellings were removed at v2.0.0 (#784).
@Suite("Issue 486: Curve2D batch-eval spellings agree")
struct Issue486Curve2DBatchTests {

    private func bspline() -> Curve2D? {
        Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(2, 3), SIMD2(5, 5), SIMD2(8, 3), SIMD2(10, 0),
        ])
    }

    @Test("empty parameters give an empty result, not one padded with zeroes")
    func emptyParametersGiveEmptyResult() {
        guard let curve = bspline() else {
            Issue.record("interpolating curve not built")
            return
        }
        #expect(curve.evaluateGrid([]).isEmpty)
        #expect(curve.evaluateGridD1([]).isEmpty)

        // The control: two parameters give the curve's own end points, so an evaluator that
        // always answered nothing cannot pass.
        let pts = curve.evaluateGrid([curve.domain.lowerBound, curve.domain.upperBound])
        #expect(pts.count == 2)
        if pts.count == 2 {
            #expect(abs(pts[0].x) < 1e-9 && abs(pts[0].y) < 1e-9, "start \(pts[0])")
            #expect(abs(pts[1].x - 10) < 1e-9 && abs(pts[1].y) < 1e-9, "end \(pts[1])")
        }
        #expect(curve.evaluateGridD1([curve.domain.lowerBound]).count == 1)
    }
}
