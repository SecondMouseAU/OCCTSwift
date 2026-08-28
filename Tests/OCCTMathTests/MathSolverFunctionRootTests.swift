import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.110.0 Math Solver Tests

@Suite("MathSolver FunctionRoot v0.110")
struct MathSolverFunctionRootTests {
    // #1250: findRootNewton()/findRootNegative() were a clean @Test(arguments:) collapse
    // candidate, identical closure body `x*x - 4`/`2*x`, differing only in the `near:`
    // starting literal and the expected root's sign.
    @Test(
        "findRoot(near:) finds both roots of x^2 - 4",
        arguments: [
            (3.0, 2.0),
            (-3.0, -2.0),
        ] as [(Double, Double)])
    func findRootNewton(near: Double, expected: Double) {
        // f(x) = x^2 - 4, roots at x=+-2
        if let root = MathSolver.findRoot(near: near) { x in
            (value: x * x - 4, derivative: 2 * x)
        } {
            #expect(abs(root - expected) < 1e-6)
        }
    }

    @Test func findRootBounded() {
        // f(x) = x^2 - 4, root at x=2 in [0, 5]
        if let root = MathSolver.findRoot(near: 3.0, in: 0.0...5.0) { x in
            (value: x * x - 4, derivative: 2 * x)
        } {
            #expect(abs(root - 2.0) < 1e-6)
        }
    }

    @Test func findRootBisection() {
        // f(x) = x^2 - 4 on [0, 5], root at x=2
        if let root = MathSolver.findRootBisection(in: 0.0...5.0) { x in
            (value: x * x - 4, derivative: 2 * x)
        } {
            #expect(abs(root - 2.0) < 1e-6)
        }
    }

    @Test func findRootCubic() {
        // f(x) = x^3 - 8, root at x=2
        if let root = MathSolver.findRoot(near: 3.0) { x in
            (value: x * x * x - 8, derivative: 3 * x * x)
        } {
            #expect(abs(root - 2.0) < 1e-6)
        }
    }
}

