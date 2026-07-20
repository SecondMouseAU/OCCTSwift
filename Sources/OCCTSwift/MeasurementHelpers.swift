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
    /// Angle between this edge's tangent and another edge's tangent, measured at
    /// their respective mid-parameters. Returns radians in [0, π].
    ///
    /// For straight edges the result is the line-line angle. For curved edges
    /// it's the angle between the mid-curve tangents — useful as an approximation
    /// but note the angle varies along a curve; pass `atParameter:` for a
    /// specific point.
    public func angle(to other: Edge, atParameter t: Double = 0.5) -> Double? {
        guard let bounds = parameterBounds, let otherBounds = other.parameterBounds else { return nil }
        let clamped = max(0, min(1, t))
        let p = bounds.first + (bounds.last - bounds.first) * clamped
        let op = otherBounds.first + (otherBounds.last - otherBounds.first) * clamped
        guard let t1 = tangent(at: p), let t2 = other.tangent(at: op) else { return nil }
        return unsignedAngle(between: t1, and: t2)
    }

    /// Whether this edge is parallel to another at the given tangent-comparison
    /// tolerance (radians). Convenience over `angle(to:)`.
    public func isParallel(to other: Edge, toleranceRadians: Double = 1e-4) -> Bool? {
        guard let a = angle(to: other) else { return nil }
        return a < toleranceRadians || (.pi - a) < toleranceRadians
    }

    /// Whether this edge is perpendicular to another at the given tangent-comparison
    /// tolerance (radians).
    public func isPerpendicular(to other: Edge, toleranceRadians: Double = 1e-4) -> Bool? {
        guard let a = angle(to: other) else { return nil }
        return abs(a - .pi / 2) < toleranceRadians
    }
}

extension Face {
    /// Angle between this face's normal and another face's normal, evaluated at
    /// the UV midpoint of each. Returns radians in [0, π]. For two planar faces
    /// this is the dihedral angle + π/2 correction; for curved faces it's a
    /// point estimate.
    public func angle(to other: Face) -> Double? {
        guard let bounds = uvBounds else { return nil }
        let uMid = (bounds.uMin + bounds.uMax) / 2
        let vMid = (bounds.vMin + bounds.vMax) / 2
        guard let n1 = normal(atU: uMid, v: vMid) else { return nil }
        guard let otherBounds = other.uvBounds else { return nil }
        let uM2 = (otherBounds.uMin + otherBounds.uMax) / 2
        let vM2 = (otherBounds.vMin + otherBounds.vMax) / 2
        guard let n2 = other.normal(atU: uM2, v: vM2) else { return nil }
        return unsignedAngle(between: n1, and: n2)
    }

    /// Whether this face is parallel to another at the given normal-comparison
    /// tolerance (radians). Convenience over `angle(to:)`.
    public func isParallel(to other: Face, toleranceRadians: Double = 1e-4) -> Bool? {
        guard let a = angle(to: other) else { return nil }
        return a < toleranceRadians || (.pi - a) < toleranceRadians
    }

    /// Whether this face is perpendicular to another (normals at 90°).
    public func isPerpendicular(to other: Face, toleranceRadians: Double = 1e-4) -> Bool? {
        guard let a = angle(to: other) else { return nil }
        return abs(a - .pi / 2) < toleranceRadians
    }

    /// Whether this face is coplanar with another — normals parallel AND origin
    /// lies on the other face's plane.
    public func isCoplanar(with other: Face, tolerance: Double = 1e-6) -> Bool? {
        guard let parallel = isParallel(to: other, toleranceRadians: 1e-4),
              parallel,
              let bounds = uvBounds,
              let origin = point(atU: (bounds.uMin + bounds.uMax) / 2,
                                 v: (bounds.vMin + bounds.vMax) / 2),
              let otherOrigin = (other.uvBounds.flatMap {
                  other.point(atU: ($0.uMin + $0.uMax) / 2, v: ($0.vMin + $0.vMax) / 2)
              }),
              let otherNormal = (other.uvBounds.flatMap {
                  other.normal(atU: ($0.uMin + $0.uMax) / 2, v: ($0.vMin + $0.vMax) / 2)
              }) else {
            return nil
        }
        let offset = origin - otherOrigin
        let signedDist = abs(simd_dot(offset, simd_normalize(otherNormal)))
        return signedDist < tolerance
    }
}

