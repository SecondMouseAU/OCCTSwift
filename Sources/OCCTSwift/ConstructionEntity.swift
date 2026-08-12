import Foundation
import OCCTBridge
import simd

// MARK: - Construction Geometry (#72 Phase 2)
//
// Typed construction-plane / axis / point recipes that carry TopologyRefs
// rather than absolute coordinates. Resolution computes a Placement against
// the current graph state — so when the underlying model is edited, the
// construction entity auto-updates through the BRepGraph history machinery
// introduced in v0.141 Phase 0+1.
//
// Design inspired by Fusion 360's `ConstructionPlaneInput.setBy*` discriminators
// (see #72 research). Each variant carries the *defining inputs* as persistent
// references, not the computed plane — so if the inputs evolve, the plane does too.

/// A rigid-body placement in 3D space — origin plus an orthonormal basis.
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
    public init(origin: SIMD3<Double>, normal: SIMD3<Double>) {
        let z = simd_normalize(normal)
        let worldUp = SIMD3<Double>(0, 0, 1)
        var rightRaw = simd_cross(worldUp, z)
        if simd_length(rightRaw) < 1e-9 {
            rightRaw = simd_cross(SIMD3(0, 1, 0), z)
        }
        let x = simd_normalize(rightRaw)
        let y = simd_normalize(simd_cross(z, x))
        self.init(origin: origin, xAxis: x, yAxis: y, zAxis: z)
    }
}

