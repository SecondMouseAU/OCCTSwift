import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathHouseholder Tests")
struct MathHouseholderTests {

    @Test func overdetermindedSolve() {
        // 3x2 system: [[1,0],[0,1],[1,1]] x = [1,2,4]
        let A = [1.0, 0.0, 0.0, 1.0, 1.0, 1.0]
        let b = [1.0, 2.0, 4.0]
        if let x = MathHouseholder.solve(matrix: A, rows: 3, cols: 2, rhs: b) {
            #expect(x.count == 2)
            #expect(x[0] > 0 && x[1] > 0)
        }
    }
}

