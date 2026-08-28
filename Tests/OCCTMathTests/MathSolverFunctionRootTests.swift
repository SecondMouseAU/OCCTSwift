import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.110.0 Math Solver Tests

@Suite("MathSolver FunctionRoot v0.110")
struct MathSolverFunctionRootTests {
    @Test func findRootNewton() {
        // f(x) = x^2 - 4, root at x=2
        if let root = MathSolver.findRoot(near: 3.0) { x in
            (value: x * x - 4, derivative: 2 * x)
        } {
            #expect(abs(root - 2.0) < 1e-6)
        }
    }

    @Test func findRootNegative() {
        // f(x) = x^2 - 4, root at x=-2
        if let root = MathSolver.findRoot(near: -3.0) { x in
            (value: x * x - 4, derivative: 2 * x)
        } {
            #expect(abs(root + 2.0) < 1e-6)
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