extension ConstructionAxis {
    /// Angle between two construction axes, resolved against the given graph.
    /// Returns radians in [0, π].
    public func angle(to other: ConstructionAxis, in graph: BRepGraph) -> Double? {
        guard case .success(let a) = graph.resolve(self),
              case .success(let b) = graph.resolve(other) else { return nil }
        return unsignedAngle(between: a.direction, and: b.direction)
    }
}

extension ConstructionPlane {
    /// Angle between two construction planes (angle between their normals).
    /// Returns radians in [0, π].
    public func angle(to other: ConstructionPlane, in graph: BRepGraph) -> Double? {
        guard case .success(let a) = graph.resolve(self),
              case .success(let b) = graph.resolve(other) else { return nil }
        return unsignedAngle(between: a.zAxis, and: b.zAxis)
    }
}

/// Unsigned angle in [0, π] between two 3D vectors. Returns nil for degenerate input.
public func unsignedAngle(between a: SIMD3<Double>, and b: SIMD3<Double>) -> Double {
    let la = simd_length(a), lb = simd_length(b)
    guard la > 1e-12, lb > 1e-12 else { return 0 }
    let cosTheta = simd_dot(a, b) / (la * lb)
    return acos(max(-1.0, min(1.0, cosTheta)))
}

// MARK: - Circle properties (v0.143 M4)

extension Edge {
    /// Extracted circle / arc geometry for an edge whose underlying curve is a
    /// circle. Returns nil for non-circular edges.
    public struct CircleProperties: Sendable, Hashable {
        public let center: SIMD3<Double>
        public let radius: Double
        public let axis: SIMD3<Double>    // unit normal to the circle's plane
        public let isFullCircle: Bool
        public let startAngle: Double     // radians; 0 for a full circle
        public let endAngle: Double       // radians; 2π for a full circle
    }

    /// Circle / arc properties if this edge is a circular edge. Returns nil for
    /// straight lines, ellipses, BSpline curves, etc.
    public var circleProperties: CircleProperties? {
        guard curveType == .circle else { return nil }
        guard let bounds = parameterBounds else { return nil }
        // For a Geom_Circle parameterisation, start/end parameters are the angles.
        // The point at parameter 0 is on the +X axis of the circle's local frame;
        // we recover centre and radius from three sampled points.
        let sample1Param = bounds.first
        let sample2Param = bounds.first + (bounds.last - bounds.first) * 0.5
        let sample3Param = bounds.last
        guard let p1 = point(at: sample1Param),
              let p2 = point(at: sample2Param),
              let p3 = point(at: sample3Param) else { return nil }
        guard let (center, radius, axis) = circleThroughThreePoints(p1, p2, p3) else { return nil }
        let full = abs((bounds.last - bounds.first) - 2 * .pi) < 1e-6
        return CircleProperties(center: center, radius: radius, axis: axis,
                                 isFullCircle: full,
                                 startAngle: bounds.first,
                                 endAngle: bounds.last)
    }
}

extension Face {
    /// Axis + radius of a cylindrical / conical / toroidal / spherical face.
    /// Returns nil for planar or free-form faces.
    public struct RevolutionProperties: Sendable, Hashable {
        public let axis: ShapeAxis
        public let radius: Double
    }

    public var revolutionProperties: RevolutionProperties? {
        guard let primary = primaryAxis else { return nil }
        switch surfaceType {
        case .cylinder:
            // Radius is the distance from the axis line to any surface point.
            guard let bounds = uvBounds,
                  let pt = point(atU: (bounds.uMin + bounds.uMax) / 2,
                                 v: (bounds.vMin + bounds.vMax) / 2) else { return nil }
            let offset = pt - primary.origin
            let axisUnit = simd_normalize(primary.direction)
            let axialComponent = simd_dot(offset, axisUnit) * axisUnit
            let radial = offset - axialComponent
            return RevolutionProperties(axis: primary, radius: simd_length(radial))
        case .cone, .sphere, .torus, .surfaceOfRevolution:
            // For non-cylindrical revolved surfaces "radius" is ambiguous; return
            // the distance from the axis at the face centre as a representative
            // value. Callers who need major/minor radii use the Surface type's
            // dedicated properties.
            guard let bounds = uvBounds,
                  let pt = point(atU: (bounds.uMin + bounds.uMax) / 2,
                                 v: (bounds.vMin + bounds.vMax) / 2) else { return nil }
            let offset = pt - primary.origin
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
/// Returns nil if the points are collinear.
internal func circleThroughThreePoints(_ p1: SIMD3<Double>, _ p2: SIMD3<Double>, _ p3: SIMD3<Double>)
    -> (center: SIMD3<Double>, radius: Double, axis: SIMD3<Double>)? {
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
