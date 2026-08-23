import Foundation
import OCCTBridge
import simd

// Continuity order for filling constraints is `SurfaceContinuity` (Continuity.swift); the
// `FillingContinuity` copy this file used to declare is now a deprecated alias of it. See #398.

/// Builder for N-sided surface filling using BRepOffsetAPI_MakeFilling.
///
/// Creates a smooth surface that satisfies boundary edge constraints and optional.
/// interior point constraints.
///
/// Useful for creating patches that fill holes or.
/// connect multiple surface boundaries.
///
/// Shares its bridge implementation with ``Shape/fill(boundaries:parameters:)`` and
/// ``Shape/fill(constraints:parameters:)`` (#434); this is the incremental, stateful form
/// (build up constraints one call at a time and inspect per-build error introspection), where.
/// those are one-shot convenience calls over an array.
///
/// ```swift.
/// let edges = box.edges().
/// let filling = FillingSurface().
/// filling.add(edge: edges[0], continuity: .g0)
/// filling.add(edge: edges[1], continuity: .g0)
/// filling.add(edge: edges[2], continuity: .g0)
/// filling.add(edge: edges[3], continuity: .g0)
/// filling.add(point: SIMD3(5, 5, 3))  // surface passes through this point
/// let face = filling.build().
/// ```.
///
/// ## Refused constraints.
///
/// An add that returns false did not add its constraint, and that refusal is *sticky*:
/// ``build()`` then returns nil however many other constraints succeeded, rather than fitting a.
/// surface to a subset the caller never asked for (#482).
///
/// This is what.
/// ``Shape/fill(constraints:parameters:)`` has always done for the same input; ``build()``
/// used to succeed here instead.
///
/// Since every add is `@discardableResult`, the refusal is.
/// reported whether or not the return value was read.
///
/// Check `hasRefusedConstraint` to tell a.
/// poisoned build from an ordinary fitting failure.
///
/// ```swift.
/// let filling = FillingSurface().
/// filling.add(edge: e1, continuity: .g0)
/// filling.add(edge: rim, support: importedWall, continuity: .g1)  // false: no pcurve there
///
/// filling.hasRefusedConstraint   // true.
/// filling.build()                // nil, not a face fitted to e1 alone.
/// ```.
///
/// To attempt a constraint speculatively and carry on regardless, use.
/// ``add(edge:continuity:)``, which derives the continuity reference from the edge itself and
/// so has nothing to refuse.
public final class FillingSurface: @unchecked Sendable {
    private let handle: OCCTFillingRef

    /// Create a filling surface builder.
    ///
    /// - Parameters:
    ///   - degree: Target polynomial degree (default 3)
    ///   - pointsOnCurve: Number of discretization points on each constraint curve (default 15)
    ///   - maxDegree: Maximum polynomial degree (default 8)
    ///   - maxSegments: Maximum number of segments (default 9)
    ///   - tolerance: 3D tolerance (default 1e-4)
    public init(
        degree: Int = 3, pointsOnCurve: Int = 15, maxDegree: Int = 8,
        maxSegments: Int = 9, tolerance: Double = 1e-4
    ) {
        self.handle = OCCTFillingCreate(
            Int32(degree), Int32(pointsOnCurve),
            Int32(maxDegree), Int32(maxSegments), tolerance)
    }

    deinit {
        OCCTFillingRelease(handle)
    }

    /// Add a boundary edge constraint, deriving the continuity reference from the edge's own.
    /// underlying surface.
    ///
    /// - Parameters:
    ///   - edge: Edge to add as boundary constraint
    ///   - continuity: Continuity order at this edge (default .g0)
    /// - Returns: true if the edge was added successfully, which says nothing about whether
    ///   the order is usable: `BRepOffsetAPI_MakeFilling::Add` only appends, so a bad order
    ///   surfaces later as a nil ``build()`` that takes every other constraint with it.
    ///
    ///   With no support face to validate, this overload only refuses a constraint OCCT itself.
    ///   throws on; see `hasRefusedConstraint` for what a refusal costs.
    @discardableResult
    public func add(edge: Edge, continuity: SurfaceContinuity = .g0) -> Bool {
        OCCTFillingAddEdge(handle, edge.handle, continuity.rawValue)
    }

