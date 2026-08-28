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
        }
    }
}

