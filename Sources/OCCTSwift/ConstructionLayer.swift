import Foundation
import simd
import OCCTBridge

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
    /// On STEP/IGES export the layer tag is preserved; on import, the shape
    /// shows up as a regular topology entry with its layer name recoverable via
    /// `AssemblyNode.layers`.
    @discardableResult
    public func addConstructionShape(_ shape: Shape) -> Int64 {
        let labelId = addShape(shape, makeAssembly: false)
        guard labelId >= 0 else { return labelId }
        // AssemblyNode is the wrapper that exposes `setLayer(_:)`.
        let node = AssemblyNode(document: self, labelId: labelId)
        node.setLayer(Document.constructionLayerName)
        return labelId
    }

    /// The label IDs of shapes in this document currently tagged with the
    /// CONSTRUCTION layer. Used to identify construction-marked geometry after
    /// a STEP/IGES load.
    public var constructionShapeLabels: [Int64] {
        rootNodes
            .filter { $0.isLayerSet(Document.constructionLayerName) }
            .map { $0.labelId }
    }
}

extension ConstructionContext {
    /// Options for the size of materialised construction shapes — these are
    /// finite stand-ins for the underlying infinite / unbounded geometry, so we
    /// need a size. Defaults are sensible for models in the millimetre range.
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
    public func materialize(in document: Document,
                            graph: BRepGraph,
                            options: MaterializeOptions = MaterializeOptions()) -> MaterializationResult {
        var planeShapes: [(id: PlaneID, labelId: Int64)] = []
        var axisShapes: [(id: AxisID, labelId: Int64)] = []
        var pointShapes: [(id: PointID, labelId: Int64)] = []
        var failures: [MaterializationFailure] = []

        for entry in allPlanes {
            switch graph.resolve(entry.plane) {
            case .success(let placement):
                if let shape = planeShape(placement: placement, halfSize: options.planeHalfSize) {
                    let labelId = document.addConstructionShape(shape)
                    planeShapes.append((id: entry.id, labelId: labelId))
                } else {
                    failures.append(.planeShapeFailed(entry.id))
                }
            case .failure(let err):
                failures.append(.planeResolveFailed(entry.id, err))
            }
        }

        for entry in allAxes {
            switch graph.resolve(entry.axis) {
            case .success(let ax):
                if let shape = axisShape(origin: ax.origin,
                                          direction: ax.direction,
                                          halfLength: options.axisHalfLength) {
                    let labelId = document.addConstructionShape(shape)
                    axisShapes.append((id: entry.id, labelId: labelId))
                } else {
                    failures.append(.axisShapeFailed(entry.id))
                }
            case .failure(let err):
                failures.append(.axisResolveFailed(entry.id, err))
            }
        }

        for entry in allPoints {
            switch graph.resolve(entry.point) {
            case .success(let point):
                if let shape = pointShape(at: point) {
                    let labelId = document.addConstructionShape(shape)
                    pointShapes.append((id: entry.id, labelId: labelId))
                } else {
                    failures.append(.pointShapeFailed(entry.id))
                }
            case .failure(let err):
                failures.append(.pointResolveFailed(entry.id, err))
            }
        }

        return MaterializationResult(planeShapes: planeShapes,
                                      axisShapes: axisShapes,
                                      pointShapes: pointShapes,
                                      failures: failures)
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

    private func axisShape(origin: SIMD3<Double>, direction: SIMD3<Double>, halfLength: Double) -> Shape? {
        let d = simd_normalize(direction)
        let start = origin - d * halfLength
        let end = origin + d * halfLength
        guard let wire = Wire.line(from: start, to: end) else { return nil }
        return Shape.face(from: wire) ?? Shape.shape(from: wire)
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
