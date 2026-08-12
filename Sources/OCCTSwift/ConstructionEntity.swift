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
/// Each variant carries its defining inputs as `TopologyRef`s, resolved against the graph at use
/// time.
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
                (point) -> Result<Placement, ConstructionResolutionError> in
                return resolveFaceOrigin(faceRef).flatMap { (_, normal) in
                    .success(Placement(origin: point, normal: normal))
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
                        let n = simd_cross(pB - pA, pC - pA)
                        return requireNonDegenerate(
                            simd_length(n), Placement(origin: pA, normal: n),
                            "three points are collinear")
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
            return resolveFaceOrigin(faceRef).flatMap { (_, normal) in
                resolveVertexPoint(atRef).map { anchor in
                    (anchor, simd_normalize(normal))
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
                    return requireNonDegenerate(
                        simd_length(d), (pA, simd_normalize(d)), "points coincide")
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
                    // Origin: project pA.origin onto the line of intersection.
                    // Simple approximation: the midpoint of the two origins
                    // projected onto the intersection direction.
                    let mid = (pA.origin + pB.origin) / 2
                    return requireNonDegenerate(
                        simd_length(d), (mid, simd_normalize(d)), "planes are parallel")
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
            return resolveFaceOrigin(ref).map(\.0)

        case .atEdgeParameter(let ref, let t):
            return resolveEdgePointAndTangent(ref, t: t).map(\.0)

        case .intersectionOfAxisAndPlane(let axis, let plane):
            return resolve(axis).flatMap { (axOrigin, axDir) in
                resolve(plane).flatMap { pl -> Result<SIMD3<Double>, ConstructionResolutionError> in
                    // Line origin + t * direction intersects plane where
                    // (plane.origin - axOrigin) . plane.normal == t * axDir . plane.normal
                    let n = pl.zAxis
                    let denom = simd_dot(axDir, n)
                    return requireNonDegenerate(
                        abs(denom),
                        axOrigin + (simd_dot(pl.origin - axOrigin, n) / denom) * axDir,
                        "axis parallel to plane")
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

    /// Degeneracy threshold shared by every `resolve` guard below.
    ///
    /// The five call sites compare three different kinds of quantity — a raw distance, a cross
    /// product's area-scale magnitude, and a unit-vector dot/cross — that happen to share this
    /// literal today by coincidence, not because they are numerically comparable (#887).
    /// Per-site tuning isn't supported today: `requireNonDegenerate` takes no per-call epsilon
    /// argument, so every call site shares this one constant. Supporting it would mean adding an
    /// epsilon parameter to `requireNonDegenerate` — and picking a real per-site value, not
    /// inventing one without measurement (#726) (#894 finding 5).
    private static let degeneracyEpsilon = 1e-9

    /// Cosine-of-angle threshold for two unit directions being the same or exactly opposite.
    ///
    /// Used by ``axesAgree(_:_:)`` (finding 1: every adjacent cylindrical/conical face's axis must
    /// agree before `revolutionAxis(ofEdgeAt:)` returns a definitive answer) and by
    /// `resolveEdgeDirection`'s own straight-seam check (finding 3: an edge's chord counts as
    /// lying along the candidate axis only when it's parallel/anti-parallel to it). `1e-6` mirrors
    /// the unit-vector tolerance this file's own tests already use for axis-direction checks —
    /// tight enough to catch a genuine few-degree mismatch between two non-coaxial faces, loose
    /// enough for the floating-point noise of a real OCCT curve/surface evaluation.
    private static let axisDirectionAgreementCosineTolerance = 1e-6

    /// Distance threshold for "these two axis directions describe the same line, not just two
    /// parallel offset lines" (finding 1).
    ///
    /// The perpendicular offset between one candidate's origin and the line through the other. A
    /// fixed absolute threshold, like ``degeneracyEpsilon`` above, not a fraction of model scale.
    private static let axisOriginAgreementDistanceTolerance = 1e-6

    /// Shared "is this magnitude effectively zero" guard: fails with `.degenerate(message)` when
    /// `magnitude` is below ``degeneracyEpsilon``, otherwise succeeds with `value`. `value` is an
    /// autoclosure so a division or normalization that depends on `magnitude` being safe is never
    /// evaluated on the failing path.
    private func requireNonDegenerate<T>(
        _ magnitude: Double, _ value: @autoclosure () -> T, _ message: String
    ) -> Result<T, ConstructionResolutionError> {
        guard magnitude >= Self.degeneracyEpsilon else {
            return .failure(.degenerate(message))
        }
        return .success(value())
    }

    private func resolveFaceOrigin(_ ref: TopologyRef) -> Result<
        (SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError
    > {
        return unwrapTopology(ref).flatMap {
            node -> Result<(SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError> in
            guard node.kind == .face else {
                return .failure(.notApplicable("expected a face, got \(node.kind)"))
            }
            guard let shape = shape(nodeKind: node.kind, nodeIndex: node.index),
                let face = shape.faces().first
            else {
                return .failure(.missingGeometry(node))
            }
            // Centroid via UV mid evaluation; primary axis → normal.
            guard let bounds = face.uvBounds else {
                return .failure(.missingGeometry(node))
            }
            let uMid = (bounds.uMin + bounds.uMax) / 2
            let vMid = (bounds.vMin + bounds.vMax) / 2
            guard let origin = face.point(atU: uMid, v: vMid),
                let normal = face.normal(atU: uMid, v: vMid)
            else {
                return .failure(.missingGeometry(node))
            }
            return .success((origin, normal))
        }
    }

    /// The true rotation axis of a cylindrical/conical edge, read off its adjacent face(s).
    ///
    /// Collects every adjacent face's ``Face/primaryAxis`` that is a cylinder or cone — the two
    /// surface kinds `ConstructionAxis.alongEdge`'s own doc promises (#883) — and returns a
    /// definitive axis only when every candidate agrees with the first, per ``axesAgree(_:_:)``.
    /// An edge at a branch (a T-junction between two non-coaxial cylindrical faces, or any
    /// blended transition) has more than one disagreeing candidate; `nil` there tells the caller
    /// to fall back to the endpoint secant instead of silently picking whichever face happened to
    /// sort first (#894 finding 1). Planar and free-form neighbours, and edges with no face
    /// adjacency at all, contribute no candidate at all, so this is `nil` for them too.
    private func revolutionAxis(ofEdgeAt edgeIndex: Int) -> ShapeAxis? {
        var candidates: [ShapeAxis] = []
        for faceIndex in faces(of: edgeIndex) {
            guard let faceShape = shape(nodeKind: .face, nodeIndex: faceIndex),
                let face = faceShape.faces().first,
                let axis = face.primaryAxis,
                axis.kind == .cylinder || axis.kind == .cone
            else { continue }
            candidates.append(axis)
        }
        guard let reference = candidates.first else { return nil }
        guard candidates.dropFirst().allSatisfy({ axesAgree(reference, $0) }) else { return nil }
        return reference
    }

    /// Whether two candidate revolution axes describe the same line.
    ///
    /// Their directions must be parallel or anti-parallel within
    /// ``axisDirectionAgreementCosineTolerance``, and `other`'s origin must lie within
    /// ``axisOriginAgreementDistanceTolerance`` of the line through `reference` — not merely a
    /// parallel offset line, e.g. two same-diameter but genuinely distinct bores (#894 finding 1).
    private func axesAgree(_ reference: ShapeAxis, _ other: ShapeAxis) -> Bool {
        let referenceDirection = simd_normalize(reference.direction)
        let otherDirection = simd_normalize(other.direction)
        guard
            abs(abs(simd_dot(referenceDirection, otherDirection)) - 1.0)
                < Self.axisDirectionAgreementCosineTolerance
        else {
            return false
        }
        let offset = other.origin - reference.origin
        let perpendicular = offset - simd_dot(offset, referenceDirection) * referenceDirection
        return simd_length(perpendicular) < Self.axisOriginAgreementDistanceTolerance
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
                let bounds = edge.parameterBounds
            else {
                return .failure(.missingGeometry(node))
            }
            // Only a curved edge (typically a circular/elliptical arc) can coincide with a
            // cylindrical/conical face's true rotation axis; a linear edge always resolves to its
            // own line. Gate on curveType first — cheap, no bridge call — so a straight edge never
            // pays for the face walk in `revolutionAxis` (#894 finding 4); that walk is also where
            // the answer can still legitimately come back nil (no adjacent cyl/cone face, or
            // several that disagree — #894 finding 1).
            let axis = edge.curveType != .line ? revolutionAxis(ofEdgeAt: node.index) : nil

            guard let start = edge.point(at: bounds.first), let end = edge.point(at: bounds.last)
            else {
                return .failure(.missingGeometry(node))
            }

            if let axis = axis {
                let axisDirection = simd_normalize(axis.direction)
                let chord = end - start
                let chordLength = simd_length(chord)
                // curveType is a proxy for straightness, not a guarantee of it: OCCT commonly
                // re-parameterizes a geometrically-straight edge as a low-degree BSpline after a
                // Boolean cut, fillet, or sweep, even though it's still coincident with the
                // cylinder/cone wall — the seam case the comment above this branch's gate already
                // calls out. When the edge's own chord already runs parallel or anti-parallel to
                // the candidate axis, treat it as a straight seam and keep the chord itself — both
                // origin and direction — instead of redirecting to the axis (#894 finding 3). A
                // real seam is the degenerate case where the axis direction and the chord
                // direction agree; the origin still has to stay on the edge, not move to wherever
                // the adjacent surface happens to be placed.
                if chordLength >= Self.degeneracyEpsilon,
                    abs(abs(simd_dot(chord / chordLength, axisDirection)) - 1.0)
                        < Self.axisDirectionAgreementCosineTolerance
                {
                    return .success((start, chord / chordLength))
                }
                // Keep the origin edge-local: project the edge's own start point onto the resolved
                // axis line rather than returning the adjacent surface's own placement origin,
                // which can be far from the edge itself — e.g. a cylinder's base under a rim near
                // its top (#894 finding 2).
                let toStart = start - axis.origin
                let projectedOrigin = axis.origin + simd_dot(toStart, axisDirection) * axisDirection
                return .success((projectedOrigin, axisDirection))
            }

            let dir = end - start
            return requireNonDegenerate(
                simd_length(dir), (start, simd_normalize(dir)), "zero-length edge")
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
                let bounds = edge.parameterBounds
            else {
                return .failure(.missingGeometry(node))
            }
            let clampedT = max(0, min(1, t))
            let param = bounds.first + (bounds.last - bounds.first) * clampedT
            guard let point = edge.point(at: param),
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
                // Accept a face ref too — use its centroid — for convenience in byThreePoints etc.
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
