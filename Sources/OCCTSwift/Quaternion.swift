import Foundation
import OCCTBridge
import simd

/// Quaternion for 3D rotation representation.
public final class Quaternion: @unchecked Sendable {
    let handle: OCCTQuaternionRef

    init(handle: OCCTQuaternionRef) {
        self.handle = handle
    }

    deinit {
        OCCTQuaternionRelease(handle)
    }

    /// Create a quaternion from components.
    public convenience init(x: Double = 0, y: Double = 0, z: Double = 0, w: Double = 1) {
        self.init(handle: OCCTQuaternionCreate(x, y, z, w))
    }

    /// Create a quaternion from axis-angle rotation.
    public static func fromAxisAngle(axis: SIMD3<Double>, angle: Double) -> Quaternion {
        Quaternion(handle: OCCTQuaternionCreateFromAxisAngle(axis.x, axis.y, axis.z, angle))
    }

    /// Create a quaternion from two vectors (shortest arc rotation).
    public static func fromVectors(from: SIMD3<Double>, to: SIMD3<Double>) -> Quaternion {
        Quaternion(
            handle: OCCTQuaternionCreateFromVectors(from.x, from.y, from.z, to.x, to.y, to.z))
    }

    /// Get components as (x, y, z, w).
    public var components: (x: Double, y: Double, z: Double, w: Double) {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        var w = 0.0
        OCCTQuaternionGetComponents(handle, &x, &y, &z, &w)
        return (x, y, z, w)
    }

    /// Set Euler angles.
    ///
    /// `order` is passed straight through to OCCT's `gp_EulerSequence` enum, whose ordinals
    /// are NOT alphabetical and do NOT start at `Intrinsic_XYZ`. Per the pinned
    /// `gp_EulerSequence.hxx`:
    /// - `0` = `gp_EulerAngles` (alias `Intrinsic_ZXZ`, "classic" Euler angles)
    /// - `1` = `gp_YawPitchRoll` (alias `Intrinsic_ZYX`)
    /// - `2`-`7` = `Extrinsic_XYZ`, `XZY`, `YZX`, `YXZ`, `ZXY`, `ZYX`
    /// - `8`-`13` = `Intrinsic_XYZ`, `XZY`, `YZX`, `YXZ`, `ZXY`, `ZYX`
    /// - `14`-`19` = `Extrinsic_XYX`, `XZX`, `YZY`, `YXY`, `ZYZ`, `ZXZ`
    /// - `20`-`25` = `Intrinsic_XYX`, `XZX`, `YZY`, `YXY`, `ZXZ`, `ZYZ`
    ///
    /// So `order: 8`, not `order: 0`, is `Intrinsic_XYZ`. See the pinned header for the full,
    /// authoritative list.
    public func setEulerAngles(order: Int32, alpha: Double, beta: Double, gamma: Double) {
        OCCTQuaternionSetEulerAngles(handle, order, alpha, beta, gamma)
    }

    /// Get Euler angles.
    ///
    /// `order` uses the same `gp_EulerSequence` ordinal table as
    /// `setEulerAngles(order:alpha:beta:gamma:)`; see that method's doc for the full list.
    public func getEulerAngles(order: Int32) -> (alpha: Double, beta: Double, gamma: Double) {
        var a = 0.0
        var b = 0.0
        var g = 0.0
        OCCTQuaternionGetEulerAngles(handle, order, &a, &b, &g)
        return (a, b, g)
    }

    /// Get rotation matrix as 9 doubles (row-major).
    public var matrix: [Double] {
        var m = [Double](repeating: 0, count: 9)
        m.withUnsafeMutableBufferPointer { buf in
            OCCTQuaternionGetMatrix(handle, buf.baseAddress!)
        }
        return m
    }

    /// Rotate a vector by this quaternion.
    public func rotate(_ vector: SIMD3<Double>) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTQuaternionMultiplyVec(handle, vector.x, vector.y, vector.z, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Multiply with another quaternion (Hamilton product).
    public func multiplied(by other: Quaternion) -> Quaternion {
        Quaternion(handle: OCCTQuaternionMultiply(handle, other.handle))
    }

    /// Get axis-angle representation.
    public var axisAngle: (axis: SIMD3<Double>, angle: Double) {
        var ax = 0.0
        var ay = 0.0
        var az = 0.0
        var angle = 0.0
        OCCTQuaternionGetVectorAndAngle(handle, &ax, &ay, &az, &angle)
        return (SIMD3(ax, ay, az), angle)
    }

    /// Get the rotation angle.
    public var rotationAngle: Double {
        OCCTQuaternionGetRotationAngle(handle)
    }

    /// Normalize to unit length.
    public func normalize() {
        OCCTQuaternionNormalize(handle)
    }
}
