import Foundation
import simd

// MARK: - FeatureReconstructor (#62, on #72 substrate)
//
// Declarative feature-spec → Shape dispatcher. Consumes a sequence of typed
// FeatureSpec entries (revolve / extrude / hole / thread / fillet / chamfer /
// boolean) and produces a Shape via staged evaluation:
//
//   additive (revolve, extrude, boolean union)
//   → subtractive (hole, boolean subtract)
//   → finishing (fillet, chamfer)
//   → annotation (thread)
//
// The EdgeSelector carried by fillet / chamfer uses TopologyRef (from #72
// Phase 1), so "the edge created by extrude op #3" is a stable reference that
// survives subsequent mutations, rather than an index-based heuristic.
//
// This is the v1 implementation. It:
//   - Does not yet use BRepGraph history recording during dispatch (the
//     shapes produced are built from primitives; each FeatureSpec gets tagged
//     with its own opName so downstream callers can use TopologyRef.createdBy
//     against the final graph).
//   - Supports partial reconstruction: failures accumulate in skipped[] rather
//     than aborting the whole build.
//   - Emits threads as annotations (metadata) rather than geometry, the
//     Shape.threadedHole / threadedShaft path from v0.139 can be invoked by
//     the caller if real thread geometry is wanted.

public enum FeatureSpec: Sendable, Hashable, Codable {
    case revolve(Revolve)
    case extrude(Extrude)
    case hole(Hole)
    case thread(Thread)
    case fillet(Fillet)
    case chamfer(Chamfer)
    case boolean(Boolean)

    public var id: String? {
        switch self {
        case .revolve(let r): return r.id
        case .extrude(let e): return e.id
        case .hole(let h): return h.id
        case .thread(let t): return t.id
        case .fillet(let f): return f.id
        case .chamfer(let c): return c.id
        case .boolean(let b): return b.id
        }
    }

    public struct Revolve: Sendable, Hashable, Codable {
        public var profilePoints2D: [SIMD2<Double>]
        public var axisOrigin: SIMD3<Double>
        public var axisDirection: SIMD3<Double>
        public var angleDeg: Double
        public var id: String?

        public init(
            profilePoints2D: [SIMD2<Double>],
            axisOrigin: SIMD3<Double>,
            axisDirection: SIMD3<Double>,
            angleDeg: Double = 360,
            id: String? = nil
        ) {
            self.profilePoints2D = profilePoints2D
            self.axisOrigin = axisOrigin
            self.axisDirection = axisDirection
            self.angleDeg = angleDeg
            self.id = id
        }
    }

    public struct Extrude: Sendable, Hashable, Codable {
        public var profilePoints2D: [SIMD2<Double>]
        public var planeOrigin: SIMD3<Double>
        public var planeNormal: SIMD3<Double>
        public var length: Double
        public var id: String?

        public init(
            profilePoints2D: [SIMD2<Double>],
            planeOrigin: SIMD3<Double>,
            planeNormal: SIMD3<Double>,
            length: Double,
            id: String? = nil
        ) {
            self.profilePoints2D = profilePoints2D
            self.planeOrigin = planeOrigin
            self.planeNormal = planeNormal
            self.length = length
            self.id = id
        }
    }

    public struct Hole: Sendable, Hashable, Codable {
        public var axisPoint: SIMD3<Double>
        public var axisDirection: SIMD3<Double>
        public var diameter: Double
        public var depth: Double?
        public var id: String?

        public init(
            axisPoint: SIMD3<Double>,
            axisDirection: SIMD3<Double>,
            diameter: Double,
            depth: Double? = nil,
            id: String? = nil
        ) {
            self.axisPoint = axisPoint
            self.axisDirection = axisDirection
            self.diameter = diameter
            self.depth = depth
            self.id = id
        }
    }

    public struct Thread: Sendable, Hashable, Codable {
        public var holeRef: String
        public var spec: String  // "M5x0.8", "1/4-20 UNC"
        public var length: Double?
        public var id: String?

        public init(holeRef: String, spec: String, length: Double? = nil, id: String? = nil) {
            self.holeRef = holeRef
            self.spec = spec
            self.length = length
            self.id = id
        }
    }

    public enum EdgeSelector: Sendable, Hashable, Codable {
        case all
        case nearPoint(SIMD3<Double>, tolerance: Double)
        case onFeature(String)  // feature id; maps to TopologyRef.createdBy
    }

