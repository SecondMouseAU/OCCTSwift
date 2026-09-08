//
//  Issue1643EigenvalueOffDiagonalTests.swift
//  OCCTSwift
//
//  #1643: `MathSolver.eigenvalues`/`.eigenvaluesAndVectors` used to take an n-element
//  `subdiagonal` and let OCCT throw its first element away. Three doc layers said the last
//  one was dead, and the example shipped in the API's own doc comment,
//  `subdiagonal: [1.0, 1.0, 0.0]`, described off-diagonals (1, 1) while computing the
//  spectrum of (1, 0): it returned [1, 3, 2] instead of 2 - sqrt(2), 2, 2 + sqrt(2). The
//  fix is the signature: `offDiagonal` is the n - 1 entries the matrix actually has.
//
//  These tests assert eigenVALUES, not eigenvalue counts. The suite that existed before
//  #1643 asserted only `ev.count == 3`, which every wrong convention also satisfies, and
//  that is exactly why the wrong convention survived long enough to be documented three
//  times. Expected spectra come from numpy's `eigvalsh` on the intended matrix, an
//  independent construction of the same problem.
//

import Testing

@testable import OCCTSwift

@Suite("Issue #1643: eigenvalues take the n-1 real off-diagonal entries")
struct Issue1643EigenvalueOffDiagonal {

    /// Dense symmetric matrix-vector product for a tridiagonal `(diagonal, offDiagonal)`
    /// pair, built from the arrays a caller passes, not from anything the API returns.
    private static func multiply(
        diagonal: [Double], offDiagonal: [Double], by vector: [Double]
    ) -> [Double] {
        let n = diagonal.count
        var out = [Double](repeating: 0, count: n)
        for i in 0..<n {
            out[i] = diagonal[i] * vector[i]
            if i > 0 { out[i] += offDiagonal[i - 1] * vector[i - 1] }
            if i < n - 1 { out[i] += offDiagonal[i] * vector[i + 1] }
        }
        return out
    }

    @Test("A constant-diagonal matrix returns 2 - sqrt(2), 2, 2 + sqrt(2), not 1, 2, 3")
    func constantDiagonalSpectrum() {
        // [[2, 1, 0], [1, 2, 1], [0, 1, 2]]. Closed form: 2 + 2 cos(k pi / 4), k = 1, 2, 3.
        let root2 = 2.0.squareRoot()
        let expected = [2 - root2, 2, 2 + root2]

        let ev = MathSolver.eigenvalues(diagonal: [2, 2, 2], offDiagonal: [1, 1])
        #expect(ev != nil)
        if let ev = ev {
            #expect(ev.count == 3)
            for (got, want) in zip(ev.sorted(), expected) {
                #expect(abs(got - want) < 1e-12)
            }
            // The old convention read this same pair of ones as off-diagonals (1, 0) and
            // returned the spectrum of a different matrix. Named so a regression reads as a
            // regression rather than as an unexplained tolerance failure.
            #expect(abs(ev.sorted()[0] - 1.0) > 0.1, "1, 2, 3 is the discarded-wrong-end answer")
        }
    }

    @Test("An asymmetric diagonal pins the off-diagonal ORDER as well as its magnitudes")
    func asymmetricDiagonalSpectrum() {
        // [[1, 1, 0], [1, 2, 2], [0, 2, 3]]. A constant diagonal cannot catch a reversed
        // off-diagonal, because reversing a symmetric tridiagonal is a similarity transform
        // (J A J) and preserves the spectrum. Varying the diagonal breaks that symmetry, so
        // this case fails for a wrong ORDER where the case above only fails for a wrong
        // MAGNITUDE. numpy eigvalsh of the intended matrix:
        let expected = [-0.14510269120042243, 1.476023602918134, 4.669079088282289]

        let ev = MathSolver.eigenvalues(diagonal: [1, 2, 3], offDiagonal: [1, 2])
        #expect(ev != nil)
        if let ev = ev {
            #expect(ev.count == 3)
            for (got, want) in zip(ev.sorted(), expected) {
                #expect(abs(got - want) < 1e-12)
            }
        }
    }

