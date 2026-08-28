import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathPolynomialRoots Tests")
struct MathPolynomialRootsTests {

    @Test func quadratic() {
        // x²-5x+6=0 → x=2,3
        if let roots = MathPolynomialRoots.solve(coefficients: [1.0, -5.0, 6.0]) {
            #expect(roots.count == 2)
            let sorted = roots.sorted()
            if sorted.count == 2 {
                #expect(abs(sorted[0] - 2.0) < 1e-10)
                #expect(abs(sorted[1] - 3.0) < 1e-10)
            }
        }
    }

    @Test func linear() {
        // 2x+4=0 → x=-2
        if let roots = MathPolynomialRoots.solve(coefficients: [2.0, 4.0]) {
            #expect(roots.count == 1)
            if roots.count == 1 { #expect(abs(roots[0] + 2.0) < 1e-10) }
        }
    }

    @Test func noRealRoots() {
        // x²+1=0
        if let roots = MathPolynomialRoots.solve(coefficients: [1.0, 0.0, 1.0]) {
            #expect(roots.count == 0)
        }
    }
}