    public struct Fillet: Sendable, Hashable, Codable {
        public var edgeSelector: EdgeSelector
        public var radius: Double
        public var id: String?

        public init(edgeSelector: EdgeSelector, radius: Double, id: String? = nil) {
            self.edgeSelector = edgeSelector
            self.radius = radius
            self.id = id
        }
    }

    public struct Chamfer: Sendable, Hashable, Codable {
        public var edgeSelector: EdgeSelector
        public var distance: Double
        public var id: String?

        public init(edgeSelector: EdgeSelector, distance: Double, id: String? = nil) {
            self.edgeSelector = edgeSelector
            self.distance = distance
            self.id = id
        }
    }

    public struct Boolean: Sendable, Hashable, Codable {
        public enum Op: String, Sendable, Codable { case union, subtract, intersect }
        public var op: Op
        public var leftID: String
        public var rightID: String
        public var id: String?

        public init(op: Op, leftID: String, rightID: String, id: String? = nil) {
            self.op = op
            self.leftID = leftID
            self.rightID = rightID
            self.id = id
        }
    }
}

public struct FeatureReconstructor: Sendable {
    public struct BuildResult: Sendable {
        public let shape: Shape?
        public let fulfilled: [String]
        public let skipped: [Skipped]
        public let annotations: [Annotation]
        /// Per-feature `ShapeHistoryRef` retained from history-recording
        /// builders (booleans + the Tier-2 modification ops, when used).
        ///
        /// Keyed by the feature id passed in `FeatureSpec.*.id`. Features
        /// without an id are not retained here, their history can't be
        /// remapped without a key.
        ///
        /// Use this to walk selection IDs across chained features:
        /// `result.histories["my_hole"]?.record(of: face)` returns the
        /// post-cut derivatives of `face`.
        public let histories: [String: ShapeHistoryRef]
    }

    public struct Skipped: Sendable {
        public enum Reason: Sendable {
            case underDetermined(String)
            case occtFailure(String)
            case unresolvedRef(String)
            case unsupported(String)
        }
        public enum Stage: String, Sendable { case additive, subtractive, finishing, annotation }
        public let featureID: String
        public let reason: Reason
        public let stage: Stage
    }

    public struct Annotation: Sendable {
        public enum Kind: Sendable {
            case thread(spec: String, holeRef: String, length: Double?)
        }
        public let kind: Kind
        public let featureID: String
    }

    // MARK: - Entry point

    /// Sentinel id under which a non-nil `inputBody` is registered in
    /// `namedShapes`.
    ///
    /// Boolean operands, fillet/chamfer `.onFeature` selectors, and any other feature spec that references a named shape
    /// can use this key to address the starting body. JSON envelopes can
    /// emit it as a literal string. The leading `@` keeps it disjoint from
    /// any feature id a caller is likely to supply; if a feature does
    /// register an id of `"@input"`, it shadows the input under standard
    /// last-write-wins semantics for `namedShapes`.
    public static let inputBodySentinel = "@input"

    public static func build(
        from specs: [FeatureSpec],
        inputBody: Shape? = nil
    ) -> BuildResult {
        var ctx = BuildContext()

        if let inputBody {
            // Seed the in-progress shape and register the input under the
            // sentinel id so additive (union), subtractive (cut/intersect),
            // and finishing (fillet/chamfer .onFeature) stages can address
            // it the same way they address any other feature output.
            ctx.current = inputBody
            ctx.namedShapes[inputBodySentinel] = inputBody
        }

        // Stage 1: additive
        for spec in specs {
            switch spec {
            case .revolve(let r):
                applyRevolve(r, ctx: &ctx)
            case .extrude(let e):
                applyExtrude(e, ctx: &ctx)
            case .boolean(let b) where b.op == .union:
                applyBoolean(b, stage: .additive, ctx: &ctx)
            default: break
            }
        }

        // Stage 2: subtractive
        for spec in specs {
            switch spec {
            case .hole(let h):
                applyHole(h, ctx: &ctx)
            case .boolean(let b) where b.op == .subtract || b.op == .intersect:
                applyBoolean(b, stage: .subtractive, ctx: &ctx)
            default: break
            }
        }

        // Stage 3: finishing
        for spec in specs {
            switch spec {
            case .fillet(let f):
                applyFillet(f, ctx: &ctx)
            case .chamfer(let c):
                applyChamfer(c, ctx: &ctx)
            default: break
            }
        }

        // Stage 4: annotation
        for spec in specs {
            if case .thread(let t) = spec {
                ctx.annotations.append(
                    Annotation(
                        kind: .thread(spec: t.spec, holeRef: t.holeRef, length: t.length),
                        featureID: t.id ?? "thread"))
                if let id = t.id { ctx.fulfilled.append(id) }
            }
        }

        return BuildResult(
            shape: ctx.current, fulfilled: ctx.fulfilled,
            skipped: ctx.skipped, annotations: ctx.annotations,
            histories: ctx.histories)
    }

