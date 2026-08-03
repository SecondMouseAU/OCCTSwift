import Foundation
import simd
import OCCTBridge

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
                    OCCTMathGaussSolve(mBuf.baseAddress!, Int32(n), bBuf.baseAddress!, xBuf.baseAddress!)
                }
            }
        }
        return ok ? solution : nil
    }

    /// Compute determinant using Gauss elimination.
    public static func determinant(matrix: [Double], n: Int) -> Double {
        matrix.withUnsafeBufferPointer { buf in
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
    public static func solve(matrix: [Double], rows: Int, cols: Int, rhs: [Double]) -> [Double]? {
        guard matrix.count == rows * cols, rhs.count == rows else { return nil }
        var solution = [Double](repeating: 0, count: cols)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            rhs.withUnsafeBufferPointer { bBuf in
                solution.withUnsafeMutableBufferPointer { xBuf in
                    OCCTMathSVDSolve(mBuf.baseAddress!, Int32(rows), Int32(cols), bBuf.baseAddress!, xBuf.baseAddress!)
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
                OCCTMathPolynomialRoots(cBuf.baseAddress!, Int32(coefficients.count), rBuf.baseAddress!)
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
    public static func eigenvalues(matrix: [Double], n: Int) -> [Double]? {
        guard matrix.count == n * n else { return nil }
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
    public static func solve(matrix: [Double], rows: Int, cols: Int, rhs: [Double]) -> [Double]? {
        guard matrix.count == rows * cols, rhs.count == rows, rows >= cols else { return nil }
        var solution = [Double](repeating: 0, count: cols)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            rhs.withUnsafeBufferPointer { bBuf in
                solution.withUnsafeMutableBufferPointer { xBuf in
                    OCCTMathHouseholderSolve(mBuf.baseAddress!, Int32(rows), Int32(cols),
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
                    OCCTMathCroutSolve(mBuf.baseAddress!, Int32(n), bBuf.baseAddress!, xBuf.baseAddress!)
                }
            }
        }
        return ok ? solution : nil
    }

    /// Determinant of symmetric matrix via Crout.
    public static func determinant(matrix: [Double], n: Int) -> Double {
        matrix.withUnsafeBufferPointer { buf in
            OCCTMathCroutDeterminant(buf.baseAddress!, Int32(n))
        }
    }
}
