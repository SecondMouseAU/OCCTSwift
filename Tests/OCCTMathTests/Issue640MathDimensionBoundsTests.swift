import Foundation
import Testing

@testable import OCCTSwift

// #640: the math solver/optimizer family traps on a negative "problem dimension" argument,
// and reads out of bounds on a positive but mismatched one. PR #634 (issue #622) named this
// family, deliberately left it unfixed -- its numbers are problem dimensions that must agree
// with the caller's own arrays, so `Sampling.requested`/`capacity` is the wrong tool -- and
// recorded 13 trapping sites in `Document.swift` for a future issue.
//
// #640 is that issue, but its own 13-site count was itself a re-statement of #634's census,
// which only used one lens: does `Array(repeating:count:)` trap on a negative count. Reading
// every candidate bridge function's C++ implementation (a third lens: does a raw pointer get
// indexed up to a caller-supplied count with no check that the backing Swift array is that
// long) found **20**, not 13:
//
//   MathGauss.determinant, MathSVD.solve, MathJacobi.eigenvalues, MathHouseholder.solve,
//   MathCrout.determinant, MathSolver.solveSystem, .minimize, .minimizePowell,
//   .particleSwarm, .globalMinimize, .solveSystemNewton, .minimizeNewton, .leastSquares,
//   .uzawa, .eigenvalues(diagonal:subdiagonal:), .eigenvaluesAndVectors(diagonal:subdiagonal:),
//   .gaussMultipleIntegration, .gaussSetIntegration, and both `findAllRoots(samples:)` overloads.
//
// Five of these were invisible to the trap-shaped census:
// - `MathGauss.determinant`/`MathCrout.determinant` return a scalar `Double`, not an `Array`
//   sized by the dimension, so there was nothing for lens 1 to see. The bridge still loops
//   `matrixData[i*n+j]` for `i, j in 0..<n` unconditionally.
// - `.eigenvalues(diagonal:subdiagonal:)`, `.eigenvaluesAndVectors`, and
//   `.gaussMultipleIntegration` each derive their own dimension from an array's own `.count`
//   (always non-negative), so lens 1 sees nothing to trap on -- but a SECOND array
//   (`subdiagonal`/`upper`/`order`) is read up to that dimension with no check that it is
//   actually that long.
//
// The out-of-bounds read is not unique to `leastSquares` either. Measured one call per
// process (a crash or trap takes the whole process down with it), against this tree before
// the fix below:
//
// | case                                                  | before #640          | after #640 |
// |--------------------------------------------------------|----------------------|------------|
// | MathSVD.solve(rows: 0, cols: -1)                        | traps (signal 5)     | nil        |
// | MathJacobi.eigenvalues(matrix: [1.0], n: -1)             | traps (signal 5)     | nil        |
// | MathHouseholder.solve(rows: 0, cols: -1)                 | traps (signal 5)     | nil        |
// | MathSolver.leastSquares(rows: 0, cols: -1)               | traps (signal 5)     | nil        |
// | MathSolver.leastSquares(rows: 1000, cols: 1000, 1-elem)  | SIGBUS (signal 10)   | nil        |
// | MathSolver.solveSystem(variables: -1)                    | traps (signal 5)     | nil        |
// | MathSolver.solveSystem(variables: 50, 1-elem startPoint) | SUCCEEDS w/ garbage  | nil        |
// | MathSolver.minimize(variables: 50, 1-elem startPoint)    | SUCCEEDS w/ garbage  | nil        |
// | MathSolver.minimizePowell(variables: -1)                 | traps (signal 5)     | nil        |
// | MathSolver.particleSwarm(variables: -1)                  | traps (signal 5)     | nil        |
// | MathSolver.particleSwarm(variables: 50, 1-elem bounds)   | SUCCEEDS w/ garbage  | nil        |
// | MathSolver.globalMinimize(variables: -1)                 | traps (signal 5)     | nil        |
// | MathSolver.solveSystemNewton(variables: -1)              | traps (signal 5)     | nil        |
// | MathSolver.minimizeNewton(variables: -1)                 | traps (signal 5)     | nil        |
// | MathSolver.gaussSetIntegration(nEquations: -1)           | traps (signal 5)     | nil        |
// | MathSolver.gaussSetIntegration(1-elem lower, 5-elem up.) | SUCCEEDS w/ garbage  | nil        |
// | MathSolver.uzawa(nVars: -1)                              | traps (signal 5)     | nil        |
// | MathSolver.uzawa(nConstraints/nVars: 20, 1-elem arrays)  | SUCCEEDS w/ garbage  | nil        |
// | MathGauss.determinant(matrix: [1.0], n: 1000)            | SIGBUS (signal 10)   | 0.0        |
// | MathCrout.determinant(matrix: [1.0], n: 1000)            | SIGBUS (signal 10)   | 0.0        |
// | MathSolver.eigenvalues(50-elem diag, 1-elem subdiag)     | SUCCEEDS w/ garbage  | nil        |
// | MathSolver.eigenvaluesAndVectors(50-elem, 1-elem)        | SUCCEEDS w/ garbage  | nil        |
// | MathSolver.gaussMultipleIntegration(50-elem, 1-elem)     | (nil this run; UB)   | nil        |
// | MathSolver.findAllRoots(samples: Int32.max + 1)          | traps (signal 5)     | []         |
// | MathSolver.findAllRoots(samples: -1)                     | uncontrolled result  | []         |
//
// "SUCCEEDS w/ garbage" is the more dangerous outcome the issue calls out: no crash, no
// trap, a fully-populated, plausible-looking answer built from whatever memory happened to
// follow the too-short array. `MathSolver.minimize(variables: 50, startPoint: [1.0])`
// returned a 50-element point array of uninitialized-looking doubles (`4.147e-314`, ...)
// and reported convergence.
//
// `findAllRoots(samples:)` is a different shape (#558's family, not #622's/#640's): `samples`
// is a subdivision count, not a problem dimension, so it is bounded through
// `Sampling.requested` like every other sampler instead of a positivity/consistency guard.
//
// Checked and confirmed correctly OUT of scope: `kronrodIntegrate`/`kronrodIntegrateAdaptive`/
// `integGauss`/`integKronrod`/`integKronrodAdaptive`'s `points`/`gaussPoints` parameters trap
// the same `Int32(_:)` way at `Int(Int32.max) + 1`, but they select a quadrature RULE order
// inside OCCT, not an array length -- no bridge function indexes a raw pointer by them, and a
// negative value is rejected cleanly via `IsDone() == false` (measured, not assumed). #622's
// reasoning that this family is "kernel-side, not a Swift buffer" holds for these; it did not
// hold for `findAllRoots`, which is why that one moved into `Sampling` and these did not.
//
// Every case in the table above was run in a standalone process before this fix landed and
// confirmed to trap, crash, or silently succeed with the wrong answer; after the fix, the
// identical calls below return their documented `nil`/`0.0`/`[]` instead, which is what makes
// it possible to assert them in-process at all.
@Suite("Issue #640: math dimension arguments reject negative and mismatched input")
struct Issue640MathDimensionBounds {

