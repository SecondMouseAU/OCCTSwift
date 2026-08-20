import Foundation
import OCCTBridge
import simd

/// 2D projection of a 3D shape using Hidden Line Removal (HLR).
///
/// Use `Drawing` to create technical drawings, 2D views, or DXF exports.
///
/// ```swift
/// let box = Shape.box(width: 100, height: 50, depth: 30)
/// let topView = Drawing.project(box, direction: SIMD3(0, 0, 1))
/// let visibleEdges = topView.edges(ofType: .visible)
/// ```
public final class Drawing: @unchecked Sendable {

    /// Projection type for creating 2D views.
    ///
    /// ```swift
    /// let ortho = Drawing.project(box, direction: SIMD3(0, 0, 1))
    /// let persp = Drawing.project(box, direction: SIMD3(0, 0, 1),
    ///                             type: .perspective(focus: 50))
    /// ```
    public enum ProjectionType: Sendable, Equatable {
        /// Orthographic projection (parallel lines).
        case orthographic
        /// Perspective projection (converging lines) from an eye point at `focus * direction`,
        /// measured from the **world origin** rather than from the shape. Must be positive, and
        /// must exceed how far the shape reaches along the view direction from that same origin,
        /// or the projection returns `nil` rather than a drawing of the geometry behind the eye.
        case perspective(focus: Double)
    }

    /// Type of edges in a 2D projection.
    public enum EdgeType: UInt32 {
        /// Visible edges (not obscured by other geometry)
        case visible = 0
        /// Hidden edges (behind other geometry)
        case hidden = 1
        /// Outline/silhouette edges
        case outline = 2
    }

    internal let handle: OCCTDrawingRef
    internal let annotationStore = DrawingAnnotationStore()

    internal init(handle: OCCTDrawingRef) {
        self.handle = handle
    }

    deinit {
        OCCTDrawingRelease(handle)
    }

    // MARK: - Dimensions and annotations (v0.137, #64)

    /// All dimensions attached to this drawing.
    public var dimensions: [DrawingDimension] { annotationStore.dimensions }

    /// All non-dimensional annotations (centrelines, centremarks, text) attached to this drawing.
    public var annotations: [DrawingAnnotation] { annotationStore.annotations }

    @discardableResult
    public func addLinearDimension(
        from: SIMD2<Double>, to: SIMD2<Double>,
        offset: Double = 10,
        label: String? = nil,
        style: DrawingLineStyle = .solid,
        id: String? = nil
    ) -> DrawingDimension {
        let d = DrawingDimension.linear(
            .init(
                from: from, to: to, offset: offset,
                label: label, style: style, id: id))
        annotationStore.appendDimension(d)
        return d
    }

    @discardableResult
    public func addRadialDimension(
        centre: SIMD2<Double>, radius: Double,
        leaderAngle: Double = .pi / 4,
        label: String? = nil,
        style: DrawingLineStyle = .solid,
        id: String? = nil
    ) -> DrawingDimension {
        let d = DrawingDimension.radial(
            .init(
                centre: centre, radius: radius,
                leaderAngle: leaderAngle,
                label: label, style: style, id: id))
        annotationStore.appendDimension(d)
        return d
    }

    @discardableResult
    public func addDiameterDimension(
        centre: SIMD2<Double>, radius: Double,
        leaderAngle: Double = .pi / 4,
        label: String? = nil,
        style: DrawingLineStyle = .solid,
        id: String? = nil
    ) -> DrawingDimension {
        let d = DrawingDimension.diameter(
            .init(
                centre: centre, radius: radius,
                leaderAngle: leaderAngle,
                label: label, style: style, id: id))
        annotationStore.appendDimension(d)
        return d
    }

    @discardableResult
    public func addAngularDimension(
        vertex: SIMD2<Double>,
        ray1: SIMD2<Double>,
        ray2: SIMD2<Double>,
        arcRadius: Double = 20,
        label: String? = nil,
        style: DrawingLineStyle = .solid,
        id: String? = nil
    ) -> DrawingDimension {
        let d = DrawingDimension.angular(
            .init(
                vertex: vertex, ray1: ray1, ray2: ray2,
                arcRadius: arcRadius,
                label: label, style: style, id: id))
        annotationStore.appendDimension(d)
        return d
    }

