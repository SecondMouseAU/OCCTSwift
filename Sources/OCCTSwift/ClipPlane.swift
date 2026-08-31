import Foundation
import OCCTBridge
import simd

/// A clipping plane that can be used to cut geometry during rendering.
///
/// Wraps OCCT's `Graphic3d_ClipPlane`. The plane equation `Ax + By + Cz + D = 0`
/// defines the half-space: points with `Ax + By + Cz + D > 0` are visible.
///
/// For Metal rendering, the equation maps directly to `[[clip_distance]]` in the
/// vertex shader. Apple Silicon supports up to 8 hardware-accelerated clip distances.
///
/// `@unchecked Sendable` reflects that `handle` is a plain bridge handle, not that concurrent use
/// of one instance is safe, it isn't: `equation`/`isOn`/`isCapping`/`cappingColor`/`hatchStyle`/
/// `isHatchOn` are all read-write properties mutating the underlying `Graphic3d_ClipPlane` handle
/// in place, and `chainNext(_:)` mutates the chain link. Serialize mixed access with
/// `OCCTSerial.withLock { }`.
public final class ClipPlane: @unchecked Sendable {
    internal let handle: OCCTClipPlaneRef

    /// Result of probing a point or bounding box against the clip plane.
    public enum ClipState: Int32, Sendable {
        /// Fully outside the clipping region (should be discarded).
        case out = 0
        /// Fully inside the clipping region (not clipped).
        case `in` = 1
        /// On the boundary or partially clipped.
        case on = 2
    }

    /// Standard hatch patterns for capping surfaces.
    public enum HatchStyle: Int32, Sendable {
        case solid = 0
        case gridDiagonal = 1
        case gridDiagonalWide = 2
        case grid = 3
        case gridWide = 4
        case diagonal45 = 5
        case diagonal135 = 6
        case horizontal = 7
        case vertical = 8
        case diagonal45Wide = 9
        case diagonal135Wide = 10
        case horizontalWide = 11
        case verticalWide = 12
    }

    /// Create a clip plane from the equation `Ax + By + Cz + D = 0`.
    ///
    /// - Parameter equation: The plane equation coefficients (A, B, C, D).
    public init(equation: SIMD4<Double>) {
        handle = OCCTClipPlaneCreate(equation.x, equation.y, equation.z, equation.w)
    }

    /// Create a clip plane from a normal vector and distance from origin.
    ///
    /// The equation is `normal.x * x + normal.y * y + normal.z * z + distance = 0`.
    /// - Parameters:
    ///   - normal: The plane normal (will be used as-is, should be normalized).
    ///   - distance: Signed distance from the origin along the normal.
    public init(normal: SIMD3<Double>, distance: Double) {
        handle = OCCTClipPlaneCreate(normal.x, normal.y, normal.z, distance)
    }

    deinit {
        OCCTClipPlaneDestroy(handle)
    }

    // MARK: - Equation

    /// The plane equation coefficients (A, B, C, D) where `Ax + By + Cz + D = 0`.
    public var equation: SIMD4<Double> {
        get {
            var a = 0.0
            var b = 0.0
            var c = 0.0
            var d = 0.0
            OCCTClipPlaneGetEquation(handle, &a, &b, &c, &d)
            return SIMD4(a, b, c, d)
        }
        set {
            OCCTClipPlaneSetEquation(handle, newValue.x, newValue.y, newValue.z, newValue.w)
        }
    }

    /// The reversed equation (negated coefficients), useful for back-face clipping.
    public var reversedEquation: SIMD4<Double> {
        var a = 0.0
        var b = 0.0
        var c = 0.0
        var d = 0.0
        OCCTClipPlaneGetReversedEquation(handle, &a, &b, &c, &d)
        return SIMD4(a, b, c, d)
    }

    // MARK: - Enable/Disable

    /// Whether the clip plane is active.
    public var isOn: Bool {
        get { OCCTClipPlaneIsOn(handle) }
        set { OCCTClipPlaneSetOn(handle, newValue) }
    }

    // MARK: - Capping

    /// Whether capping (cross-section fill) is enabled.
    ///
    /// When enabled, the clipped cross-section surface is rendered. In Metal,
    /// this is implemented using the stencil buffer technique:
    /// 1. Render back faces with stencil increment
    /// 2. Render front faces with stencil decrement
    /// 3. Fill where stencil != 0 with capping material
    public var isCapping: Bool {
        get { OCCTClipPlaneIsCapping(handle) }
        set { OCCTClipPlaneSetCapping(handle, newValue) }
    }

    /// The color used for the capping surface (RGB, values in 0...1).
    public var cappingColor: SIMD3<Double> {
        get {
            var r = 0.0
            var g = 0.0
            var b = 0.0
            OCCTClipPlaneGetCappingColor(handle, &r, &g, &b)
            return SIMD3(r, g, b)
        }
        set {
            OCCTClipPlaneSetCappingColor(handle, newValue.x, newValue.y, newValue.z)
        }
    }

    /// The hatch pattern used on the capping surface.
    public var hatchStyle: HatchStyle {
        get { HatchStyle(rawValue: OCCTClipPlaneGetCappingHatch(handle)) ?? .solid }
        set { OCCTClipPlaneSetCappingHatch(handle, newValue.rawValue) }
    }

    /// Whether hatch pattern rendering is enabled on the capping surface.
    public var isHatchOn: Bool {
        get { OCCTClipPlaneIsCappingHatchOn(handle) }
        set { OCCTClipPlaneSetCappingHatchOn(handle, newValue) }
    }

    // MARK: - Probing

    /// Test a world-space point against the clip plane (or chain of planes).
    ///
    /// - Parameter point: The 3D point to test.
    /// - Returns: The clip state indicating if the point is inside, outside, or on the boundary.
    public func probe(point: SIMD3<Double>) -> ClipState {
        ClipState(rawValue: OCCTClipPlaneProbePoint(handle, point.x, point.y, point.z)) ?? .out
    }

    /// Test an axis-aligned bounding box against the clip plane (or chain of planes).
    ///
    /// - Parameter box: The bounding box defined by (min, max) corners.
    /// - Returns: The clip state indicating if the box is fully inside, fully outside, or partially clipped.
    public func probe(box: (min: SIMD3<Double>, max: SIMD3<Double>)) -> ClipState {
        ClipState(
            rawValue: OCCTClipPlaneProbeBox(
                handle,
                box.min.x, box.min.y, box.min.z,
                box.max.x, box.max.y, box.max.z)) ?? .out
    }

    // MARK: - Chaining

    /// Chain another clip plane for logical AND clipping (conjunction).
    ///
    /// When planes are chained, a point must satisfy ALL planes in the chain
    /// to be considered visible. This creates complex clipping regions.
    ///
    /// - Parameter plane: The next plane in the chain, or `nil` to clear.
    public func chainNext(_ plane: ClipPlane?) {
        OCCTClipPlaneSetChainNext(handle, plane?.handle)
    }

    /// The number of planes in the forward chain (including this one).
    public var chainLength: Int {
        Int(OCCTClipPlaneChainLength(handle))
    }
}