    // MARK: - MathLibrary.swift: the three sites #634 named plus the two determinants it could not see

    @Test("MathGauss.determinant rejects a non-positive n and a matrix shorter than n*n")
    func gaussDeterminantBounds() {
        #expect(MathGauss.determinant(matrix: [1.0], n: -1) == nil)
        #expect(MathGauss.determinant(matrix: [1.0], n: 0) == nil)
        // n positive but matrix far shorter: this used to SIGBUS (bridge reads
        // matrixData[i*n+j] for i,j in 0..<n unconditionally).
        #expect(MathGauss.determinant(matrix: [1.0], n: 1000) == nil)
        // n positive: this used to overflow n*n before the guard could reject it (review
        // finding 8). Rejected, not trapped.
        #expect(MathGauss.determinant(matrix: [1.0], n: .max) == nil)
        // Control: a real 2x2 still computes correctly.
        if let det = MathGauss.determinant(matrix: [2.0, 1.0, 1.0, 3.0], n: 2) {
            #expect(abs(det - 5.0) < 1e-9)
        } else {
            Issue.record("expected a determinant")
        }
    }

    @Test(
        "MathGauss.determinant distinguishes an invalid dimension from a genuinely singular matrix")
    func gaussDeterminantSentinelDistinguishability() {
        // Review finding 7: before #640's fix, both an invalid dimension and a genuinely
        // singular matrix returned the same bare `0.0` -- indistinguishable. Returning
        // `Double?` makes them two different answers: `nil` (invalid input) and `.some(0.0)`
        // (a real, correctly-computed zero).
        #expect(MathGauss.determinant(matrix: [1.0], n: -1) == nil)
        // [[1, 2], [2, 4]]: row 2 is 2x row 1, singular, determinant genuinely 0.
        #expect(MathGauss.determinant(matrix: [1.0, 2.0, 2.0, 4.0], n: 2) == .some(0.0))
    }