    /// Add a boundary edge constraint with an explicit reference face for tangency/curvature.
    ///
    /// Mirrors `FillConstraint`'s support-face semantics: a face named here is used or the
    /// constraint fails, rather than silently falling back to another surface.
    ///
    /// Use.
    /// ``add(edge:continuity:)`` to accept whichever surface the edge itself resolves instead.
    ///
    /// The failure is not confined to this call. A refusal here poisons ``build()``, which then.
    /// returns nil whatever else succeeded: the same answer
    /// ``Shape/fill(constraints:parameters:)`` gives for the same input (#482).
    ///
    /// - Note: support is only meaningful above `.g0`: a positional constraint has nothing
    ///   to be tangent or curvature-continuous *with*, so at `.g0` it is never read, matching.
    ///   `FillConstraint`, whose continuity also defaults to `.g1` rather than `.g0` for.
    ///   this reason.
    ///
    /// - Parameters:
    ///   - edge: Edge to add as boundary constraint
    ///   - support: Face to be continuous with.
    ///
    ///   Used or the constraint fails: if it carries no
    ///     pcurve for edge it cannot serve as the continuity reference.
    ///   - continuity: Continuity order at this edge (default .g1)
    /// - Returns: true if the edge was added successfully.
    ///
    /// False means the constraint is not in.
    ///   the builder and ``build()`` will return nil; `hasRefusedConstraint` reports the same.
    ///   thing later, for callers who discarded this result.
    @discardableResult
    public func add(edge: Edge, support: Face, continuity: SurfaceContinuity = .g1) -> Bool {
        OCCTFillingAddEdgeWithSupport(handle, edge.handle, support.handle, continuity.rawValue)
    }

    /// Add a free (non-boundary) edge constraint.
    ///
    /// Free edges are not required to be topologically connected to other edges.
    ///
    /// - Parameters:
    ///   - freeEdge: Edge to add as a free constraint
    ///   - continuity: Continuity order at this edge (default .g0)
    /// - Returns: true if the edge was added successfully
    @discardableResult
    public func add(freeEdge edge: Edge, continuity: SurfaceContinuity = .g0) -> Bool {
        OCCTFillingAddFreeEdge(handle, edge.handle, continuity.rawValue)
    }

    /// Add a point constraint that the filling surface must pass through.
    ///
    /// - Parameter point: 3D point the surface must interpolate
    /// - Returns: true if the point was added successfully
    @discardableResult
    public func add(point: SIMD3<Double>) -> Bool {
        OCCTFillingAddPoint(handle, point.x, point.y, point.z)
    }

    /// Build the filling surface and return the resulting shape.
    ///
    /// Returns nil without attempting the build if any add was refused (#482).
    ///
    /// Fitting a.
    /// surface to the constraints that did make it in would answer a different question than.
    /// the one the caller posed, so the refusal takes the whole build with it, matching.
    /// ``Shape/fill(constraints:parameters:)``.
    ///
    /// Check `hasRefusedConstraint` to tell that.
    /// case apart from a fit that was attempted and failed.
    ///
    /// - Returns: The filled face as a Shape, or nil if a constraint was refused or the fit
    ///   failed.
    public func build() -> Shape? {
        guard OCCTFillingBuild(handle) else { return nil }
        guard let ref = OCCTFillingGetFace(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Whether the filling surface has been successfully built.
    ///
    /// Stays false after a refused add, since ``build()`` never attempts the fit in that case.
    public var isDone: Bool {
        OCCTFillingIsDone(handle)
    }

    /// Number of add calls this builder refused (#482).
    ///
    /// A refused constraint is one that is *not* in the builder: a nominated support face
    /// carrying no pcurve for its edge, or a constraint OCCT threw on.
    ///
    /// Only ever increases: a
    /// later successful add does not clear it, because the refused constraint is still.
    /// missing from the surface that would be fitted.
    ///
    /// ```swift.
    /// let filling = FillingSurface().
    /// filling.add(edge: rim, support: importedWall, continuity: .g1)
    ///
    /// if filling.refusedConstraintCount > 0 {.
    ///     // build() will return nil; the wall carries no pcurve for the rim.
    /// }.
    /// ```.
    public var refusedConstraintCount: Int {
        Int(OCCTFillingRefusedConstraintCount(handle))
    }

    /// Whether any add was refused, which makes ``build()`` return nil (#482).
    ///
    /// The one signal that separates "a constraint never made it in" from "the fit was.
    /// attempted and failed".
    ///
    /// Both return nil from ``build()``.
    ///
    /// ```swift.
    /// guard let face = filling.build() else {.
    ///     print(filling.hasRefusedConstraint ? "a constraint was refused" : "the fit failed")
    ///     return.
    /// }.
    /// ```.
    public var hasRefusedConstraint: Bool {
        refusedConstraintCount > 0
    }

    /// Positional (G0) error of the built surface.
    ///
    /// Returns the maximum distance from the surface to its constraints.
    public var g0Error: Double? {
        let err = OCCTFillingG0Error(handle)
        return err >= 0 ? err : nil
    }

    /// Tangent (G1) error of the built surface.
    public var g1Error: Double? {
        let err = OCCTFillingG1Error(handle)
        return err >= 0 ? err : nil
    }

    /// Curvature (G2) error of the built surface.
    public var g2Error: Double? {
        let err = OCCTFillingG2Error(handle)
        return err >= 0 ? err : nil
    }
}
