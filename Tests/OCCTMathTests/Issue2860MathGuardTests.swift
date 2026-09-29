import Foundation
import Testing
import simd

@testable import OCCTSwift

//
//  Issue2860MathGuardTests.swift
//  #2860: MathMatrix.invert/determinant/transpose/value, MathSolver.uzawa,
//  Shape.scaledAboutPoint and Shape.trsfModification refuse the inputs whose validity checks
//  are compiled out of the kernel this package ships.
//
//  Why this is not Issue640MathDimensionBoundsTests' subject. #640 bounded arguments against the
//  caller's OWN arrays: a dimension that disagrees with an array length. Every input here is
//  perfectly self-consistent in its array lengths and still wrong, because the precondition is a
//  relation OCCT documents and does not enforce. `nConstraints: 4, nVars: 2` with a 8-element
//  matrix, a 4-element RHS and a 2-element start point passes every #640 check.
//
//  Why a crash-shaped test would not have been enough, and how the inputs below were chosen.
//  Both containers under math_Matrix and math_Vector have a small-buffer optimisation, and it, not
//  the defect, decides whether a run faults or lies:
//
//    math_DoubleTab inlines 64 doubles (math_DoubleTab.hxx:33), so a math_Matrix with
//    rows * cols <= 64 keeps its elements inside the object;
//    math_VectorBase inlines 32 (math_VectorBase.hxx:63), so a math_Vector of 32 or fewer does.
//
//  Measured either side of both, by taking the address of element (1,1) and asking whether it lies
//  within the object's own footprint (Scripts/repro/2860-guard-preconditions/, mode `thresholds`):
//  3x2 = 6 and 2x32 = 64 are inlined, 2x33 = 66 and 100x1 = 100 are not. Below the threshold the
//  overrun scribbles inside the object and hands back a plausible number forever, which is why
//  every case here asserts the refusal rather than the absence of a crash: a 3x2 determinant
//  returned -1, and 4 constraints over 2 variables returned IsDone() == true with a wrong answer.
//  Above it the same call is a SIGBUS or a SIGSEGV. The unguarded code fails one way on one side of
//  the threshold and the other way on the other, so removing any guard below shows up either as an
//  #expect failure or as the process dying mid-suite.
//
//  Full transcripts: Scripts/repro/2801-sweep-math/ (the defects) and
//  Scripts/repro/2860-guard-preconditions/ (the thresholds and the guard predicates), both
//  re-verified against the pinned v4.0.0-kernel.2 asset.
//
@Suite("#2860 math and transform value guards")
struct Issue2860MathGuardTests {

    // MARK: - math_Matrix squareness

    @Test("A non-square MathMatrix refuses determinant, invert and transpose, inlined or not")
    func nonSquareIsRefused() {
        // One list rather than @Test(arguments:), because a tuple element pairing a
        // reference-counted member with a builtin vector of 32 bytes or more corrupts the Swift
        // task allocator whatever the body does (swiftlang/swift#91639, #1057). The elements here
        // are plain Ints and would be safe, and the list is kept anyway so the shape of this file
        // does not invite somebody to add a String or a SIMD3 case later.
        //
        // rows, cols, and whether rows * cols sits inside math_DoubleTab's 64-element buffer.
        let cases: [(rows: Int, cols: Int, inlined: Bool)] = [
            (3, 2, true),  // 6 elements: the case that returned -1 as a determinant
            (2, 32, true),  // 64 elements: exactly at the threshold, still inlined
            (2, 33, false),  // 66 elements: first size on the heap
            (100, 1, false),  // 100 elements: the SIGBUS case
            (1, 2, true),  // the smallest non-square of all
        ]
        for c in cases {
            let m = MathMatrix(rows: c.rows, cols: c.cols, initialValue: 1.0)
            #expect(m.rows == c.rows, "\(c.rows)x\(c.cols) reported \(m.rows) rows")
            #expect(m.cols == c.cols, "\(c.rows)x\(c.cols) reported \(m.cols) cols")
            #expect(!m.isSquare, "\(c.rows)x\(c.cols) reported itself square")
            let shape = "\(c.rows)x\(c.cols), inlined \(c.inlined)"
            #expect(m.determinant == nil, "\(shape) returned a determinant")
            #expect(!m.invert(), "\(c.rows)x\(c.cols) accepted invert()")
            #expect(!m.transpose(), "\(c.rows)x\(c.cols) accepted transpose()")
        }
    }