    /// ISO 129-1 §9.3 ordinate dimensioning: a shared origin plus N features,
    /// each shown as an X and Y offset measured from the origin.
    ///
    /// Features are supplied as tuples of `(position, optional custom label)`;
    /// when the label is nil the writer auto-formats the offset value.
    @discardableResult
    public func addOrdinateDimensions(
        origin: SIMD2<Double>,
        features: [(position: SIMD2<Double>, label: String?)],
        tolerance: DrawingTolerance = .none,
        id: String? = nil
    ) -> DrawingDimension {
        let featureStructs = features.map {
            DrawingDimension.Ordinate.Feature(
                position: $0.position,
                label: $0.label)
        }
        let d = DrawingDimension.ordinate(
            .init(
                origin: origin,
                features: featureStructs,
                tolerance: tolerance,
                id: id))
        annotationStore.appendDimension(d)
        return d
    }

    @discardableResult
    public func addCentreLine(
        from: SIMD2<Double>, to: SIMD2<Double>,
        style: DrawingLineStyle = .chain,
        id: String? = nil
    ) -> DrawingAnnotation {
        let a = DrawingAnnotation.centreline(.init(from: from, to: to, style: style, id: id))
        annotationStore.appendAnnotation(a)
        return a
    }

    @discardableResult
    public func addCentermark(
        centre: SIMD2<Double>, extent: Double = 8,
        style: DrawingLineStyle = .chain,
        id: String? = nil
    ) -> DrawingAnnotation {
        let a = DrawingAnnotation.centermark(
            .init(centre: centre, extent: extent, style: style, id: id))
        annotationStore.appendAnnotation(a)
        return a
    }

    @discardableResult
    public func addTextLabel(
        _ text: String, at position: SIMD2<Double>,
        height: Double = 3.5, rotation: Double = 0,
        id: String? = nil
    ) -> DrawingAnnotation {
        let a = DrawingAnnotation.textLabel(
            .init(
                position: position, text: text,
                height: height, rotation: rotation, id: id))
        annotationStore.appendAnnotation(a)
        return a
    }

    /// Assembly-drawing balloon callout: a numbered circle keyed to a
    /// `BillOfMaterials` row, optionally with a leader line to the part.
    @discardableResult
    public func addBalloon(
        itemNumber: Int,
        at position: SIMD2<Double>,
        leaderTo target: SIMD2<Double>? = nil,
        radius: Double = 5,
        id: String? = nil
    ) -> DrawingAnnotation {
        let a = DrawingAnnotation.balloon(
            .init(
                itemNumber: itemNumber,
                centre: position,
                radius: radius,
                leaderTo: target,
                id: id))
        annotationStore.appendAnnotation(a)
        return a
    }

    /// ISO 128-40 cutting-plane line marking where a section was cut on the
    /// parent view.
    ///
    /// Projects the cutting plane's trace into this drawing's 2D frame and adds a
    /// typed `.cuttingPlaneLine` annotation. `viewDirection` is the direction this
    /// parent drawing was projected along.
    @discardableResult
    public func addCuttingPlaneLine(
        label: String,
        cuttingPlaneOrigin: SIMD3<Double>,
        cuttingPlaneNormal: SIMD3<Double>,
        sectionViewDirection: SIMD3<Double>,
        viewDirection: SIMD3<Double>,
        traceLength: Double = 60
    ) -> DrawingAnnotation? {
        // Trace direction in 3D = cross(cuttingPlaneNormal, viewDirection). If
        // the cutting plane is parallel to the view plane, the trace is a
        // single point — return nil.
        let traceDir3D = simd_cross(
            simd_normalize(cuttingPlaneNormal),
            simd_normalize(viewDirection))
        if simd_length(traceDir3D) < 1e-9 { return nil }
        let traceDirUnit = simd_normalize(traceDir3D)
        let originInView = projectPointToPlane(cuttingPlaneOrigin, viewDirection: viewDirection)
        let traceDir2D =
            projectPointToPlane(traceDirUnit, viewDirection: viewDirection)
            - projectPointToPlane(.zero, viewDirection: viewDirection)
        let traceDir2Dn =
            simd_length(traceDir2D) > 1e-9
            ? simd_normalize(traceDir2D) : SIMD2(1, 0)
        let half = traceLength / 2
        let start = originInView - half * traceDir2Dn
        let end = originInView + half * traceDir2Dn
        // Arrow direction in the view 2D — project section view direction.
        let arrowDir3D = simd_normalize(sectionViewDirection)
        let arrowDir2D =
            projectPointToPlane(arrowDir3D, viewDirection: viewDirection)
            - projectPointToPlane(.zero, viewDirection: viewDirection)
        let arrowDir2Dn =
            simd_length(arrowDir2D) > 1e-9
            ? simd_normalize(arrowDir2D) : SIMD2(0, 1)
        let cpl = DrawingAnnotation.CuttingPlaneLine(
            label: label,
            traceStart: start,
            traceEnd: end,
            arrowDirection: arrowDir2Dn)
        let ann = DrawingAnnotation.cuttingPlaneLine(cpl)
        annotationStore.appendAnnotation(ann)
        return ann
    }

