import Foundation
import Testing

@testable import OCCTSwift

@Suite("MathPolynomialRoots Tests")
struct MathPolynomialRootsTests {
    // The kernel returns roots in no fixed order (probed: [3, 2] for the quadratic), so every
    // test sorts before comparing. The roots are exact small integers, probed to be within 1e-10.

    @Test func quadratic() throws {
        // x²-5x+6=0 → x=2,3
        let roots = try #require(MathPolynomialRoots.solve(coefficients: [1.0, -5.0, 6.0]))
        #expect(roots.count == 2)
        let sorted = roots.sorted()
        try #require(sorted.count == 2)
        #expect(abs(sorted[0] - 2.0) < 1e-10)
        #expect(abs(sorted[1] - 3.0) < 1e-10)
    }

    @Test func linear() throws {
        // 2x+4=0 → x=-2
        let roots = try #require(MathPolynomialRoots.solve(coefficients: [2.0, 4.0]))
        try #require(roots.count == 1)
        #expect(abs(roots[0] + 2.0) < 1e-10)
    }

    @Test func noRealRoots() throws {
        // x²+1=0: a result (not nil, which means an error) holding zero roots.
        let roots = try #require(MathPolynomialRoots.solve(coefficients: [1.0, 0.0, 1.0]))
        #expect(roots.isEmpty)
        // Control: the same shape with a real pair, x²-1=0, is not empty, so the empty answer
        // above is the discriminant and not a solver that returns nothing.
        let real = try #require(MathPolynomialRoots.solve(coefficients: [1.0, 0.0, -1.0]))
        try #require(real.count == 2)
        let sorted = real.sorted()
        #expect(abs(sorted[0] + 1.0) < 1e-10)
        #expect(abs(sorted[1] - 1.0) < 1e-10)
    }
}