    @Test("Each eigenvector solves A v = lambda v for the matrix the caller described")
    func eigenvectorsSolveTheIntendedMatrix() {
        let diagonal = [1.0, 2.0, 3.0]
        let offDiagonal = [1.0, 2.0]
        let result = MathSolver.eigenvaluesAndVectors(
            diagonal: diagonal, offDiagonal: offDiagonal)
        #expect(result != nil)
        guard let r = result else { return }

        #expect(r.eigenvalues.count == 3)
        #expect(r.eigenvectors.count == 3)
        for (lambda, vector) in zip(r.eigenvalues, r.eigenvectors) {
            #expect(vector.count == 3)
            guard vector.count == 3 else { continue }
            // A unit vector, so the residual below is not trivially small.
            let norm = vector.reduce(0) { $0 + $1 * $1 }.squareRoot()
            #expect(abs(norm - 1) < 1e-12)

            let av = Self.multiply(diagonal: diagonal, offDiagonal: offDiagonal, by: vector)
            for i in 0..<3 {
                #expect(abs(av[i] - lambda * vector[i]) < 1e-12)
            }
        }
    }

    @Test("A 1x1 matrix takes an empty offDiagonal and returns its single entry")
    func oneByOne() {
        let ev = MathSolver.eigenvalues(diagonal: [5], offDiagonal: [])
        #expect(ev != nil)
        if let ev = ev {
            #expect(ev.count == 1)
            #expect(abs(ev[0] - 5) < 1e-12)
        }
        let r = MathSolver.eigenvaluesAndVectors(diagonal: [5], offDiagonal: [])
        #expect(r != nil)
        if let r = r {
            #expect(r.eigenvalues.count == 1)
            #expect(r.eigenvectors.count == 1)
        }
    }

    @Test("offDiagonal.count must be diagonal.count - 1, so the old n-element call returns nil")
    func lengthGuard() {
        // The old shape. A caller who did not notice the rename gets nil, not a spectrum.
        #expect(MathSolver.eigenvalues(diagonal: [2, 2, 2], offDiagonal: [1, 1, 0]) == nil)
        #expect(MathSolver.eigenvaluesAndVectors(diagonal: [2, 2, 2], offDiagonal: [1, 1, 0]) == nil)
        // Too short, the #640 out-of-bounds read.
        #expect(MathSolver.eigenvalues(diagonal: [2, 2, 2], offDiagonal: [1]) == nil)
        #expect(MathSolver.eigenvaluesAndVectors(diagonal: [2, 2, 2], offDiagonal: [1]) == nil)
        // No matrix at all. Labelled as documenting the contract rather than isolating a
        // guard: removing the Swift n >= 1 check, the bridge n < 1 check, or both together
        // leaves these two green, because math_EigenValuesSearcher reports dimension 0 for
        // an empty matrix and the bridge maps 0 to nil. The other four expectations here
        // fail as soon as the Swift length check goes.
        #expect(MathSolver.eigenvalues(diagonal: [], offDiagonal: []) == nil)
        #expect(MathSolver.eigenvaluesAndVectors(diagonal: [], offDiagonal: []) == nil)
    }

    @Test("MathDimension.tridiagonal is the shared check, not a hand-written == at each site")
    func tridiagonalValidator() {
        #expect(MathDimension.tridiagonal(3, offDiagonal: 2))
        #expect(!MathDimension.tridiagonal(3, offDiagonal: 3))
        #expect(!MathDimension.tridiagonal(3, offDiagonal: 1))
        #expect(MathDimension.tridiagonal(1, offDiagonal: 0))
        #expect(!MathDimension.tridiagonal(0, offDiagonal: 0))
        #expect(!MathDimension.tridiagonal(-1, offDiagonal: -2))
    }
}