    /// Internal state carried through the staged dispatch.
    fileprivate struct BuildContext {
        var current: Shape? = nil
        var fulfilled: [String] = []
        var skipped: [Skipped] = []
        var annotations: [Annotation] = []
        /// Named-shape registry.
        ///
        /// Features with non-nil ids register their produced shape here so downstream Boolean specs can reference them.
        var namedShapes: [String: Shape] = [:]
        /// Per-feature ShapeHistoryRef from history-recording builders.
        var histories: [String: ShapeHistoryRef] = [:]
    }

    // MARK: - Stage handlers

    private static func applyRevolve(_ r: FeatureSpec.Revolve, ctx: inout BuildContext) {
        guard r.profilePoints2D.count >= 3 else {
            recordSkip(
                ctx: &ctx, id: r.id,
                reason: .underDetermined("revolve profile needs ≥3 points"),
                stage: .additive)
            return
        }
        let pts3D = r.profilePoints2D.map { SIMD3<Double>($0.x, 0, $0.y) }
        guard let wire = Wire.polygon3D(pts3D, closed: true) else {
            recordSkip(
                ctx: &ctx, id: r.id,
                reason: .occtFailure("wire construction failed"),
                stage: .additive)
            return
        }
        let angle = r.angleDeg * .pi / 180
        guard
            let body = Shape.revolve(
                profile: wire,
                axisOrigin: r.axisOrigin,
                axisDirection: r.axisDirection,
                angle: angle)
        else {
            recordSkip(
                ctx: &ctx, id: r.id,
                reason: .occtFailure("revolve failed"),
                stage: .additive)
            return
        }
        absorbAdditive(body, id: r.id, ctx: &ctx)
    }

    private static func applyExtrude(_ e: FeatureSpec.Extrude, ctx: inout BuildContext) {
        guard e.profilePoints2D.count >= 3 else {
            recordSkip(
                ctx: &ctx, id: e.id,
                reason: .underDetermined("extrude profile needs ≥3 points"),
                stage: .additive)
            return
        }
        let placement = Placement(origin: e.planeOrigin, normal: e.planeNormal)
        let pts3D = e.profilePoints2D.map { placement.lift($0) }
        guard let wire = Wire.polygon3D(pts3D, closed: true) else {
            recordSkip(
                ctx: &ctx, id: e.id,
                reason: .occtFailure("wire construction failed"),
                stage: .additive)
            return
        }
        guard
            let body = Shape.extrude(
                profile: wire,
                direction: simd_normalize(e.planeNormal),
                length: e.length)
        else {
            recordSkip(
                ctx: &ctx, id: e.id,
                reason: .occtFailure("extrude failed"),
                stage: .additive)
            return
        }
        absorbAdditive(body, id: e.id, ctx: &ctx)
    }

    private static func applyHole(_ h: FeatureSpec.Hole, ctx: inout BuildContext) {
        guard let target = ctx.current else {
            recordSkip(
                ctx: &ctx, id: h.id,
                reason: .underDetermined("no target shape"),
                stage: .subtractive)
            return
        }
        let depth = h.depth ?? 100.0
        guard
            let drill = Shape.cylinder(
                at: h.axisPoint,
                direction: h.axisDirection,
                radius: h.diameter / 2,
                height: depth)
        else {
            recordSkip(
                ctx: &ctx, id: h.id,
                reason: .occtFailure("drill cylinder failed"),
                stage: .subtractive)
            return
        }
        // Use the history-recording variant so consumers (e.g. selection
        // remappers) can walk per-input subshape history through the cut.
        if let id = h.id, let r = target.subtractedWithFullHistory(drill) {
            ctx.current = r.result
            ctx.fulfilled.append(id)
            ctx.namedShapes[id] = r.result
            ctx.histories[id] = r.history
        } else if h.id == nil, let cut = target.subtracting(drill) {
            // No id → no key to retain history under; skip the history capture.
            ctx.current = cut
        } else {
            recordSkip(
                ctx: &ctx, id: h.id,
                reason: .occtFailure("boolean subtract failed"),
                stage: .subtractive)
            return
        }
    }

