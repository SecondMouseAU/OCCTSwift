import Foundation
import OCCTBridge
import simd

/// OCCT precision constants.
///
/// Every value is read from `Precision.hxx` through the bridge rather than restated here, so a
/// kernel repin moves them without a source change. They are compile-time constants in OCCT and
/// derived from one another: `intersection` is `confusion / 100`, `approximation` is
/// `confusion * 10`, and `pConfusion` is `confusion` converted to parametric space.
///
/// ```swift
/// let tol = OCCTPrecision.confusion          // 1e-7
/// if OCCTPrecision.isInfinite(surface.uMax) {
///     // an untrimmed, infinite surface: trim before converting to BSpline
/// }
/// ```
public enum OCCTPrecision {
    /// Confusion tolerance (1e-7), the general 3D distance tolerance.
    public static var confusion: Double { OCCTPrecisionConfusion() }
    /// Angular tolerance (1e-12), for direction comparisons.
    public static var angular: Double { OCCTPrecisionAngular() }
    /// Intersection tolerance (1e-9), `Precision::Confusion() / 100`.
    public static var intersection: Double { OCCTPrecisionIntersection() }
    /// Approximation tolerance (1e-6), `Precision::Confusion() * 10`, deliberately looser
    /// than ``confusion``.
    public static var approximation: Double { OCCTPrecisionApproximation() }
    /// Infinite value (2e100).
    public static var infinite: Double { OCCTPrecisionInfinite() }
    /// Parametric confusion tolerance (1e-9).
    ///
    /// A constant, not a function of the curve: `Precision::PConfusion()` is ``confusion``
    /// converted to parametric space for OCCT's default mean tangent length of 100. The
    /// overload that takes a tangent length, `Precision::PConfusion(T)`, is not wrapped (#1399).
    public static var pConfusion: Double { OCCTPrecisionPConfusion() }
    /// Check if a value is considered infinite.
    public static func isInfinite(_ value: Double) -> Bool { OCCTPrecisionIsInfinite(value) }
}
