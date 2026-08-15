import Foundation
import simd

// MARK: - Ad-hoc measurement helpers (v0.143 M3, M4)
//
// Small ergonomic layer on top of OCCTSwift's existing measurement coverage.
// These aren't new capabilities — the underlying geometry is already wrapped —
// they're the one-liner accessors users reach for in agent / viewport workflows
// where clicking two entities and reading an angle or a radius is the core UX.

// MARK: - Angles

extension Edge {
    /// This edge's curve parameter at a normalized `[0, 1]` fraction of its parameter
    /// bounds, via naive linear interpolation over the raw parameter domain — NOT arc
    /// length. `Shape.edgeParameterAtFraction(_:)` is the arc-length-accurate variant
    /// (#603); the two disagree on non-uniformly-parameterized curves (ellipses,
    /// BSplines). `fraction` is clamped to `[0, 1]` first.
    ///
    /// Internal: the shared fraction→parameter idiom `resolveEdgePointAndTangent`/
    /// `resolveEdgeDirection` (`ConstructionEntity.swift`) and `angle(to:atParameter:)`
    /// below both used to inline separately (#888). Named distinctly from
    /// `edgeParameterAtFraction(_:)` so the two don't read as interchangeable (PR #897
    /// review, finding 10).
    internal func parameterByLinearFraction(_ fraction: Double) -> Double? {
        guard let bounds = parameterBounds else { return nil }
        let clamped = max(0, min(1, fraction))
        return bounds.first + (bounds.last - bounds.first) * clamped
    }

    /// This edge's 3D point at a normalized `[0, 1]` fraction of its parameter bounds,
    /// via `parameterByLinearFraction(_:)` — naive linear interpolation, not arc length.
    ///
    /// Convenience over `parameterByLinearFraction(_:)` + `point(at:)`.
    internal func pointByLinearFraction(_ fraction: Double) -> SIMD3<Double>? {
        guard let param = parameterByLinearFraction(fraction) else { return nil }
        return point(at: param)
    }

    /// Angle between this edge's tangent and another edge's tangent, measured at
    /// their respective mid-parameters.
    ///
    /// Returns radians in [0, π]. For straight edges the result is the line-line
    /// angle. For curved edges it's the angle between the mid-curve tangents —
    /// useful as an approximation but note the angle varies along a curve; pass
    /// `atParameter:` for a specific point.
    public func angle(to other: Edge, atParameter t: Double = 0.5) -> Double? {
        guard let p = parameterByLinearFraction(t), let op = other.parameterByLinearFraction(t)
        else {
            return nil
        }
        guard let t1 = tangent(at: p), let t2 = other.tangent(at: op) else { return nil }
        return unsignedAngle(between: t1, and: t2)
    }

    /// Whether this edge is parallel to another at the given tangent-comparison tolerance (radians).
    ///
    /// Convenience over `angle(to:)`. Shares its tolerance-comparison formula with
    /// `normalsAreParallel(_:_:toleranceRadians:)` below via `angleIsParallel(_:toleranceRadians:)`
    /// instead of inlining its own copy (PR #897 review, second xhigh pass, finding 6/11).
    public func isParallel(to other: Edge, toleranceRadians: Double = 1e-4) -> Bool? {
        guard let a = angle(to: other) else { return nil }
        return angleIsParallel(a, toleranceRadians: toleranceRadians)
    }

    /// Whether this edge is perpendicular to another at the given tangent-comparison
    /// tolerance (radians).
    public func isPerpendicular(to other: Edge, toleranceRadians: Double = 1e-4) -> Bool? {
        guard let a = angle(to: other) else { return nil }
        return abs(a - .pi / 2) < toleranceRadians
    }
}

extension Face {
    /// This face's UV-domain midpoint, shared by `uvMidpointPoint()`, `uvMidpointNormal()`,
    /// and `uvMidpointSample()` below.
    private var uvMidpoint: (u: Double, v: Double)? {
        guard let bounds = uvBounds else { return nil }
        return ((bounds.uMin + bounds.uMax) / 2, (bounds.vMin + bounds.vMax) / 2)
    }

    /// This face's point sampled at its UV-domain midpoint, without evaluating the normal too.
    ///
    /// Use this over `uvMidpointSample()` when only the point is needed (e.g.
    /// `revolutionProperties`, PR #897 review) to skip a redundant `normal(atU:v:)` evaluation.
    internal func uvMidpointPoint() -> SIMD3<Double>? {
        guard let mid = uvMidpoint else { return nil }
        return point(atU: mid.u, v: mid.v)
    }