    @Test("MathCrout.determinant rejects a non-positive n and a matrix shorter than n*n")
    func croutDeterminantBounds() {
        #expect(MathCrout.determinant(matrix: [1.0], n: -1) == nil)
        #expect(MathCrout.determinant(matrix: [1.0], n: 1000) == nil)
        #expect(MathCrout.determinant(matrix: [1.0], n: .max) == nil)
        if let det = MathCrout.determinant(matrix: [4.0, 2.0, 2.0, 3.0], n: 2) {
            #expect(abs(det - 8.0) < 1e-9)
        } else {
            Issue.record("expected a determinant")
        }
    }

    @Test(
        "MathCrout.determinant distinguishes an invalid dimension from a genuinely singular matrix")
    func croutDeterminantSentinelDistinguishability() {
        #expect(MathCrout.determinant(matrix: [1.0], n: -1) == nil)
        // [[1, 2], [2, 4]]: singular, determinant genuinely 0. Crout targets symmetric
        // systems; this one is both symmetric and singular.
        #expect(MathCrout.determinant(matrix: [1.0, 2.0, 2.0, 4.0], n: 2) == .some(0.0))
    }

    @Test("MathSVD.solve rejects a consistent-but-non-positive dimension")
    func svdSolveBounds() {
        // matrix.count == rows*cols holds exactly (0 == 0*-1); consistency alone is not
        // enough (#640's headline case, restated for this sibling).
        #expect(MathSVD.solve(matrix: [], rows: 0, cols: -1, rhs: []) == nil)
        #expect(MathSVD.solve(matrix: [], rows: -1, cols: 0, rhs: []) == nil)
        // rows positive: this used to overflow rows*cols before the guard could reject it
        // (review finding 8). Rejected, not trapped.
        #expect(MathSVD.solve(matrix: [1.0], rows: .max, cols: 2, rhs: [1.0]) == nil)
        let A: [Double] = [1, 0, 0, 1, 1, 1]
        let b: [Double] = [1, 2, 3]
        #expect(MathSVD.solve(matrix: A, rows: 3, cols: 2, rhs: b) != nil)
    }

    @Test("MathJacobi.eigenvalues rejects a consistent-but-negative n")
    func jacobiEigenvaluesBounds() {
        // The issue's own example: matrix.count == n*n holds exactly (1 == (-1)*(-1)).
        #expect(MathJacobi.eigenvalues(matrix: [1.0], n: -1) == nil)
        #expect(MathJacobi.eigenvalues(matrix: [1.0], n: 0) == nil)
        // n positive: overflow guard (review finding 8), same as the determinants.
        #expect(MathJacobi.eigenvalues(matrix: [1.0], n: .max) == nil)
        let matrix = [4.0, 1.0, 1.0, 4.0]
        #expect(MathJacobi.eigenvalues(matrix: matrix, n: 2) != nil)
    }

    @Test("MathHouseholder.solve rejects a consistent-but-non-positive dimension")
    func householderSolveBounds() {
        #expect(MathHouseholder.solve(matrix: [], rows: 0, cols: -1, rhs: []) == nil)
        #expect(MathHouseholder.solve(matrix: [1.0], rows: .max, cols: 2, rhs: [1.0]) == nil)
        let A: [Double] = [1, 0, 0, 1, 1, 1]
        let b: [Double] = [1, 2, 3]
        #expect(MathHouseholder.solve(matrix: A, rows: 3, cols: 2, rhs: b) != nil)
    }

