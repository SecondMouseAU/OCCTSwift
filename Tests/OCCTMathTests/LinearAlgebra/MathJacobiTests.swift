import Foundation
import Testing

@testable import OCCTSwift

@Suite("MathJacobi Tests")
struct MathJacobiTests {

    @Test func eigenvalues() throws {
        // [[2,1],[1,2]] → eigenvalues 1,3
        let matrix = [2.0, 1.0, 1.0, 2.0]
        let ev = try #require(MathJacobi.eigenvalues(matrix: matrix, n: 2))
        try #require(ev.count == 2)
        let sorted = ev.sorted()
        #expect(abs(sorted[0] - 1.0) < 1e-10)
        #expect(abs(sorted[1] - 3.0) < 1e-10)
    }
}