    /// ISO 128-50 section-view hatching over a closed boundary polygon.
    ///
    /// Angle defaults to 45° and spacing to 3 mm per ISO convention. `islands` are
    /// optional inner boundaries excluded from the fill.
    @discardableResult
    public func addHatch(
        boundary: [SIMD2<Double>],
        angle: Double = .pi / 4,
        spacing: Double = 3.0,
        islands: [[SIMD2<Double>]] = [],
        layer: String = "HATCH",
        id: String? = nil
    ) -> DrawingAnnotation {
        let a = DrawingAnnotation.hatch(
            .init(
                boundary: boundary, angle: angle,
                spacing: spacing, islands: islands,
                layer: layer, id: id))
        annotationStore.appendAnnotation(a)
        return a
    }

    /// Remove all dimensions and annotations from this drawing.
    public func clearAnnotations() { annotationStore.clear() }

    // MARK: - Uniform append API (v0.148, #83, #84)

    /// Append a pre-built annotation to this drawing.
    ///
    /// Usually used to install the result of a static factory like
    /// `DrawingAnnotation.surfaceFinish(...)` or
    /// `DrawingAnnotation.featureControlFrame(...)`.
    ///
    /// This dispatcher covers every `DrawingAnnotation` case (centreline,
    /// centermark, textLabel, hatch, cuttingPlaneLine). When new cases are
    /// added to the enum, the compiler will flag this method and consumers
    /// pick them up automatically — no per-case switch in consumer code.
    public func append(_ annotation: DrawingAnnotation) {
        annotationStore.appendAnnotation(annotation)
    }

    /// Append a batch of pre-built annotations, typically the output of a
    /// factory returning `[DrawingAnnotation]` (e.g. `.surfaceFinish(...)`,
    /// `.featureControlFrame(...)`, `.datumFeature(...)`, `.breakLine(...)`,
    /// `.cosmeticThreadSideView(...)`).
    public func append(contentsOf annotations: [DrawingAnnotation]) {
        for annotation in annotations {
            annotationStore.appendAnnotation(annotation)
        }
    }

    /// Append a pre-built dimension.
    ///
    /// Symmetric to `append(_:)` for annotations.
    public func append(_ dimension: DrawingDimension) {
        annotationStore.appendDimension(dimension)
    }

    /// Append a batch of pre-built dimensions.
    public func append(contentsOf dimensions: [DrawingDimension]) {
        for dimension in dimensions {
            annotationStore.appendDimension(dimension)
        }
    }

    // MARK: - Creation

    /// Create a 2D projection of a 3D shape.
    ///
    /// ```swift
    /// let box = Shape.box(width: 100, height: 50, depth: 30)
    /// let flat = Drawing.project(box, direction: SIMD3(0, 0, 1))
    /// let near = Drawing.project(box, direction: SIMD3(0, 0, 1),
    ///                            type: .perspective(focus: 50))
    /// ```
    ///
    /// - Parameters:
    ///   - shape: The 3D shape to project
    ///   - direction: View direction (the direction you're looking from)
    ///   - type: Projection type, carrying the focal distance in the perspective case
    /// - Returns: Drawing containing the projected edges, or nil if projection fails or the
    ///   perspective focal distance is not positive
    public static func project(
        _ shape: Shape,
        direction: SIMD3<Double>,
        type: ProjectionType = .orthographic
    ) -> Drawing? {
        let rawType: OCCTProjectionType
        let focus: Double
        switch type {
        case .orthographic:
            rawType = OCCTProjectionOrthographic
            focus = 0
        case .perspective(let f):
            rawType = OCCTProjectionPerspective
            focus = f
        }
        guard
            let handle = OCCTDrawingCreate(
                shape.handle,
                direction.x, direction.y, direction.z,
                rawType, focus
            )
        else {
            return nil
        }
        return Drawing(handle: handle)
    }

