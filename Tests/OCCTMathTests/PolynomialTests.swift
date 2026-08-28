import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Polynomial Solvers")
struct PolynomialTests {
    @Test("Solve quadratic x²-5x+6=0")
    func quadratic() {
        let result = PolynomialSolver.quadratic(a: 1, b: -5, c: 6)
        #expect(result.count == 2)
        #expect(abs(result.roots[0] - 2.0) < 1e-10)
        #expect(abs(result.roots[1] - 3.0) < 1e-10)
    }

    @Test("Quadratic with no real roots")
    func quadraticNoRoots() {
        let result = PolynomialSolver.quadratic(a: 1, b: 0, c: 1)
        #expect(result.count == 0)
    }

    @Test("Quadratic with one root")
    func quadraticOneRoot() {
        let result = PolynomialSolver.quadratic(a: 1, b: -2, c: 1)
        #expect(result.count >= 1)
        #expect(abs(result.roots[0] - 1.0) < 1e-10)
    }

    @Test("Solve cubic x³-6x²+11x-6=0")
    func cubic() {
        let result = PolynomialSolver.cubic(a: 1, b: -6, c: 11, d: -6)
        #expect(result.count == 3)
        #expect(abs(result.roots[0] - 1.0) < 1e-10)
        #expect(abs(result.roots[1] - 2.0) < 1e-10)
        #expect(abs(result.roots[2] - 3.0) < 1e-10)
    }

    @Test("Solve quartic x⁴-10x²+9=0")
    func quartic() {
        // (x²-1)(x²-9) = 0  →  x = ±1, ±3
        let result = PolynomialSolver.quartic(a: 1, b: 0, c: -10, d: 0, e: 9)
        #expect(result.count == 4)
        #expect(abs(result.roots[0] - (-3.0)) < 1e-10)
        #expect(abs(result.roots[1] - (-1.0)) < 1e-10)
        #expect(abs(result.roots[2] - 1.0) < 1e-10)
        #expect(abs(result.roots[3] - 3.0) < 1e-10)
    }
}

