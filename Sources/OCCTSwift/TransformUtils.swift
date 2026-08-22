import Foundation
import OCCTBridge
import simd

/// Coordinate system transformation utilities.
public enum TransformUtils {
    /// 3x4 matrix result (row-major).
    public struct Matrix3x4: Sendable {
        public let values: [Double]  // 12 elements: [a11,a12,a13,a14, a21,a22,a23,a24, a31,a32,a33,a34]
    }

    /// Compute displacement transform from one coordinate system to another.
    public static func displacement(
        from: (point: SIMD3<Double>, direction: SIMD3<Double>),
        to: (point: SIMD3<Double>, direction: SIMD3<Double>)
    ) -> Matrix3x4 {
        var a11 = 0.0
        var a12 = 0.0
        var a13 = 0.0
        var a14 = 0.0
        var a21 = 0.0
        var a22 = 0.0
        var a23 = 0.0
        var a24 = 0.0
        var a31 = 0.0
        var a32 = 0.0
        var a33 = 0.0
        var a34 = 0.0
        OCCTTrsfDisplacement(
            from.point.x, from.point.y, from.point.z,
            from.direction.x, from.direction.y, from.direction.z,
            to.point.x, to.point.y, to.point.z,
            to.direction.x, to.direction.y, to.direction.z,
            &a11, &a12, &a13, &a14, &a21, &a22, &a23, &a24, &a31, &a32, &a33, &a34)
        return Matrix3x4(values: [a11, a12, a13, a14, a21, a22, a23, a24, a31, a32, a33, a34])
    }

    /// Compute coordinate transformation between two systems.
    public static func transformation(
        from: (point: SIMD3<Double>, direction: SIMD3<Double>),
        to: (point: SIMD3<Double>, direction: SIMD3<Double>)
    ) -> Matrix3x4 {
        var a11 = 0.0
        var a12 = 0.0
        var a13 = 0.0
        var a14 = 0.0
        var a21 = 0.0
        var a22 = 0.0
        var a23 = 0.0
        var a24 = 0.0
        var a31 = 0.0
        var a32 = 0.0
        var a33 = 0.0
        var a34 = 0.0
        OCCTTrsfTransformation(
            from.point.x, from.point.y, from.point.z,
            from.direction.x, from.direction.y, from.direction.z,
            to.point.x, to.point.y, to.point.z,
            to.direction.x, to.direction.y, to.direction.z,
            &a11, &a12, &a13, &a14, &a21, &a22, &a23, &a24, &a31, &a32, &a33, &a34)
        return Matrix3x4(values: [a11, a12, a13, a14, a21, a22, a23, a24, a31, a32, a33, a34])
    }
}
