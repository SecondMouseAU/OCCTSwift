import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #486 unified `Curve3D`'s three batch-evaluation spellings (`evaluateGrid`/`evaluateGridD1`,
/// v0.29.0's `GeomGridEval_Curve`; the v0.110.0 `evalBatchD0`/`D1`; and the v0.111.0
/// `gridEvalD0`/`D1`) onto the first. The two forwarding spellings were removed at v2.0.0 (#784).

@Suite("Issue 486: Curve3D batch-eval spellings agree")
struct Issue486Curve3DBatchTests {

    private func bspline() -> Curve3D? {
        Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0.5), SIMD3(5, 5, 1.5), SIMD3(8, 3, 0), SIMD3(10, 0, 2),
        ])
    }

    @Test("empty parameters give an empty result, not one padded with zeroes")
    func emptyParametersGiveEmptyResult() {
        guard let curve = bspline() else { return }
        #expect(curve.evaluateGrid([]).isEmpty)
        #expect(curve.evaluateGridD1([]).isEmpty)
    }
}
