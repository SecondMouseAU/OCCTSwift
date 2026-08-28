import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.117.0 Tests

@Suite("MathPolyRc4")
struct MathPolyRc4Tests {
    @Test func linear() {
        // 2x + 4 = 0 => x = -2
        let roots = PolynomialSolver.linearRc4(a: 2, b: 4)
        #expect(roots != nil)
        if let r = roots {
            #expect(r.count == 1)
            #expect(abs(r[0] - (-2.0)) < 1e-10)
        }
    }

    @Test func linearDegenerate() {
        // 0x + 0 = 0 => infinite solutions => returns -1
        let roots = PolynomialSolver.linearRc4(a: 0, b: 0)
        // InfiniteSolutions status means IsDone() is false => returns nil or -1
        // The function returns -1 when IsDone is false, so nil
        #expect(roots == nil)
    }

    @Test func quadratic() {
        // x^2 - 5x + 6 = 0 => x = 2, 3
        let roots = PolynomialSolver.quadraticRc4(a: 1, b: -5, c: 6)
        #expect(roots != nil)
        if let r = roots {
            #expect(r.count == 2)
            #expect(abs(r[0] - 2.0) < 1e-10)
            #expect(abs(r[1] - 3.0) < 1e-10)
        }
    }

    @Test func quadraticNoRealRoots() {
        // x^2 + 1 = 0 => no real roots
        let roots = PolynomialSolver.quadraticRc4(a: 1, b: 0, c: 1)
        #expect(roots != nil)
        if let r = roots {
            #expect(r.count == 0)
        }
    }

    @Test func cubic() {
        // x^3 - 6x^2 + 11x - 6 = 0 => x = 1, 2, 3
        let roots = PolynomialSolver.cubicRc4(a: 1, b: -6, c: 11, d: -6)
        #expect(roots != nil)
        if let r = roots {
            #expect(r.count == 3)
            #expect(abs(r[0] - 1.0) < 1e-8)
            #expect(abs(r[1] - 2.0) < 1e-8)
            #expect(abs(r[2] - 3.0) < 1e-8)
        }
    }

    @Test func quartic() {
        // (x-1)(x-2)(x-3)(x-4) = x^4 - 10x^3 + 35x^2 - 50x + 24
        let roots = PolynomialSolver.quarticRc4(a: 1, b: -10, c: 35, d: -50, e: 24)
        #expect(roots != nil)
        if let r = roots {
            #expect(r.count == 4)
            #expect(abs(r[0] - 1.0) < 1e-6)
            #expect(abs(r[1] - 2.0) < 1e-6)
            #expect(abs(r[2] - 3.0) < 1e-6)
            #expect(abs(r[3] - 4.0) < 1e-6)
        }
    }
}