    private static func applyBoolean(
        _ b: FeatureSpec.Boolean,
        stage: Skipped.Stage,
        ctx: inout BuildContext
    ) {
        guard let left = ctx.namedShapes[b.leftID] else {
            recordSkip(
                ctx: &ctx, id: b.id,
                reason: .unresolvedRef("left id '\(b.leftID)' not found in registry"),
                stage: stage)
            return
        }
        guard let right = ctx.namedShapes[b.rightID] else {
            recordSkip(
                ctx: &ctx, id: b.id,
                reason: .unresolvedRef("right id '\(b.rightID)' not found in registry"),
                stage: stage)
            return
        }
        // Prefer the history-recording variant when the feature has an id so
        // consumers can remap selections through the boolean. When no id, fall
        // back to the cheap path (no key to attach the history under anyway).
        if let id = b.id {
            let withHist: (result: Shape, history: ShapeHistoryRef)?
            switch b.op {
            case .union: withHist = left.unionWithFullHistory(right)
            case .subtract: withHist = left.subtractedWithFullHistory(right)
            case .intersect: withHist = left.intersectionWithFullHistory(right)
            }
            guard let r = withHist else {
                recordSkip(
                    ctx: &ctx, id: b.id,
                    reason: .occtFailure("boolean \(b.op.rawValue) failed"),
                    stage: stage)
                return
            }
            ctx.fulfilled.append(id)
            ctx.namedShapes[id] = r.result
            ctx.histories[id] = r.history
            ctx.current = r.result
        } else {
            let result: Shape?
            switch b.op {
            case .union: result = left.union(right)
            case .subtract: result = left.subtracting(right)
            case .intersect: result = left.intersection(right)
            }
            guard let r = result else {
                recordSkip(
                    ctx: &ctx, id: b.id,
                    reason: .occtFailure("boolean \(b.op.rawValue) failed"),
                    stage: stage)
                return
            }
            ctx.current = r
        }
    }

    private static func applyFillet(_ f: FeatureSpec.Fillet, ctx: inout BuildContext) {
        guard let target = ctx.current else {
            recordSkip(
                ctx: &ctx, id: f.id,
                reason: .underDetermined("no target shape"),
                stage: .finishing)
            return
        }
        let edgeIndices: [Int]?
        switch f.edgeSelector {
        case .all:
            let allEdges = target.subShapes(ofType: .edge)
            edgeIndices = allEdges.isEmpty ? nil : Array(allEdges.indices)
        case .nearPoint(let point, let tolerance):
            edgeIndices = edgeIndicesNearPoint(target, point: point, tolerance: tolerance)
            guard edgeIndices != nil else {
                recordSkip(
                    ctx: &ctx, id: f.id,
                    reason: .occtFailure("no edge found near point within tolerance"),
                    stage: .finishing)
                return
            }
        case .onFeature(let featureID):
            guard let source = ctx.namedShapes[featureID] else {
                recordSkip(
                    ctx: &ctx, id: f.id,
                    reason: .unresolvedRef("feature '\(featureID)' not registered"),
                    stage: .finishing)
                return
            }
            edgeIndices = edgeIndicesContributedBy(target: target, source: source)
            guard edgeIndices != nil else {
                recordSkip(
                    ctx: &ctx, id: f.id,
                    reason: .occtFailure("fillet onFeature failed"),
                    stage: .finishing)
                return
            }
        }
        guard let indices = edgeIndices else {
            recordSkip(
                ctx: &ctx, id: f.id,
                reason: .occtFailure("uniform fillet failed"),
                stage: .finishing)
            return
        }
        // History-recording path; falls back to the non-history primitive on nil
        // so the back-compat surface stays defensive against any future builder
        // that reports a builder failure but has nothing useful to recover.
        if let r = target.filletedWithFullHistory(radius: f.radius, edges: indices) {
            ctx.current = r.result
            if let id = f.id {
                ctx.fulfilled.append(id)
                ctx.namedShapes[id] = r.result
                ctx.histories[id] = r.history
            }
            return
        }
        // Fallback. For .all this exercises BRepFilletAPI_MakeFillet's
        // shape-level convenience overload.
        let fallback: Shape?
        switch f.edgeSelector {
        case .all:
            fallback = target.filleted(radius: f.radius)
        case .nearPoint, .onFeature:
            // Look up the matching Edge objects and call the typed-edges variant.
            let allTypedEdges = target.edges()
            let edgeObjects = indices.compactMap { i -> Edge? in
                (i >= 0 && i < allTypedEdges.count) ? allTypedEdges[i] : nil
            }
            fallback =
                edgeObjects.isEmpty ? nil : target.filleted(edges: edgeObjects, radius: f.radius)
        }
        if let filleted = fallback {
            ctx.current = filleted
            if let id = f.id {
                ctx.fulfilled.append(id)
                ctx.namedShapes[id] = filleted
            }
        } else {
            recordSkip(
                ctx: &ctx, id: f.id,
                reason: .occtFailure("uniform fillet failed"),
                stage: .finishing)
        }
    }

