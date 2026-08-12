import Foundation
import OCCTBridge
import simd

// MARK: - XCAF CONSTRUCTION layer persistence (#72 D1, v0.143)
//
// OCCT has no typed "construction geometry" attribute, but the XCAF Layer system
// provides a standard way to tag shapes as belonging to a named layer — and
// both STEP and IGES round-trip layer assignments.
//
// Strategy here matches FreeCAD's best-effort approach:
// 1. Recipes (ConstructionPlane, ConstructionAxis, ConstructionPoint) remain
//    in-memory — their structure is not preserved through STEP.
// 2. On `materialize(in:graph:)`, each recipe is resolved against a graph and
//    a representative `TopoDS_Shape` is created: a finite-but-large face for a
//    plane, an edge segment for an axis, a vertex for a point.
// 3. These shapes are added to the document and tagged with the `CONSTRUCTION`
//    XCAF layer. STEP export preserves the layer tag; reimport produces shapes
//    tagged with `CONSTRUCTION` but no typed recipe metadata.
//
// This is the ceiling of what's possible without extending OCCT. It matches
// FreeCAD's 20-year workaround and the industry-standard STEP AP214 layer
// convention. Callers that need typed recipe round-trip should serialise the
// ConstructionContext structure separately (e.g. via Codable to JSON) alongside
// the STEP file.

extension Document {
    public static let constructionLayerName = "CONSTRUCTION"

    /// Add a shape to the document tagged with the CONSTRUCTION XCAF layer.
    ///
    /// On STEP/IGES export the layer tag is preserved; on import, the shape shows up as a
    /// regular topology entry with its layer name recoverable via `AssemblyNode.layers`.
    @discardableResult
    public func addConstructionShape(_ shape: Shape) -> Int64 {
        let labelId = addShape(shape, makeAssembly: false)
        guard labelId >= 0 else { return labelId }
        // AssemblyNode is the wrapper that exposes `setLayer(_:)`.
        let node = AssemblyNode(document: self, labelId: labelId)
        node.setLayer(Document.constructionLayerName)
        return labelId
    }

    /// The label IDs of shapes in this document currently tagged with the CONSTRUCTION layer.
    ///
    /// Used to identify construction-marked geometry after a STEP/IGES load.
    public var constructionShapeLabels: [Int64] {
        rootNodes
            .filter { $0.isLayerSet(Document.constructionLayerName) }
            .map { $0.labelId }
    }
}

extension ConstructionContext {
    /// Options for the size of materialised construction shapes.
    ///
    /// These are finite stand-ins for the underlying infinite / unbounded geometry, so we need a
    /// size. Defaults are sensible for models in the millimetre range.
    public struct MaterializeOptions: Sendable {
        public var planeHalfSize: Double = 100
        public var axisHalfLength: Double = 100
        public init(planeHalfSize: Double = 100, axisHalfLength: Double = 100) {
            self.planeHalfSize = planeHalfSize
            self.axisHalfLength = axisHalfLength
        }
    }

    /// Materialise all construction entities as `TopoDS_Shape`s on the document's
    /// CONSTRUCTION layer. Each resolved placement becomes a finite representative
    /// shape:
    /// - Planes → a rectangular face (2 × `planeHalfSize`) centred on the plane origin
    /// - Axes   → an edge of length 2 × `axisHalfLength` centred on the axis origin
    /// - Points → a vertex
    ///
    /// Returns a breakdown of what got materialised and what failed to resolve.
    @discardableResult
    public func materialize(
        in document: Document,
        graph: BRepGraph,
        options: MaterializeOptions = MaterializeOptions()
    ) -> MaterializationResult {
        var planeShapes: [(id: PlaneID, labelId: Int64)] = []
        var axisShapes: [(id: AxisID, labelId: Int64)] = []
        var pointShapes: [(id: PointID, labelId: Int64)] = []
        var failures: [MaterializationFailure] = []

        for entry in allPlanes {
            switch materializeOne(
                id: entry.id, resolution: graph.resolve(entry.plane), in: document,
                buildShape: { planeShape(placement: $0, halfSize: options.planeHalfSize) },
                resolveFailure: MaterializationFailure.planeResolveFailed,
                shapeFailure: MaterializationFailure.planeShapeFailed)
            {
            case .success(let materialized): planeShapes.append(materialized)
            case .failure(let failure): failures.append(failure)
            }
        }

        for entry in allAxes {
            switch materializeOne(
                id: entry.id, resolution: graph.resolve(entry.axis), in: document,
                buildShape: {
                    axisShape(
                        origin: $0.origin, direction: $0.direction,
                        halfLength: options.axisHalfLength)
                },
                resolveFailure: MaterializationFailure.axisResolveFailed,
                shapeFailure: MaterializationFailure.axisShapeFailed)
            {
            case .success(let materialized): axisShapes.append(materialized)
            case .failure(let failure): failures.append(failure)
            }
        }

        for entry in allPoints {
            switch materializeOne(
                id: entry.id, resolution: graph.resolve(entry.point), in: document,
                buildShape: { pointShape(at: $0) },
                resolveFailure: MaterializationFailure.pointResolveFailed,
                shapeFailure: MaterializationFailure.pointShapeFailed)
            {
            case .success(let materialized): pointShapes.append(materialized)
            case .failure(let failure): failures.append(failure)
            }
        }

        return MaterializationResult(
            planeShapes: planeShapes,
            axisShapes: axisShapes,
            pointShapes: pointShapes,
            failures: failures)
    }

