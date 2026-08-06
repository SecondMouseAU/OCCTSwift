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

    /// Always 0. This has never been computed: the bridge's own comment on the field
    /// reads "would require more expensive computation", so it is not a measured absence of
    /// self-intersection, only an unimplemented one. Use ``Shape/isSelfIntersecting(timeout:)``
    /// for a real answer (#702).
    public let selfIntersectionCount: Int

    /// Number of free (unconnected) edges across every shell of the analyzed shape, via
    /// `ShapeAnalysis_Shell`. Before #702 this was hardcoded to 0 for every shape: the bridge
    /// called `LoadShells()`, which only registers a shell for bookkeeping and runs no edge
    /// analysis, instead of `CheckOrientedShells()`, which is what actually populates the
    /// free-edge set. A shape with a genuine gap, an open shell, or a solid `healed()`/
    /// `fixSolid()` could not close and returned as a shell instead, read 0 here regardless.
    public let freeEdgeCount: Int

    /// Number of shells, among every shell of the analyzed shape, found to have at least one
    /// free edge (i.e. not fully closed). Same #702 fix as ``freeEdgeCount``, since both come
    /// from the same per-shell scan.
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
