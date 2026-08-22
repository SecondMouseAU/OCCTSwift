import Foundation
import OCCTBridge
import simd

/// Dense mathematical matrix with 1-based indexing.
public final class MathMatrix: @unchecked Sendable {
    let handle: OCCTMathMatrixRef

    init(handle: OCCTMathMatrixRef) { self.handle = handle }
    deinit { OCCTMathMatrixRelease(handle) }

    /// Create a matrix with given dimensions, initialized to a value.
    public init(rows: Int, cols: Int, initialValue: Double = 0.0) {
        handle = OCCTMathMatrixCreate(Int32(rows), Int32(cols), initialValue)
    }

    /// Number of rows.
    public var rows: Int { Int(OCCTMathMatrixRows(handle)) }
    /// Number of columns.
    public var cols: Int { Int(OCCTMathMatrixCols(handle)) }

    /// Get value at (row, col) — 1-based indexing.
    public func value(row: Int, col: Int) -> Double {
        OCCTMathMatrixGetValue(handle, Int32(row), Int32(col))
    }

    /// Set value at (row, col) — 1-based indexing.
    public func setValue(row: Int, col: Int, value: Double) {
        OCCTMathMatrixSetValue(handle, Int32(row), Int32(col), value)
    }

    /// Compute determinant.
    public var determinant: Double { OCCTMathMatrixDeterminant(handle) }

    /// Invert the matrix in-place.
    @discardableResult
    public func invert() -> Bool { OCCTMathMatrixInvert(handle) }

    /// Multiply all elements by a scalar.
    public func multiply(by scalar: Double) { OCCTMathMatrixMultiplyScalar(handle, scalar) }

    /// Transpose the matrix in-place.
    public func transpose() { OCCTMathMatrixTranspose(handle) }
}

/// Gaussian elimination linear system solver.
public enum MathGauss {

    /// Solve Ax=b where A is NxN and b is length N.
    /// - Parameters:
    ///   - matrix: Row-major NxN matrix (N*N elements)
    ///   - rhs: Right-hand side vector (N elements)
    /// - Returns: Solution vector, or nil on failure
    public static func solve(matrix: [Double], rhs: [Double]) -> [Double]? {
        let n = rhs.count
        guard matrix.count == n * n else { return nil }
        var solution = [Double](repeating: 0, count: n)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            rhs.withUnsafeBufferPointer { bBuf in
                solution.withUnsafeMutableBufferPointer { xBuf in
                    OCCTMathGaussSolve(
                        mBuf.baseAddress!, Int32(n), bBuf.baseAddress!, xBuf.baseAddress!)
                }
            }
        }
        return ok ? solution : nil
    }

    /// Compute determinant using Gauss elimination.
    ///
    /// Returns `nil`, not `0.0`, when `n` is not positive or does not match `matrix`'s
    /// length exactly (`matrix.count == n * n`) -- review finding 7 on #640: `0.0` is also
    /// the determinant of a genuinely singular matrix, so a bare `Double` sentinel could not
    /// tell "you gave me an invalid dimension" apart from "your matrix is singular", and it
    /// silently covered the positive-but-mismatched `n` case that used to crash loudly
    /// instead of returning anything at all. Before #640 the bridge looped
    /// `matrixData[i*n+j]` for `i, j in 0..<n` unconditionally, so a positive `n` larger than
    /// `matrix` read out of bounds rather than failing, and a negative `n` was a
    /// `Standard_Failure` the bridge's own `catch (...)` already absorbed into a crash-free
    /// (but, until now, indistinguishable) `0.0`. `n * n` itself is checked for overflow
    /// (review finding 8), so a large positive `n` is rejected rather than trapping the
    /// multiplication before this guard can run.
    ///
    /// ```swift
    /// MathGauss.determinant(matrix: [2.0, 1.0, 1.0, 3.0], n: 2)   // 5.0
    /// MathGauss.determinant(matrix: [1.0], n: -1)                 // nil, not 0.0
    /// ```
    public static func determinant(matrix: [Double], n: Int) -> Double? {
        guard MathDimension.validSquare(n, count: matrix.count) else { return nil }
        return matrix.withUnsafeBufferPointer { buf in
            OCCTMathGaussDeterminant(buf.baseAddress!, Int32(n))
        }
    }
}

