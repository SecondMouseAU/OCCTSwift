import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathSVD Tests")
struct MathSVDTests {

    @Test func leastSquares() {
        // Overdetermined 3x2 system
        let A = [1.0, 0.0, 0.0, 1.0, 1.0, 1.0]
        let b = [1.0, 2.0, 4.0]
        if let x = MathSVD.solve(matrix: A, rows: 3, cols: 2, rhs: b) {
            #expect(x.count == 2)
            #expect(x[0] > 0 && x[1] > 0)
            // Positive is not solved: the swapped solution (7/3, 4/3) passes the line above.
            // Least squares gives (4/3, 7/3), math_SVD's own value in
            // Scripts/repro/766-math-globopt-powell-pso-systems-svd.
            #expect(abs(x[0] - 4.0 / 3.0) < 1e-10)
            #expect(abs(x[1] - 7.0 / 3.0) < 1e-10)
        } else {
            Issue.record("expected a least-squares solution")
        }
    }
}

