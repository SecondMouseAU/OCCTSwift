import Foundation
import OCCTBridge

/// Results from polynomial root solving.
public struct PolynomialRoots: Sendable {
    /// The real roots found, sorted ascending.
    public let roots: [Double]

    /// Number of real roots found.
    public var count: Int { roots.count }
}

/// Analytical polynomial solvers for degrees 2-4.
///
/// Uses OCCT's numerically stable implementations with
/// Newton-Raphson refinement and degenerate case handling.
///
/// ## Example
///
/// ```swift
/// // Solve x² - 5x + 6 = 0  →  x = 2, 3
/// let result = PolynomialSolver.quadratic(a: 1, b: -5, c: 6)
/// // result.roots == [2.0, 3.0]
///
/// // Solve x³ - 6x² + 11x - 6 = 0  →  x = 1, 2, 3
/// let cubic = PolynomialSolver.cubic(a: 1, b: -6, c: 11, d: -6)
/// ```
public enum PolynomialSolver {
    /// Solve a quadratic equation: ax² + bx + c = 0
    ///
    /// - Returns: 0, 1, or 2 real roots sorted ascending
    public static func quadratic(a: Double, b: Double, c: Double) -> PolynomialRoots {
        let result = OCCTSolveQuadratic(a, b, c)
        let n = Int(result.count)
        var roots = [Double]()
        if n > 0 { roots.append(result.roots.0) }
        if n > 1 { roots.append(result.roots.1) }
        return PolynomialRoots(roots: roots)
    }

    /// Solve a cubic equation: ax³ + bx² + cx + d = 0
    ///
    /// - Returns: 1, 2, or 3 real roots sorted ascending
    public static func cubic(a: Double, b: Double, c: Double, d: Double) -> PolynomialRoots {
        let result = OCCTSolveCubic(a, b, c, d)
        let n = Int(result.count)
        var roots = [Double]()
        if n > 0 { roots.append(result.roots.0) }
        if n > 1 { roots.append(result.roots.1) }
        if n > 2 { roots.append(result.roots.2) }
        return PolynomialRoots(roots: roots)
    }

    /// Solve a quartic equation: ax⁴ + bx³ + cx² + dx + e = 0
    ///
    /// - Returns: 0-4 real roots sorted ascending
    public static func quartic(a: Double, b: Double, c: Double, d: Double, e: Double)
        -> PolynomialRoots
    {
        let result = OCCTSolveQuartic(a, b, c, d, e)
        let n = Int(result.count)
        var roots = [Double]()
        if n > 0 { roots.append(result.roots.0) }
        if n > 1 { roots.append(result.roots.1) }
        if n > 2 { roots.append(result.roots.2) }
        if n > 3 { roots.append(result.roots.3) }
        return PolynomialRoots(roots: roots)
    }
}

extension PolynomialSolver {

    /// Find real roots of a polynomial of any degree using Laguerre's method.
    ///
    /// Coefficients are in ascending order (constant first):
    /// for polynomial a0 + a1*x + a2*x^2 + ... + an*x^n, pass [a0, a1, ..., an].
    /// - Parameter coefficients: Polynomial coefficients in ascending order
    /// - Returns: Array of real roots (sorted)
    public static func laguerreRoots(coefficients: [Double]) -> [Double] {
        let degree = coefficients.count - 1
        guard degree >= 1 else { return [] }
        var roots = [Double](repeating: 0, count: 20)
        let n = OCCTPolyLaguerreRoots(coefficients, Int32(degree), &roots, 20)
        return Array(roots.prefix(Int(n)))
    }

    /// Find complex roots of a polynomial using Laguerre's method.
    ///
    /// - Parameter coefficients: Polynomial coefficients in ascending order (constant first)
    /// - Returns: Array of (real, imaginary) pairs for complex roots
    public static func laguerreComplexRoots(coefficients: [Double]) -> [(
        real: Double, imaginary: Double
    )] {
        let degree = coefficients.count - 1
        guard degree >= 1 else { return [] }
        var realParts = [Double](repeating: 0, count: 20)
        var imagParts = [Double](repeating: 0, count: 20)
        let n = OCCTPolyLaguerreComplexRoots(
            coefficients, Int32(degree), &realParts, &imagParts, 20)
        return (0..<Int(n)).map { (realParts[$0], imagParts[$0]) }
    }

    /// Find real roots of a quintic polynomial: a*x^5 + b*x^4 + c*x^3 + d*x^2 + e*x + f = 0.
    ///
    /// - Returns: Array of real roots (sorted)
    public static func quinticRoots(
        a: Double, b: Double, c: Double, d: Double, e: Double, f: Double
    ) -> [Double] {
        var roots = [Double](repeating: 0, count: 5)
        let n = OCCTPolyQuinticRoots(a, b, c, d, e, f, &roots, 5)
        return Array(roots.prefix(Int(n)))
    }
}

extension PolynomialSolver {

    /// Solve linear equation: ax + b = 0 using MathPoly rc4 solver.
    public static func linearRc4(a: Double, b: Double) -> [Double]? {
        var roots = [Double](repeating: 0, count: 1)
        let n = OCCTMathPolyLinear(a, b, &roots, 1)
        return n >= 0 ? Array(roots.prefix(Int(n))) : nil
    }

    /// Solve quadratic equation: ax^2 + bx + c = 0 using MathPoly rc4 solver.
    public static func quadraticRc4(a: Double, b: Double, c: Double) -> [Double]? {
        var roots = [Double](repeating: 0, count: 2)
        let n = OCCTMathPolyQuadratic(a, b, c, &roots, 2)
        return n >= 0 ? Array(roots.prefix(Int(n))) : nil
    }

    /// Solve cubic equation: ax^3 + bx^2 + cx + d = 0 using MathPoly rc4 solver.
    public static func cubicRc4(a: Double, b: Double, c: Double, d: Double) -> [Double]? {
        var roots = [Double](repeating: 0, count: 3)
        let n = OCCTMathPolyCubic(a, b, c, d, &roots, 3)
        return n >= 0 ? Array(roots.prefix(Int(n))) : nil
    }

    /// Solve quartic equation: ax^4 + bx^3 + cx^2 + dx + e = 0 using MathPoly rc4 solver.
    public static func quarticRc4(a: Double, b: Double, c: Double, d: Double, e: Double)
        -> [Double]?
    {
        var roots = [Double](repeating: 0, count: 4)
        let n = OCCTMathPolyQuartic(a, b, c, d, e, &roots, 4)
        return n >= 0 ? Array(roots.prefix(Int(n))) : nil
    }
}
