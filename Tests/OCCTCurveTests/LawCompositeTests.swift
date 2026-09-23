import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Law Composite Tests")
struct LawCompositeTests {
    @Test func compositeLaw() {
        guard let l1 = LawFunction.linear(from: 1.0, to: 3.0, parameterRange: 0...0.5),
            let l2 = LawFunction.linear(from: 3.0, to: 1.0, parameterRange: 0.5...1.0)
        else {
            Issue.record("could not build the two linear laws")  // #766: was a silent return
            return
        }
        if let comp = LawFunction.composite(laws: [l1, l2]) {
            // #766: tightened from 0.1. Both pieces are linear, so Law_Composite is exact:
            // 1, 2, 3, 1 at 0, 0.25, 0.5, 1 (Scripts/repro/766-curve-law-function).
            #expect(abs(comp.value(at: 0.0) - 1.0) < 1e-9)
            #expect(abs(comp.value(at: 0.25) - 2.0) < 1e-9)
            #expect(abs(comp.value(at: 0.5) - 3.0) < 1e-9)
            #expect(abs(comp.value(at: 1.0) - 1.0) < 1e-9)
        } else {
            Issue.record("composite returned nil")  // #766: was a silent skip
        }
    }

    @Test func bsplineKnotSplitting() {
        guard
            let law = LawFunction.bspline(
                poles: [1.0, 3.0, 2.0, 5.0, 4.0, 6.0],
                knots: [0.0, 0.5, 1.0],
                multiplicities: [4, 2, 4],
                degree: 3)
        else {
            Issue.record("could not build the BSpline law")  // #766: was a silent return
            return
        }
        let splits = law.knotSplitting(continuityOrder: .c2)
        #expect(splits.count >= 2)
        // #766: `>= 2` held for the two end knots alone. The multiplicity-2 knot at 0.5 is only
        // C1, so Law_BSplineKnotSplitting at C2 reports three splits.
        #expect(splits.count == 3)
    }
}
