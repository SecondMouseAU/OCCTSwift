import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathJacobi Tests")
struct MathJacobiTests {

    @Test func eigenvalues() {
        // [[2,1],[1,2]] → eigenvalues 1,3
        let matrix = [2.0, 1.0, 1.0, 2.0]
        if let ev = MathJacobi.eigenvalues(matrix: matrix, n: 2) {
            #expect(ev.count == 2)
            let sorted = ev.sorted()
            if sorted.count == 2 {
                #expect(abs(sorted[0] - 1.0) < 1e-10)
                #expect(abs(sorted[1] - 3.0) < 1e-10)
            }
        }
    }
}

