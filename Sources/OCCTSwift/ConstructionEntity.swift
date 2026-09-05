import Foundation
import OCCTBridge
import simd

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
    public init(origin: SIMD3<Double>, normal: SIMD3<Double>) {
        let z = simd_normalize(normal)
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
                point -> Result<Placement, ConstructionResolutionError> in
                resolveFaceNormal(faceRef, at: point).map { (onFacePoint, normal) in
                    // Use the actual on-face point the normal was evaluated at, not the raw
                    // `atRef` point: they can differ when `at` doesn't genuinely lie on `face`
                    // (#897 review, finding 2).
                    Placement(origin: onFacePoint, normal: normal)
                }
            }

        case .midPlane(let a, let b):
            return resolveFaceOrigin(a).flatMap { (oA, nA) in
                resolveFaceOrigin(b).flatMap { (oB, nB) in
                    let origin = (oA + oB) / 2
                    let avgNormal =
                        simd_length_squared(nA + nB) > 1e-12
                        ? simd_normalize(nA + nB)
                        : simd_normalize(nA - nB)  // antiparallel faces, use either normal
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
            // Result's Success isn't tuple-label-covariant the way a bare tuple return is, so
            // the relabel has to be explicit here even though the names are identical.
            return resolveEdgeDirection(edgeRef).map { origin, direction in
                (origin: origin, direction: direction)
            }

        case .normalToFace(let faceRef, let atRef):
            return resolveVertexPoint(atRef).flatMap { anchor in
                resolveFaceAxisDirection(faceRef, at: anchor).map { (point, direction) in
                    // Use the actual on-axis or on-face point the direction was evaluated
                    // at, not the raw `atRef` point, for the same reason `tangentToFace`
                    // does (#897 review, second xhigh pass finding 2, third pass): they can
                    // differ, and returning them mismatched produces an axis anchored at
                    // one point but pointing in the direction measured at another.
                    (point, direction)
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
    /// The five call sites compare three different kinds of quantity, a raw distance, a cross
    /// product's area-scale magnitude, and a unit-vector dot/cross, that happen to share this
    /// literal today by coincidence, not because they are numerically comparable (#887).
    /// Per-site tuning isn't supported today: `requireNonDegenerate` takes no per-call epsilon
    /// argument, so every call site shares this one constant. Supporting it would mean adding an
    /// epsilon parameter to `requireNonDegenerate`, and picking a real per-site value, not
    /// inventing one without measurement (#726) (#894 finding 5).
    private static let degeneracyEpsilon = 1e-9

    /// Cosine-of-angle threshold for two unit directions being the same or exactly opposite.
    ///
    /// Used by ``axesAgree(_:_:)``: every adjacent cylindrical/conical face's axis must agree
    /// before `revolutionAxis(ofEdgeAt:)` returns a definitive answer (finding 1, first pass).
    /// `resolveEdgeDirection` originally had a second use, a chord-parallel-to-the-candidate-axis
    /// check standing in for "is this edge a straight seam", but that check was never true for a
    /// straight seam on a *cone* (a cone's generatrix meets its axis at the cone's own nonzero
    /// half-angle, never 0) and could misfire true for a helical edge whose two-point secant
    /// happens to land near-parallel to the axis by coincidence of the sweep angle (both findings
    /// 1/3, second pass). ``coaxialCrossSection(of:bounds:start:end:axis:edgeTolerance:)``
    /// replaces it with a direct geometric test that doesn't need this tolerance at all (finding
    /// 1, third pass), so this constant is `axesAgree`'s alone again.
    ///
    /// `OCCTPrecision.angular` (`Precision::Angular()`, 1e-12), not a hand-invented literal: this
    /// codebase has a documented history of a hardcoded direction-comparison tolerance silently
    /// drifting from the canonical one (`docs/reference/Surface-Analysis.md`'s "ten times looser
    /// than `Precision::Confusion()`" note; #494/#529 are whole issues about exactly this).
    /// Verified, not assumed, that the tighter value is safe here: swapped in and re-ran the full
    /// `OCCTBRepGraphTests` and `OCCTMiscTests` targets (#894 finding 6, second pass), no
    /// behavior changed, since a genuine adjacent-face-axis comparison (either the identical
    /// `TopoDS_Face` read twice, or a BOP-split piece sharing the same analytic `Geom_Surface`
    /// handle) agrees to within floating-point noise far tighter than even 1e-12, while two
    /// genuinely different cylinders (e.g. this file's T-branch fixture) disagree by orders of
    /// magnitude more than either tolerance.
    ///
    /// **This value is a cosine tolerance, not a direct radian one, despite the name's own
    /// provenance claim above.** `axesAgree` below compares it against `|dot(a, b)| - 1|`, not
    /// against an angle from `acos`. For unit vectors separated by a small angle θ,
    /// `1 - |cos θ| ≈ θ²/2`, so the guard actually admits any θ up to
    /// `sqrt(2 × OCCTPrecision.angular) ≈ 1.41e-6` rad, about six orders of magnitude looser than
    /// `Precision::Angular()`'s own 1e-12 rad, and looser than a direct `acos(dot(a, b)) <
    /// OCCTPrecision.angular` comparison would be by the same factor (#914 review, second round).
    /// Not a live bug: on a 100mm part that's ~0.14 µm of divergence over the part's length,
    /// harmless in practice and well inside the margin the verification paragraph above already
    /// measured (floating-point-noise agreement vs. orders-of-magnitude disagreement), but the
    /// quantity being compared is `angular²/2`-equivalent, not `angular` itself, and a future
    /// tightening of this constant should account for the squaring.
    private static let axisDirectionAgreementCosineTolerance = OCCTPrecision.angular

    /// Distance threshold for "this point sits on this axis line". Used two ways:
    ///
    /// - ``axesAgree(_:_:)``: the perpendicular offset between one candidate axis's origin and
    ///   the line through another, so two same-diameter but genuinely distinct bores don't
    ///   count as one (finding 1, first pass). Used directly, unmodified, the two faces being
    ///   compared here are either the identical `TopoDS_Face` read twice or a BOP-split piece
    ///   sharing the same analytic `Geom_Surface` handle, so machine precision is the right bar.
    /// - ``coaxialCrossSection(of:bounds:start:end:axis:edgeTolerance:)``: the FLOOR under how
    ///   much a sampled point's height along the axis, or its radius from it, may vary across the
    ///   edge before it stops counting as a genuine perpendicular cross-section (finding 1, third
    ///   pass). The actual comparison there is `max(edge's own measured BRep_Tool::Tolerance,
    ///   this floor)`, not this constant alone: a real edge that has survived a Boolean/fillet
    ///   commonly measures 1e-4-1e-3, far looser than this machine-precision value, and this
    ///   constant alone rejected genuine circular rims on exactly that kind of edge (#894
    ///   finding 2, fifth pass). The floor still applies to a pristine, machine-precision edge,
    ///   `max` never makes the check LOOSER than this value, only ever loosens it upward to match
    ///   what the edge itself already measures.
    ///
    /// A fixed absolute threshold, like ``degeneracyEpsilon`` above, not a fraction of model
    /// scale. `OCCTPrecision.confusion` (`Precision::Confusion()`, 1e-7), the canonical "points
    /// closer than this are 'same'" distance, not a hand-invented literal, for the same reason as
    /// ``axisDirectionAgreementCosineTolerance`` above (#894 finding 6, second pass); also
    /// verified against the full test sweep described there. This is 10x tighter than the `1e-6`
    /// it replaces and than `Shape.revolutionAxes(tolerance:)`'s own default (`ShapeAxis.swift`)
    /// and the bridge-side `axesCoincide` it wraps (`OCCTBridge_Topology.mm`), not because either
    /// is called from here (that dedup runs in the C++ layer over every face of a whole shape;
    /// this code only ever compares the 1-2 faces adjacent to a single edge, so there's no shared
    /// function to actually call across that boundary), but so a future retune of one is at least
    /// discoverable from the other (finding 4, third pass). The two are independent constants
    /// (`1e-7` here vs. `revolutionAxes`' `1e-6`), not required to match.
    private static let axisOriginAgreementDistanceTolerance = OCCTPrecision.confusion

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

    /// Resolves `ref` to a node of the given `kind`, extracting a typed topology element via
    /// `extract`, and failing with `.notApplicable`/`.missingGeometry` as appropriate.
    ///
    /// Shared by `resolveFace(_:)` and `resolveEdge(_:)` below, which used to duplicate this
    /// unwrap→kind-guard→extract→success shape independently, the same
    /// `unwrapTopology(ref)` → kind check → `shape(nodeKind:nodeIndex:)` → first-element →
    /// success-tuple steps, differing only in the `NodeKind` and the extracted type (#897
    /// review, third pass, finding 1). Unlabeled, like `projectedNormal(on:at:)` below, for the
    /// same reason (`okf/policies/code-style.md`), every call site of `resolveFace(_:)`/
    /// `resolveEdge(_:)` already destructures positionally, never by label, so the labels those
    /// two used to bake in were pure documentation, costless to drop (#897 review, third pass).
    private func resolveTopologyNode<T>(
        _ ref: TopologyRef, kind: NodeKind, expected: String, extract: (Shape) -> T?
    ) -> Result<(NodeRef, T), ConstructionResolutionError> {
        return unwrapTopology(ref).flatMap {
            node -> Result<(NodeRef, T), ConstructionResolutionError> in
            guard node.kind == kind else {
                return .failure(.notApplicable("expected \(expected), got \(node.kind)"))
            }
            guard let shape = shape(nodeKind: node.kind, nodeIndex: node.index),
                let value = extract(shape)
            else {
                return .failure(.missingGeometry(node))
            }
            return .success((node, value))
        }
    }

    /// Resolves `ref` to a face node, failing with `.notApplicable`/`.missingGeometry` as appropriate.
    ///
    /// Shared by every face-based resolver below.
    private func resolveFace(_ ref: TopologyRef) -> Result<
        (NodeRef, Face), ConstructionResolutionError
    > {
        return resolveTopologyNode(ref, kind: .face, expected: "a face") { $0.faces().first }
    }

    /// Resolves `ref` to an edge node, failing with `.notApplicable`/`.missingGeometry` as appropriate.
    ///
    /// Shared by `resolveEdgeDirection` and `resolveEdgePointAndTangent` below.
    private func resolveEdge(_ ref: TopologyRef) -> Result<
        (NodeRef, Edge), ConstructionResolutionError
    > {
        return resolveTopologyNode(ref, kind: .edge, expected: "an edge") { $0.edges().first }
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
            guard let (point, normal) = face.uvMidpointSample() else {
                return .failure(.missingGeometry(node))
            }
            return .success((point, normal))
        }
    }

    /// Face-representative point only, sampled at the face's UV-domain midpoint,
    /// without evaluating the normal.
    ///
    /// Used by `resolveVertexPoint`'s face-ref fallback, which, unlike
    /// `resolveFaceOrigin`'s callers, only ever reads the point, so this skips the
    /// unused `normal(atU:v:)` evaluation `resolveFaceOrigin`'s `uvMidpointSample()`
    /// would otherwise pay for on every `.byThreePoints`/`.tangentToFace(at:)`
    /// resolution through this path (#897 review, finding 9).
    private func resolveFacePoint(_ ref: TopologyRef) -> Result<
        SIMD3<Double>, ConstructionResolutionError
    > {
        return resolveFace(ref).flatMap {
            node, face -> Result<SIMD3<Double>, ConstructionResolutionError> in
            guard let point = face.uvMidpointPoint() else {
                return .failure(.missingGeometry(node))
            }
            return .success(point)
        }
    }

    /// The surface normal at the projected location of `point` on the face, and
    /// the point actually used.
    ///
    /// That returned point is `point` itself only when `point` already lies on
    /// `face` (#897 review, finding 2), closer to the truth than the raw `point`,
    /// not a guaranteed on-face location: `Face.project(point:)` bounds its search to
    /// `face`'s UV bounds (`BRepTools::UVBounds`, a rectangular box in parameter
    /// space), not the exact trimmed boundary, so for a non-convex or holed face the
    /// result can land inside that box but outside the real trimmed region (#914
    /// review, finding 3, the specific "point past a face's v-range converges
    /// anyway" reproducer that finding proposed was checked directly against the
    /// bridge and does NOT reproduce: `GeomAPI_ProjectPointOnSurf`'s bounded
    /// constructor genuinely constrains convergence to those bounds, confirmed with a
    /// cylindrical face trimmed to `v ∈ [0, 10]`, projecting a point at `v = 25` on
    /// the same infinite cylinder, `project(point:)` correctly returns `nil`, not a
    /// point at `v = 25`).
    ///
    /// Falls back to the UV-midpoint sample (point AND normal together, so the two
    /// stay mutually consistent) when the projection itself fails to converge,
    /// `nil`, not just a defensive guard: `GeomAPI_ProjectPointOnSurf`'s gradient
    /// search has no stationary point to find for a point equidistant from an entire
    /// symmetric surface, e.g. a sphere's or torus's own center projected onto its
    /// own lateral face (measured directly, #897 review, second xhigh pass, finding
    /// 1/3). Falls back to the UV-midpoint normal ALONE, keeping the real projected
    /// point as the origin, when the projection succeeds but the local normal at
    /// that exact location is undefined, a genuine parametric singularity (e.g. a
    /// cone apex) distinct from a projection failure; `projection.point` there is
    /// still within `face`'s UV bounds, with the same box-vs-exact-boundary caveat
    /// as above.
    ///
    /// Shared by `resolveFaceNormal` (`.tangentToFace`) and `resolveFaceAxisDirection`'s
    /// no-`primaryAxis` fallback (`.normalToFace`), both used to duplicate this same
    /// project→normal→fallback shape independently (#897 review, second xhigh pass,
    /// finding 9).
    ///
    /// Unlabeled: an internal function returning a tuple with baked-in labels forces
    /// every call site whose own labels differ into a two-step bind-then-relabel
    /// instead of a direct return (`okf/policies/code-style.md`, established on this
    /// same file's sibling `ShapeAxis.swift` by #903/#904; #897 review, third pass).
    private func projectedNormal(on face: Face, at point: SIMD3<Double>) -> (
        SIMD3<Double>, SIMD3<Double>
    )? {
        guard let projection = face.project(point: point) else {
            guard let (fallbackPoint, fallbackNormal) = face.uvMidpointSample() else { return nil }
            return (fallbackPoint, fallbackNormal)
        }
        if let normal = face.normal(atU: projection.u, v: projection.v) {
            return (projection.point, normal)
        }
        guard let fallback = face.uvMidpointNormal() else { return nil }
        return (projection.point, fallback)
    }

    /// The `(point, normal)` `.tangentToFace` needs, via ``projectedNormal(on:at:)``.
    ///
    /// Used by `.tangentToFace` so the plane is tangent at the requested point, not
    /// at the face's unrelated UV midpoint (#879). `face.normal(atU:v:)` reports
    /// `nil` at a genuine parametric singularity (`GeomLProp_SLProps::IsNormalDefined()`
    /// false, the two tangent directions coincide, not merely shrink; see
    /// `docs/reference/Face.md`'s `normal` entry). Before this point-specific
    /// resolution existed, `tangentToFace` always used the UV-midpoint normal and so
    /// always succeeded for any face with valid `uvBounds`; ``projectedNormal(on:at:)``'s
    /// fallback on either failure mode instead of failing outright preserves that
    /// property (PR #897 review, 3rd + xhigh pass).
    private func resolveFaceNormal(_ ref: TopologyRef, at point: SIMD3<Double>) -> Result<
        (SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError
    > {
        return resolveFace(ref).flatMap {
            node, face -> Result<(SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError> in
            guard let resolved = projectedNormal(on: face, at: point) else {
                return .failure(.missingGeometry(node))
            }
            return .success(resolved)
        }
    }

    /// The direction (and its own on-axis or on-face anchor point) the normalToFace
    /// doc promises.
    ///
    /// The surface's own axis of revolution (`Face.primaryAxis`) for
    /// cylindrical/conical/toroidal/revolved faces, an ALLOW-list, not a deny-list,
    /// so a future `ShapeAxis.Kind` this file doesn't yet know about defaults to the
    /// safe normal-based fallback below rather than silently being treated as a
    /// genuine axis (PR #897 review, finding 8), NOT the same allow-list as the
    /// sibling `revolutionAxis(ofEdgeAt:)` a few dozen lines above, despite an earlier
    /// version of this comment claiming so: that one only accepts `.cylinder`/`.cone`
    /// (#897 review, third pass), `.torus`/`.revolution` faces have a genuine
    /// `primaryAxis` this branch correctly uses, but an edge merely adjacent to one
    /// doesn't get the same recognition from `alongEdge`, a real (if narrow)
    /// inconsistency between the two `Construction*` APIs, not a documentation bug to
    /// paper over, tracked, not fixed, here.
    ///
    /// The returned point is `point` projected onto the true axis line, `axis.origin
    /// + ((point - axis.origin) · direction) * direction`, not `point` itself: a
    /// true rotation axis's direction is the same everywhere on the surface, but its
    /// LOCATION is not `point` unless `point` already happens to sit on that line,
    /// which it generally doesn't (a vertex `at` names is usually on the surface,
    /// offset from the true centerline by the cylinder's own radius). Pairing the
    /// correct direction with an off-axis point would describe a different line
    /// entirely, parallel to, but not coincident with, the true axis (#897 review,
    /// third pass). Kept edge-local rather than snapped to `axis.origin` itself
    /// (which can be far from `point`, e.g. a cylinder's base under a rim near its
    /// top), matching `resolveEdgeDirection`'s identical projection a few dozen lines
    /// below.
    ///
    /// Falls back to ``projectedNormal(on:at:)``, the local surface normal at `point`'s
    /// own projected location, and the point it was actually evaluated at, for planes
    /// and free-form/BSpline faces, which have no `primaryAxis` at all: the same
    /// point-aware projection `resolveFaceNormal` uses for `tangentToFace`, so the
    /// direction varies with `point`, and its paired origin is never a different point
    /// than the one the direction was measured at (#897 review, finding 4 + second
    /// xhigh pass finding 2).
    ///
    /// Falls back to the UV-midpoint SAMPLE, point and normal together, not
    /// `projectedNormal(on:at:)`'s point-aware resolution above, but also not the raw
    /// `point` paired with an unrelated normal, for `.extrusion` and `.sphere`,
    /// which DO have a `primaryAxis` but not a genuine one: extrusion's `direction`
    /// is the sweep direction of `Geom_SurfaceOfLinearExtrusion`, tangent to the
    /// surface, not a normal. Sphere has no intrinsic rotation axis at all (it's
    /// symmetric about every axis through its center), so
    /// `gp_Sphere::Position().Direction()`, what `primaryAxis` reports for a sphere
    ///, is just the arbitrary construction-frame pole (`FeatureRecognition.swift`'s
    /// `isMaterialRadiallyInward` already carries this same exclusion for the
    /// identical reason). These two are deliberately kept off the point-aware path: a
    /// sphere's TRUE local normal at its own pole is parallel to this very (excluded)
    /// axis, the radial direction from center, so making this branch point-aware
    /// there would silently reproduce the excluded axis by another route at exactly
    /// the vertex the exclusion exists to guard (see
    /// `normalToFaceSphereFallsBackToNormal`). But pairing the raw, possibly off-face
    /// `point` with a normal sampled at the UNRELATED UV midpoint is its own
    /// origin/direction mismatch (#897 review, third pass), the same class of bug
    /// this whole function exists to fix elsewhere, so both come from the UV
    /// midpoint together instead.
    private func resolveFaceAxisDirection(_ ref: TopologyRef, at point: SIMD3<Double>) -> Result<
        (SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError
    > {
        return resolveFace(ref).flatMap {
            node, face -> Result<(SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError> in
            if let axis = face.primaryAxis {
                switch axis.kind {
                case .cylinder, .cone, .torus, .revolution:
                    let axisDirection = simd_normalize(axis.direction)
                    let toPoint = point - axis.origin
                    let onAxis = axis.origin + simd_dot(toPoint, axisDirection) * axisDirection
                    return .success((onAxis, axisDirection))
                default:
                    guard let (fallbackPoint, fallbackNormal) = face.uvMidpointSample() else {
                        return .failure(.missingGeometry(node))
                    }
                    return .success((fallbackPoint, simd_normalize(fallbackNormal)))
                }
            }
            guard let resolved = projectedNormal(on: face, at: point) else {
                return .failure(.missingGeometry(node))
            }
            return .success((resolved.0, simd_normalize(resolved.1)))
        }
    }

    /// The face's real area centroid (`Face.surfaceInertia.centerOfMass`), the
    /// same quantity `Shape.measure()` reports for the same face,
    /// not the UV-midpoint approximation `resolveFaceOrigin` uses (#884).
    ///
    /// `centerOfMass` is nil exactly when `area == 0` at the Swift level (see
    /// `MassProperties.swift`), but the bridge function behind it (`OCCTBRepGPropSinert`)
    /// catches any exception and returns a zero-initialized result on failure too, so a
    /// self-intersecting or otherwise ill-conditioned face whose `BRepGProp_Sinert`
    /// computation genuinely fails is indistinguishable, at this layer, from one that's
    /// truly zero-area. The failure message says so rather than diagnosing a specific
    /// cause this API can't actually tell apart (#897 review, third pass).
    private func resolveFaceCentroid(_ ref: TopologyRef) -> Result<
        SIMD3<Double>, ConstructionResolutionError
    > {
        return resolveFace(ref).flatMap {
            _, face -> Result<SIMD3<Double>, ConstructionResolutionError> in
            guard let centroid = face.surfaceInertia.centerOfMass else {
                return .failure(
                    .degenerate("face area is zero, or its inertia could not be computed"))
            }
            return .success(centroid)
        }
    }

    /// The true rotation axis of a cylindrical/conical edge, read off its adjacent face(s).
    ///
    /// Collects every adjacent face's ``Face/primaryAxis`` that is a cylinder or cone, the two
    /// surface kinds `ConstructionAxis.alongEdge`'s own doc promises (#883), and returns a
    /// definitive axis only when every candidate agrees with the first, per ``axesAgree(_:_:)``.
    /// An edge at a branch (a T-junction between two non-coaxial cylindrical faces, or any
    /// blended transition) has more than one disagreeing candidate; `nil` there tells the caller
    /// to fall back to the endpoint secant instead of silently picking whichever face happened to
    /// sort first (#894 finding 1). Planar and free-form neighbours, and edges with no face
    /// adjacency at all, contribute no candidate at all, so this is `nil` for them too.
    ///
    /// `internal`, not `private`: `ConstructionAxisTests.alongEdgeBranchWithDisagreeingAxesFallsBackToChord`
    /// calls this directly (via `@testable import`) instead of hand-rolling a parallel copy of the
    /// candidate-gathering loop's disagreement test with its own drifted tolerance (#894 finding 5,
    /// second pass). `count-operations.py` only counts `public` declarations, so this stays out of
    /// the operation count either way.
    func revolutionAxis(ofEdgeAt edgeIndex: Int) -> ShapeAxis? {
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
    /// ``axisOriginAgreementDistanceTolerance`` of the line through `reference`, not merely a
    /// parallel offset line, e.g. two same-diameter but genuinely distinct bores (#894 finding 1).
    ///
    /// `internal`, not `private`, for the same testability reason as ``revolutionAxis(ofEdgeAt:)``
    /// (#894 finding 5, second pass).
    func axesAgree(_ reference: ShapeAxis, _ other: ShapeAxis) -> Bool {
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

    /// - Returns: `(origin, direction)`, unlabeled, an internal function returning a tuple with
    ///   baked-in labels forces every call site whose own labels differ into a two-step
    ///   bind-then-relabel instead of a direct return (`okf/policies/code-style.md`; #914 review,
    ///   second round). The public `resolve(_ axis:)` above returns this directly and its own
    ///   declared, labeled `(origin:, direction:)` return type supplies the labels for that call.
    private func resolveEdgeDirection(_ ref: TopologyRef) -> Result<
        (SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError
    > {
        return resolveEdge(ref).flatMap {
            node, edge -> Result<
                (SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError
            > in
            guard let bounds = edge.parameterBounds else {
                return .failure(.missingGeometry(node))
            }

            // Only a curved edge (typically a circular arc) can coincide with a
            // cylindrical/conical face's true rotation axis; a linear edge always resolves to its
            // own line. Gate on curveType first, cheap, no bridge call, so a straight edge never
            // pays for the face walk in `revolutionAxis` (#894 finding 4, first pass), nor for the
            // arc-length degeneracy check below (#894 finding 3, fifth pass): a line can never be
            // closed with a zero secant the way a full circle can (see the comment below), so the
            // cheap secant-based check the pre-round-3 code used is still correct for a line,
            // only the non-line path below needs the true arc length.
            if edge.curveType == .line {
                // `edge.point(at:)` directly against the already-held `bounds` tuple, not a
                // fraction→point helper that would re-derive `parameterBounds` internally: a
                // redundant bridge round-trip when `bounds` is already in scope from the guard
                // above (#897 review, second xhigh pass, finding 8), this file is otherwise
                // deliberate about avoiding exactly this class of extra OCCT call (see the
                // comments a few lines below).
                guard let start = edge.point(at: bounds.first),
                    let end = edge.point(at: bounds.last)
                else {
                    return .failure(.missingGeometry(node))
                }
                let dir = end - start
                return requireNonDegenerate(
                    simd_length(dir), (start, simd_normalize(dir)), "zero-length edge")
            }

            // The edge's own degeneracy is checked before any axis lookup, and by true arc
            // length rather than the endpoint secant a few lines below: a full-circle rim is
            // legitimately closed (start == end, secant == 0) without being remotely degenerate
            //, that's exactly why the axis redirect below exists at all, so this can't reuse
            // the secant the way the fallback path does. Unconditional (for every non-line edge)
            // so a genuinely near-zero-length sliver edge (a leftover fillet/boolean artifact)
            // still reports `.degenerate` even when it happens to sit next to one clean
            // cylindrical/conical face and would otherwise get an unambiguous but meaningless
            // axis match below (#894 finding 2, third pass). Paying for this arc-length bridge
            // call only here, not on the line fast path above, is what finding 3 (fifth pass)
            // asked for.
            guard edge.length >= Self.degeneracyEpsilon else {
                return .failure(.degenerate("zero-length edge"))
            }

            // Same reasoning as the `.line` fast path above: `bounds` is already held, so use it
            // directly rather than re-deriving it via a fraction→point helper (#897 review,
            // second xhigh pass, finding 8).
            guard let start = edge.point(at: bounds.first), let end = edge.point(at: bounds.last)
            else {
                return .failure(.missingGeometry(node))
            }

            // The walk below is also where the answer can still legitimately come back nil (no
            // adjacent cyl/cone face, or several that disagree, #894 finding 1, first pass). A
            // candidate found there is only actually used once `coaxialCrossSection` confirms the
            // edge is genuinely a circular cross-section of it, not merely non-linear and next to
            // the right kind of face (#894 finding 1, third pass), see that function's doc for
            // the elliptical-rim, reparameterized-straight-seam, and helical-edge cases it exists
            // to reject.
            if let axis = revolutionAxis(ofEdgeAt: node.index),
                coaxialCrossSection(
                    of: edge, bounds: bounds, start: start, end: end, axis: axis,
                    edgeTolerance: edgeTolerance(node.index))
            {
                // `axis.direction`'s sign comes from `Face.primaryAxis`, the adjacent surface's
                // own placement convention, which has nothing to do with which of the edge's two
                // ends is `bounds.first`. Every other path through this function derives its sign
                // from the edge's own start->end order (`dir = end - start` below); re-derive it
                // here the same way so a caller building `throughAxis` off two edges that trace the
                // "same" physical rim/arc with opposite parameterization gets consistent, sign-aware
                // results instead of whatever the surface happened to store (#894 finding 2, second
                // pass). `chord` itself can't do this, `coaxialCrossSection` just confirmed it's
                // (near-)perpendicular to the axis, so its dot with `axisDirection` is noise, not
                // signal. Use the tangent at the edge's own start point instead: for a point
                // parameterized with increasing angle around `axisDirection` in a right-handed
                // frame, `cross(radial, tangent)` is `radius^2 * axisDirection`, so its sign against
                // `axisDirection` says whether increasing parameter, start->end, agrees with
                // `axisDirection` or runs opposite it.
                //
                // `edge.tangent(at:)` can return nil even where `edge.point(at:)` already
                // succeeded (e.g. a first-derivative singularity on a reparameterized curve).
                // Failing loudly here rather than silently keeping the unflipped `Face.primaryAxis`
                // sign matches this function's own "fail on ambiguity" convention elsewhere (#894
                // finding 1, fifth pass), a plausible-looking wrong sign is worse than an explicit
                // `.degenerate`.
                guard let tangentAtStart = edge.tangent(at: bounds.first) else {
                    return .failure(
                        .degenerate(
                            "edge tangent unavailable at start; cannot determine axis sign"))
                }
                var axisDirection = simd_normalize(axis.direction)
                let radial = start - axis.origin
                if simd_dot(axisDirection, simd_cross(radial, tangentAtStart)) < 0 {
                    axisDirection = -axisDirection
                }
                // Keep the origin edge-local: project the edge's own start point onto the resolved
                // axis line rather than returning the adjacent surface's own placement origin,
                // which can be far from the edge itself, e.g. a cylinder's base under a rim near
                // its top (#894 finding 2, first pass). Invariant to the sign flip above: negating
                // both `axisDirection` and the dot product it's multiplied by leaves the product
                // unchanged.
                let toStart = start - axis.origin
                let projectedOrigin = axis.origin + simd_dot(toStart, axisDirection) * axisDirection
                return .success((projectedOrigin, axisDirection))
            }

            let dir = end - start
            return requireNonDegenerate(
                simd_length(dir), (start, simd_normalize(dir)), "zero-length edge")
        }
    }

    /// Whether `edge` is genuinely a circular cross-section of `axis`, a closed rim, or an open
    /// arc bounding one, rather than merely non-linear and adjacent to the right kind of face.
    ///
    /// Every point of an edge that bounds a cylindrical or conical face already sits at that
    /// surface's own radius from the axis by construction, so radius-from-axis alone can't tell a
    /// true circular rim from the elliptical edge an OBLIQUE plane cuts from a cylinder, both lie
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
    /// since two points on any curve are trivially "coplanar" and "equidistant", the check needs
    /// enough samples to actually see curvature/tilt across the edge's own span, not just at its
    /// ends.
    ///
    /// The height/radius comparison tolerance is `max(edgeTolerance,
    /// axisOriginAgreementDistanceTolerance)`, not the latter alone: a real edge that has survived
    /// a Boolean/fillet routinely measures `BRep_Tool::Tolerance` in the 1e-4-1e-3 range,
    /// looser than the machine-precision `axisOriginAgreementDistanceTolerance` floor, and
    /// comparing sampled noise against that floor alone rejected genuine circular rims outright
    /// (#894 finding 2, fifth pass). `edgeTolerance` is the caller's own measured value for this
    /// edge (`BRepGraph.edgeTolerance(_:)`, wrapping `BRep_Tool::Tolerance`), not invented here,
    /// this function stays a pure geometric test of its arguments, with no lookup of its own.
    /// `internal`, not `private`, so `ConstructionAxisTests` can exercise the tolerance derivation
    /// directly against controlled sample noise, for the same testability reason as
    /// `revolutionAxis(ofEdgeAt:)`/`axesAgree(_:_:)` (#894 finding 5, second pass).
    func coaxialCrossSection(
        of edge: Edge, bounds: (first: Double, last: Double), start: SIMD3<Double>,
        end: SIMD3<Double>, axis: ShapeAxis, edgeTolerance: Double
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
        let crossSectionTolerance = max(edgeTolerance, Self.axisOriginAgreementDistanceTolerance)
        return maxHeight - minHeight < crossSectionTolerance
            && maxRadius - minRadius < crossSectionTolerance
    }

    private func resolveEdgePointAndTangent(_ ref: TopologyRef, t: Double) -> Result<
        (SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError
    > {
        return resolveEdge(ref).flatMap {
            node, edge -> Result<(SIMD3<Double>, SIMD3<Double>), ConstructionResolutionError> in
            guard let param = edge.parameterByLinearFraction(t),
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
                // Accept a face ref too, use its UV-midpoint sample, not a true
                // centroid (see resolveFaceCentroid), for convenience in byThreePoints etc.
                if node.kind == .face {
                    return resolveFacePoint(ref)
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