    private static func applyChamfer(_ c: FeatureSpec.Chamfer, ctx: inout BuildContext) {
        guard let target = ctx.current else {
            recordSkip(
                ctx: &ctx, id: c.id,
                reason: .underDetermined("no target shape"),
                stage: .finishing)
            return
        }
        let edgeIndices: [Int]?
        switch c.edgeSelector {
        case .all:
            let allEdges = target.subShapes(ofType: .edge)
            edgeIndices = allEdges.isEmpty ? nil : Array(allEdges.indices)
        case .nearPoint(let point, let tolerance):
            edgeIndices = edgeIndicesNearPoint(target, point: point, tolerance: tolerance)
            guard edgeIndices != nil else {
                recordSkip(
                    ctx: &ctx, id: c.id,
                    reason: .occtFailure("no edge found near point within tolerance"),
                    stage: .finishing)
                return
            }
        case .onFeature(let featureID):
            guard let source = ctx.namedShapes[featureID] else {
                recordSkip(
                    ctx: &ctx, id: c.id,
                    reason: .unresolvedRef("feature '\(featureID)' not registered"),
                    stage: .finishing)
                return
            }
            edgeIndices = edgeIndicesContributedBy(target: target, source: source)
            guard edgeIndices != nil else {
                recordSkip(
                    ctx: &ctx, id: c.id,
                    reason: .occtFailure("chamfer onFeature failed"),
                    stage: .finishing)
                return
            }
        }
        guard let indices = edgeIndices else {
            recordSkip(
                ctx: &ctx, id: c.id,
                reason: .occtFailure("uniform chamfer failed"),
                stage: .finishing)
            return
        }
        if let r = target.chamferedWithFullHistory(distance: c.distance, edges: indices) {
            ctx.current = r.result
            if let id = c.id {
                ctx.fulfilled.append(id)
                ctx.namedShapes[id] = r.result
                ctx.histories[id] = r.history
            }
            return
        }
        // Fallback: only the .all case has an index-less fast-path
        // (`Shape.chamfered(distance:)`); .nearPoint / .onFeature go through
        // BRepFilletAPI_MakeChamfer with explicit edges, which the history
        // variant already covers.
        if case .all = c.edgeSelector, let chamfered = target.chamfered(distance: c.distance) {
            ctx.current = chamfered
            if let id = c.id {
                ctx.fulfilled.append(id)
                ctx.namedShapes[id] = chamfered
            }
        } else {
            recordSkip(
                ctx: &ctx, id: c.id,
                reason: .occtFailure("uniform chamfer failed"),
                stage: .finishing)
        }
    }

    // MARK: - Edge-selector helpers

    /// Edge indices in `shape` whose midpoint lies within `tolerance` of `point`.
    ///
    /// Index space matches `shape.subShapes(ofType: .edge)` / `shape.edges()`,
    /// both are TopExp_MapShapes traversals in canonical order.
    private static func edgeIndicesNearPoint(
        _ shape: Shape,
        point: SIMD3<Double>,
        tolerance: Double
    ) -> [Int]? {
        var matching: [Int] = []
        for (i, edge) in shape.edges().enumerated() {
            guard let bounds = edge.parameterBounds,
                let mid = edge.point(at: (bounds.first + bounds.last) / 2)
            else { continue }
            if simd_length(mid - point) <= tolerance {
                matching.append(i)
            }
        }
        return matching.isEmpty ? nil : matching
    }

