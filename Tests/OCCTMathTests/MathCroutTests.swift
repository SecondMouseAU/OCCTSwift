import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathCrout Tests")
struct MathCroutTests {

    @Test func symmetricSolve() {
        // [[4,2],[2,3]] x = [8,7] → x=1.25, y=1.5
        let A = [4.0, 2.0, 2.0, 3.0]
        let b = [8.0, 7.0]
        if let x = MathCrout.solve(matrix: A, rhs: b) {
            #expect(abs(x[0] - 1.25) < 1e-10)
            #expect(abs(x[1] - 1.5) < 1e-10)
        }
    }

    @Test func determinant() {
        if let det = MathCrout.determinant(matrix: [4.0, 2.0, 2.0, 3.0], n: 2) {
            #expect(abs(det - 8.0) < 1e-10)
        } else {
            Issue.record("expected a determinant")
        }
    }
}

