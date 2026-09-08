import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("EigenValues")
struct EigenValuesTests {
    // These two asserted only a count until #1643, and a count is what let the wrong
    // sub-diagonal convention survive three doc layers. They now assert the spectrum, and
    // Issue1643EigenvalueOffDiagonalTests carries the rest of the argument.
    @Test func tridiagonal() {
        // [[2, 1, 0], [1, 2, 1], [0, 1, 2]]: 2 - sqrt(2), 2, 2 + sqrt(2).
        let diag = [2.0, 2.0, 2.0]
        let offDiag = [1.0, 1.0]
        let ev = MathSolver.eigenvalues(diagonal: diag, offDiagonal: offDiag)
        #expect(ev != nil)
        if let ev = ev {
            #expect(ev.count == 3)
            let root2 = 2.0.squareRoot()
            for (got, want) in zip(ev.sorted(), [2 - root2, 2, 2 + root2]) {
                #expect(abs(got - want) < 1e-12)
            }
        }
    }

    @Test func withVectors() {
        let diag = [2.0, 2.0, 2.0]
        let offDiag = [1.0, 1.0]
        let result = MathSolver.eigenvaluesAndVectors(diagonal: diag, offDiagonal: offDiag)
        #expect(result != nil)
        if let r = result {
            #expect(r.eigenvalues.count == 3)
            #expect(r.eigenvectors.count == 3)
            #expect(r.eigenvectors[0].count == 3)
            let root2 = 2.0.squareRoot()
            for (got, want) in zip(r.eigenvalues.sorted(), [2 - root2, 2, 2 + root2]) {
                #expect(abs(got - want) < 1e-12)
            }
        }
    }
}

