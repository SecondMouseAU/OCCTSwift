import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathSolver SystemOfEquations v0.110")
struct MathSolverSystemTests {
    @Test func solveCircleLine() {
        // x^2 + y^2 = 25, x - y = 1
        // Starting near (4, 3)
        if let sol = MathSolver.solveSystem(
            variables: 2, equations: 2,
            startPoint: [4.0, 3.0],
            values: { x in
                [x[0] * x[0] + x[1] * x[1] - 25, x[0] - x[1] - 1]
            },
            jacobian: { x in
                [2 * x[0], 2 * x[1], 1.0, -1.0]
            }
        ) {
            // Check solution satisfies both equations
            let eq1 = sol[0] * sol[0] + sol[1] * sol[1] - 25
            let eq2 = sol[0] - sol[1] - 1
            #expect(abs(eq1) < 1e-4)
            #expect(abs(eq2) < 1e-4)
        }
    }

    @Test func solveLinearSystem() {
        // 2x + y = 5, x - y = 1 -> x=2, y=1
        if let sol = MathSolver.solveSystem(
            variables: 2, equations: 2,
            startPoint: [0.0, 0.0],
            values: { x in
                [2 * x[0] + x[1] - 5, x[0] - x[1] - 1]
            },
            jacobian: { _ in
                [2.0, 1.0, 1.0, -1.0]
            }
        ) {
            #expect(abs(sol[0] - 2.0) < 1e-4)
            #expect(abs(sol[1] - 1.0) < 1e-4)
        }
    }
}

