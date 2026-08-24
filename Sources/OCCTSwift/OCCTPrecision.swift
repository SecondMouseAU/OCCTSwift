import Foundation
import OCCTBridge
import simd

/// OCCT precision constants.
public enum OCCTPrecision {
    /// Confusion tolerance (1e-7) — general distance tolerance.
    public static var confusion: Double { OCCTPrecisionConfusion() }
    /// Angular tolerance (1e-12) — for direction comparisons.
    public static var angular: Double { OCCTPrecisionAngular() }
    /// Intersection tolerance.
    public static var intersection: Double { OCCTPrecisionIntersection() }
    /// Approximation tolerance.
    public static var approximation: Double { OCCTPrecisionApproximation() }
    /// Infinite value (2e100).
    public static var infinite: Double { OCCTPrecisionInfinite() }
    /// Parametric confusion tolerance.
    public static var pConfusion: Double { OCCTPrecisionPConfusion() }
    /// Check if a value is considered infinite.
    public static func isInfinite(_ value: Double) -> Bool { OCCTPrecisionIsInfinite(value) }
}