    // MARK: - MathSolver.swift: the ten sites that had no consistency check at all

    @Test("MathSolver.solveSystem rejects non-positive dimensions and a mismatched startPoint")
    func solveSystemBounds() {
        #expect(
            MathSolver.solveSystem(
                variables: -1, equations: 1, startPoint: [],
                values: { _ in [0] }, jacobian: { _ in [0] }) == nil)
        #expect(
            MathSolver.solveSystem(
                variables: 1, equations: -1, startPoint: [0],
                values: { _ in [0] }, jacobian: { _ in [0] }) == nil)
        // variables positive but startPoint shorter: this used to SUCCEED with heap garbage.
        #expect(
            MathSolver.solveSystem(
                variables: 50, equations: 1, startPoint: [1.0],
                values: { x in [x.reduce(0, +)] },
                jacobian: { x in [Double](repeating: 1, count: x.count) }
            ) == nil)
        // Control: a real, correctly-dimensioned system still solves.
        #expect(
            MathSolver.solveSystem(
                variables: 1, equations: 1, startPoint: [2.0],
                values: { x in [x[0] - 3] },
                jacobian: { _ in [1] }) != nil)
    }

    @Test(
        "MathSolver.solveSystem/.solveSystemNewton reject a values/jacobian closure that returns the wrong length"
    )
    func solveSystemClosureLengthBounds() {
        // Review findings 3/4: `startPoint`'s own length is checked above, but before this
        // fix nothing checked the CLOSURE's returned array -- a `values` closure returning
        // fewer than `equations` elements, or a `jacobian` closure returning fewer than
        // `equations * variables`, indexed the short array and trapped the whole process.
        // The guard turns that into `nil`.
        #expect(
            MathSolver.solveSystem(
                variables: 1, equations: 1, startPoint: [2.0],
                values: { _ in [] },
                jacobian: { _ in [1] }) == nil)
        #expect(
            MathSolver.solveSystem(
                variables: 1, equations: 1, startPoint: [2.0],
                values: { x in [x[0] - 3] },
                jacobian: { _ in [] }) == nil)
        #expect(
            MathSolver.solveSystemNewton(
                variables: 1, equations: 1, startPoint: [2.0],
                values: { _ in [] },
                jacobian: { _ in [1] }) == nil)
        #expect(
            MathSolver.solveSystemNewton(
                variables: 1, equations: 1, startPoint: [2.0],
                values: { x in [x[0] - 3] },
                jacobian: { _ in [] }) == nil)
    }

    @Test("MathSolver.minimize rejects a non-positive variables and a mismatched startPoint")
    func minimizeBounds() {
        #expect(
            MathSolver.minimize(variables: -1, startPoint: [], function: { _ in (0, []) }) == nil)
        #expect(
            MathSolver.minimize(
                variables: 50, startPoint: [1.0],
                function: { x in (x.reduce(0, +), x) }) == nil)
        // Control: a real, correctly-dimensioned minimization still runs.
        #expect(
            MathSolver.minimize(
                variables: 1, startPoint: [1.0],
                function: { x in (x[0] * x[0], [2 * x[0]]) }) != nil)
    }

    @Test(
        "MathSolver.minimize/.minimizeNewton/.minimizeFRPR reject a function closure whose gradient/hessian is the wrong length"
    )
    func minimizeClosureLengthBounds() {
        // Review finding 5: `function`'s own returned `gradient` (and, for `minimizeNewton`,
        // `hessian`) is indexed up to `variables`/`variables * variables` with no length
        // check before this fix -- the same trap-on-a-closure-return-value shape as
        // findings 3/4, in the minimization family. `minimizeFRPR` shares the identical
        // `OCCTMathMultiVarGradCallback` shape but was not itself named by the review; fixed
        // and tested here for the same reason.
        #expect(
            MathSolver.minimize(
                variables: 1, startPoint: [1.0],
                function: { x in (x[0] * x[0], []) }) == nil)
        #expect(
            MathSolver.minimizeNewton(
                variables: 1, startPoint: [1.0],
                function: { x in (x[0] * x[0], [], [2.0]) }) == nil)
        #expect(
            MathSolver.minimizeNewton(
                variables: 1, startPoint: [1.0],
                function: { x in (x[0] * x[0], [2 * x[0]], []) }) == nil)
        #expect(
            MathSolver.minimizeFRPR(
                startPoint: [1.0],
                function: { x in (x[0] * x[0], []) }) == nil)
        // Controls: correctly-shaped closures still run.
        #expect(
            MathSolver.minimizeNewton(
                variables: 1, startPoint: [1.0],
                function: { x in (x[0] * x[0], [2 * x[0]], [2.0]) }) != nil)
        #expect(
            MathSolver.minimizeFRPR(
                startPoint: [1.0],
                function: { x in (x[0] * x[0], [2 * x[0]]) }) != nil)
    }

    @Test("MathSolver.minimizePowell rejects a non-positive variables and a mismatched startPoint")
    func minimizePowellBounds() {
        #expect(
            MathSolver.minimizePowell(variables: -1, startPoint: [], function: { _ in 0 }) == nil)
        #expect(
            MathSolver.minimizePowell(variables: 50, startPoint: [1.0], function: { x in x[0] })
                == nil)
    }

    @Test("MathSolver.particleSwarm rejects a non-positive variables and mismatched bounds")
    func particleSwarmBounds() {
        #expect(
            MathSolver.particleSwarm(
                variables: -1, lower: [], upper: [], steps: [],
                function: { _ in 0 }) == nil)
        #expect(
            MathSolver.particleSwarm(
                variables: 50, lower: [0], upper: [1], steps: [0.1],
                function: { x in x.reduce(0, +) }) == nil)
    }

    @Test("MathSolver.globalMinimize rejects a non-positive variables and mismatched bounds")
    func globalMinimizeBounds() {
        #expect(
            MathSolver.globalMinimize(variables: -1, lower: [], upper: [], function: { _ in 0 })
                == nil)
        #expect(
            MathSolver.globalMinimize(
                variables: 50, lower: [0], upper: [1],
                function: { x in x.reduce(0, +) }) == nil)
    }

    @Test(
        "MathSolver.solveSystemNewton rejects non-positive dimensions and a mismatched startPoint")
    func solveSystemNewtonBounds() {
        #expect(
            MathSolver.solveSystemNewton(
                variables: -1, equations: 1, startPoint: [],
                values: { _ in [0] }, jacobian: { _ in [0] }) == nil)
        #expect(
            MathSolver.solveSystemNewton(
                variables: 50, equations: 1, startPoint: [1.0],
                values: { x in [x.reduce(0, +)] },
                jacobian: { x in [Double](repeating: 1, count: x.count) }
            ) == nil)
    }

    @Test("MathSolver.minimizeNewton rejects a non-positive n and a mismatched startPoint")
    func minimizeNewtonBounds() {
        #expect(
            MathSolver.minimizeNewton(
                variables: -1, startPoint: [],
                function: { _ in (0, [], []) }) == nil)
        #expect(
            MathSolver.minimizeNewton(
                variables: 50, startPoint: [1.0],
                function: { x in (0, x, x) }) == nil)
    }

    @Test(
        "MathSolver.leastSquares rejects a non-positive dimension and reads no further out of bounds"
    )
    func leastSquaresBounds() {
        #expect(MathSolver.leastSquares(matrix: [], rows: 0, cols: -1, rhs: []) == nil)
        // rows/cols positive but matrix/rhs are 1 element: this used to SIGBUS at
        // rows/cols 1000, and silently return `nil` from a garbage-fed IsDone() at smaller
        // mismatches -- never a reliable failure, which is why it needed a guard rather than
        // relying on the bridge to notice.
        #expect(MathSolver.leastSquares(matrix: [1.0], rows: 1000, cols: 1000, rhs: [1.0]) == nil)
        #expect(MathSolver.leastSquares(matrix: [1.0], rows: 3, cols: 3, rhs: [1.0]) == nil)
        // rows positive: overflow guard (review finding 8).
        #expect(MathSolver.leastSquares(matrix: [1.0], rows: .max, cols: 2, rhs: [1.0]) == nil)
        // Control: a real 3x2 overdetermined system still solves.
        let A: [Double] = [1, 0, 0, 1, 1, 1]
        let b: [Double] = [1, 2, 3]
        #expect(MathSolver.leastSquares(matrix: A, rows: 3, cols: 2, rhs: b) != nil)
    }

    @Test("MathSolver.uzawa rejects non-positive dimensions and mismatched constraint arrays")
    func uzawaBounds() {
        #expect(
            MathSolver.uzawa(
                constraintMatrix: [], nConstraints: 0, nVars: -1,
                constraintRHS: [], startPoint: []) == nil)
        // nConstraints/nVars positive but every array is 1 element: this used to SUCCEED
        // with heap garbage.
        #expect(
            MathSolver.uzawa(
                constraintMatrix: [1.0], nConstraints: 20, nVars: 20,
                constraintRHS: [1.0], startPoint: [1.0]) == nil)
        // nConstraints positive: overflow guard (review finding 8).
        #expect(
            MathSolver.uzawa(
                constraintMatrix: [1.0], nConstraints: .max, nVars: 2,
                constraintRHS: [1.0], startPoint: [1.0, 1.0]) == nil)
        let cont: [Double] = [1, 1]
        let sec: [Double] = [1]
        #expect(
            MathSolver.uzawa(
                constraintMatrix: cont, nConstraints: 1, nVars: 2,
                constraintRHS: sec, startPoint: [0, 0]) != nil)
    }

    // MARK: - Sites invisible to a trap-shaped census: no Array(repeating:count:) at all

    @Test("MathSolver.eigenvalues/eigenvaluesAndVectors reject a subdiagonal shorter than diagonal")
    func eigenvaluesSubdiagonalLengthBounds() {
        // diagonal.count (50) can never be negative, so nothing here ever traps -- the bridge
        // just reads subdiagonal[i] for i in 0..<50 regardless, which used to succeed with
        // heap garbage against a 1-element subdiagonal.
        let longDiagonal = [Double](repeating: 1, count: 50)
        #expect(MathSolver.eigenvalues(diagonal: longDiagonal, subdiagonal: [1.0]) == nil)
        #expect(MathSolver.eigenvaluesAndVectors(diagonal: longDiagonal, subdiagonal: [1.0]) == nil)

        let diag = [2.0, 2.0, 2.0]
        let subdiag = [1.0, 1.0, 0.0]
        #expect(MathSolver.eigenvalues(diagonal: diag, subdiagonal: subdiag) != nil)
        #expect(MathSolver.eigenvaluesAndVectors(diagonal: diag, subdiagonal: subdiag) != nil)
    }

    @Test("MathSolver.gaussMultipleIntegration/.gaussSetIntegration reject mismatched arrays")
    func gaussIntegrationLengthBounds() {
        // lower.count (50) can never be negative; upper/order are the unguarded reads.
        let longLower = [Double](repeating: 0, count: 50)
        #expect(
            MathSolver.gaussMultipleIntegration(
                lower: longLower, upper: [1.0], order: [10],
                function: { x in x.reduce(0, +) }) == nil)
        #expect(
            MathSolver.gaussSetIntegration(
                nEquations: -1, lower: [1], upper: [2], order: [10],
                function: { _ in [0] }) == nil)
        #expect(
            MathSolver.gaussSetIntegration(
                nEquations: 1, lower: [0], upper: [1, 2, 3, 4, 5],
                order: [10, 10, 10, 10, 10],
                function: { x in [x.reduce(0, +)] }) == nil)

        // gaussMultipleIntegration genuinely supports more than one variable
        // (math_GaussMultipleIntegration integrates recursively): the double integral of
        // x^2 + y^2 over the unit square is 1/3 + 1/3 = 2/3.
        let result = MathSolver.gaussMultipleIntegration(
            lower: [0, 0], upper: [1, 1], order: [10, 10]
        ) { x in x[0] * x[0] + x[1] * x[1] }
        if let r = result {
            #expect(abs(r - 2.0 / 3.0) < 1e-6)
        } else {
            Issue.record("expected a result")
        }
    }

    @Test(
        "MathSolver.gaussSetIntegration rejects more than one variable instead of silently integrating only the first"
    )
    func gaussSetIntegrationRejectsMultipleVariables() {
        // Review finding 2. `math_GaussSetIntegration`'s own header says "the case M>1 is
        // not implemented", and the pinned kernel's `No_Exception` build compiles out
        // OCCT's own runtime check for it (Standard_NotImplemented_Raise_if), so a call with
        // more than one variable used to silently succeed at the WRONG answer instead of
        // failing: measured directly against the unguarded implementation,
        // `gaussSetIntegration(nEquations: 1, lower: [0, 0], upper: [1, 1], order: [10, 10])`
        // integrating `x + y` returned 0.5 -- `INT x dx` over `[0, 1]` with `y` silently
        // pinned at 0 the whole time, not `INT INT (x + y) dx dy` over the unit square, which
        // is 1.0. Neither 0.5 nor 1.0 is an acceptable answer from this entry point for a
        // 2-variable call: it must refuse, which is what this test pins.
        #expect(
            MathSolver.gaussSetIntegration(
                nEquations: 1, lower: [0, 0], upper: [1, 1], order: [10, 10]
            ) { x in [x[0] + x[1]] } == nil)

        // The one-variable, multiple-EQUATION case (what "Set" actually names) is exactly
        // what the class supports, and still works: integrate [x, x^2] over [0, 2] as two
        // separate scalar integrals sharing one evaluation point.
        let setResult = MathSolver.gaussSetIntegration(
            nEquations: 2, lower: [0], upper: [2], order: [10]
        ) { x in [x[0], x[0] * x[0]] }
        if let r = setResult {
            #expect(r.count == 2)
            #expect(abs(r[0] - 2.0) < 1e-9)
            #expect(abs(r[1] - 8.0 / 3.0) < 1e-9)
        } else {
            Issue.record("expected a result")
        }
    }

    @Test("MathSolver.gaussSetIntegration rejects a function closure that returns the wrong length")
    func gaussSetIntegrationClosureLengthBounds() {
        // Review finding 6: the same closure-return-length gap as findings 3-6, in the
        // Gauss integration family. A closure returning fewer than `nEquations` elements
        // used to index the short array and trap.
        #expect(
            MathSolver.gaussSetIntegration(
                nEquations: 2, lower: [0], upper: [2], order: [10]
            ) { x in [x[0]] } == nil)
    }

    // MARK: - findAllRoots(samples:): a sampler, not a problem dimension (#558's family)

    @Test("findAllRoots(samples:) routes through Sampling instead of trapping past Int32")
    func findAllRootsSamplesBounds() {
        let pastInt32 = Int(Int32.max) + 1
        #expect(
            MathSolver.findAllRoots(in: 0...10, samples: pastInt32) { x in (x - 5, 1) }.count == 0)
        #expect(MathSolver.findAllRoots(in: 0...10, samples: -1) { x in (x - 5, 1) }.count == 0)
        #expect(MathSolver.findAllRoots(in: 0...10, samples: 0) { x in (x - 5, 1) }.count == 0)

        #expect(
            MathSolver.findAllRoots(
                in: 0...10, samples: pastInt32, epsX: 1e-8, epsF: 1e-8,
                epsNul: 1e-8
            ) { x in (x - 5, 1) }.count == 0)
        #expect(
            MathSolver.findAllRoots(
                in: 0...10, samples: -1, epsX: 1e-8, epsF: 1e-8,
                epsNul: 1e-8
            ) { x in (x - 5, 1) }.count == 0)

        // Controls: a real search still finds the root at both defaults.
        let roots1 = MathSolver.findAllRoots(in: -5.0...5.0, samples: 20) { x in (x, 1) }
        #expect(roots1.contains { abs($0) < 1e-6 })
        let roots2 = MathSolver.findAllRoots(in: -5.0...5.0) { x in (x, 1) }
        #expect(roots2.contains { abs($0) < 1e-6 })
    }

    @Test(
        "findAllRoots(samples:) accepts the documented minimum of 1, not Sampling's own default floor of 2"
    )
    func findAllRootsAcceptsMinimumOfOne() {
        // Review finding 1: both overloads called `Sampling.requested(samples)` with no
        // `atLeast:`, so the default floor of 2 applied even though this file's own doc
        // comments and the reference docs document the valid range as 1...10,000,000.
        // `samples: 1` was silently rejected before `function` was ever called -- proved
        // here by counting calls rather than asserting a root is found, since whether one
        // sample happens to bracket a root is the search algorithm's business, not the
        // guard's.
        var calls1 = 0
        _ = MathSolver.findAllRoots(in: -1.0...1.0, samples: 1) { x in
            calls1 += 1
            return (x, 1)
        }
        #expect(calls1 > 0)

        var calls2 = 0
        _ = MathSolver.findAllRoots(
            in: -1.0...1.0, samples: 1, epsX: 1e-8, epsF: 1e-8, epsNul: 1e-8
        ) { x in
            calls2 += 1
            return (x, 1)
        }
        #expect(calls2 > 0)

        // samples: 0 is still outside the documented range and still rejected.
        var calls3 = 0
        _ = MathSolver.findAllRoots(in: -1.0...1.0, samples: 0) { x in
            calls3 += 1
            return (x, 1)
        }
        #expect(calls3 == 0)
    }
}