/// Singular Value Decomposition solver.
public enum MathSVD {

    /// Solve least-squares Ax=b where A is MxN.
    /// - Parameters:
    ///   - matrix: Row-major MxN matrix
    ///   - rows: M
    ///   - cols: N
    ///   - rhs: Right-hand side (length M)
    /// - Returns: Solution vector (length N), or nil on failure
    ///
    /// `rows` and `cols` must both be positive. A consistency check alone is not enough
    /// (#640): `rows: 0, cols: -1` satisfies `matrix.count == rows * cols` exactly (`0 == 0`)
    /// and `rhs.count == rows` exactly (`0 == 0`), so without a positivity bound this still
    /// reaches `Array(repeating:count:)` with a negative count and traps. `rows * cols` is
    /// itself checked for overflow (review finding 8), so a huge positive `rows`/`cols` is
    /// rejected rather than trapping the multiplication before this guard can run.
    ///
    /// ```swift
    /// MathSVD.solve(matrix: [1, 0, 0, 1, 1, 1], rows: 3, cols: 2, rhs: [1, 2, 3])   // != nil
    /// MathSVD.solve(matrix: [], rows: 0, cols: -1, rhs: [])                        // nil
    /// ```
    public static func solve(matrix: [Double], rows: Int, cols: Int, rhs: [Double]) -> [Double]? {
        guard MathDimension.validRectangle(rows: rows, cols: cols, count: matrix.count),
            rhs.count == rows
        else { return nil }
        var solution = [Double](repeating: 0, count: cols)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            rhs.withUnsafeBufferPointer { bBuf in
                solution.withUnsafeMutableBufferPointer { xBuf in
                    OCCTMathSVDSolve(
                        mBuf.baseAddress!, Int32(rows), Int32(cols), bBuf.baseAddress!,
                        xBuf.baseAddress!)
                }
            }
        }
        return ok ? solution : nil
    }
}

/// Polynomial root finder (degree 1-4).
public enum MathPolynomialRoots {

    /// Find real roots of a polynomial.
    /// - Parameter coefficients: [a, b, c, ...] for a*x^n + b*x^(n-1) + ... (2-5 elements)
    /// - Returns: Array of real roots, or nil on error
    public static func solve(coefficients: [Double]) -> [Double]? {
        guard coefficients.count >= 2, coefficients.count <= 5 else { return nil }
        var roots = [Double](repeating: 0, count: 4)
        let n = coefficients.withUnsafeBufferPointer { cBuf in
            roots.withUnsafeMutableBufferPointer { rBuf in
                OCCTMathPolynomialRoots(
                    cBuf.baseAddress!, Int32(coefficients.count), rBuf.baseAddress!)
            }
        }
        if n < 0 { return nil }
        return Array(roots.prefix(Int(n)))
    }
}

/// Jacobi eigenvalue solver for symmetric matrices.
public enum MathJacobi {

    /// Compute eigenvalues of a symmetric NxN matrix.
    /// - Parameters:
    ///   - matrix: Row-major NxN symmetric matrix
    ///   - n: Dimension
    /// - Returns: Eigenvalues, or nil on failure
    ///
    /// `n` must be positive. `eigenvalues(matrix: [1.0], n: -1)` satisfies
    /// `matrix.count == n * n` exactly (`1 == (-1) * (-1)`) and would otherwise reach
    /// `Array(repeating:count:)` with a negative count and trap (#640). `n * n` is itself
    /// checked for overflow (review finding 8), so `n: .max` is rejected rather than
    /// trapping the multiplication before this guard can run.
    ///
    /// ```swift
    /// MathJacobi.eigenvalues(matrix: [4.0, 1.0, 1.0, 4.0], n: 2)   // != nil
    /// MathJacobi.eigenvalues(matrix: [1.0], n: -1)                 // nil, not a trap
    /// ```
    public static func eigenvalues(matrix: [Double], n: Int) -> [Double]? {
        guard MathDimension.validSquare(n, count: matrix.count) else { return nil }
        var eigenvalues = [Double](repeating: 0, count: n)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            eigenvalues.withUnsafeMutableBufferPointer { eBuf in
                OCCTMathJacobiEigenvalues(mBuf.baseAddress!, Int32(n), eBuf.baseAddress!)
            }
        }
        return ok ? eigenvalues : nil
    }
}

