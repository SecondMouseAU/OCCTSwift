import Foundation
import OCCTBridge
import simd

/// Classification of a point relative to a shape
public enum PointClassification: Int32, Sendable {
    /// Point is inside the shape
    case inside = 0  // TopAbs_IN
    /// Point is outside the shape
    case outside = 1  // TopAbs_OUT
    /// Point is on the boundary of the shape
    case onBoundary = 2  // TopAbs_ON
    /// Classification could not be determined
    case unknown = 3  // TopAbs_UNKNOWN
}
