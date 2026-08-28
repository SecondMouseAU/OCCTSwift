import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathSolver NewtonSystem v0.111")
struct MathSolverNewtonSystemTests {
    @Test func solveCircleLine() {
        // x^2 + y^2 = 25, x - y = 1, starting near (4, 3)
        if let sol = MathSolver.solveSystemNewton(
            variables: 2, equations: 2,
            startPoint: [4.0, 3.0],
            values: { x in [x[0] * x[0] + x[1] * x[1] - 25, x[0] - x[1] - 1] },
            jacobian: { x in [2 * x[0], 2 * x[1], 1.0, -1.0] }
        ) {
            let eq1 = sol[0] * sol[0] + sol[1] * sol[1] - 25
            #expect(abs(eq1) < 1e-4)
            let eq2 = sol[0] - sol[1] - 1
            #expect(abs(eq2) < 1e-4)
        }
    }
}

