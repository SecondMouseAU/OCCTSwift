import Foundation
import simd
import OCCTBridge

/// Polynomial-to-BSpline conversion utilities.
public enum PolynomialConvert {
    /// Result of polynomial to BSpline poles conversion.
    public struct PolesResult: Sendable {
        public let poles: [Double]
        public let knots: [Double]
        public let degree: Int
    }

    /// Convert a polynomial to BSpline poles and knots.
    /// - Parameters:
    ///   - dimension: Number of dimensions (1 for scalar, 3 for 3D)
    ///   - maxDegree: Maximum degree
    ///   - degree: Actual degree of polynomial
    ///   - coefficients: Polynomial coefficients (constant, linear, quadratic, ...)
    ///   - polynomialInterval: Parameter interval of the polynomial
    ///   - trueInterval: Target parameter interval for the BSpline
    public static func polynomialToPoles(
        dimension: Int, maxDegree: Int, degree: Int,
        coefficients: [Double],
        polynomialInterval: ClosedRange<Double>,
        trueInterval: ClosedRange<Double>
    ) -> PolesResult? {
        var outPoles: UnsafeMutablePointer<Double>?
        var outKnots: UnsafeMutablePointer<Double>?
        var outPoleCount: Int32 = 0
        var outKnotCount: Int32 = 0
        var outDegree: Int32 = 0
        let ok = coefficients.withUnsafeBufferPointer { buf in
            OCCTConvertPolynomialToPoles(
                Int32(dimension), Int32(maxDegree), Int32(degree),
                buf.baseAddress!, Int32(coefficients.count),
                polynomialInterval.lowerBound, polynomialInterval.upperBound,
                trueInterval.lowerBound, trueInterval.upperBound,
                &outPoles, &outPoleCount, &outKnots, &outKnotCount, &outDegree)
        }
        guard ok, let poles = outPoles, let knots = outKnots else { return nil }
        defer { free(poles); free(knots) }
        let polesArray = Array(UnsafeBufferPointer(start: poles, count: Int(outPoleCount) * dimension))
        let knotsArray = Array(UnsafeBufferPointer(start: knots, count: Int(outKnotCount)))
        return PolesResult(poles: polesArray, knots: knotsArray, degree: Int(outDegree))
    }
}