/// Fusion 360-style recipe for a construction plane.
///
/// Each variant carries its defining inputs as `TopologyRef`s, resolved against the graph at use time.
public indirect enum ConstructionPlane: Sendable, Hashable {
    case absolute(origin: SIMD3<Double>, normal: SIMD3<Double>)

    /// Plane parallel to `face`, offset by `distance` along the face normal.
    case offsetFromFace(face: TopologyRef, distance: Double)

    /// Plane containing `axis` edge, rotated `angleDeg` from a reference plane.
    /// Reference plane is deduced from the first face adjacent to the axis.
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

    /// Intersection of two planes. Falls back to the absolute origin if the
    /// planes are parallel.
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

extension BRepGraph {
    public func resolve(_ plane: ConstructionPlane) -> Result<
        Placement, ConstructionResolutionError
    > {
        switch plane {
        case .absolute(let origin, let normal):
            return .success(Placement(origin: origin, normal: normal))

        case .offsetFromFace(let faceRef, let distance):
            return resolveFaceOrigin(faceRef).flatMap { (origin, normal) in
                .success(
                    Placement(origin: origin + distance * simd_normalize(normal), normal: normal))
            }

        case .throughAxis(let axisRef, let angleDeg):
            return resolveEdgeDirection(axisRef).flatMap {
                (anchor, dir) -> Result<Placement, ConstructionResolutionError> in
                // Rotate a perpendicular-to-dir reference by angleDeg around dir.
                let dirN = simd_normalize(dir)
                let worldUp = abs(dirN.z) < 0.9 ? SIMD3<Double>(0, 0, 1) : SIMD3<Double>(0, 1, 0)
                let refPerp = simd_normalize(simd_cross(dirN, worldUp))
                let rad = angleDeg * .pi / 180
                let rotated = cos(rad) * refPerp + sin(rad) * simd_cross(dirN, refPerp)
                let normal = simd_normalize(simd_cross(dirN, rotated))
                return .success(Placement(origin: anchor, normal: normal))
            }

        case .tangentToFace(let faceRef, let atRef):
            return resolveVertexPoint(atRef).flatMap {
                point -> Result<Placement, ConstructionResolutionError> in
                resolveFaceNormal(faceRef, at: point).map { normal in
                    Placement(origin: point, normal: normal)
                }
            }

        case .midPlane(let a, let b):
            return resolveFaceOrigin(a).flatMap { (oA, nA) in
                resolveFaceOrigin(b).flatMap { (oB, nB) in
                    let origin = (oA + oB) / 2
                    let avgNormal =
                        simd_length_squared(nA + nB) > 1e-12
                        ? simd_normalize(nA + nB)
                        : simd_normalize(nA - nB)  // antiparallel faces — use either normal
                    return .success(Placement(origin: origin, normal: avgNormal))
                }
            }

        case .byThreePoints(let a, let b, let c):
            return resolveVertexPoint(a).flatMap { pA in
                resolveVertexPoint(b).flatMap { pB in
                    resolveVertexPoint(c).flatMap {
                        pC -> Result<Placement, ConstructionResolutionError> in
                        let u = pB - pA
                        let v = pC - pA
                        let n = simd_cross(u, v)
                        if simd_length(n) < 1e-9 {
                            return .failure(.degenerate("three points are collinear"))
                        }
                        return .success(Placement(origin: pA, normal: n))
                    }
                }
            }

        case .normalToEdge(let edgeRef, let t):
            return resolveEdgePointAndTangent(edgeRef, t: t).map { (point, tangent) in
                Placement(origin: point, normal: tangent)
            }
        }
    }

    public func resolve(_ axis: ConstructionAxis) -> Result<
        (origin: SIMD3<Double>, direction: SIMD3<Double>), ConstructionResolutionError
    > {
        switch axis {
        case .absolute(let origin, let direction):
            return .success((origin, simd_normalize(direction)))

        case .alongEdge(let edgeRef):
            return resolveEdgeDirection(edgeRef)

        case .normalToFace(let faceRef, let atRef):
            return resolveFaceAxisDirection(faceRef).flatMap { direction in
                resolveVertexPoint(atRef).map { anchor in
                    (anchor, direction)
                }
            }

        case .throughPoints(let a, let b):
            return resolveVertexPoint(a).flatMap { pA in
                resolveVertexPoint(b).flatMap {
                    pB -> Result<
                        (origin: SIMD3<Double>, direction: SIMD3<Double>),
                        ConstructionResolutionError
                    > in
                    let d = pB - pA
                    if simd_length(d) < 1e-9 {
                        return .failure(.degenerate("points coincide"))
                    }
                    return .success((pA, simd_normalize(d)))
                }
            }

        case .intersectionOfPlanes(let planeA, let planeB):
            return resolve(planeA).flatMap { pA in
                resolve(planeB).flatMap {
                    pB -> Result<
                        (origin: SIMD3<Double>, direction: SIMD3<Double>),
                        ConstructionResolutionError
                    > in
                    let d = simd_cross(pA.zAxis, pB.zAxis)
                    if simd_length(d) < 1e-9 {
                        return .failure(.degenerate("planes are parallel"))
                    }
                    // Origin: project pA.origin onto the line of intersection.
                    // Simple approximation: the midpoint of the two origins
                    // projected onto the intersection direction.
                    let mid = (pA.origin + pB.origin) / 2
                    return .success((mid, simd_normalize(d)))
                }
            }
        }
    }

    public func resolve(_ point: ConstructionPoint) -> Result<
        SIMD3<Double>, ConstructionResolutionError
    > {
        switch point {
        case .absolute(let p):
            return .success(p)

        case .atVertex(let ref):
            return resolveVertexPoint(ref)

        case .midpointOfEdge(let ref):
            return resolveEdgePointAndTangent(ref, t: 0.5).map(\.0)

        case .centroidOfFace(let ref):
            return resolveFaceCentroid(ref)

        case .atEdgeParameter(let ref, let t):
            return resolveEdgePointAndTangent(ref, t: t).map(\.0)

        case .intersectionOfAxisAndPlane(let axis, let plane):
            return resolve(axis).flatMap { (axOrigin, axDir) in
                resolve(plane).flatMap { pl -> Result<SIMD3<Double>, ConstructionResolutionError> in
                    // Line origin + t * direction intersects plane where
                    // (plane.origin - axOrigin) . plane.normal == t * axDir . plane.normal
                    let n = pl.zAxis
                    let denom = simd_dot(axDir, n)
                    if abs(denom) < 1e-9 {
                        return .failure(.degenerate("axis parallel to plane"))
                    }
                    let t = simd_dot(pl.origin - axOrigin, n) / denom
                    return .success(axOrigin + t * axDir)
                }
            }
        }
    }

    // MARK: - Internal geometric helpers (TopologyRef → 3D data)

    private func unwrapTopology(_ ref: TopologyRef) -> Result<NodeRef, ConstructionResolutionError>
    {
        switch resolve(ref) {
        case .success(let n): return .success(n)
        case .failure(let e): return .failure(.topology(e))
        }
    }

    /// Resolves `ref` to a face node, failing with `.notApplicable`/`.missingGeometry` as appropriate.
    ///
    /// Shared by every face-based resolver below.
    private func resolveFace(_ ref: TopologyRef) -> Result<
        (node: NodeRef, face: Face), ConstructionResolutionError
    > {
        return unwrapTopology(ref).flatMap {
            node -> Result<(node: NodeRef, face: Face), ConstructionResolutionError> in
            guard node.kind == .face else {
                return .failure(.notApplicable("expected a face, got \(node.kind)"))
            }
            guard let shape = shape(nodeKind: node.kind, nodeIndex: node.index),
                let face = shape.faces().first
            else {
                return .failure(.missingGeometry(node))
            }
            return .success((node, face))
        }
    }

    /// Face-representative point + normal, sampled at the face's UV-domain midpoint.
    ///
    /// Used by `.offsetFromFace` and `.midPlane`, which genuinely want a
    /// face-representative sample rather than a point-specific value.
    private func resolveFaceOrigin(_ ref: TopologyRef) -> Result<
        (SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError
    > {
        return resolveFace(ref).flatMap {
            node, face -> Result<(SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError> in
            guard let sample = face.uvMidpointSample() else {
                return .failure(.missingGeometry(node))
            }
            return .success((sample.point, sample.normal))
        }
    }

    /// The surface normal at the given point's own projected location on the face.
    ///
    /// Used by `.tangentToFace` so the plane is tangent at the requested point, not
    /// at the face's unrelated UV midpoint (#879).
    private func resolveFaceNormal(_ ref: TopologyRef, at point: SIMD3<Double>) -> Result<
        SIMD3<Double>, ConstructionResolutionError
    > {
        return resolveFace(ref).flatMap {
            node, face -> Result<SIMD3<Double>, ConstructionResolutionError> in
            guard let projection = face.project(point: point),
                let normal = face.normal(atU: projection.u, v: projection.v)
            else {
                return .failure(.missingGeometry(node))
            }
            return .success(normal)
        }
    }

    /// The direction the normalToFace doc promises.
    ///
    /// The surface's own axis of revolution (`Face.primaryAxis`) for
    /// cylindrical/conical/spherical/toroidal/revolved/extruded faces, falling back
    /// to the UV-midpoint surface normal for planes and free-form faces, which
    /// have no such axis (#882).
    private func resolveFaceAxisDirection(_ ref: TopologyRef) -> Result<
        SIMD3<Double>, ConstructionResolutionError
    > {
        return resolveFace(ref).flatMap {
            node, face -> Result<SIMD3<Double>, ConstructionResolutionError> in
            if let axis = face.primaryAxis {
                return .success(simd_normalize(axis.direction))
            }
            guard let sample = face.uvMidpointSample() else {
                return .failure(.missingGeometry(node))
            }
            return .success(simd_normalize(sample.normal))
        }
    }

    /// The face's real area centroid (`Face.surfaceInertia.centerOfMass`) — the
    /// same quantity `ShapeMeasurements.measure()` reports for the same face,
    /// not the UV-midpoint approximation `resolveFaceOrigin` uses (#884).
    private func resolveFaceCentroid(_ ref: TopologyRef) -> Result<
        SIMD3<Double>, ConstructionResolutionError
    > {
        return resolveFace(ref).flatMap {
            _, face -> Result<SIMD3<Double>, ConstructionResolutionError> in
            guard let centroid = face.surfaceInertia.centerOfMass else {
                return .failure(.degenerate("face has zero area"))
            }
            return .success(centroid)
        }
    }

    private func resolveEdgeDirection(_ ref: TopologyRef) -> Result<
        (origin: SIMD3<Double>, direction: SIMD3<Double>), ConstructionResolutionError
    > {
        return unwrapTopology(ref).flatMap {
            node -> Result<
                (origin: SIMD3<Double>, direction: SIMD3<Double>), ConstructionResolutionError
            > in
            guard node.kind == .edge else {
                return .failure(.notApplicable("expected an edge, got \(node.kind)"))
            }
            guard let shape = shape(nodeKind: node.kind, nodeIndex: node.index),
                let edge = shape.edges().first,
                let bounds = edge.parameterBounds,
                let start = edge.point(at: bounds.first),
                let end = edge.point(at: bounds.last)
            else {
                return .failure(.missingGeometry(node))
            }
            let dir = end - start
            if simd_length(dir) < 1e-9 {
                return .failure(.degenerate("zero-length edge"))
            }
            return .success((start, simd_normalize(dir)))
        }
    }

    private func resolveEdgePointAndTangent(_ ref: TopologyRef, t: Double) -> Result<
        (SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError
    > {
        return unwrapTopology(ref).flatMap {
            node -> Result<(SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError> in
            guard node.kind == .edge else {
                return .failure(.notApplicable("expected an edge, got \(node.kind)"))
            }
            guard let shape = shape(nodeKind: node.kind, nodeIndex: node.index),
                let edge = shape.edges().first,
                let param = edge.parameter(atFraction: t),
                let point = edge.point(at: param),
                let tangent = edge.tangent(at: param)
            else {
                return .failure(.missingGeometry(node))
            }
            return .success((point, simd_normalize(tangent)))
        }
    }

    private func resolveVertexPoint(_ ref: TopologyRef) -> Result<
        SIMD3<Double>, ConstructionResolutionError
    > {
        return unwrapTopology(ref).flatMap {
            node -> Result<SIMD3<Double>, ConstructionResolutionError> in
            guard node.kind == .vertex else {
                // Accept a face ref too — use its UV-midpoint sample, not a true
                // centroid (see resolveFaceCentroid) — for convenience in byThreePoints etc.
                if node.kind == .face {
                    return resolveFaceOrigin(ref).map(\.0)
                }
                return .failure(.notApplicable("expected a vertex, got \(node.kind)"))
            }
            guard let shape = shape(nodeKind: node.kind, nodeIndex: node.index) else {
                return .failure(.missingGeometry(node))
            }
            var x: Double = 0
            var y: Double = 0
            var z: Double = 0
            OCCTShapeVertexPoint(shape.handle, &x, &y, &z)
            return .success(SIMD3(x, y, z))
        }
    }
}

// MARK: - childIndices (shared helper, used by .containedIn in TopologyRef and by Phase 2 resolvers)

extension BRepGraph {
    /// Indices of descendant nodes of a given kind from a root node.
    ///
    /// Complements the existing `childCount(rootKind:rootIndex:targetKind:)`.
    public func childIndices(rootKind: NodeKind, rootIndex: Int, targetKind: NodeKind) -> [Int] {
        let total = childCount(rootKind: rootKind, rootIndex: rootIndex, targetKind: targetKind)
        guard total > 0 else { return [] }
        var buf = [Int32](repeating: 0, count: total)
        let n = buf.withUnsafeMutableBufferPointer { bp in
            OCCTBRepGraphChildIndices(
                handle, rootKind.rawValue, Int32(rootIndex),
                targetKind.rawValue, bp.baseAddress!, Int32(total))
        }
        return (0..<Int(n)).map { Int(buf[$0]) }
    }
}
