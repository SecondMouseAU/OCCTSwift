// Continuity vocabularies.
//
// OCCTSwift had grown nine separate enums for "continuity level", each written against a
// different bridge call and each re-deriving its own raw-int meaning (#398). They collapse
// into exactly three contracts, which is why there are two shared enums here rather than one:
//
//   1. Geometric constraint order, 0/1/2 = G0/G1/G2. Handed to a plate solver as the order of
//      a point, curve or edge constraint. GeomPlate_CurveConstraint validates it directly and
//      rejects anything outside [-1, 2] with the message "The continuity is not G0 G1 or G2".
//      That is `SurfaceContinuity`.
//
//   2. Required parametric continuity, 0/1/2/3 = C0/C1/C2/C3. Answers "split, approximate or
//      restrict this geometry so every piece is at least Cn". Reaches OCCT either as a real
//      GeomAbs_Shape continuity class or as a literal derivative-order integer.
//      That is `ParametricContinuity`.
//
//   3. A GeomAbs_Shape ordinal reported back as a *result*, which is a different job from
//      either input vocabulary above and keeps its own type: see `Surface.Continuity`.
//
// The two are not interchangeable even though both count 0, 1, 2. G1 asks only for parallel
// tangent directions; C1 asks for equal derivative vectors. Feeding one enum's raw value to
// the other's bridge call is precisely the class of defect #398 was filed about, so they are
// deliberately distinct types that will not silently substitute for one another.

// MARK: - Geometric constraint order (G0/G1/G2)

/// Geometric continuity order for a surface constraint.
///
/// The single vocabulary behind every OCCTSwift call that constrains a generated surface
/// against a point, edge or wire: ``Shape/fill(boundaries:parameters:)``,
/// ``Shape/fill(constraints:parameters:)``, ``FillingSurface`` and
/// ``Shape/plateSurface(through:orders:degree:pointsOnCurves:iterations:tolerance:)``.
/// All of them hand the raw value to OCCT as a plate constraint order.
///
/// ```swift
/// // Tangent to the wall the rim came from
/// let skinned = solid.fill(
///     constraints: [FillConstraint(edge: rimEdge, support: wallFace, continuity: .g1)]
/// )
///
/// // Curvature-continuous patch across a hole
/// let smooth = solid.fill(
///     boundaries: [holeWire],
///     parameters: FillingParameters(continuity: .g2)
/// )
/// ```
///
/// - Note: Not every API accepts every order. A bare point cannot carry curvature, so
///   ``Shape/plateSurface(through:orders:degree:pointsOnCurves:iterations:tolerance:)``
///   fails outright if any point is given ``g2`` (`GeomPlate_PointConstraint` throws above
///   order 1). ``FillingSurface`` currently mis-maps both non-default orders; see issue #433.
public enum SurfaceContinuity: Int32, Sendable, CaseIterable {
    /// Positional continuity (G0). The surface passes through the constraint.
    case g0 = 0
    /// Tangent continuity (G1). The surface is tangent along the constraint.
    case g1 = 1
    /// Curvature continuity (G2). The surface matches curvature along the constraint.
    case g2 = 2
}

extension SurfaceContinuity {
    /// Positional continuity. Former spelling of ``g0``.
    ///
    /// The G-prefixed spellings are canonical: these orders are geometric continuity, which is
    /// what OCCT itself calls them.
    @available(*, deprecated, renamed: "g0")
    public static var c0: SurfaceContinuity { .g0 }

    /// Tangent continuity. Former spelling of ``g1``, from `FillingContinuity`.
    @available(*, deprecated, renamed: "g1")
    public static var c1: SurfaceContinuity { .g1 }

    /// Curvature continuity. Former spelling of ``g2``, from `FillingContinuity`.
    @available(*, deprecated, renamed: "g2")
    public static var c2: SurfaceContinuity { .g2 }
}

/// Former name for ``SurfaceContinuity`` used by ``FillingSurface``.
@available(*, deprecated, renamed: "SurfaceContinuity")
public typealias FillingContinuity = SurfaceContinuity

/// Former name for ``SurfaceContinuity`` used by the plate-surface constraint APIs.
@available(*, deprecated, renamed: "SurfaceContinuity")
public typealias PlateConstraintOrder = SurfaceContinuity

// MARK: - Required parametric continuity (C0/C1/C2/C3)

/// Minimum parametric continuity to require of a piece of geometry.
///
/// Used wherever an operation splits, approximates or simplifies geometry against a continuity
/// floor: ``Shape/divided(at:)``, ``Shape/bsplineRestriction(tol3d:tol2d:maxDegree:maxSegments:continuity3d:continuity2d:degreePriority:rational:)``,
/// ``Curve3D/approxWithDetails(tolerance:continuity:maxSegments:maxDegree:)``,
/// ``Surface/approxWithDetails(tolerance:uContinuity:vContinuity:maxSegments:maxDegree:)`` and
/// ``Curve3D/continuityBreaks(minContinuity:)``.
///
/// ```swift
/// // Split a shape wherever it drops below C2
/// let pieces = shape.divided(at: .c2)
///
/// // Knots where a BSpline fails to be C3. A cubic interpolated curve is C2 at its
/// // interior knots, so .c3 is the order that actually reports them.
/// let breaks = bspline.continuityBreaks(minContinuity: .c3)
/// ```
///
/// - Note: This is *parametric* continuity (equal derivative vectors), not the geometric
///   G0/G1/G2 constraint order of ``SurfaceContinuity`` (parallel tangent directions). The
///   two count the same way but mean different things and are not interchangeable.
public enum ParametricContinuity: Int32, Sendable, CaseIterable {
    /// Positional continuity (C0).
    case c0 = 0
    /// First-derivative continuity (C1).
    case c1 = 1
    /// Second-derivative continuity (C2).
    case c2 = 2
    /// Third-derivative continuity (C3).
    case c3 = 3
}

/// Former name for ``ParametricContinuity`` used by ``Shape/divided(at:)``.
///
/// The old name was a misnomer: the value maps to `GeomAbs_C0` through `GeomAbs_C3`, which is
/// parametric continuity, not geometric. The geometric vocabulary is ``SurfaceContinuity``.
@available(*, deprecated, renamed: "ParametricContinuity")
public typealias GeometricContinuity = ParametricContinuity

/// Former name for ``ParametricContinuity`` used by the approximation APIs.
@available(*, deprecated, renamed: "ParametricContinuity")
public typealias ApproxContinuity = ParametricContinuity

extension Shape {
    /// Former name for ``ParametricContinuity`` used by BSpline restriction.
    @available(*, deprecated, renamed: "ParametricContinuity")
    public typealias BSplineContinuity = ParametricContinuity
}

extension Curve3D {
    /// Former name for ``ParametricContinuity`` used by knot-splitting analysis.
    ///
    /// The old enum stopped at `c2`, which made every value it offered a no-op on an ordinary
    /// cubic BSpline: such a curve is already C2 at its interior knots, so nothing below C3
    /// reports a break. ``ParametricContinuity/c3`` is reachable and fixes that.
    @available(*, deprecated, renamed: "ParametricContinuity")
    public typealias ContinuityOrder = ParametricContinuity
}