    /// This face's normal sampled at its UV-domain midpoint, without evaluating the point too.
    ///
    /// Use this over `uvMidpointSample()` when only the normal is needed (e.g. `angle(to:)`,
    /// `resolveFaceAxisDirection`'s fallback, PR #897 review) to skip a redundant
    /// `point(atU:v:)` evaluation.
    internal func uvMidpointNormal() -> SIMD3<Double>? {
        guard let mid = uvMidpoint else { return nil }
        return normal(atU: mid.u, v: mid.v)
    }

    /// This face's point + normal sampled at its UV-domain midpoint — a cheap,
    /// always-available representative sample, not the area centroid (see
    /// `surfaceInertia.centerOfMass` for that).
    ///
    /// Internal: this formula used to be reimplemented inline at 7 call sites
    /// across `ConstructionEntity.swift` and this file (#889). Callers that only
    /// need one of the two components should call `uvMidpointPoint()` /
    /// `uvMidpointNormal()` directly instead, to avoid paying for the unused one.
    ///
    /// Computes `uvMidpoint` once and evaluates both `point(atU:v:)`/`normal(atU:v:)`
    /// against it directly, rather than delegating to `uvMidpointPoint()`/
    /// `uvMidpointNormal()` — those each independently re-derive `uvMidpoint`, which
    /// would fetch `uvBounds` twice per call here (PR #897 review, 2nd pass).
    internal func uvMidpointSample() -> (point: SIMD3<Double>, normal: SIMD3<Double>)? {
        guard let mid = uvMidpoint else { return nil }
        guard let samplePoint = point(atU: mid.u, v: mid.v),
            let sampleNormal = normal(atU: mid.u, v: mid.v)
        else {
            return nil
        }
        return (samplePoint, sampleNormal)
    }

    /// Angle between this face's normal and another face's normal, evaluated at the UV midpoint of each.
    ///
    /// Returns radians in [0, π]. For two planar faces this is the dihedral angle
    /// + π/2 correction; for curved faces it's a point estimate.
    public func angle(to other: Face) -> Double? {
        guard let normal = uvMidpointNormal(), let otherNormal = other.uvMidpointNormal() else {
            return nil
        }
        return unsignedAngle(between: normal, and: otherNormal)
    }

    /// Whether this face is parallel to another at the given normal-comparison tolerance (radians).
    ///
    /// Samples both normals directly (rather than via `angle(to:)`) so this and
    /// `isCoplanar(with:)` can share `normalsAreParallel(_:_:toleranceRadians:)` below.
    public func isParallel(to other: Face, toleranceRadians: Double = 1e-4) -> Bool? {
        guard let normal = uvMidpointNormal(), let otherNormal = other.uvMidpointNormal() else {
            return nil
        }
        return normalsAreParallel(normal, otherNormal, toleranceRadians: toleranceRadians)
    }

    /// Whether this face is perpendicular to another (normals at 90°).
    public func isPerpendicular(to other: Face, toleranceRadians: Double = 1e-4) -> Bool? {
        guard let a = angle(to: other) else { return nil }
        return abs(a - .pi / 2) < toleranceRadians
    }

    /// Whether this face is coplanar with another — normals parallel AND origin
    /// lies on the other face's plane. `nil` (not `false`) when either face's
    /// UV-midpoint normal/point is unavailable, or when the two faces aren't parallel.
    ///
    /// Checks the (cheaper) normals first, via the same `uvMidpointNormal()` +
    /// `normalsAreParallel(_:_:toleranceRadians:)` shape `isParallel(to:)` above uses, and only
    /// fetches each face's UV-midpoint *point* — a second, independent `point(atU:v:)`
    /// evaluation per face — once the normals are confirmed parallel. An all-pairs coplanarity
    /// sweep (feature recognition, symmetry detection) spends most of its calls on non-parallel
    /// pairs, so short-circuiting there before ever touching `point(atU:v:)` matters: the
    /// previous shape called `uvMidpointSample()` (point AND normal) for both faces unconditionally
    /// up front, paying for 2 points it would then discard on every non-parallel pair (PR #897
    /// review, second xhigh pass, finding 7) — the same class of avoidable re-evaluation this
    /// file's `uvMidpointPoint()`/`uvMidpointNormal()` split exists to let callers skip.
    public func isCoplanar(with other: Face, tolerance: Double = 1e-6) -> Bool? {
        guard let normal = uvMidpointNormal(), let otherNormal = other.uvMidpointNormal() else {
            return nil
        }
        guard normalsAreParallel(normal, otherNormal, toleranceRadians: 1e-4) == true else {
            return nil
        }
        guard let point = uvMidpointPoint(), let otherPoint = other.uvMidpointPoint() else {
            return nil
        }
        let offset = point - otherPoint
        let signedDist = abs(simd_dot(offset, simd_normalize(otherNormal)))
        return signedDist < tolerance
    }
}

