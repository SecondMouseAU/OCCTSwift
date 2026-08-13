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
        let (x, y) = perpendicularBasis(to: z)
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
                let (refPerp, _) = perpendicularBasis(to: dirN)
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
    /// Used by ``axesAgree(_:_:)``: every adjacent cylindrical/conical face's axis must agree
    /// before `revolutionAxis(ofEdgeAt:)` returns a definitive answer (finding 1, first pass).
    /// `resolveEdgeDirection` originally had a second use — a chord-parallel-to-the-candidate-axis
    /// check standing in for "is this edge a straight seam" — but that check was never true for a
    /// straight seam on a *cone* (a cone's generatrix meets its axis at the cone's own nonzero
    /// half-angle, never 0) and could misfire true for a helical edge whose two-point secant
    /// happens to land near-parallel to the axis by coincidence of the sweep angle (both findings
    /// 1/3, second pass). ``coaxialCrossSection(of:bounds:start:end:axis:)`` replaces it with a
    /// direct geometric test that doesn't need this tolerance at all (finding 1, third pass), so
    /// this constant is `axesAgree`'s alone again. `1e-6` mirrors the unit-vector tolerance this
    /// file's own tests already use for axis-direction checks — tight enough to catch a genuine
    /// few-degree mismatch between two non-coaxial faces, loose enough for the floating-point
    /// noise of a real OCCT curve/surface evaluation.
    private static let axisDirectionAgreementCosineTolerance = 1e-6

    /// Distance threshold for "this point sits on this axis line". Used two ways:
    ///
    /// - ``axesAgree(_:_:)``: the perpendicular offset between one candidate axis's origin and
    ///   the line through another, so two same-diameter but genuinely distinct bores don't
    ///   count as one (finding 1, first pass).
    /// - ``coaxialCrossSection(of:bounds:start:end:axis:)``: how much a sampled point's height
    ///   along the axis, or its radius from it, may vary across the edge before it stops
    ///   counting as a genuine perpendicular cross-section (finding 1, third pass).
    ///
    /// A fixed absolute threshold, like ``degeneracyEpsilon`` above, not a fraction of model
    /// scale. `1e-6` matches `Shape.revolutionAxes(tolerance:)`'s own default (`ShapeAxis.swift`)
    /// and the bridge-side `axesCoincide` it wraps (`OCCTBridge_Topology.mm`) — not because either
    /// is called from here (that dedup runs in the C++ layer over every face of a whole shape;
    /// this code only ever compares the 1-2 faces adjacent to a single edge, so there's no shared
    /// function to actually call across that boundary), but so a future retune of one is at least
    /// discoverable from the other (finding 4, third pass).
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
            // The edge's own degeneracy is checked before any axis lookup, and by true arc
            // length rather than the endpoint secant a few lines below: a full-circle rim is
            // legitimately closed (start == end, secant == 0) without being remotely degenerate
            // — that's exactly why the axis redirect below exists at all — so this can't reuse
            // the secant the way the fallback path does. Unconditional so a genuinely
            // near-zero-length sliver edge (a leftover fillet/boolean artifact) still reports
            // `.degenerate` even when it happens to sit next to one clean cylindrical/conical
            // face and would otherwise get an unambiguous but meaningless axis match below
            // (#894 finding 2, third pass).
            guard edge.length >= Self.degeneracyEpsilon else {
                return .failure(.degenerate("zero-length edge"))
            }

            guard let start = edge.point(at: bounds.first), let end = edge.point(at: bounds.last)
            else {
                return .failure(.missingGeometry(node))
            }

            // Only a curved edge (typically a circular arc) can coincide with a
            // cylindrical/conical face's true rotation axis; a linear edge always resolves to its
            // own line. Gate on curveType first — cheap, no bridge call — so a straight edge never
            // pays for the face walk in `revolutionAxis` (#894 finding 4, first pass); that walk is
            // also where the answer can still legitimately come back nil (no adjacent cyl/cone
            // face, or several that disagree — #894 finding 1, first pass). A candidate found there
            // is only actually used once `coaxialCrossSection` confirms the edge is genuinely a
            // circular cross-section of it, not merely non-linear and next to the right kind of
            // face (#894 finding 1, third pass) — see that function's doc for the elliptical-rim,
            // reparameterized-straight-seam, and helical-edge cases it exists to reject.
            if edge.curveType != .line,
                let axis = revolutionAxis(ofEdgeAt: node.index),
                coaxialCrossSection(of: edge, bounds: bounds, start: start, end: end, axis: axis)
            {
                let axisDirection = simd_normalize(axis.direction)
                // Keep the origin edge-local: project the edge's own start point onto the resolved
                // axis line rather than returning the adjacent surface's own placement origin,
                // which can be far from the edge itself — e.g. a cylinder's base under a rim near
                // its top (#894 finding 2, first pass).
                let toStart = start - axis.origin
                let projectedOrigin = axis.origin + simd_dot(toStart, axisDirection) * axisDirection
                return .success((projectedOrigin, axisDirection))
            }

            let dir = end - start
            return requireNonDegenerate(
                simd_length(dir), (start, simd_normalize(dir)), "zero-length edge")
        }
    }

    /// Whether `edge` is genuinely a circular cross-section of `axis` — a closed rim, or an open
    /// arc bounding one — rather than merely non-linear and adjacent to the right kind of face.
    ///
    /// Every point of an edge that bounds a cylindrical or conical face already sits at that
    /// surface's own radius from the axis by construction, so radius-from-axis alone can't tell a
    /// true circular rim from the elliptical edge an OBLIQUE plane cuts from a cylinder — both lie
    /// exactly on the wall (#894 finding 1, third pass). What does distinguish them is height
    /// along the axis: a genuine perpendicular cross-section's points all sit at the same signed
    /// distance along `axis.direction`; an oblique-cut ellipse's height varies as you go around
    /// it. Checking both radius and height also rejects two cases finding 1's own second-pass
    /// follow-ups raised against the chord-parallel-to-axis check this replaced: a straight seam
    /// reparameterized as a BSpline (round-1 finding 3) runs ALONG the axis, so its height changes
    /// across the edge rather than staying constant; a helical edge's height changes with the
    /// sweep angle the same way, regardless of how close its two-point secant happens to land to
    /// the axis direction by coincidence of the pitch. Both fall through to the endpoint-secant
    /// fallback in `resolveEdgeDirection`, which is already the right answer for a true straight
    /// line and the most honest available answer for a helix.
    ///
    /// Samples `start`, `end`, and three interior points rather than just the two endpoints,
    /// since two points on any curve are trivially "coplanar" and "equidistant" — the check needs
    /// enough samples to actually see curvature/tilt across the edge's own span, not just at its
    /// ends.
    private func coaxialCrossSection(
        of edge: Edge, bounds: (first: Double, last: Double), start: SIMD3<Double>,
        end: SIMD3<Double>, axis: ShapeAxis
    ) -> Bool {
        let axisDirection = simd_normalize(axis.direction)
        let span = bounds.last - bounds.first
        var samples = [start]
        for fraction in [0.25, 0.5, 0.75] {
            guard let point = edge.point(at: bounds.first + span * fraction) else { return false }
            samples.append(point)
        }
        samples.append(end)

        let heights = samples.map { simd_dot($0 - axis.origin, axisDirection) }
        let radii = samples.map { sample -> Double in
            let offset = sample - axis.origin
            return simd_length(offset - simd_dot(offset, axisDirection) * axisDirection)
        }
        guard let minHeight = heights.min(), let maxHeight = heights.max(),
            let minRadius = radii.min(), let maxRadius = radii.max()
        else { return false }
        return maxHeight - minHeight < Self.axisOriginAgreementDistanceTolerance
            && maxRadius - minRadius < Self.axisOriginAgreementDistanceTolerance
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