    @Test("A 0x0 MathMatrix is not square for this purpose, because Determinant() reports 1 for it")
    func zeroByZeroIsRefused() {
        // math_Matrix accepts the construction silently, and RowNumber() == ColNumber() == 0, so a
        // squareness-only guard would let all three operations through. Measured: Determinant() on a
        // 0x0 returns 1, a confident answer for a matrix with no entries
        // (Scripts/repro/2860-guard-preconditions/, mode `zero-dims-accessors`).
        let m = MathMatrix(rows: 0, cols: 0)
        #expect(m.rows == 0)
        #expect(!m.isSquare)
        #expect(m.determinant == nil)
        #expect(!m.invert())
        #expect(!m.transpose())
        // And every index of it is refused, which is the other half of #2860 finding 5.
        #expect(m.value(row: 1, col: 1) == nil)
        #expect(!m.setValue(row: 1, col: 1, value: 1.0))
    }

    @Test("A MathMatrix built with a negative dimension refuses every accessor")
    func negativeDimensionsRefuseEveryAccessor() {
        // math_Matrix(1, -5, 1, -5) constructs without complaint and reports RowNumber() == -5
        // (same probe, mode `negative-dims`), so the construction needs no refusal channel of its
        // own as long as every accessor is bounded by the reported counts, which is the branch
        // #2860's fix shape allows.
        let m = MathMatrix(rows: -5, cols: -5, initialValue: 7.0)
        #expect(m.rows == -5)
        #expect(!m.isSquare)
        #expect(m.determinant == nil)
        #expect(!m.invert())
        #expect(!m.transpose())
        #expect(m.value(row: 1, col: 1) == nil)
    }

    @Test("A square MathMatrix still computes the right determinant, inverse and transpose")
    func squareStillWorks() {
        // The other half of every guard: the refusal must not have cost the measurement.
        let m = MathMatrix(rows: 3, cols: 3)
        // [[2, 1, 0], [1, 3, 1], [0, 1, 4]], determinant 2*11 - 1*4 = 18.
        let entries: [(Int, Int, Double)] = [
            (1, 1, 2), (1, 2, 1), (1, 3, 0),
            (2, 1, 1), (2, 2, 3), (2, 3, 1),
            (3, 1, 0), (3, 2, 1), (3, 3, 4),
        ]
        for e in entries {
            #expect(m.setValue(row: e.0, col: e.1, value: e.2))
        }
        #expect(m.isSquare)
        if let det = m.determinant {
            #expect(abs(det - 18.0) < 1e-9, "determinant was \(det)")
        } else {
            Issue.record("a 3x3 was refused a determinant")
        }
        #expect(m.transpose())
        // The matrix is symmetric, so the transpose is itself; check an asymmetric pair separately.
        if let v = m.value(row: 1, col: 2) {
            #expect(abs(v - 1.0) < 1e-12)
        }
        #expect(m.invert())
    }

    @Test("transpose() actually transposes an asymmetric square matrix")
    func transposeSwapsOffDiagonals() {
        let m = MathMatrix(rows: 2, cols: 2)
        #expect(m.setValue(row: 1, col: 1, value: 1))
        #expect(m.setValue(row: 1, col: 2, value: 2))
        #expect(m.setValue(row: 2, col: 1, value: 3))
        #expect(m.setValue(row: 2, col: 2, value: 4))
        #expect(m.transpose())
        if let a12 = m.value(row: 1, col: 2), let a21 = m.value(row: 2, col: 1) {
            #expect(abs(a12 - 3.0) < 1e-12, "a12 was \(a12)")
            #expect(abs(a21 - 2.0) < 1e-12, "a21 was \(a21)")
        } else {
            Issue.record("a 2x2 refused a valid index after transpose()")
        }
    }

    // MARK: - math_Matrix indexing

