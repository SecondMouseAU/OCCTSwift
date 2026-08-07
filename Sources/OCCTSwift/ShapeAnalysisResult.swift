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

    /// Whether the shape self-intersects, or `nil` if ``Shape/analyze(tolerance:selfIntersectionTimeout:)``
    /// was not asked to check (#772).
    ///
    /// `nil` means **unmeasured, not clean**: it covers two distinct cases the type deliberately
    /// does not distinguish, the caller passed `selfIntersectionTimeout: nil` (the default), or
    /// passed a timeout but the check did not resolve within it (matches
    /// ``Shape/isSelfIntersecting(timeout:)``'s own `nil` = indeterminate). Either way, treat
    /// `nil` as "unknown", the same rule `isSelfIntersecting` already documents.
    ///
    /// This is opt-in rather than always-on because the underlying check
    /// (`BOPAlgo_ArgumentAnalyzer`'s self-interference test, #319) is orders of magnitude more
    /// expensive than the small-edge/small-face/gap scan the rest of this type reports, and on
    /// pathological input the gap is not small: measured on the #319 artifact, ~3000x-4000x the
    /// cost of the rest of the scan combined (a few ms vs 30s at a 30s timeout). On ordinary
    /// shapes (a primitive, a several-boolean-and-fillet part, a 662-face mesh-sewn import) the
    /// measured overhead was 1x-3x, cheap enough to opt into freely. See
    /// `Scripts/repro/772-analyze-self-intersection/` for the full measurement, including why the
    /// analysis forwards to ``Shape/isSelfIntersecting(timeout:)`` rather than
    /// ``Shape/isSelfIntersecting(hardTimeout:)`` (measuring both, not just the pathological
    /// case, found the latter is not a strict improvement here).
    ///
    /// This is the replacement for the `selfIntersectionCount` field removed in #763 (it was
    /// always 0, never computed). Non-`nil` is reachable on a real path (not an always-closed
    /// gate, see #771): pass a non-`nil` `selfIntersectionTimeout` to a shape the check resolves
    /// for within it.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.analyze()!.hasSelfIntersection)                                    // nil: not asked
    /// print(box.analyze(selfIntersectionTimeout: 30)!.hasSelfIntersection)         // Optional(false)
    ///
    /// let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)!
    /// let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)!
    /// let overlapping = Shape.compound([a, b])!
    /// print(overlapping.analyze(selfIntersectionTimeout: 30)!.hasSelfIntersection) // Optional(true)
    /// ```
    public let hasSelfIntersection: Bool?

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
    ///
    /// Not counted in ``totalProblems``: this is a derived summary of the same scan, not an
    /// independent defect. It is never nonzero unless ``freeEdgeCount`` is also nonzero (a shell
    /// only contributes here because it has at least one free edge, which ``freeEdgeCount``
    /// already counted), so adding both would count one open shell's boundary gap twice, once per
    /// edge and once more as a flat "+1 shell" (#717 review).
    public let freeFaceCount: Int

    /// Whether the topology is invalid
    public let hasInvalidTopology: Bool

    /// Total number of problems found.
    ///
    /// Sums each independent defect category once: small edges, small faces, gaps, free edges,
    /// self-intersection (a flat +1 when ``hasSelfIntersection`` is `true`, `+0` when it is
    /// `false` **or `nil`**: a `nil` here means "not checked", not "clean", so this total does
    /// not reflect self-intersection at all unless the analysis was run with a non-`nil`
    /// `selfIntersectionTimeout`), and invalid topology (a flat +1, not a count).
    /// ``freeFaceCount`` is deliberately excluded: see its doc comment for why including it
    /// would double-count the same open-shell defect ``freeEdgeCount`` already reports.
    public var totalProblems: Int {
        smallEdgeCount + smallFaceCount + gapCount + freeEdgeCount
            + (hasInvalidTopology ? 1 : 0)
            + (hasSelfIntersection == true ? 1 : 0)
    }

    /// Whether the shape appears to be healthy (no problems found).
    ///
    /// - Important: If the analysis did not pass a non-`nil` `selfIntersectionTimeout`, this says
    ///   nothing about self-intersection either way; see ``hasSelfIntersection``.
    public var isHealthy: Bool {
        totalProblems == 0 && !hasInvalidTopology
    }
}
