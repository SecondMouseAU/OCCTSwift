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
        if let x = x { #expect(x.count == 2) }
    }
}

