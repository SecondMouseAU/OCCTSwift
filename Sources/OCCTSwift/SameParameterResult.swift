import Foundation
import OCCTBridge
import simd

/// Result of same-parameter check between 3D and 2D curves on a surface.
public struct SameParameterResult: Sendable {
    /// True if the curves already have the same parameterization.
    public let isSameParameter: Bool
    /// Maximum distance between the 3D curve and the surface evaluation of the 2D curve.
    public let toleranceReached: Double
}
