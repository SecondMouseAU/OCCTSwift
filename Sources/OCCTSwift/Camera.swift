import Foundation
import OCCTBridge
import simd

/// A 3D camera backed by OpenCASCADE Graphic3d_Camera.
///
/// Provides projection/view matrices in Metal-compatible format (column-major,.
/// zero-to-one depth range) and project/unproject utilities for coordinate conversion.
public final class Camera: @unchecked Sendable {
    internal let handle: OCCTCameraRef

    /// Camera projection mode.
    public enum ProjectionType: Int32, Sendable {
        /// Perspective projection (objects farther away appear smaller).
        case perspective = 0
        /// Orthographic projection (no perspective foreshortening).
        case orthographic = 1
    }

    /// Create a new camera with default settings.
    public init() {
        handle = OCCTCameraCreate()
    }

    deinit {
        OCCTCameraDestroy(handle)
    }

    // MARK: - Position

    /// Camera eye (observer) position in world coordinates.
    public var eye: SIMD3<Double> {
        get {
            var x = 0.0
            var y = 0.0
            var z = 0.0
            OCCTCameraGetEye(handle, &x, &y, &z)
            return SIMD3(x, y, z)
        }
        set {
            OCCTCameraSetEye(handle, newValue.x, newValue.y, newValue.z)
        }
    }

    /// Camera look-at target in world coordinates.
    public var center: SIMD3<Double> {
        get {
            var x = 0.0
            var y = 0.0
            var z = 0.0
            OCCTCameraGetCenter(handle, &x, &y, &z)
            return SIMD3(x, y, z)
        }
        set {
            OCCTCameraSetCenter(handle, newValue.x, newValue.y, newValue.z)
        }
    }

    /// Camera up direction vector.
    public var up: SIMD3<Double> {
        get {
            var x = 0.0
            var y = 0.0
            var z = 0.0
            OCCTCameraGetUp(handle, &x, &y, &z)
            return SIMD3(x, y, z)
        }
        set {
            OCCTCameraSetUp(handle, newValue.x, newValue.y, newValue.z)
        }
    }

    // MARK: - Projection Parameters

    /// Projection type (perspective or orthographic).
    public var projectionType: ProjectionType {
        get {
            ProjectionType(rawValue: Int32(OCCTCameraGetProjectionType(handle))) ?? .perspective
        }
        set {
            OCCTCameraSetProjectionType(handle, Int32(newValue.rawValue))
        }
    }

    /// Vertical field of view in degrees (perspective mode).
    public var fieldOfView: Double {
        get { OCCTCameraGetFOV(handle) }
        set { OCCTCameraSetFOV(handle, newValue) }
    }

    /// Camera scale factor (orthographic mode).
    public var scale: Double {
        get { OCCTCameraGetScale(handle) }
        set { OCCTCameraSetScale(handle, newValue) }
    }

    /// Near and far clipping plane distances.
    public var zRange: (near: Double, far: Double) {
        get {
            var zNear = 0.0
            var zFar = 0.0
            OCCTCameraGetZRange(handle, &zNear, &zFar)
            return (zNear, zFar)
        }
        set {
            OCCTCameraSetZRange(handle, newValue.near, newValue.far)
        }
    }

    /// Aspect ratio (width / height).
    public var aspect: Double {
        get { OCCTCameraGetAspect(handle) }
        set { OCCTCameraSetAspect(handle, newValue) }
    }

    // MARK: - Matrices (Metal-compatible, column-major, [0,1] depth)

    /// Projection matrix as column-major simd_float4x4 with Metal [0,1] depth range.
    public var projectionMatrix: simd_float4x4 {
        var data = [Float](repeating: 0, count: 16)
        OCCTCameraGetProjectionMatrix(handle, &data)
        return simd_float4x4(
            SIMD4(data[0], data[1], data[2], data[3]),
            SIMD4(data[4], data[5], data[6], data[7]),
            SIMD4(data[8], data[9], data[10], data[11]),
            SIMD4(data[12], data[13], data[14], data[15])
        )
    }

    /// View (camera) matrix as column-major simd_float4x4.
    public var viewMatrix: simd_float4x4 {
        var data = [Float](repeating: 0, count: 16)
        OCCTCameraGetViewMatrix(handle, &data)
        return simd_float4x4(
            SIMD4(data[0], data[1], data[2], data[3]),
            SIMD4(data[4], data[5], data[6], data[7]),
            SIMD4(data[8], data[9], data[10], data[11]),
            SIMD4(data[12], data[13], data[14], data[15])
        )
    }

    // MARK: - Coordinate Conversion

    /// Project a world-space point to normalized screen coordinates.
    public func project(_ point: SIMD3<Double>) -> SIMD3<Double> {
        var sX = 0.0
        var sY = 0.0
        var sZ = 0.0
        OCCTCameraProject(handle, point.x, point.y, point.z, &sX, &sY, &sZ)
        return SIMD3(sX, sY, sZ)
    }

    /// Unproject a screen-space point to world coordinates.
    public func unproject(_ point: SIMD3<Double>) -> SIMD3<Double> {
        var wX = 0.0
        var wY = 0.0
        var wZ = 0.0
        OCCTCameraUnproject(handle, point.x, point.y, point.z, &wX, &wY, &wZ)
        return SIMD3(wX, wY, wZ)
    }

    // MARK: - Fitting

    /// Adjust camera to fit the given axis-aligned bounding box in view.
    public func fit(boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>)) {
        OCCTCameraFitBBox(
            handle,
            boundingBox.min.x, boundingBox.min.y, boundingBox.min.z,
            boundingBox.max.x, boundingBox.max.y, boundingBox.max.z)
    }
}
