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
        #expect(abs(result - 2.0) < 0.01)
    }

    @Test func integratePolynomial() {
        // Integral of x^2 from 0 to 1 = 1/3
        let result = MathSolver.integrate(from: 0, to: 1, order: 5) { x in
            x * x
        }
        #expect(abs(result - 1.0 / 3.0) < 0.01)
    }

    @Test func integrateConstant() {
        // Integral of 1 from 0 to 5 = 5
        let result = MathSolver.integrate(from: 0, to: 5, order: 3) { _ in 1.0 }
        #expect(abs(result - 5.0) < 0.01)
    }
}

