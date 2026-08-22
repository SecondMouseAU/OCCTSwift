import Foundation
import OCCTBridge
import simd

/// Result of converting a curve to its analytical form.
public struct CurveToAnalyticalResult: Sendable {
    /// The recognized curve. Independent of the curve it was recognized from.
    public let curve: Curve3D
    /// Range start, expressed in `curve`'s own parameterization — not the input's.
    public let newFirst: Double
    /// Range end, expressed in `curve`'s own parameterization — not the input's.
    public let newLast: Double
    /// Maximum deviation from the input curve. Exactly `0` when the input was already analytical.
    public let gap: Double
}

/// Result of converting a surface to its analytical form.
public struct SurfaceToAnalyticalResult: Sendable {
    /// The recognized surface. Independent of the surface it was recognized from.
    public let surface: Surface
    /// Maximum deviation from the input surface. Exactly `0` when the input was already analytical.
    public let gap: Double
}
