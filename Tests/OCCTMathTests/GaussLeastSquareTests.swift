import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GaussLeastSquare")
struct GaussLeastSquareTests {
    @Test func overdetermined() {
        let A: [Double] = [1, 0, 0, 1, 1, 1]  // 3x2
        let b: [Double] = [1, 2, 3]
        let x = MathSolver.leastSquares(matrix: A, rows: 3, cols: 2, rhs: b)
        #expect(x != nil)
        if let x = x {
            #expect(x.count == 2)
            // A count held for any solution. This system is consistent, so the least-squares
            // answer is exact: x = (1, 2). Kernel value from
            // Scripts/repro/766-math-drawing-eigen-solvers/transcript.txt.
            if x.count == 2 {
                #expect(abs(x[0] - 1) < 1e-12)
                #expect(abs(x[1] - 2) < 1e-12)
            }
        }
    }
}

