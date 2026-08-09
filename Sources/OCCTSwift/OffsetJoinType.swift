import Foundation
import simd
import OCCTBridge

/// Join type for offset operations.
public enum OffsetJoinType: Int32, Sendable {
    /// Arc — fill gaps with pipe arcs and spheres (smooth, rounded)
    case arc = 0
    /// Tangent — tangent extension of faces
    case tangent = 1
    /// Intersection — extend and intersect adjacent faces (sharp edges)
    case intersection = 2
}
