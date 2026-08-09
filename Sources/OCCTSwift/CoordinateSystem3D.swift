import Foundation
import simd
import OCCTBridge

/// A 3D coordinate system (right- or left-handed), wrapping gp_Ax3.
public struct CoordinateSystem3D: Sendable {
    public let origin: SIMD3<Double>
    public let direction: SIMD3<Double>
    public let xDirection: SIMD3<Double>
    public let yDirection: SIMD3<Double>
    public let isDirect: Bool

    /// Create from origin, main direction, and X direction.
    public init(origin: SIMD3<Double>, direction: SIMD3<Double>, xDirection: SIMD3<Double>) {
        var isDirect = false
        var xDx = 0.0, xDy = 0.0, xDz = 0.0
        var yDx = 0.0, yDy = 0.0, yDz = 0.0
        OCCTAx3Create(origin.x, origin.y, origin.z,
                       direction.x, direction.y, direction.z,
                       xDirection.x, xDirection.y, xDirection.z,
                       &isDirect, &xDx, &xDy, &xDz, &yDx, &yDy, &yDz)
        self.origin = origin
        self.direction = direction
        self.xDirection = SIMD3(xDx, xDy, xDz)
        self.yDirection = SIMD3(yDx, yDy, yDz)
        self.isDirect = isDirect
    }

    /// Create from origin and main direction only (X/Y auto-computed).
    public init(origin: SIMD3<Double>, direction: SIMD3<Double>) {
        var isDirect = false
        var xDx = 0.0, xDy = 0.0, xDz = 0.0
        var yDx = 0.0, yDy = 0.0, yDz = 0.0
        OCCTAx3CreateFromNormal(origin.x, origin.y, origin.z,
                                direction.x, direction.y, direction.z,
                                &isDirect, &xDx, &xDy, &xDz, &yDx, &yDy, &yDz)
        self.origin = origin
        self.direction = direction
        self.xDirection = SIMD3(xDx, xDy, xDz)
        self.yDirection = SIMD3(yDx, yDy, yDz)
        self.isDirect = isDirect
    }

    /// Angle between this and another coordinate system.
    public func angle(to other: CoordinateSystem3D) -> Double {
        OCCTAx3Angle(origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, xDirection.x, xDirection.y, xDirection.z,
                     other.origin.x, other.origin.y, other.origin.z, other.direction.x, other.direction.y, other.direction.z,
                     other.xDirection.x, other.xDirection.y, other.xDirection.z)
    }

    /// Check if this and another coordinate system are coplanar.
    public func isCoplanar(with other: CoordinateSystem3D, linearTolerance: Double = 1e-6, angularTolerance: Double = 1e-6) -> Bool {
        OCCTAx3IsCoplanar(origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, xDirection.x, xDirection.y, xDirection.z,
                          other.origin.x, other.origin.y, other.origin.z, other.direction.x, other.direction.y, other.direction.z,
                          other.xDirection.x, other.xDirection.y, other.xDirection.z,
                          linearTolerance, angularTolerance)
    }

    /// Mirror this coordinate system about a point.
    public func mirrored(about point: SIMD3<Double>) -> CoordinateSystem3D {
        var rpx = 0.0, rpy = 0.0, rpz = 0.0
        var rnx = 0.0, rny = 0.0, rnz = 0.0
        var rxDx = 0.0, rxDy = 0.0, rxDz = 0.0
        OCCTAx3MirrorPoint(origin.x, origin.y, origin.z, direction.x, direction.y, direction.z,
                           xDirection.x, xDirection.y, xDirection.z,
                           point.x, point.y, point.z,
                           &rpx, &rpy, &rpz, &rnx, &rny, &rnz, &rxDx, &rxDy, &rxDz)
        return CoordinateSystem3D(origin: SIMD3(rpx, rpy, rpz), direction: SIMD3(rnx, rny, rnz), xDirection: SIMD3(rxDx, rxDy, rxDz))
    }

    /// Rotate about an axis.
    public func rotated(about axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, angle: Double) -> CoordinateSystem3D {
        var rpx = 0.0, rpy = 0.0, rpz = 0.0
        var rnx = 0.0, rny = 0.0, rnz = 0.0
        var rxDx = 0.0, rxDy = 0.0, rxDz = 0.0
        OCCTAx3Rotate(origin.x, origin.y, origin.z, direction.x, direction.y, direction.z,
                      xDirection.x, xDirection.y, xDirection.z,
                      axisOrigin.x, axisOrigin.y, axisOrigin.z, axisDirection.x, axisDirection.y, axisDirection.z, angle,
                      &rpx, &rpy, &rpz, &rnx, &rny, &rnz, &rxDx, &rxDy, &rxDz)
        return CoordinateSystem3D(origin: SIMD3(rpx, rpy, rpz), direction: SIMD3(rnx, rny, rnz), xDirection: SIMD3(rxDx, rxDy, rxDz))
    }

    /// Translate by a vector.
    public func translated(by vector: SIMD3<Double>) -> CoordinateSystem3D {
        var rpx = 0.0, rpy = 0.0, rpz = 0.0
        OCCTAx3Translate(origin.x, origin.y, origin.z, direction.x, direction.y, direction.z,
                         xDirection.x, xDirection.y, xDirection.z,
                         vector.x, vector.y, vector.z, &rpx, &rpy, &rpz)
        return CoordinateSystem3D(origin: SIMD3(rpx, rpy, rpz), direction: direction, xDirection: xDirection)
    }
}
