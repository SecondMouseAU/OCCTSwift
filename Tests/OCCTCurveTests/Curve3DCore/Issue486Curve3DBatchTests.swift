import Foundation
import Testing

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
        guard let curve = bspline() else {
            Issue.record("interpolating curve not built")
            return
        }
        #expect(curve.evaluateGrid([]).isEmpty)
        #expect(curve.evaluateGridD1([]).isEmpty)

        // The control, so an evaluator that always answered nothing cannot pass: the same call
        // with two parameters returns two points, and they are the curve's own ends.
        let u0 = curve.domain.lowerBound
        let u1 = curve.domain.upperBound
        let pts = curve.evaluateGrid([u0, u1])
        #expect(pts.count == 2)
        if pts.count == 2 {
            #expect(vectorLength(pts[0] - SIMD3(0, 0, 0)) < 1e-9, "start \(pts[0])")
            #expect(vectorLength(pts[1] - SIMD3(10, 0, 2)) < 1e-9, "end \(pts[1])")
        }
        let d1 = curve.evaluateGridD1([u0, u1])
        #expect(d1.count == 2)
        for (i, p) in d1.enumerated() where i < pts.count {
            #expect(vectorLength(p.point - pts[i]) < 1e-9)
            #expect(vectorLength(p.tangent) > 1e-6, "a nonzero tangent at parameter \(i)")
        }
    }
}
