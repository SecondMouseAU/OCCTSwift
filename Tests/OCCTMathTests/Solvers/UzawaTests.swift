import Foundation
import Testing

@testable import OCCTSwift

@Suite("Uzawa")
struct UzawaTests {
    @Test func constrainedOptimization() throws {
        let cont: [Double] = [1, 1]  // x + y = 1
        let sec: [Double] = [1]
        let r = try #require(
            MathSolver.uzawa(
                constraintMatrix: cont, nConstraints: 1, nVars: 2,
                constraintRHS: sec, startPoint: [0, 0]))
        #expect(abs(r.result[0] - 0.5) < 0.1)
        #expect(abs(r.result[1] - 0.5) < 0.1)
    }
}
