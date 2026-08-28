import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathGauss Tests")
struct MathGaussTests {

    @Test func solve2x2() {
        // 2x+y=5, x+3y=7 → x=1.6, y=1.8
        let matrix = [2.0, 1.0, 1.0, 3.0]
        let rhs = [5.0, 7.0]
        if let solution = MathGauss.solve(matrix: matrix, rhs: rhs) {
            #expect(abs(solution[0] - 1.6) < 1e-10)
            #expect(abs(solution[1] - 1.8) < 1e-10)
        }
    }

    @Test func determinant() {
        if let det = MathGauss.determinant(matrix: [2.0, 1.0, 1.0, 3.0], n: 2) {
            #expect(abs(det - 5.0) < 1e-10)
        } else {
            Issue.record("expected a determinant")
        }
    }
}

