import OCCTBridge
import OCCTPlatform

// MARK: - Construction Geometry (#72 Phase 2)
//
// Typed construction-plane / axis / point recipes that carry TopologyRefs
// rather than absolute coordinates. Resolution computes a Placement against
// the current graph state, so when the underlying model is edited, the
// construction entity auto-updates through the BRepGraph history machinery
// introduced in v0.141 Phase 0+1.
//
// Design inspired by Fusion 360's `ConstructionPlaneInput.setBy*` discriminators
// (see #72 research). Each variant carries the *defining inputs* as persistent
// references, not the computed plane, so if the inputs evolve, the plane does too.

/// A rigid-body placement in 3D space, origin plus an orthonormal basis.
public struct Placement: Sendable, Hashable {
    public let origin: SIMD3<Double>
    public let xAxis: SIMD3<Double>  // unit
    public let yAxis: SIMD3<Double>  // unit
    public let zAxis: SIMD3<Double>  // unit (plane normal for planes)

    public init(
        origin: SIMD3<Double>, xAxis: SIMD3<Double>, yAxis: SIMD3<Double>, zAxis: SIMD3<Double>
    ) {
        self.origin = origin
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.zAxis = zAxis
    }

    /// Build a placement from a point on the plane and a normal.
    ///
    /// Picks deterministic x/y axes perpendicular to the normal.
    ///
    /// A zero or non-finite `normal` gives NaN axes (IEEE division). `BRepGraph.resolve(_:)` refuses
    /// such a normal as `.degenerate` before one is built, so only a hand-built `Placement` has it.
    public init(origin: SIMD3<Double>, normal: SIMD3<Double>) {
        let z = normalizedVector(normal)
        let (x, y) = perpendicularBasis(to: z)
        self.init(origin: origin, xAxis: x, yAxis: y, zAxis: z)
    }

    /// Map a 2D point in the placement's local (x, y) plane to 3D world space.
    ///
    /// - Parameter p: 2D coordinates where `x` scales `xAxis` and `y` scales `yAxis`.
    /// - Returns: The corresponding 3D point: `origin + x * xAxis + y * yAxis`.
    public func lift(_ p: SIMD2<Double>) -> SIMD3<Double> {
        origin + p.x * xAxis + p.y * yAxis
    }
}

/// Fusion 360-style recipe for a construction plane.
///
/// Each variant carries its defining inputs as `TopologyRef`s, resolved against the graph at use
/// time.
public indirect enum ConstructionPlane: Sendable, Hashable {
    case absolute(origin: SIMD3<Double>, normal: SIMD3<Double>)

    /// Plane parallel to `face`, offset by `distance` along the face normal.
    case offsetFromFace(face: TopologyRef, distance: Double)

    /// Plane containing `axis` edge, rotated `angleDeg` from a reference plane.
    /// Reference plane is the canonical `perpendicularBasis(to:)` basis for the axis
    /// direction (OCCT's `gp_Ax2` smallest-component algorithm), not derived from any
    /// adjacent face.
    case throughAxis(axis: TopologyRef, angleDeg: Double)

    /// Plane tangent to `face` at a point (`at` resolves to a vertex on that face).
    case tangentToFace(face: TopologyRef, at: TopologyRef)

    /// Midplane between two parallel faces.
    case midPlane(TopologyRef, TopologyRef)

    /// Plane defined by three points (`a`, `b`, `c` resolve to vertices).
    case byThreePoints(TopologyRef, TopologyRef, TopologyRef)

    /// Plane normal to an edge at parameter t (0..1 along the edge).
    case normalToEdge(edge: TopologyRef, t: Double)
}

public indirect enum ConstructionAxis: Sendable, Hashable {
    case absolute(origin: SIMD3<Double>, direction: SIMD3<Double>)

    /// Axis coinciding with an edge's underlying line (for linear edges) or the
    /// axis of revolution (for cylindrical / conical edges).
    case alongEdge(TopologyRef)

    /// Axis normal to a face at a reference point. For planar faces the direction
    /// is the face normal; for cylindrical faces it's the rotation axis.
    case normalToFace(face: TopologyRef, at: TopologyRef)

    /// Axis through two points.
    case throughPoints(TopologyRef, TopologyRef)

    /// The line two planes share. The origin is the point of that line nearest the world
    /// origin, so it lies on both planes, and the direction is `cross(normalA, normalB)`.
    /// Resolution fails with ``ConstructionResolutionError/degenerate(_:)`` when the planes
    /// are parallel (or opposed), since they share no single line.
    ///
    /// ```swift
    /// let a = ConstructionPlane.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))  // z = 0
    /// let b = ConstructionPlane.absolute(origin: SIMD3(10, 0, 0), normal: SIMD3(1, 0, 0))  // x = 10
    /// let axis = try graph.resolve(ConstructionAxis.intersectionOfPlanes(a, b)).get()
    /// // axis.origin == (10, 0, 0), axis.direction == (0, 1, 0)
    /// ```
    case intersectionOfPlanes(ConstructionPlane, ConstructionPlane)
}

public indirect enum ConstructionPoint: Sendable, Hashable {
    case absolute(SIMD3<Double>)
    case atVertex(TopologyRef)
    case midpointOfEdge(TopologyRef)
    case centroidOfFace(TopologyRef)
    case atEdgeParameter(edge: TopologyRef, t: Double)
    case intersectionOfAxisAndPlane(ConstructionAxis, ConstructionPlane)
}

public enum ConstructionResolutionError: Error, Sendable {
    case topology(TopologyResolutionError)
    case notApplicable(String)  // e.g. "face is not planar"
    case degenerate(String)  // e.g. "parallel planes"
    case missingGeometry(BRepGraph.NodeRef)
}
