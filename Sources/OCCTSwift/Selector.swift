import Foundation
import simd
import OCCTBridge

/// BVH-accelerated hit testing for interactive picking without OpenGL.
///
/// Manages a set of shapes identified by integer IDs and performs
/// point or rectangle picking against them using a camera's projection.
/// Supports sub-shape selection modes for picking individual faces,
/// edges, or vertices within a shape.
public final class Selector: @unchecked Sendable {
    internal let handle: OCCTSelectorRef

    /// Selection modes controlling what level of sub-shape is selectable.
    ///
    /// Maps to OCCT's `TopAbs_ShapeEnum` decomposition in `StdSelect_BRepSelectionTool`.
    public enum SelectionMode: Int32, Sendable {
        /// Select the entire shape as one entity.
        case shape = 0
        /// Select individual vertices.
        case vertex = 1
        /// Select individual edges.
        case edge = 2
        /// Select wires (connected edge loops).
        case wire = 3
        /// Select individual faces.
        case face = 4
    }

    /// The type of sub-shape that was picked.
    ///
    /// Maps to OCCT's `TopAbs_ShapeEnum` values.
    public enum SubShapeType: Int32, Sendable {
        case compound = 0
        case compsolid = 1
        case solid = 2
        case shell = 3
        case face = 4
        case wire = 5
        case edge = 6
        case vertex = 7
        case shape = 8
    }

    /// Result of a pick operation.
    public struct PickResult: Sendable {
        /// The shape ID that was assigned when adding the shape.
        public let shapeId: Int32

        /// Depth of the hit (distance from camera).
        public let depth: Double

        /// 3D world-space point where the pick intersected.
        public let point: SIMD3<Double>

        /// The type of sub-shape that was hit.
        public let subShapeType: SubShapeType

        /// 0-based index of the sub-shape within its parent shape, addressable with
        /// ``Shape/face(at:)`` or ``Shape/subShape(type:index:)``.
        ///
        /// `-1` when the whole shape was selected (mode 0). It used to be 1-based with `0` as
        /// that sentinel, so a picked sub-shape's index named the one before it and the sentinel
        /// was indistinguishable from a hit on sub-shape 0 (#541).
        public let subShapeIndex: Int32
    }

    public init() {
        handle = OCCTSelectorCreate()
    }

    deinit {
        OCCTSelectorDestroy(handle)
    }

    // MARK: - Shape Management

    /// Add a shape to the selector with a unique integer ID.
    ///
    /// The shape is registered with mode 0 (whole shape) active by default.
    /// Use ``activateMode(_:for:)`` to enable sub-shape selection.
    ///
    /// If a shape with the same ID already exists, it is replaced.
    /// - Returns: `true` if the shape was added successfully.
    @discardableResult
    public func add(shape: Shape, id: Int32) -> Bool {
        OCCTSelectorAddShape(handle, shape.handle, id)
    }

    /// Remove a shape by its ID.
    /// - Returns: `true` if the shape was found and removed.
    @discardableResult
    public func remove(id: Int32) -> Bool {
        OCCTSelectorRemoveShape(handle, id)
    }

    /// Remove all shapes from the selector.
    public func clearAll() {
        OCCTSelectorClear(handle)
    }

    // MARK: - Selection Modes

    /// Activate a selection mode for a shape.
    ///
    /// Multiple modes can be active simultaneously. For example, activating
    /// both `.face` and `.edge` allows picking either faces or edges.
    ///
    /// - Parameters:
    ///   - mode: The selection mode to activate.
    ///   - shapeId: The ID of the shape to configure.
    public func activateMode(_ mode: SelectionMode, for shapeId: Int32) {
        OCCTSelectorActivateMode(handle, shapeId, mode.rawValue)
    }

    /// Deactivate a selection mode for a shape.
    ///
    /// - Parameters:
    ///   - mode: The selection mode to deactivate.
    ///   - shapeId: The ID of the shape to configure.
    public func deactivateMode(_ mode: SelectionMode, for shapeId: Int32) {
        OCCTSelectorDeactivateMode(handle, shapeId, mode.rawValue)
    }

    /// Check if a selection mode is active for a shape.
    public func isModeActive(_ mode: SelectionMode, for shapeId: Int32) -> Bool {
        OCCTSelectorIsModeActive(handle, shapeId, mode.rawValue)
    }

    // MARK: - Pixel Tolerance

    /// Pixel tolerance for picking near edges and vertices.
    ///
    /// Higher values make it easier to pick thin geometry like edges.
    /// Default is 2 pixels.
    public var pixelTolerance: Int32 {
        get { OCCTSelectorGetPixelTolerance(handle) }
        set { OCCTSelectorSetPixelTolerance(handle, newValue) }
    }

