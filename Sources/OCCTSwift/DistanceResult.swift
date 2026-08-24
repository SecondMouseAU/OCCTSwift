import Foundation
import OCCTBridge
import simd

/// Result of distance measurement between two shapes.
public struct DistanceResult: Sendable, Equatable {
    /// Minimum distance between the shapes.
    public var distance: Double

    /// Closest point on the first shape.
    public var pointOnShape1: SIMD3<Double>

    /// Closest point on the second shape.
    public var pointOnShape2: SIMD3<Double>

    /// Number of solutions found (may be > 1 for symmetric cases).
    public var solutionCount: Int

    public init(
        distance: Double,
        pointOnShape1: SIMD3<Double>,
        pointOnShape2: SIMD3<Double>,
        solutionCount: Int
    ) {
        self.distance = distance
        self.pointOnShape1 = pointOnShape1
        self.pointOnShape2 = pointOnShape2
        self.solutionCount = solutionCount
    }
}
