import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Uzawa")
struct UzawaTests {
    @Test func constrainedOptimization() {
        let cont: [Double] = [1, 1]  // x + y = 1
        let sec: [Double] = [1]
        let result = MathSolver.uzawa(
            constraintMatrix: cont, nConstraints: 1, nVars: 2,
            constraintRHS: sec, startPoint: [0, 0])
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.result[0] - 0.5) < 0.1)
            #expect(abs(r.result[1] - 0.5) < 0.1)
        }
    }
}