    /// Edge indices of `target` that were "contributed by" `source`, heuristic.
    ///
    /// edges of target whose midpoint lies within a small tolerance of any edge
    /// midpoint of source. Useful for "fillet the edges the extrude created"
    /// without needing full BRepGraph history.
    private static func edgeIndicesContributedBy(
        target: Shape,
        source: Shape,
        tolerance: Double = 1e-4
    ) -> [Int]? {
        let sourceEdgeMidpoints = source.edges().compactMap { edge -> SIMD3<Double>? in
            guard let bounds = edge.parameterBounds else { return nil }
            return edge.point(at: (bounds.first + bounds.last) / 2)
        }
        var matching: [Int] = []
        for (i, edge) in target.edges().enumerated() {
            guard let bounds = edge.parameterBounds,
                let mid = edge.point(at: (bounds.first + bounds.last) / 2)
            else { continue }
            if sourceEdgeMidpoints.contains(where: { simd_length($0 - mid) <= tolerance }) {
                matching.append(i)
            }
        }
        return matching.isEmpty ? nil : matching
    }

    // MARK: - Utilities

    private static func recordSkip(
        ctx: inout BuildContext,
        id: String?,
        reason: Skipped.Reason,
        stage: Skipped.Stage
    ) {
        guard let id = id else { return }
        ctx.skipped.append(Skipped(featureID: id, reason: reason, stage: stage))
    }

    private static func absorbAdditive(_ body: Shape, id: String?, ctx: inout BuildContext) {
        // First additive feature → just seed `current` (no fusion happened).
        // Later additive features → fuse into existing current; capture history
        // when an id is set so selections originating in either operand can be
        // remapped through the union.
        if let prior = ctx.current {
            if let id, let r = prior.unionWithFullHistory(body) {
                ctx.current = r.result
                ctx.histories[id] = r.history
            } else if let id {
                // History-recording union failed; fall back to the plain union.
                // If that also fails, this id'd feature never fused: surface it
                // as Skipped and leave `ctx.current` (every prior accumulated
                // shape) untouched, matching applyBoolean/applyHole/applyFillet/
                // applyChamfer's own failure-path handling.
                guard let fused = prior.union(body) else {
                    recordSkip(
                        ctx: &ctx, id: id,
                        reason: .occtFailure("boolean union failed"),
                        stage: .additive)
                    return
                }
                ctx.current = fused
            } else {
                // No id: no Skipped entry possible anyway (recordSkip is a no-op
                // for a nil id), so an anonymous feature that fails to fuse still
                // falls back to absorbing its own unfused body.
                ctx.current = prior.union(body) ?? body
            }
        } else {
            ctx.current = body
        }
        if let id = id {
            ctx.fulfilled.append(id)
            ctx.namedShapes[id] = body  // register the feature's own body, not the fused
        }
    }
}

// MARK: - JSON front end

extension FeatureReconstructor {
    /// Minimal JSON front end: parses a top-level `{"features": [...]}` object.
    ///
    /// with `kind`-discriminated entries. The full schema mirrors the OCCTDesignLoop
    /// part_graph.py contract; this is a starting surface for JSON-driven
    /// dispatch, to be extended as the schema stabilises.
    public static func buildJSON(
        _ data: Data,
        inputBody: Shape? = nil
    ) throws -> BuildResult {
        struct Envelope: Decodable {
            var features: [FeatureEntry]
        }
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        let result = build(
            from: env.features.compactMap { $0.spec },
            inputBody: inputBody)

        // Surface unknown JSON `kind` values as `Skipped` entries so a typo
        // or a version-drift schema doesn't silently lose features.
        var augmentedSkipped = result.skipped
        for entry in env.features {
            guard let kind = entry.unknownKind, let id = entry.unknownID else {
                continue
            }
            augmentedSkipped.append(
                Skipped(
                    featureID: id,
                    reason: .unsupported("unknown JSON kind: \(kind)"),
                    stage: .additive))
        }
        return BuildResult(
            shape: result.shape,
            fulfilled: result.fulfilled,
            skipped: augmentedSkipped,
            annotations: result.annotations,
            histories: result.histories)
    }
}

