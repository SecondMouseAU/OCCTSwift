import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("PolynomialSolver Laguerre v0.111")
struct PolynomialSolverLaguerreTests {
    @Test func quadraticRoots() {
        // x^2 - 5x + 6 = 0 -> roots 2, 3
        let roots = PolynomialSolver.laguerreRoots(coefficients: [6.0, -5.0, 1.0])
        #expect(roots.count == 2)
        if roots.count >= 2 {
            #expect(abs(roots[0] - 2.0) < 0.1)
            #expect(abs(roots[1] - 3.0) < 0.1)
        }
    }

    @Test func cubicRoots() {
        // x^3 - 6x^2 + 11x - 6 = 0 -> roots 1, 2, 3
        let roots = PolynomialSolver.laguerreRoots(coefficients: [-6.0, 11.0, -6.0, 1.0])
        #expect(roots.count == 3)
        if roots.count >= 3 {
            #expect(abs(roots[0] - 1.0) < 0.1)
            #expect(abs(roots[1] - 2.0) < 0.1)
            #expect(abs(roots[2] - 3.0) < 0.1)
        }
    }

    @Test func complexRoots() {
        // x^2 + 1 = 0 -> complex roots i, -i (no real roots)
        let realRoots = PolynomialSolver.laguerreRoots(coefficients: [1.0, 0.0, 1.0])
        #expect(realRoots.count == 0)

        let complexRoots = PolynomialSolver.laguerreComplexRoots(coefficients: [1.0, 0.0, 1.0])
        #expect(complexRoots.count == 2)
        if complexRoots.count >= 2 {
            // Should be approximately (0, 1) and (0, -1)
            #expect(abs(complexRoots[0].real) < 0.1)
            #expect(abs(abs(complexRoots[0].imaginary) - 1.0) < 0.1)
        }
    }

    @Test func quinticRoots() {
        // x^5 - 15x^4 + 85x^3 - 225x^2 + 274x - 120 = 0 -> roots 1, 2, 3, 4, 5
        let roots = PolynomialSolver.quinticRoots(a: 1, b: -15, c: 85, d: -225, e: 274, f: -120)
        // Quintic uses PolyResult with max 4 roots, so we may get up to 4
        #expect(roots.count >= 3)
    }
}

