import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("EigenValues")
struct EigenValuesTests {
    @Test func tridiagonal() {
        let diag = [2.0, 2.0, 2.0]
        let subdiag = [1.0, 1.0, 0.0]
        let ev = MathSolver.eigenvalues(diagonal: diag, subdiagonal: subdiag)
        #expect(ev != nil)
        if let ev = ev { #expect(ev.count == 3) }
    }

    @Test func withVectors() {
        let diag = [2.0, 2.0, 2.0]
        let subdiag = [1.0, 1.0, 0.0]
        let result = MathSolver.eigenvaluesAndVectors(diagonal: diag, subdiagonal: subdiag)
        #expect(result != nil)
        if let r = result {
            #expect(r.eigenvalues.count == 3)
            #expect(r.eigenvectors.count == 3)
            #expect(r.eigenvectors[0].count == 3)
        }
    }
}