extension ConstructionAxis {
    /// Angle between two construction axes, resolved against the given graph.
    ///
    /// Returns radians in [0, π].
    public func angle(to other: ConstructionAxis, in graph: BRepGraph) -> Double? {
        guard case .success(let a) = graph.resolve(self),
            case .success(let b) = graph.resolve(other)
        else { return nil }
        return unsignedAngle(between: a.direction, and: b.direction)
    }
}

extension ConstructionPlane {
    /// Angle between two construction planes (angle between their normals).
    ///
    /// Returns radians in [0, π].
    public func angle(to other: ConstructionPlane, in graph: BRepGraph) -> Double? {
        guard case .success(let a) = graph.resolve(self),
            case .success(let b) = graph.resolve(other)
        else { return nil }
        return unsignedAngle(between: a.zAxis, and: b.zAxis)
    }
}

/// Unsigned angle in [0, π] between two 3D vectors.
///
/// Returns nil for degenerate (near-zero-length) input — this doc already claimed
/// nil for that case while the implementation unconditionally returned `0`, silently
/// reporting a degenerate/near-singular normal as "parallel" to anything through
/// `normalsAreParallel` below (PR #897 review, finding 5).
public func unsignedAngle(between a: SIMD3<Double>, and b: SIMD3<Double>) -> Double? {
    let la = simd_length(a)
    let lb = simd_length(b)
    guard la > 1e-12, lb > 1e-12 else { return nil }
    let cosTheta = simd_dot(a, b) / (la * lb)
    return acos(max(-1.0, min(1.0, cosTheta)))
}

/// Whether `angle` (already computed, radians in `[0, π]`) is within `toleranceRadians` of `0`
/// or `π` — i.e. whether the two directions it was measured between are parallel or
/// anti-parallel.
///
/// Shared by `Edge.isParallel(to:)` above and `normalsAreParallel(_:_:toleranceRadians:)` below,
/// which used to each inline this identical comparison independently (PR #897 review, second
/// xhigh pass, finding 6/11) — a future correction to the boundary behavior (e.g. exactly at
/// `angle == toleranceRadians`) now only has one implementation to fix.
internal func angleIsParallel(_ angle: Double, toleranceRadians: Double) -> Bool {
    angle < toleranceRadians || (.pi - angle) < toleranceRadians
}

/// Whether two already-sampled face normals are parallel (or anti-parallel) within
/// `toleranceRadians`. `nil` (not `false`) when either normal is degenerate
/// (near-zero-length) — propagated from `unsignedAngle`, rather than reporting a
/// degenerate normal as parallel to everything (PR #897 review, finding 5).
///
/// Shared by `Face.isParallel(to:)` and `Face.isCoplanar(with:)` so callers that
/// already hold both normals (`isCoplanar`, from its own `uvMidpointSample()` calls)
/// don't have to re-derive them just to reuse the tolerance check (PR #897 review,
/// 3rd + 4th pass).
internal func normalsAreParallel(
    _ normal: SIMD3<Double>, _ otherNormal: SIMD3<Double>, toleranceRadians: Double
) -> Bool? {
    guard let normalAngle = unsignedAngle(between: normal, and: otherNormal) else { return nil }
    return angleIsParallel(normalAngle, toleranceRadians: toleranceRadians)
}

// MARK: - Circle properties (v0.143 M4)

extension Edge {
    /// Extracted circle / arc geometry for an edge whose underlying curve is a circle.
    ///
    /// Returns nil for non-circular edges.
    public struct CircleProperties: Sendable, Hashable {
        public let center: SIMD3<Double>
        public let radius: Double
        public let axis: SIMD3<Double>  // unit normal to the circle's plane
        public let isFullCircle: Bool
        public let startAngle: Double  // radians; 0 for a full circle
        public let endAngle: Double  // radians; 2π for a full circle
    }

