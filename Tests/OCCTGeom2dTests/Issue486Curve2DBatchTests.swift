import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #486 unified `Curve2D`'s three batch-evaluation spellings (`evaluateGrid`/`evaluateGridD1`,
/// v0.28.0's `Geom2dGridEval_Curve`; the v0.110.0 `evalBatchD0`/`D1`; and the v0.111.0
/// `gridEvalD0`/`D1`) onto the first. The two forwarding spellings were removed at v2.0.0 (#784).
@Suite("Issue 486: Curve2D batch-eval spellings agree")
struct Issue486Curve2DBatchTests {

    private func bspline() -> Curve2D? {
        Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(2, 3), SIMD2(5, 5), SIMD2(8, 3), SIMD2(10, 0),
        ])
    }

    @Test("empty parameters give an empty result, not one padded with zeroes")
    func emptyParametersGiveEmptyResult() {
        guard let curve = bspline() else { return }
        #expect(curve.evaluateGrid([]).isEmpty)
        #expect(curve.evaluateGridD1([]).isEmpty)
    }
}
