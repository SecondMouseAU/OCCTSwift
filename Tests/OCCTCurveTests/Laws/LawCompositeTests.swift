import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Law Composite Tests")
struct LawCompositeTests {
    @Test func compositeLaw() {
        guard let l1 = LawFunction.linear(from: 1.0, to: 3.0, parameterRange: 0...0.5),
            let l2 = LawFunction.linear(from: 3.0, to: 1.0, parameterRange: 0.5...1.0)
        else { return }
        if let comp = LawFunction.composite(laws: [l1, l2]) {
            #expect(abs(comp.value(at: 0.0) - 1.0) < 0.1)
            #expect(abs(comp.value(at: 0.5) - 3.0) < 0.1)
            #expect(abs(comp.value(at: 1.0) - 1.0) < 0.1)
        }
    }

    @Test func bsplineKnotSplitting() {
        guard
            let law = LawFunction.bspline(
                poles: [1.0, 3.0, 2.0, 5.0, 4.0, 6.0],
                knots: [0.0, 0.5, 1.0],
                multiplicities: [4, 2, 4],
                degree: 3)
        else { return }
        let splits = law.knotSplitting(continuityOrder: .c2)
        #expect(splits.count >= 2)
    }
}