    /// Circle / arc properties if this edge is a circular edge.
    ///
    /// Returns nil for straight lines, ellipses, BSpline curves, etc.
    public var circleProperties: CircleProperties? {
        guard curveType == .circle else { return nil }
        guard let bounds = parameterBounds else { return nil }
        let range = bounds.last - bounds.first
        let full = abs(range - 2 * .pi) < 1e-6
        // For a Geom_Circle parameterisation, start/end parameters are the angles.
        // The point at parameter 0 is on the +X axis of the circle's local frame;
        // we recover centre and radius from three sampled points. A full circle
        // is periodic, so point(at: bounds.last) coincides with point(at: bounds.first)
        // to floating-point precision — sample interior thirds instead so all
        // three points are distinct.
        let sample1Param = bounds.first
        let sample2Param = bounds.first + range * (full ? 1.0 / 3.0 : 0.5)
        let sample3Param = bounds.first + range * (full ? 2.0 / 3.0 : 1.0)
        guard let p1 = point(at: sample1Param),
            let p2 = point(at: sample2Param),
            let p3 = point(at: sample3Param)
        else { return nil }
        guard let (center, radius, axis) = circleThroughThreePoints(p1, p2, p3) else { return nil }
        return CircleProperties(
            center: center, radius: radius, axis: axis,
            isFullCircle: full,
            startAngle: bounds.first,
            endAngle: bounds.last)
    }
}

extension Face {
    /// Axis + radius of a cylindrical / conical / toroidal / spherical face.
    ///
    /// Returns nil for planar or free-form faces.
    public struct RevolutionProperties: Sendable, Hashable {
        public let axis: ShapeAxis
        public let radius: Double
    }

    public var revolutionProperties: RevolutionProperties? {
        guard let primary = primaryAxis else { return nil }
        switch surfaceType {
        case .sphere:
            // A sphere has no genuine rotation axis (`ShapeAxis.direction`'s doc) — `primary`
            // here is only the arbitrary construction-frame pole, the same exclusion
            // `resolveFaceAxisDirection` applies for the identical reason. But unlike
            // cone/torus/surfaceOfRevolution, a sphere's radius IS well-defined and constant:
            // every surface point sits exactly R from the center regardless of which
            // (arbitrary) pole direction is reported, so this doesn't need the axis-relative
            // radial component below at all — just the distance to the center (PR #897
            // review, finding 1). Using the radial component instead (as this case used to,
            // sharing the branch below) is only correct by coincidence, for an untrimmed
            // sphere sampled exactly on its equator, and is arbitrarily wrong for a trimmed
            // spherical cap as the sample point approaches the pole.
            guard let samplePoint = uvMidpointPoint() else { return nil }
            return RevolutionProperties(
                axis: primary, radius: simd_length(samplePoint - primary.origin))
        case .cylinder, .cone, .torus, .surfaceOfRevolution:
            // Radius is the distance from the axis line to a representative
            // surface point. For non-cylindrical revolved surfaces "radius" is
            // ambiguous; this is the distance from the axis at the face centre.
            // Callers who need major/minor radii use the Surface type's own
            // dedicated properties. Only the point is needed here, not the
            // normal, so use the lighter-weight accessor (PR #897 review).
            guard let samplePoint = uvMidpointPoint() else { return nil }
            let offset = samplePoint - primary.origin
            let axisUnit = simd_normalize(primary.direction)
            let axialComponent = simd_dot(offset, axisUnit) * axisUnit
            let radial = offset - axialComponent
            return RevolutionProperties(axis: primary, radius: simd_length(radial))
        default:
            return nil
        }
    }
}

// MARK: - Three-point circle (internal)

/// Given three non-collinear points, compute the circle through them.
///
/// Returns nil if the points are collinear.
internal func circleThroughThreePoints(
    _ p1: SIMD3<Double>, _ p2: SIMD3<Double>, _ p3: SIMD3<Double>
)
    -> (center: SIMD3<Double>, radius: Double, axis: SIMD3<Double>)?
{
    let a = p2 - p1
    let b = p3 - p1
    let axb = simd_cross(a, b)
    let denom = 2 * simd_length_squared(axb)
    guard denom > 1e-18 else { return nil }
    let aLenSq = simd_length_squared(a)
    let bLenSq = simd_length_squared(b)
    let term1 = bLenSq * simd_dot(a, a - b) * a
    let term2 = aLenSq * simd_dot(b, b - a) * b
    let center = p1 + (term1 + term2) / denom
    let radius = simd_length(center - p1)
    let axis = simd_normalize(axb)
    return (center, radius, axis)
}