    // MARK: - Picking

    /// Pick shapes at a single pixel coordinate.
    ///
    /// - Parameters:
    ///   - pixel: Pixel coordinates in the viewport.
    ///   - camera: The camera providing projection/view transforms.
    ///   - viewSize: Viewport size in pixels (width, height).
    ///   - maxResults: Output *capacity* (default 32), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of pick results sorted by depth (nearest first).
    public func pick(at pixel: SIMD2<Double>,
                     camera: Camera,
                     viewSize: SIMD2<Double>,
                     maxResults: Int = 32) -> [PickResult] {
        let maxResults = Sampling.capacity(maxResults)
        guard maxResults > 0 else { return [] }
        var buffer = [OCCTPickResult](repeating: OCCTPickResult(), count: maxResults)
        let count = OCCTSelectorPick(handle, camera.handle,
                                     viewSize.x, viewSize.y,
                                     pixel.x, pixel.y,
                                     &buffer, Int32(maxResults))
        return (0..<Int(count)).map { i in
            PickResult(shapeId: buffer[i].shapeId,
                       depth: buffer[i].depth,
                       point: SIMD3(buffer[i].pointX, buffer[i].pointY, buffer[i].pointZ),
                       subShapeType: SubShapeType(rawValue: buffer[i].subShapeType) ?? .shape,
                       subShapeIndex: buffer[i].subShapeIndex)
        }
    }

    /// Pick shapes within a rectangular region.
    ///
    /// - Parameters:
    ///   - rect: Rectangle defined by (min, max) pixel coordinates.
    ///   - camera: The camera providing projection/view transforms.
    ///   - viewSize: Viewport size in pixels (width, height).
    ///   - maxResults: Output *capacity* (default 32), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of pick results for all shapes intersecting the rectangle.
    public func pick(rect: (min: SIMD2<Double>, max: SIMD2<Double>),
                     camera: Camera,
                     viewSize: SIMD2<Double>,
                     maxResults: Int = 32) -> [PickResult] {
        let maxResults = Sampling.capacity(maxResults)
        guard maxResults > 0 else { return [] }
        var buffer = [OCCTPickResult](repeating: OCCTPickResult(), count: maxResults)
        let count = OCCTSelectorPickRect(handle, camera.handle,
                                         viewSize.x, viewSize.y,
                                         rect.min.x, rect.min.y,
                                         rect.max.x, rect.max.y,
                                         &buffer, Int32(maxResults))
        return (0..<Int(count)).map { i in
            PickResult(shapeId: buffer[i].shapeId,
                       depth: buffer[i].depth,
                       point: SIMD3(buffer[i].pointX, buffer[i].pointY, buffer[i].pointZ),
                       subShapeType: SubShapeType(rawValue: buffer[i].subShapeType) ?? .shape,
                       subShapeIndex: buffer[i].subShapeIndex)
        }
    }

    /// Pick shapes within a closed polygon (lasso selection).
    ///
    /// The polygon must have at least 3 points. The polygon is automatically
    /// closed (last point connects to first).
    ///
    /// - Parameters:
    ///   - polygon: Array of pixel coordinates defining the polygon vertices.
    ///   - camera: The camera providing projection/view transforms.
    ///   - viewSize: Viewport size in pixels (width, height).
    ///   - maxResults: Output *capacity* (default 32), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of pick results for all shapes inside the polygon.
    public func pick(polygon: [SIMD2<Double>],
                     camera: Camera,
                     viewSize: SIMD2<Double>,
                     maxResults: Int = 32) -> [PickResult] {
        let maxResults = Sampling.capacity(maxResults)
        guard polygon.count >= 3, maxResults > 0 else { return [] }
        var buffer = [OCCTPickResult](repeating: OCCTPickResult(), count: maxResults)
        var polyXY = [Double]()
        polyXY.reserveCapacity(polygon.count * 2)
        for pt in polygon {
            polyXY.append(pt.x)
            polyXY.append(pt.y)
        }
        let count = OCCTSelectorPickPoly(handle, camera.handle,
                                         viewSize.x, viewSize.y,
                                         polyXY, Int32(polygon.count),
                                         &buffer, Int32(maxResults))
        return (0..<Int(count)).map { i in
            PickResult(shapeId: buffer[i].shapeId,
                       depth: buffer[i].depth,
                       point: SIMD3(buffer[i].pointX, buffer[i].pointY, buffer[i].pointZ),
                       subShapeType: SubShapeType(rawValue: buffer[i].subShapeType) ?? .shape,
                       subShapeIndex: buffer[i].subShapeIndex)
        }
    }
}