/// Householder QR least-squares solver.
public enum MathHouseholder {

    /// Solve overdetermined Ax=b using Householder QR (M >= N).
    ///
    /// `rows` and `cols` must both be positive, the same positivity gap as `MathSVD.solve`
    /// (#640): `rows >= cols` alone does not exclude `rows: 0, cols: -1`. `rows * cols` is
    /// itself checked for overflow (review finding 8).
    ///
    /// ```swift
    /// MathHouseholder.solve(matrix: [1, 0, 0, 1, 1, 1], rows: 3, cols: 2, rhs: [1, 2, 3])   // != nil
    /// MathHouseholder.solve(matrix: [], rows: 0, cols: -1, rhs: [])                        // nil
    /// ```
    public static func solve(matrix: [Double], rows: Int, cols: Int, rhs: [Double]) -> [Double]? {
        guard MathDimension.validRectangle(rows: rows, cols: cols, count: matrix.count),
            rhs.count == rows, rows >= cols
        else { return nil }
        var solution = [Double](repeating: 0, count: cols)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            rhs.withUnsafeBufferPointer { bBuf in
                solution.withUnsafeMutableBufferPointer { xBuf in
                    OCCTMathHouseholderSolve(
                        mBuf.baseAddress!, Int32(rows), Int32(cols),
                        bBuf.baseAddress!, xBuf.baseAddress!)
                }
            }
        }
        return ok ? solution : nil
    }
}

/// Crout LDL^T solver for symmetric systems.
public enum MathCrout {

    /// Solve symmetric Ax=b using Crout decomposition.
    public static func solve(matrix: [Double], rhs: [Double]) -> [Double]? {
        let n = rhs.count
        guard matrix.count == n * n else { return nil }
        var solution = [Double](repeating: 0, count: n)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            rhs.withUnsafeBufferPointer { bBuf in
                solution.withUnsafeMutableBufferPointer { xBuf in
                    OCCTMathCroutSolve(
                        mBuf.baseAddress!, Int32(n), bBuf.baseAddress!, xBuf.baseAddress!)
                }
            }
        }
        return ok ? solution : nil
    }

    /// Determinant of symmetric matrix via Crout.
    ///
    /// Same fix as `MathGauss.determinant` (#640, review finding 7): returns `nil`, not
    /// `0.0`, when `n` is not positive or does not match `matrix`'s length exactly, since a
    /// bare `Double` sentinel cannot tell an invalid dimension apart from a genuinely
    /// singular matrix. Before #640 the bridge's unconditional `matrixData[i*n+j]` loop read
    /// out of bounds on a mismatch. `n * n` is checked for overflow (review finding 8).
    ///
    /// ```swift
    /// MathCrout.determinant(matrix: [4.0, 2.0, 2.0, 3.0], n: 2)   // 8.0
    /// MathCrout.determinant(matrix: [1.0], n: -1)                 // nil, not 0.0
    /// ```
    public static func determinant(matrix: [Double], n: Int) -> Double? {
        guard MathDimension.validSquare(n, count: matrix.count) else { return nil }
        return matrix.withUnsafeBufferPointer { buf in
            OCCTMathCroutDeterminant(buf.baseAddress!, Int32(n))
        }
    }
}
