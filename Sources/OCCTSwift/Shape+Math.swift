import Foundation
import simd
import OCCTBridge

extension Shape {

    /// Scale this shape non-uniformly along each axis.
    ///
    /// Unlike `scaled(by:)` which applies uniform scaling, this allows
    /// different scale factors for X, Y, and Z axes.
    ///
    /// - Parameters:
    ///   - sx: Scale factor along X axis
    ///   - sy: Scale factor along Y axis
    ///   - sz: Scale factor along Z axis
    /// - Returns: The scaled shape, or nil on failure
    public func nonUniformScaled(sx: Double, sy: Double, sz: Double) -> Shape? {
        guard let h = OCCTShapeNonUniformScale(handle, sx, sy, sz) else { return nil }
        return Shape(handle: h)
    }

    /// Mirror this shape about a point (point symmetry / inversion).
    ///
    /// - Parameter point: The center point of the point mirror
    /// - Returns: Mirrored shape, or nil on failure
    public func mirroredAboutPoint(_ point: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeMirrorAboutPoint(handle, point.x, point.y, point.z) else { return nil }
        return Shape(handle: h)
    }

    /// Mirror this shape about an axis line.
    ///
    /// - Parameters:
    ///   - origin: A point on the axis
    ///   - direction: Direction of the axis
    /// - Returns: Mirrored shape, or nil on failure
    public func mirroredAboutAxis(origin: SIMD3<Double>, direction: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeMirrorAboutAxis(handle,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z) else { return nil }
        return Shape(handle: h)
    }

    /// Scale this shape about a specific center point.
    ///
    /// Unlike `scaled(by:)` which scales about the origin, this scales about a given point.
    ///
    /// - Parameters:
    ///   - center: Center of scaling
    ///   - factor: Scale factor
    /// - Returns: Scaled shape, or nil on failure
    public func scaledAboutPoint(_ center: SIMD3<Double>, factor: Double) -> Shape? {
        guard let h = OCCTShapeScaleAboutPoint(handle,
            center.x, center.y, center.z, factor) else { return nil }
        return Shape(handle: h)
    }

    /// Translate this shape by the vector from one point to another.
    ///
    /// - Parameters:
    ///   - from: Start point of the translation vector
    ///   - to: End point of the translation vector
    /// - Returns: Translated shape, or nil on failure
    public func translated(from: SIMD3<Double>, to: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeTranslateByPoints(handle,
            from.x, from.y, from.z,
            to.x, to.y, to.z) else { return nil }
        return Shape(handle: h)
    }
    /// Apply a transformation matrix via BRepTools_TrsfModification.
    /// The 3x4 matrix is specified as row-major (a11..a14, a21..a24, a31..a34).
    public static func trsfModification(_ shape: Shape,
                                          a11: Double, a12: Double, a13: Double, a14: Double,
                                          a21: Double, a22: Double, a23: Double, a24: Double,
                                          a31: Double, a32: Double, a33: Double, a34: Double) -> Shape? {
        guard let ref = OCCTShapeTrsfModification(shape.handle,
                                                    a11, a12, a13, a14,
                                                    a21, a22, a23, a24,
                                                    a31, a32, a33, a34) else { return nil }
        return Shape(handle: ref)
    }

    /// Apply a general transformation matrix via BRepTools_GTrsfModification.
    /// Supports non-uniform scaling. Shape should be NURBS-converted first for non-affine transforms.
    public static func gtrsfModification(_ shape: Shape,
                                           a11: Double, a12: Double, a13: Double, a14: Double,
                                           a21: Double, a22: Double, a23: Double, a24: Double,
                                           a31: Double, a32: Double, a33: Double, a34: Double) -> Shape? {
        guard let ref = OCCTShapeGTrsfModification(shape.handle,
                                                     a11, a12, a13, a14,
                                                     a21, a22, a23, a24,
                                                     a31, a32, a33, a34) else { return nil }
        return Shape(handle: ref)
    }
    /// Apply a general affine transformation (3x3 rotation + translation).
    /// matrix12 = [r00,r01,r02, r10,r11,r12, r20,r21,r22, tx,ty,tz]
    public func transformed(matrix: [Double]) -> Shape? {
        guard matrix.count == 12 else { return nil }
        guard let ref = matrix.withUnsafeBufferPointer({ buf in
            OCCTShapeTransformed(handle, buf.baseAddress!)
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// Apply a general affine transformation (non-uniform scaling).
    /// matrix12 = row-major 3x4 affine matrix [r00,r01,r02,tx, r10,r11,r12,ty, r20,r21,r22,tz]
    public func gTransformed(matrix: [Double]) -> Shape? {
        guard matrix.count == 12 else { return nil }
        guard let ref = matrix.withUnsafeBufferPointer({ buf in
            OCCTShapeGTransformed(handle, buf.baseAddress!)
        }) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {
    /// Transform shape using a 3x4 matrix (row-major: [a11..a14, a21..a24, a31..a34]).
    public func transformed(byMatrix matrix: [Double]) -> Shape? {
        guard matrix.count == 12 else { return nil }
        var result: OCCTShapeRef?
        OCCTShapeTransformFromMatrix(handle,
            matrix[0], matrix[1], matrix[2], matrix[3],
            matrix[4], matrix[5], matrix[6], matrix[7],
            matrix[8], matrix[9], matrix[10], matrix[11],
            &result)
        guard let r = result else { return nil }
        return Shape(handle: r)
    }

    /// Check if the shape's location transform has negative determinant (mirror/reflection).
    public var isTransformNegative: Bool {
        OCCTShapeTransformIsNegative(handle)
    }
}

extension Shape {

    /// Compute the magnitude of the cross product of two vectors.
    public static func vecCrossMagnitude(_ v1: SIMD3<Double>, _ v2: SIMD3<Double>) -> Double {
        OCCTVecCrossMagnitude(v1.x, v1.y, v1.z, v2.x, v2.y, v2.z)
    }

    /// Compute the square magnitude of the cross product of two vectors.
    public static func vecCrossSquareMagnitude(_ v1: SIMD3<Double>, _ v2: SIMD3<Double>) -> Double {
        OCCTVecCrossSquareMagnitude(v1.x, v1.y, v1.z, v2.x, v2.y, v2.z)
    }

    /// Check if two directions are opposite within angular tolerance (radians).
    public static func dirIsOpposite(_ d1: SIMD3<Double>, _ d2: SIMD3<Double>,
                                     tolerance: Double = 1e-10) -> Bool {
        OCCTDirIsOpposite(d1.x, d1.y, d1.z, d2.x, d2.y, d2.z, tolerance)
    }

    /// Check if two directions are normal (perpendicular) within angular tolerance (radians).
    public static func dirIsNormal(_ d1: SIMD3<Double>, _ d2: SIMD3<Double>,
                                   tolerance: Double = 1e-10) -> Bool {
        OCCTDirIsNormal(d1.x, d1.y, d1.z, d2.x, d2.y, d2.z, tolerance)
    }
}
