import Foundation
import Testing

@testable import OCCTSwift

@Suite("MathSolver SystemOfEquations v0.110")
struct MathSolverSystemTests {
    // x^2 + y^2 = 25, x - y = 1 has exactly two solutions, (4, 3) and (-3, -4). Probed on the
    // pinned kernel: Newton reaches each exactly from the starts below (to the last printed
    // digit), so the 1e-6 window is a margin over a measured exact answer.
    private func solveCircleLine(from start: [Double]) -> [Double]? {
        MathSolver.solveSystem(
            variables: 2, equations: 2,
            startPoint: start,
            values: { x in
                [x[0] * x[0] + x[1] * x[1] - 25, x[0] - x[1] - 1]
            },
            jacobian: { x in
                [2 * x[0], 2 * x[1], 1.0, -1.0]
            }
        )
    }

    @Test func solveCircleLine() throws {
        // Starts away from either root (the old start, (4, 3), was already a root, so a solver
        // that returned its start point passed).
        let sol = try #require(solveCircleLine(from: [6.0, 1.0]))
        try #require(sol.count == 2)
        #expect(abs(sol[0] - 4.0) < 1e-6)
        #expect(abs(sol[1] - 3.0) < 1e-6)
        // Check solution satisfies both equations
        let eq1 = sol[0] * sol[0] + sol[1] * sol[1] - 25
        let eq2 = sol[0] - sol[1] - 1
        #expect(abs(eq1) < 1e-4)
        #expect(abs(eq2) < 1e-4)

        // The other basin converges to the other root, so the answer follows the start point.
        let other = try #require(solveCircleLine(from: [-1.0, -1.0]))
        try #require(other.count == 2)
        #expect(abs(other[0] + 3.0) < 1e-6)
        #expect(abs(other[1] + 4.0) < 1e-6)
    }

    @Test func solveLinearSystem() throws {
        // 2x + y = 5, x - y = 1 -> x=2, y=1
        let solved = MathSolver.solveSystem(
            variables: 2, equations: 2,
            startPoint: [0.0, 0.0],
            values: { x in
                [2 * x[0] + x[1] - 5, x[0] - x[1] - 1]
            },
            jacobian: { _ in
                [2.0, 1.0, 1.0, -1.0]
            }
        )
        let sol = try #require(solved)
        try #require(sol.count == 2)
        #expect(abs(sol[0] - 2.0) < 1e-4)
        #expect(abs(sol[1] - 1.0) < 1e-4)
    }
}
