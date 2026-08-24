import Foundation
import OCCTBridge
import simd

/// Configuration for a rendering Z-layer that controls depth testing, polygon offset,
/// and other render-pass properties.
///
/// Wraps OCCT's `Graphic3d_ZLayerSettings`. In a Metal renderer, these settings map to:
/// - `MTLDepthStencilDescriptor` (depth test/write)
/// - Depth attachment `loadAction` (clear depth)
/// - `setDepthBias()` on `MTLRenderCommandEncoder` (polygon offset)
/// - Render pass ordering (layer priority)
public final class ZLayerSettings: @unchecked Sendable {
    internal let handle: OCCTZLayerSettingsRef

    // MARK: - Predefined Layer IDs

    /// 2D underlay layer (drawn behind everything).
    public static let bottomOSD: Int32 = -5
    /// Main 3D scene layer (default).
    public static let `default`: Int32 = 0
    /// 3D overlay layer (inherits depth from default layer).
    public static let top: Int32 = -2
    /// 3D overlay layer (independent depth buffer).
    public static let topmost: Int32 = -3
    /// 2D overlay layer for annotations and UI.
    public static let topOSD: Int32 = -4

    /// Polygon offset mode controlling which primitives receive the offset.
    public enum PolygonOffsetMode: Int32, Sendable {
        case off = 0
        /// Apply offset to filled polygons (shaded faces).
        case fill = 1
        /// Apply offset to line primitives.
        case line = 2
        /// Apply offset to point primitives.
        case point = 4
        /// Apply offset to all primitive types.
        case all = 7
    }

    /// Polygon offset parameters for depth bias.
    ///
    /// Maps to Metal's `setDepthBias(depthBias:slopeScale:clamp:)` on the render encoder.
    /// - `factor` corresponds to `slopeScale`
    /// - `units` corresponds to `depthBias`
    public struct PolygonOffset: Sendable {
        public var mode: PolygonOffsetMode
        public var factor: Float
        public var units: Float

        public init(mode: PolygonOffsetMode = .off, factor: Float = 0, units: Float = 0) {
            self.mode = mode
            self.factor = factor
            self.units = units
        }
    }

    public init() {
        handle = OCCTZLayerSettingsCreate()
    }

    deinit {
        OCCTZLayerSettingsDestroy(handle)
    }

    // MARK: - Depth

    /// Whether depth testing is enabled for this layer.
    public var depthTestEnabled: Bool {
        get { OCCTZLayerSettingsGetDepthTest(handle) }
        set { OCCTZLayerSettingsSetDepthTest(handle, newValue) }
    }

    /// Whether depth writing is enabled for this layer.
    public var depthWriteEnabled: Bool {
        get { OCCTZLayerSettingsGetDepthWrite(handle) }
        set { OCCTZLayerSettingsSetDepthWrite(handle, newValue) }
    }

    /// Whether to clear the depth buffer before rendering this layer.
    ///
    /// In Metal, this maps to `loadAction = .clear` on the depth attachment
    /// for the layer's render pass.
    public var clearDepth: Bool {
        get { OCCTZLayerSettingsGetClearDepth(handle) }
        set { OCCTZLayerSettingsSetClearDepth(handle, newValue) }
    }

    // MARK: - Polygon Offset

    /// Polygon offset (depth bias) parameters for this layer.
    public var polygonOffset: PolygonOffset {
        get {
            var mode: Int32 = 0
            var factor: Float = 0
            var units: Float = 0
            OCCTZLayerSettingsGetPolygonOffset(handle, &mode, &factor, &units)
            return PolygonOffset(
                mode: PolygonOffsetMode(rawValue: mode) ?? .off,
                factor: factor, units: units)
        }
        set {
            OCCTZLayerSettingsSetPolygonOffset(
                handle, newValue.mode.rawValue,
                newValue.factor, newValue.units)
        }
    }

    /// Set a minimal positive depth offset (factor=1, units=1).
    ///
    /// Useful for pushing coplanar geometry slightly away from the camera.
    public func setDepthOffsetPositive() {
        OCCTZLayerSettingsSetDepthOffsetPositive(handle)
    }

    /// Set a minimal negative depth offset (factor=1, units=-1).
    ///
    /// Useful for pulling coplanar geometry slightly toward the camera
    /// (e.g., wireframe overlay on shaded geometry).
    public func setDepthOffsetNegative() {
        OCCTZLayerSettingsSetDepthOffsetNegative(handle)
    }

    // MARK: - Rendering Options

    /// Whether this layer is drawn after all normal layers (immediate mode).
    public var isImmediate: Bool {
        get { OCCTZLayerSettingsGetImmediate(handle) }
        set { OCCTZLayerSettingsSetImmediate(handle, newValue) }
    }

    /// Whether objects in this layer participate in ray tracing.
    public var isRaytracable: Bool {
        get { OCCTZLayerSettingsGetRaytracable(handle) }
        set { OCCTZLayerSettingsSetRaytracable(handle, newValue) }
    }

    /// Whether environment texture is applied to objects in this layer.
    public var useEnvironmentTexture: Bool {
        get { OCCTZLayerSettingsGetEnvironmentTexture(handle) }
        set { OCCTZLayerSettingsSetEnvironmentTexture(handle, newValue) }
    }

    /// Whether objects in this layer are rendered in the depth pre-pass.
    public var renderInDepthPrepass: Bool {
        get { OCCTZLayerSettingsGetRenderInDepthPrepass(handle) }
        set { OCCTZLayerSettingsSetRenderInDepthPrepass(handle, newValue) }
    }

    // MARK: - Culling

    /// Distance-based culling threshold.
    ///
    /// Objects farther than this distance from the camera origin are culled.
    /// A very large value (default) disables distance culling.
    public var cullingDistance: Double {
        get { OCCTZLayerSettingsGetCullingDistance(handle) }
        set { OCCTZLayerSettingsSetCullingDistance(handle, newValue) }
    }

    /// Size-based culling threshold.
    ///
    /// Objects smaller than this screen-space size are culled.
    /// A very large value (default) disables size culling.
    public var cullingSize: Double {
        get { OCCTZLayerSettingsGetCullingSize(handle) }
        set { OCCTZLayerSettingsSetCullingSize(handle, newValue) }
    }

    // MARK: - Origin

    /// Layer origin for coordinate precision in large scenes.
    ///
    /// When working with very large coordinates (e.g., geospatial), setting
    /// a layer origin near the camera avoids floating-point precision issues
    /// in the model-view matrix.
    public var origin: SIMD3<Double> {
        get {
            var x = 0.0
            var y = 0.0
            var z = 0.0
            OCCTZLayerSettingsGetOrigin(handle, &x, &y, &z)
            return SIMD3(x, y, z)
        }
        set {
            OCCTZLayerSettingsSetOrigin(handle, newValue.x, newValue.y, newValue.z)
        }
    }
}
