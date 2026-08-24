import Foundation
import OCCTBridge
import simd

/// One edge constraint for ``Shape/fill(constraints:parameters:)``.
///
/// Pairs an edge with the face the filled surface should be continuous with. Tangency and
/// curvature are relative to *something* — without a `support` face, the edge's own
/// underlying surface is used, and an edge that has neither can only be constrained
/// positionally.
///
/// ```swift
/// // Tangent to the wall the rim came from
/// let tangent = FillConstraint(edge: rimEdge, support: wallFace, continuity: .g1)
///
/// // Pass through this edge, but let it float otherwise
/// let positional = FillConstraint(edge: freeEdge, continuity: .g0)
///
/// // Pull the surface through an interior edge without it bounding the face
/// let interior = FillConstraint(edge: ridgeEdge, continuity: .g0, isBoundary: false)
/// ```
public struct FillConstraint {
    /// Edge the filled surface must satisfy.
    public var edge: Edge
    /// Face to be continuous with, or nil to derive one from the edge itself.
    ///
    /// A face named here is used or the fill fails: if it carries no pcurve for `edge` it
    /// cannot serve as the continuity reference, and the whole fill returns nil rather than
    /// quietly substituting a different surface. Leave it nil to accept whichever surface the
    /// edge itself resolves.
    public var support: Face?
    /// Continuity order at this edge.
    public var continuity: SurfaceContinuity
    /// Whether this edge bounds the resulting face (true) or is an internal constraint (false).
    public var isBoundary: Bool

    /// Create an edge constraint.
    ///
    /// - Parameters:
    ///   - edge: Edge the filled surface must satisfy
    ///   - support: Face to be continuous with, used or the fill fails (default nil — derived
    ///     from the edge)
    ///   - continuity: Continuity order at this edge (default .g1)
    ///   - isBoundary: Whether the edge bounds the resulting face (default true)
    public init(
        edge: Edge,
        support: Face? = nil,
        continuity: SurfaceContinuity = .g1,
        isBoundary: Bool = true
    ) {
        self.edge = edge
        self.support = support
        self.continuity = continuity
        self.isBoundary = isBoundary
    }
}

/// Parameters for surface filling operations.
public struct FillingParameters {
    /// Surface continuity at boundaries.
    public var continuity: SurfaceContinuity
    /// Surface tolerance.
    public var tolerance: Double
    /// Maximum surface degree.
    public var maxDegree: Int
    /// Maximum number of segments.
    public var maxSegments: Int

    /// Create filling parameters with defaults.
    public init(
        continuity: SurfaceContinuity = .g1,
        tolerance: Double = 1e-4,
        maxDegree: Int = 8,
        maxSegments: Int = 9
    ) {
        self.continuity = continuity
        self.tolerance = tolerance
        self.maxDegree = maxDegree
        self.maxSegments = maxSegments
    }

    internal var cParams: OCCTFillingParams {
        OCCTFillingParams(
            continuity: continuity.rawValue,
            tolerance: tolerance,
            maxDegree: Int32(maxDegree),
            maxSegments: Int32(maxSegments)
        )
    }
}
