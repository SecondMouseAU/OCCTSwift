import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathSolver GaussIntegrate v0.111")
struct MathSolverGaussIntegrateTests {
    @Test func integrateSin() {
        // Integral of sin(x) from 0 to pi = 2
        let result = MathSolver.integrate(from: 0, to: Double.pi, order: 10) { x in
            sin(x)
        }
        // Order-10 Gauss is exact to rounding here (probe: 2); 0.01 passed a 0.1% error.
        #expect(abs(result - 2.0) < 1e-12)
    }

    @Test func integratePolynomial() {
        // Integral of x^2 from 0 to 1 = 1/3
        let result = MathSolver.integrate(from: 0, to: 1, order: 5) { x in
            x * x
        }
        // Order-5 Gauss integrates x^2 exactly (probe: 0.33333333333333331).
        #expect(abs(result - 1.0 / 3.0) < 1e-12)
    }

    @Test func integrateConstant() {
        // Integral of 1 from 0 to 5 = 5
        let result = MathSolver.integrate(from: 0, to: 5, order: 3) { _ in 1.0 }
        // Exact for a constant (probe: 5).
        #expect(abs(result - 5.0) < 1e-12)
    }
}