// Review finding 9 on #640: the "n is positive and every array n sizes matches it exactly"
// (or, for rows/cols, "the flat array is exactly their product") check was hand-duplicated
// at 18 call sites with no shared validator, unlike `Sampling`'s own family. `MathDimension`
// (Sources/OCCTSwift/MathDimension.swift) factors it out; these tests exercise it directly,
// the same way Issue558SamplingCountBoundsTests.swift exercises `Sampling.requested`/
// `capacity`/`gridTotal` directly, rather than only indirectly through the 18 call sites
// that now share it.
@Suite("Issue #640 review finding 9: MathDimension is the one shared validator")
struct MathDimensionTests {

    @Test("valid requires positivity and every given length to match exactly")
    func validRequiresPositiveAndMatching() {
        #expect(MathDimension.valid(3, matches: 3, 3))
        #expect(!MathDimension.valid(3, matches: 3, 1))  // one mismatch among several
        #expect(!MathDimension.valid(0, matches: 0))  // zero is not positive
        #expect(!MathDimension.valid(-1, matches: 0))  // matches by coincidence, still rejected
        #expect(MathDimension.valid(1, matches: 1))  // a single matching length is fine
    }

    @Test("consistent checks length agreement only, no positivity")
    func consistentSkipsPositivity() {
        #expect(MathDimension.consistent(0, matches: 0))  // two empty arrays agree
        #expect(!MathDimension.consistent(0, matches: 1))
        #expect(MathDimension.consistent(50, matches: 50))
        #expect(!MathDimension.consistent(50, matches: 1))
    }