    /// Shared shape for the three per-kind loops in `materialize(in:graph:options:)`, above
    /// (#886): resolve-failure and shape-build-failure are reported the same way for every
    /// entity kind, and only the resolution, the shape builder, and the two failure-case
    /// constructors differ.
    private func materializeOne<ID, Resolved>(
        id: ID,
        resolution: Result<Resolved, ConstructionResolutionError>,
        in document: Document,
        buildShape: (Resolved) -> Shape?,
        resolveFailure: (ID, ConstructionResolutionError) -> MaterializationFailure,
        shapeFailure: (ID) -> MaterializationFailure
    ) -> MaterializeOutcome<ID> {
        switch resolution {
        case .success(let resolved):
            guard let shape = buildShape(resolved) else { return .failure(shapeFailure(id)) }
            let labelId = document.addConstructionShape(shape)
            return .success((id: id, labelId: labelId))
        case .failure(let error):
            return .failure(resolveFailure(id, error))
        }
    }

    /// Outcome of `materializeOne(...)`.
    ///
    /// Either the new construction-layer shape's ID/label pair, or the `MaterializationFailure`
    /// that explains why there isn't one. Not `Result<_, _>` — `MaterializationFailure` is a
    /// plain `Sendable` value, not an `Error`, by design (see its own declaration).
    private enum MaterializeOutcome<ID> {
        case success((id: ID, labelId: Int64))
        case failure(MaterializationFailure)
    }

    public struct MaterializationResult: Sendable {
        public let planeShapes: [(id: PlaneID, labelId: Int64)]
        public let axisShapes: [(id: AxisID, labelId: Int64)]
        public let pointShapes: [(id: PointID, labelId: Int64)]
        public let failures: [MaterializationFailure]

        public var totalMaterialized: Int {
            planeShapes.count + axisShapes.count + pointShapes.count
        }
    }

    public enum MaterializationFailure: Sendable {
        case planeResolveFailed(PlaneID, ConstructionResolutionError)
        case axisResolveFailed(AxisID, ConstructionResolutionError)
        case pointResolveFailed(PointID, ConstructionResolutionError)
        case planeShapeFailed(PlaneID)
        case axisShapeFailed(AxisID)
        case pointShapeFailed(PointID)
    }

    // MARK: - Representative-shape builders
    //
    // #880: `axisShape` has a bare-wire fallback and `planeShape` doesn't — deliberate, not an
    // oversight. `Placement`'s only public constructors derive an orthonormal x/y basis from a
    // single normal, so every reachable non-degenerate plane already produces a closed, planar,
    // non-self-intersecting quad, and `Shape.face(from:)` builds it: measured across a halfSize
    // sweep from 1e300 down to Precision::Confusion() (~1e-7), `BRepBuilderAPI_MakeFace` never
    // once failed on a wire `BRepBuilderAPI_MakePolygon` reported done. The one input that DOES
    // reach "wire built, face failed" is a placement corrupted by a zero-length normal (`.absolute`
    // called with `normal: .zero`): `simd_normalize` turns that into NaN, and `MakePolygon` builds
    // a "done" wire from NaN points anyway. Measured directly: adding `?? Shape.shape(from: wire)`
    // there does make that case "succeed" — by silently adding a NaN-vertexed shape to the document
    // instead of reporting `.planeShapeFailed`. That's a worse outcome than the failure it would
    // replace, so the fallback stays off. `axisShape`'s fallback doesn't have this problem: its
    // wire always comes from `Wire.line`, which already rejects a degenerate (incl. NaN-length)
    // direction before returning one — see below.

    private func planeShape(placement: Placement, halfSize: Double) -> Shape? {
        let o = placement.origin
        let x = placement.xAxis * halfSize
        let y = placement.yAxis * halfSize
        let p0 = o - x - y
        let p1 = o + x - y
        let p2 = o + x + y
        let p3 = o - x + y
        guard let wire = Wire.polygon3D([p0, p1, p2, p3], closed: true) else { return nil }
        return Shape.face(from: wire)
    }

    // An axis's wire is a single open edge (`Wire.line`), so `Shape.face(from:)` can never close
    // it into a face — unlike `planeShape` above, the bare-wire fallback here is the *only* shape
    // an axis ever materializes as, not a rare degenerate-input path. `Wire.line` itself already
    // guards against a degenerate (zero-length or NaN) direction, returning `nil` before this
    // function would otherwise see it, so the fallback only ever wraps a genuinely valid line.
    private func axisShape(origin: SIMD3<Double>, direction: SIMD3<Double>, halfLength: Double)
        -> Shape?
    {
        let d = simd_normalize(direction)
        let start = origin - d * halfLength
        let end = origin + d * halfLength
        guard let wire = Wire.line(from: start, to: end) else { return nil }
        return Shape.shape(from: wire)
    }

    private func pointShape(at p: SIMD3<Double>) -> Shape? {
        Shape.vertex(at: p)
    }
}

// Helpers: small shims over existing Wire → Shape bridges.
extension Shape {
    /// Create a shape wrapping a wire (useful when you need a shape rather than
    /// a face for a degenerate / open wire).
    internal static func shape(from wire: Wire) -> Shape? {
        guard let h = OCCTShapeFromWire(wire.handle) else { return nil }
        return Shape(handle: h)
    }
}
