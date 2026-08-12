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
    /// Apply a rigid transformation (3x3 rotation + translation) described by a
    /// ``Matrix12Grouped`` matrix (see that type's doc for the GROUPED layout and how it differs
    /// from ``TransformMatrix3D``'s INTERLEAVED layout — used instead by
    /// ``transformed(byMatrix:)``/``gTransformed(matrix:)`` — the two are not interchangeable,
    /// and passing one where the other is expected is now a compile error, not a silently
    /// garbled transform. See #835.)
    ///
    /// - Parameter matrix: The transformation, in GROUPED layout.
    /// - Returns: The transformed shape, or `nil` if the operation fails.
    ///
    /// ```swift
    /// // Pure translation by (5, 0, 0): identity rotation, translation grouped at the end.
    /// if let matrix = Matrix12Grouped([
    ///        1, 0, 0,   // r00 r01 r02
    ///        0, 1, 0,   // r10 r11 r12
    ///        0, 0, 1,   // r20 r21 r22
    ///        5, 0, 0    // tx  ty  tz
    ///    ]),
    ///    let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
    ///    let moved = box.transformed(matrix: matrix),
    ///    let bb = moved.boundingBox {
    ///     print(bb.min.x, bb.max.x)  // 5.0 15.0 — box shifted +5 along X, matching tx = 5
    /// }
    /// ```
    public func transformed(matrix: Matrix12Grouped) -> Shape? {
        guard let ref = matrix.values.withUnsafeBufferPointer({ buf in
            OCCTShapeTransformed(handle, buf.baseAddress!)
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// - Deprecated: Pass a ``Matrix12Grouped`` instead of a raw `[Double]` — the array's layout
    ///   can't be checked at compile time (#835). This overload keeps the old `matrix.count == 12`
    ///   validation (`nil` on a wrong count) for source compatibility.
    @available(*, deprecated, message: "Pass a Matrix12Grouped instead of a raw [Double] — see Matrix12Grouped's doc comment. #835")
    public func transformed(matrix: [Double]) -> Shape? {
        guard let grouped = Matrix12Grouped(matrix) else { return nil }
        return transformed(matrix: grouped)
    }

    /// Apply a general affine transformation (rotation + non-uniform scale/shear + translation)
    /// described by a ``TransformMatrix3D`` matrix (INTERLEAVED layout — see that type's doc) —
    /// driving a general `gp_GTrsf` (via `BRepBuilderAPI_GTransform`) instead of a rigid
    /// `gp_Trsf`, so non-uniform scaling and shear are supported where
    /// ``transformed(byMatrix:)``/``transformed(matrix:)`` would distort or reject them.
    ///
    /// - Parameter matrix: The transformation, in INTERLEAVED layout — the same layout
    ///   ``transformed(byMatrix:)`` uses (and `TransformFactory3D`'s builders produce), but this
    ///   method additionally accepts non-uniform scale/shear where that one is restricted to a
    ///   rigid `gp_Trsf`.
    /// - Returns: The transformed shape, or `nil` if the operation fails.
    ///
    /// ```swift
    /// // Non-uniform scale (2x, 1x, 0.5x) about the origin: no rotation, no translation.
    /// if let matrix = TransformMatrix3D([
    ///        2, 0, 0,   0,   // r00 r01 r02  tx
    ///        0, 1, 0,   0,   // r10 r11 r12  ty
    ///        0, 0, 0.5, 0    // r20 r21 r22  tz
    ///    ]),
    ///    let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
    ///    let scaled = box.gTransformed(matrix: matrix),
    ///    let bb = scaled.boundingBox {
    ///     print(bb.max.x, bb.max.y, bb.max.z)  // 20.0 10.0 5.0 — X doubled, Y unchanged, Z halved
    /// }
    /// ```
    public func gTransformed(matrix: TransformMatrix3D) -> Shape? {
        guard let ref = matrix.values.withUnsafeBufferPointer({ buf in
            OCCTShapeGTransformed(handle, buf.baseAddress!)
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// - Deprecated: Pass a ``TransformMatrix3D`` instead of a raw `[Double]` — the array's
    ///   layout can't be checked at compile time (#835). This overload keeps the old
    ///   `matrix.count == 12` validation (`nil` on a wrong count) for source compatibility.
    @available(*, deprecated, message: "Pass a TransformMatrix3D instead of a raw [Double] — see TransformMatrix3D's doc comment. #835")
    public func gTransformed(matrix: [Double]) -> Shape? {
        guard let interleaved = TransformMatrix3D(matrix) else { return nil }
        return gTransformed(matrix: interleaved)
    }
}

extension Shape {
    /// Apply a rigid transformation (3x3 rotation + translation) described by a
    /// ``TransformMatrix3D`` matrix (INTERLEAVED layout — see that type's doc for how it differs
    /// from ``Matrix12Grouped``'s GROUPED layout, used instead by ``transformed(matrix:)``). Passed
    /// straight through, positionally, to `gp_Trsf::SetValues(a11, a12, ..., a34)` — no
    /// re-shuffling. Same layout as ``gTransformed(matrix:)``, but that method additionally
    /// accepts non-uniform scale/shear; this one is restricted to a rigid `gp_Trsf`.
    ///
    /// - Parameter matrix: The transformation, in INTERLEAVED layout.
    /// - Returns: Transformed shape, or `nil` if the operation fails.
    ///
    /// ```swift
    /// // Pure translation by (5, 10, 15): identity rotation, translation folded into each row.
    /// if let matrix = TransformMatrix3D([
    ///        1, 0, 0, 5,    // a11 a12 a13 a14(tx)
    ///        0, 1, 0, 10,   // a21 a22 a23 a24(ty)
    ///        0, 0, 1, 15    // a31 a32 a33 a34(tz)
    ///    ]),
    ///    let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
    ///    let moved = box.transformed(byMatrix: matrix),
    ///    let bb = moved.boundingBox {
    ///     print(bb.min.x, bb.min.y, bb.min.z)  // 5.0 10.0 15.0
    /// }
    /// ```
    public func transformed(byMatrix matrix: TransformMatrix3D) -> Shape? {
        var result: OCCTShapeRef?
        let v = matrix.values
        OCCTShapeTransformFromMatrix(handle,
            v[0], v[1], v[2], v[3],
            v[4], v[5], v[6], v[7],
            v[8], v[9], v[10], v[11],
            &result)
        guard let r = result else { return nil }
        return Shape(handle: r)
    }

    /// - Deprecated: Pass a ``TransformMatrix3D`` instead of a raw `[Double]` — the array's
    ///   layout can't be checked at compile time (#835). This overload keeps the old
    ///   `matrix.count == 12` validation (`nil` on a wrong count) for source compatibility.
    @available(*, deprecated, message: "Pass a TransformMatrix3D instead of a raw [Double] — see TransformMatrix3D's doc comment. #835")
    public func transformed(byMatrix matrix: [Double]) -> Shape? {
        guard let interleaved = TransformMatrix3D(matrix) else { return nil }
        return transformed(byMatrix: interleaved)
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