    @Test("validSquare checks n > 0, n * n == count, and does not overflow")
    func validSquareChecksPositivityConsistencyAndOverflow() {
        #expect(MathDimension.validSquare(2, count: 4))
        #expect(!MathDimension.validSquare(2, count: 3))  // consistency fails
        #expect(!MathDimension.validSquare(0, count: 0))  // 0 * 0 == 0 holds, but 0 is not positive
        #expect(!MathDimension.validSquare(-1, count: 1))  // (-1)*(-1) == 1 holds, but -1 is not positive
        #expect(!MathDimension.validSquare(.max, count: 1))  // would overflow n * n: rejected, not trapped
    }

    @Test("validRectangle checks rows > 0, cols > 0, rows * cols == count, and does not overflow")
    func validRectangleChecksPositivityConsistencyAndOverflow() {
        #expect(MathDimension.validRectangle(rows: 3, cols: 2, count: 6))
        #expect(!MathDimension.validRectangle(rows: 3, cols: 2, count: 5))
        #expect(!MathDimension.validRectangle(rows: 0, cols: -1, count: 0))  // 0 * -1 == 0 holds
        #expect(!MathDimension.validRectangle(rows: .max, cols: 2, count: 1))  // overflow: rejected
        #expect(!MathDimension.validRectangle(rows: 2, cols: .max, count: 1))  // overflow the other factor
    }
}
