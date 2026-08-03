import Foundation
import simd
import OCCTBridge

/// 3D transformation matrix (row-major 3x4) from gce factories.
public struct TransformMatrix3D: Sendable {
    public let values: [Double] // 12 elements: row-major 3x4

    /// Apply this transform to a 3D point.
    public func apply(to point: SIMD3<Double>) -> SIMD3<Double> {
        let x = values[0]*point.x + values[1]*point.y + values[2]*point.z + values[3]
        let y = values[4]*point.x + values[5]*point.y + values[6]*point.z + values[7]
        let z = values[8]*point.x + values[9]*point.y + values[10]*point.z + values[11]
        return SIMD3(x, y, z)
    }
}

/// 2D transformation matrix (row-major 2x3) from gce factories.
public struct TransformMatrix2D: Sendable {
    public let values: [Double] // 6 elements: row-major 2x3

    /// Apply this transform to a 2D point.
    public func apply(to point: SIMD2<Double>) -> SIMD2<Double> {
        let x = values[0]*point.x + values[1]*point.y + values[2]
        let y = values[3]*point.x + values[4]*point.y + values[5]
        return SIMD2(x, y)
    }
}

/// Factory methods for creating 3D transformation matrices.
public enum TransformFactory3D {

    /// Mirror about a point (central symmetry).
    public static func mirrorPoint(_ point: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeMirrorPoint(point.x, point.y, point.z, &m)
        return TransformMatrix3D(values: m)
    }

    /// Mirror about an axis (line).
    public static func mirrorAxis(point: SIMD3<Double>, direction: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeMirrorAxis(point.x, point.y, point.z, direction.x, direction.y, direction.z, &m)
        return TransformMatrix3D(values: m)
    }

    /// Mirror about a plane.
    public static func mirrorPlane(point: SIMD3<Double>, normal: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeMirrorPlane(point.x, point.y, point.z, normal.x, normal.y, normal.z, &m)
        return TransformMatrix3D(values: m)
    }

    /// Rotation about an axis by angle (radians).
    public static func rotation(point: SIMD3<Double>, direction: SIMD3<Double>, angle: Double) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeRotation(point.x, point.y, point.z, direction.x, direction.y, direction.z, angle, &m)
        return TransformMatrix3D(values: m)
    }

    /// Uniform scale about a point.
    public static func scale(center: SIMD3<Double>, factor: Double) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeScaleTransform(center.x, center.y, center.z, factor, &m)
        return TransformMatrix3D(values: m)
    }

    /// Translation by a vector.
    public static func translation(_ vector: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeTranslationVec(vector.x, vector.y, vector.z, &m)
        return TransformMatrix3D(values: m)
    }

    /// Translation from one point to another.
    public static func translation(from p1: SIMD3<Double>, to p2: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeTranslationPoints(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, &m)
        return TransformMatrix3D(values: m)
    }
}

/// Factory methods for creating 2D transformation matrices.
public enum TransformFactory2D {

    /// Mirror about a point.
    public static func mirrorPoint(_ point: SIMD2<Double>) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeMirror2dPoint(point.x, point.y, &m)
        return TransformMatrix2D(values: m)
    }

    /// Mirror about an axis.
    public static func mirrorAxis(point: SIMD2<Double>, direction: SIMD2<Double>) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeMirror2dAxis(point.x, point.y, direction.x, direction.y, &m)
        return TransformMatrix2D(values: m)
    }

    /// Rotation about a point by angle (radians).
    public static func rotation(center: SIMD2<Double>, angle: Double) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeRotation2d(center.x, center.y, angle, &m)
        return TransformMatrix2D(values: m)
    }

    /// Uniform scale about a point.
    public static func scale(center: SIMD2<Double>, factor: Double) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeScale2d(center.x, center.y, factor, &m)
        return TransformMatrix2D(values: m)
    }

    /// Translation by a vector.
    public static func translation(_ vector: SIMD2<Double>) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeTranslation2dVec(vector.x, vector.y, &m)
        return TransformMatrix2D(values: m)
    }

    /// Translation from one point to another.
    public static func translation(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeTranslation2dPoints(p1.x, p1.y, p2.x, p2.y, &m)
        return TransformMatrix2D(values: m)
    }

    /// Create a 2D direction from coordinates. Returns nil if zero vector.
    public static func direction(x: Double, y: Double) -> SIMD2<Double>? {
        var ox = 0.0, oy = 0.0
        guard OCCTMakeDir2d(x, y, &ox, &oy) else { return nil }
        return SIMD2(ox, oy)
    }

    /// Create a 2D direction from two points. Returns nil if coincident.
    public static func direction(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> SIMD2<Double>? {
        var ox = 0.0, oy = 0.0
        guard OCCTMakeDir2dFromPoints(p1.x, p1.y, p2.x, p2.y, &ox, &oy) else { return nil }
        return SIMD2(ox, oy)
    }
}