    @Test("MathMatrix.value and setValue refuse every out-of-range 1-based index")
    func outOfRangeIndicesAreRefused() {
        let m = MathMatrix(rows: 3, cols: 3, initialValue: 1.0)
        // NCollection_Array2::Value flattens the pair to one position and bounds that against the
        // TOTAL element count only, so the list below contains two different defects and the
        // difference is measured rather than assumed (proved by removing the guard):
        //
        //   (9, 9) leaves the 9-element buffer, so NCollection_Array1::at throws, and since at is
        //   inline the throw was live here and crossed into Swift as an uncatchable SIGABRT
        //   (#345, exit 134 measured);
        //   (1, 4) STAYS inside it and returned 1.0, the element at (2, 1). No try can see that
        //   one, which is why the guard tests both indices rather than relying on the throw, and
        //   why this test asserts nil for every entry rather than only for the large ones.
        let bad: [(Int, Int)] = [
            (0, 1), (1, 0), (4, 1), (1, 4), (9, 9), (-1, 1), (1, -1),
            (Int(Int32.max), 1), (Int(Int32.min), 1),
            // Beyond Int32 entirely: the bridge takes an int32_t, so the wrapper has to refuse
            // rather than trap on the conversion.
            (Int(Int32.max) + 1, 1), (Int.max, Int.max),
        ]
        for (row, col) in bad {
            #expect(m.value(row: row, col: col) == nil, "value(row: \(row), col: \(col)) returned")
            #expect(
                !m.setValue(row: row, col: col, value: 0.5),
                "setValue(row: \(row), col: \(col)) accepted")
        }
        // And nothing the refusals touched changed the matrix.
        #expect(m.value(row: 1, col: 1) == .some(1.0))
        #expect(m.value(row: 3, col: 3) == .some(1.0))
    }

    @Test("MathMatrix accepts every in-range index, including all four corners")
    func inRangeIndicesRoundTrip() {
        let m = MathMatrix(rows: 2, cols: 3, initialValue: 0.0)
        var expected = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 2)
        for row in 1...2 {
            for col in 1...3 {
                let v = Double(row) * 10 + Double(col)
                #expect(m.setValue(row: row, col: col, value: v))
                expected[row - 1][col - 1] = v
            }
        }
        for row in 1...2 {
            for col in 1...3 {
                #expect(m.value(row: row, col: col) == .some(expected[row - 1][col - 1]))
            }
        }
    }

    // MARK: - math_Uzawa

    @Test("MathSolver.uzawa refuses more constraints than variables, inlined or not")
    func uzawaRefusesOverdetermined() {
        // math_Uzawa sizes Errinit on the constraint matrix's COLUMN count and writes it by ROW, so
        // nConstraints > nVars is an out-of-bounds write inside OCCT. This is the one precondition in
        // #2860 that turning -DBUILD_RELEASE_DISABLE_EXCEPTIONS back off would NOT restore: the
        // kernel's own Standard_DimensionError_Raise_if relates neither count to the other, and
        // math_Uzawa.cxx additionally #defines No_Standard_OutOfRange itself.
        //
        // nConstraints, nVars, and whether Errinit (length nVars) is inlined.
        let cases: [(nc: Int, nv: Int, inlined: Bool)] = [
            (4, 2, true),  // the case that returned a wrong answer with IsDone() == true
            (2, 1, true),
            (33, 32, true),  // one slot past the 32-element inline buffer
            (40, 33, false),  // Errinit on the heap, written 7 past its end
            (100, 2, true),  // the deterministic SIGSEGV
        ]
        for c in cases {
            let matrix = (0..<(c.nc * c.nv)).map { i in (i % (c.nv + 1) == 0) ? 1.0 : 0.25 }
            let result = MathSolver.uzawa(
                constraintMatrix: matrix,
                nConstraints: c.nc,
                nVars: c.nv,
                constraintRHS: [Double](repeating: 1.0, count: c.nc),
                startPoint: [Double](repeating: 0.0, count: c.nv))
            let shape = "nc \(c.nc), nv \(c.nv), inlined \(c.inlined)"
            #expect(result == nil, "uzawa(\(shape)) returned \(String(describing: result))")
        }
    }

    @Test("MathSolver.uzawa still solves a well-posed problem, and its answer is right")
    func uzawaStillSolves() {
        // Minimise the distance from the start point subject to x1 + x2 = 1. With nConstraints 1 and
        // nVars 2 the constraint matrix is 1x2, so Errinit is sized 2 and written to 1: inside its
        // own bounds, the direction that was always safe and is still accepted.
        guard
            let solved = MathSolver.uzawa(
                constraintMatrix: [1.0, 1.0],
                nConstraints: 1,
                nVars: 2,
                constraintRHS: [1.0],
                startPoint: [0.0, 0.0])
        else {
            Issue.record("uzawa refused a 1-constraint, 2-variable problem")
            return
        }
        #expect(solved.result.count == 2)
        // Whatever the iterate, it has to satisfy the constraint it was given.
        #expect(
            abs(solved.result[0] + solved.result[1] - 1.0) < 1e-5,
            "x1 + x2 = \(solved.result[0] + solved.result[1]), not 1")
        #expect(solved.iterations >= 1)

        // nConstraints == nVars is the boundary the guard admits, and it has to keep working.
        guard
            let square = MathSolver.uzawa(
                constraintMatrix: [1.0, 0.0, 0.0, 1.0],
                nConstraints: 2,
                nVars: 2,
                constraintRHS: [1.0, 2.0],
                startPoint: [0.0, 0.0])
        else {
            Issue.record("uzawa refused an equal-dimension problem")
            return
        }
        #expect(abs(square.result[0] - 1.0) < 1e-5, "x1 = \(square.result[0])")
        #expect(abs(square.result[1] - 2.0) < 1e-5, "x2 = \(square.result[1])")
    }

    // MARK: - gp_Trsf

    @Test("Shape.scaledAboutPoint refuses a null factor instead of returning a zero-volume solid")
    func scaleAboutPointRefusesNullFactor() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build the test box")
            return
        }
        // gp_Trsf::SetScale's own construction check is out-of-line and therefore absent from the
        // kernel we link, and GC_MakeScale has no status accessor at all, so before the guard
        // BRepBuilderAPI_Transform reported IsDone() == true and handed back a shape whose measured
        // volume was 0.
        #expect(box.scaledAboutPoint(SIMD3(0, 0, 0), factor: 0.0) == nil)
        #expect(box.scaledAboutPoint(SIMD3(0, 0, 0), factor: -0.0) == nil)
        #expect(
            box.scaledAboutPoint(SIMD3(0, 0, 0), factor: Double.leastNormalMagnitude / 2) == nil)
        #expect(box.scaledAboutPoint(SIMD3(1, 2, 3), factor: 0.0) == nil)

        // A legitimate factor, including a very small and a negative one, still goes through, and
        // still measures what it should: gp::Resolution() is 2.2250738585072014e-308, so 1e-6 is not
        // near it.
        if let doubled = box.scaledAboutPoint(SIMD3(0, 0, 0), factor: 2.0),
            let volume = doubled.volume
        {
            #expect(abs(volume - 8000.0) < 1e-6, "volume was \(volume)")
        } else {
            Issue.record("a factor of 2 was refused or produced no volume")
        }
        #expect(box.scaledAboutPoint(SIMD3(0, 0, 0), factor: 1e-6) != nil)
        #expect(box.scaledAboutPoint(SIMD3(0, 0, 0), factor: -1.0) != nil)
    }

    @Test("Shape.trsfModification refuses a singular 3x3 instead of building a nan transform")
    func trsfModificationRefusesSingularMatrix() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build the test box")
            return
        }
        // All-zero, and rank 2 (row 3 repeats row 2). Both measured determinant 0, and both used to
        // come back from gp_Trsf::SetValues with ScaleFactor = -0 and nan in the matrix.
        #expect(
            Shape.trsfModification(
                box,
                a11: 0, a12: 0, a13: 0, a14: 5,
                a21: 0, a22: 0, a23: 0, a24: 6,
                a31: 0, a32: 0, a33: 0, a34: 7) == nil)
        #expect(
            Shape.trsfModification(
                box,
                a11: 1, a12: 0, a13: 0, a14: 0,
                a21: 0, a22: 1, a23: 0, a24: 0,
                a31: 0, a32: 1, a33: 0, a34: 0) == nil)

        // A uniform scale of 2 has determinant 8 and must still be applied.
        if let scaled = Shape.trsfModification(
            box,
            a11: 2, a12: 0, a13: 0, a14: 0,
            a21: 0, a22: 2, a23: 0, a24: 0,
            a31: 0, a32: 0, a33: 2, a34: 0), let volume = scaled.volume
        {
            #expect(abs(volume - 8000.0) < 1e-6, "volume was \(volume)")
        } else {
            Issue.record("a uniform scale of 2 was refused")
        }
        // And so must a tiny but non-singular one: determinant 1e-15 is far above
        // gp::Resolution(), so the guard must not reject it.
        #expect(
            Shape.trsfModification(
                box,
                a11: 1e-5, a12: 0, a13: 0, a14: 0,
                a21: 0, a22: 1e-5, a23: 0, a24: 0,
                a31: 0, a32: 0, a33: 1e-5, a34: 0) != nil)
    }
}
