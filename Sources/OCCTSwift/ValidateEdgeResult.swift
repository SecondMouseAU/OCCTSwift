import Foundation
import OCCTBridge
import simd

/// Edge validation result (3D curve vs curve-on-surface consistency).
public struct ValidateEdgeResult {
    public let isDone: Bool
    public let isWithinTolerance: Bool
    public let maxDistance: Double
    public let tolerance: Double
}