// MARK: - JSON decoding helpers

private struct FeatureEntry: Decodable {
    let spec: FeatureSpec?
    /// Set when `kind` did not match any recognised case. `buildJSON` reads
    /// this to emit an `unsupported` skip so callers can detect typos /
    /// schema drift instead of features silently disappearing.
    let unknownKind: String?
    let unknownID: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case profilePoints2D = "profile_points_2d"
        case axisOrigin = "axis_origin"
        case axisDirection = "axis_direction"
        case planeOrigin = "plane_origin"
        case planeNormal = "plane_normal"
        case angleDeg = "angle_deg"
        case length
        case axisPoint = "axis_point"
        case diameter
        case depth
        case radius
        case distance
        case holeRef = "hole_ref"
        case spec = "thread_spec"
        case threadSpec = "spec"
        case id
        case op
        case leftID = "left"
        case rightID = "right"
        case edgeSelector = "edges"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        let id = try c.decodeIfPresent(String.self, forKey: .id)

        switch kind {
        case "revolve":
            let pts = try c.decode([[Double]].self, forKey: .profilePoints2D).map {
                SIMD2($0[0], $0[1])
            }
            let axisOrigin = try c.decode([Double].self, forKey: .axisOrigin)
            let axisDir = try c.decode([Double].self, forKey: .axisDirection)
            let angle = try c.decodeIfPresent(Double.self, forKey: .angleDeg) ?? 360
            self.spec = .revolve(
                .init(
                    profilePoints2D: pts,
                    axisOrigin: SIMD3(axisOrigin[0], axisOrigin[1], axisOrigin[2]),
                    axisDirection: SIMD3(axisDir[0], axisDir[1], axisDir[2]),
                    angleDeg: angle, id: id))
        case "extrude":
            let pts = try c.decode([[Double]].self, forKey: .profilePoints2D).map {
                SIMD2($0[0], $0[1])
            }
            let origin = try c.decode([Double].self, forKey: .planeOrigin)
            let normal = try c.decode([Double].self, forKey: .planeNormal)
            let length = try c.decode(Double.self, forKey: .length)
            self.spec = .extrude(
                .init(
                    profilePoints2D: pts,
                    planeOrigin: SIMD3(origin[0], origin[1], origin[2]),
                    planeNormal: SIMD3(normal[0], normal[1], normal[2]),
                    length: length, id: id))
        case "hole":
            let axisPoint = try c.decode([Double].self, forKey: .axisPoint)
            let axisDir = try c.decode([Double].self, forKey: .axisDirection)
            let d = try c.decode(Double.self, forKey: .diameter)
            let depth = try c.decodeIfPresent(Double.self, forKey: .depth)
            self.spec = .hole(
                .init(
                    axisPoint: SIMD3(axisPoint[0], axisPoint[1], axisPoint[2]),
                    axisDirection: SIMD3(axisDir[0], axisDir[1], axisDir[2]),
                    diameter: d, depth: depth, id: id))
        case "thread":
            let holeRef = try c.decode(String.self, forKey: .holeRef)
            let threadSpec = try c.decode(String.self, forKey: .spec)
            let length = try c.decodeIfPresent(Double.self, forKey: .length)
            self.spec = .thread(.init(holeRef: holeRef, spec: threadSpec, length: length, id: id))
        case "fillet":
            let radius = try c.decode(Double.self, forKey: .radius)
            self.spec = .fillet(.init(edgeSelector: .all, radius: radius, id: id))
        case "chamfer":
            let distance = try c.decode(Double.self, forKey: .distance)
            self.spec = .chamfer(.init(edgeSelector: .all, distance: distance, id: id))
        case "boolean":
            let opStr = try c.decode(String.self, forKey: .op)
            guard let op = FeatureSpec.Boolean.Op(rawValue: opStr) else {
                self.spec = nil
                self.unknownKind = "boolean(op:\(opStr))"
                self.unknownID = id
                return
            }
            let leftID = try c.decode(String.self, forKey: .leftID)
            let rightID = try c.decode(String.self, forKey: .rightID)
            self.spec = .boolean(
                .init(
                    op: op, leftID: leftID, rightID: rightID, id: id))
        default:
            self.spec = nil
            self.unknownKind = kind
            self.unknownID = id
            return
        }
        self.unknownKind = nil
        self.unknownID = nil
    }
}