    // MARK: - Standard Views

    /// Create a top view (looking down Z axis).
    public static func topView(of shape: Shape) -> Drawing? {
        project(shape, direction: SIMD3(0, 0, 1))
    }

    /// Create a front view (looking down Y axis).
    public static func frontView(of shape: Shape) -> Drawing? {
        project(shape, direction: SIMD3(0, 1, 0))
    }

    /// Create a side view (looking down X axis).
    public static func sideView(of shape: Shape) -> Drawing? {
        project(shape, direction: SIMD3(1, 0, 0))
    }

    /// Create an isometric view.
    public static func isometricView(of shape: Shape) -> Drawing? {
        let dir = SIMD3<Double>(1, 1, 1) / sqrt(3.0)
        return project(shape, direction: dir)
    }

    // MARK: - Fast Polygon-Based Projection (v0.39.0)

    /// Create a fast polygon-based 2D projection of a 3D shape.
    ///
    /// Uses the triangulation mesh rather than exact geometry for significantly faster
    /// HLR computation. The result is approximate but perfectly adequate for interactive
    /// previews and most technical drawing use cases.
    ///
    /// Orthographic only. `HLRBRep_PolyAlgo` ignores a projector's perspective flag, so there is
    /// no `type:` parameter here; use ``project(_:direction:type:)`` for a perspective view.
    ///
    /// ```swift
    /// let preview = Drawing.projectFast(shape, direction: SIMD3(0, 0, 1), deflection: 0.1)
    /// ```
    ///
    /// - Parameters:
    ///   - shape: The 3D shape to project
    ///   - direction: View direction
    ///   - deflection: Mesh deflection (smaller = more accurate, default 0.01)
    /// - Returns: Drawing containing the projected edges, or nil if projection fails
    public static func projectFast(
        _ shape: Shape,
        direction: SIMD3<Double>,
        deflection: Double = 0.01
    ) -> Drawing? {
        guard
            let handle = OCCTDrawingCreatePoly(
                shape.handle,
                direction.x, direction.y, direction.z,
                deflection
            )
        else {
            return nil
        }
        return Drawing(handle: handle)
    }

    /// Create a fast top view using polygon-based HLR.
    public static func fastTopView(of shape: Shape, deflection: Double = 0.01) -> Drawing? {
        projectFast(shape, direction: SIMD3(0, 0, 1), deflection: deflection)
    }

    /// Create a fast isometric view using polygon-based HLR.
    public static func fastIsometricView(of shape: Shape, deflection: Double = 0.01) -> Drawing? {
        let dir = SIMD3<Double>(1, 1, 1) / sqrt(3.0)
        return projectFast(shape, direction: dir, deflection: deflection)
    }

    // MARK: - Edge Access

    /// Get projected edges of a specific type as a compound shape.
    ///
    /// - Parameter type: The type of edges to retrieve
    /// - Returns: Shape containing the 2D edges, or nil if no edges of that type
    public func edges(ofType type: EdgeType) -> Shape? {
        guard let shapeHandle = OCCTDrawingGetEdges(handle, OCCTEdgeType(rawValue: type.rawValue))
        else {
            return nil
        }
        return Shape(handle: shapeHandle)
    }

    /// Get visible edges as a shape.
    public var visibleEdges: Shape? {
        edges(ofType: .visible)
    }

    /// Get hidden edges as a shape.
    public var hiddenEdges: Shape? {
        edges(ofType: .hidden)
    }

    /// Get outline/silhouette edges as a shape.
    public var outlineEdges: Shape? {
        edges(ofType: .outline)
    }

}

// MARK: - Errors

/// Errors that can occur when working with 2D drawings.
public enum DrawingError: Error, LocalizedError {
    case projectionFailed

    public var errorDescription: String? {
        switch self {
        case .projectionFailed:
            return "Failed to create 2D projection"
        }
    }
}
