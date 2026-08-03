import Foundation
import simd
import OCCTBridge

/// Result of shape analysis, containing counts of various problems found.
public struct ShapeAnalysisResult {
    /// Number of edges smaller than tolerance
    public let smallEdgeCount: Int

    /// Number of faces smaller than tolerance
    public let smallFaceCount: Int

    /// Number of gaps between edges/faces
    public let gapCount: Int

    /// Number of self-intersections detected
    public let selfIntersectionCount: Int

    /// Number of free (unconnected) edges
    public let freeEdgeCount: Int

    /// Number of free faces (shell not closed)
    public let freeFaceCount: Int

    /// Whether the topology is invalid
    public let hasInvalidTopology: Bool

    /// Total number of problems found
    public var totalProblems: Int {
        smallEdgeCount + smallFaceCount + gapCount + selfIntersectionCount + freeEdgeCount + freeFaceCount + (hasInvalidTopology ? 1 : 0)
    }

    /// Whether the shape appears to be healthy (no problems found)
    public var isHealthy: Bool {
        totalProblems == 0 && !hasInvalidTopology
    }
}
