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
    /// Apply a rigid transformation (3x3 rotation + translation) described by a 12-element
    /// matrix in **GROUPED layout**: all nine rotation entries first, then the three
    /// translation entries last.
    ///
    /// `matrix` must have exactly 12 elements, indexed as:
    /// ```
    /// matrix[0] = r00   matrix[1] = r01   matrix[2] = r02
    /// matrix[3] = r10   matrix[4] = r11   matrix[5] = r12
    /// matrix[6] = r20   matrix[7] = r21   matrix[8] = r22
    /// matrix[9] = tx    matrix[10] = ty   matrix[11] = tz
    /// ```
    /// i.e. `[r00, r01, r02, r10, r11, r12, r20, r21, r22, tx, ty, tz]` — the full 3x3 rotation
    /// block comes first, the translation vector last. The bridge re-shuffles these into
    /// `gp_Trsf::SetValues(a11...a34)`'s own interleaved parameter order internally; the array
    /// itself is grouped, not what `SetValues` takes positionally.
    ///
    /// - Important: This layout is **NOT interchangeable** with ``transformed(byMatrix:)`` or
    ///   ``gTransformed(matrix:)``, both of which take an **INTERLEAVED row-major** layout
    ///   instead (`[r00, r01, r02, tx, r10, r11, r12, ty, r20, r21, r22, tz]` — each row's
    ///   translation component folded in right after that row's rotation entries, rather than
    ///   all three translation components grouped at the end). Feeding a
    ///   `transformed(byMatrix:)`- or `gTransformed(matrix:)`-shaped array to this method (or
    ///   vice versa) silently produces a garbled rotation/translation split —
    ///   `matrix.count == 12` is the only validation any of the three methods performs. See #835.
    ///
    /// - Parameter matrix: 12-element array in GROUPED layout (see above).
    /// - Returns: The transformed shape, or `nil` if `matrix.count != 12` or the operation fails.
    ///
    /// ```swift
    /// // Pure translation by (5, 0, 0): identity rotation, translation grouped at the end.
    /// let matrix: [Double] = [
    ///     1, 0, 0,   // r00 r01 r02
    ///     0, 1, 0,   // r10 r11 r12
    ///     0, 0, 1,   // r20 r21 r22
    ///     5, 0, 0    // tx  ty  tz
    /// ]
    /// if let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
    ///    let moved = box.transformed(matrix: matrix),
    ///    let bb = moved.boundingBox {
    ///     print(bb.min.x, bb.max.x)  // 5.0 15.0 — box shifted +5 along X, matching tx = 5
    /// }
    /// ```
    public func transformed(matrix: [Double]) -> Shape? {
        guard matrix.count == 12 else { return nil }
        guard let ref = matrix.withUnsafeBufferPointer({ buf in
            OCCTShapeTransformed(handle, buf.baseAddress!)
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// Apply a general affine transformation (rotation + non-uniform scale/shear + translation)
    /// described by a 12-element matrix in the **same INTERLEAVED row-major layout as**
    /// ``transformed(byMatrix:)`` — but driving a general `gp_GTrsf` (via
    /// `BRepBuilderAPI_GTransform`) instead of a rigid `gp_Trsf`, so non-uniform scaling and
    /// shear are supported where `transformed(byMatrix:)`/`transformed(matrix:)` would distort
    /// or reject them.
    ///
    /// `matrix` must have exactly 12 elements, indexed as:
    /// ```
    /// matrix[0] = r00   matrix[1] = r01   matrix[2] = r02   matrix[3]  = tx
    /// matrix[4] = r10   matrix[5] = r11   matrix[6] = r12   matrix[7]  = ty
    /// matrix[8] = r20   matrix[9] = r21   matrix[10] = r22  matrix[11] = tz
    /// ```
    /// i.e. `[r00, r01, r02, tx, r10, r11, r12, ty, r20, r21, r22, tz]` — each row's translation
    /// component is folded in right after that row's own rotation/scale entries. Passed
    /// positionally, one 3x4 entry at a time, into `gp_GTrsf::SetValue(row, col, ...)` — no
    /// re-shuffling.
    ///
    /// - Important: This layout is **NOT interchangeable** with ``transformed(matrix:)``, which
    ///   uses a **GROUPED layout** instead (all nine rotation entries first, then the three
    ///   translation entries last: `[r00...r22, tx, ty, tz]`). It matches ``transformed(byMatrix:)``'s
    ///   layout exactly, but that method is restricted to a rigid `gp_Trsf` — reach for this
    ///   method instead of `transformed(byMatrix:)` specifically when the matrix encodes
    ///   non-uniform scale or shear. Feeding a `transformed(matrix:)`-shaped array here silently
    ///   produces a garbled rotation/translation split — `matrix.count == 12` is the only
    ///   validation any of the three methods performs. See #835.
    ///
    /// - Parameter matrix: 12-element array in INTERLEAVED row-major layout (see above).
    /// - Returns: The transformed shape, or `nil` if `matrix.count != 12` or the operation fails.
    ///
    /// ```swift
    /// // Non-uniform scale (2x, 1x, 0.5x) about the origin: no rotation, no translation.
    /// let matrix: [Double] = [
    ///     2, 0, 0,   0,   // r00 r01 r02  tx
    ///     0, 1, 0,   0,   // r10 r11 r12  ty
    ///     0, 0, 0.5, 0    // r20 r21 r22  tz
    /// ]
    /// if let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
    ///    let scaled = box.gTransformed(matrix: matrix),
    ///    let bb = scaled.boundingBox {
    ///     print(bb.max.x, bb.max.y, bb.max.z)  // 20.0 10.0 5.0 — X doubled, Y unchanged, Z halved
    /// }
    /// ```
    public func gTransformed(matrix: [Double]) -> Shape? {
        guard matrix.count == 12 else { return nil }
        guard let ref = matrix.withUnsafeBufferPointer({ buf in
            OCCTShapeGTransformed(handle, buf.baseAddress!)
        }) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {
    /// Apply a rigid transformation (3x3 rotation + translation) described by a 12-element
    /// matrix in **INTERLEAVED row-major layout**: each row of the 3x4 affine matrix is stored
    /// together, with that row's translation component folded in as its 4th entry.
    ///
    /// `matrix` must have exactly 12 elements, indexed as:
    /// ```
    /// matrix[0] = a11   matrix[1] = a12   matrix[2]  = a13   matrix[3]  = a14 (tx)
    /// matrix[4] = a21   matrix[5] = a22   matrix[6]  = a23   matrix[7]  = a24 (ty)
    /// matrix[8] = a31   matrix[9] = a32   matrix[10] = a33   matrix[11] = a34 (tz)
    /// ```
    /// i.e. `[r00, r01, r02, tx, r10, r11, r12, ty, r20, r21, r22, tz]`. Passed straight
    /// through, positionally, to `gp_Trsf::SetValues(a11, a12, ..., a34)` — no re-shuffling.
    ///
    /// - Important: This layout is **NOT interchangeable** with ``transformed(matrix:)``, which
    ///   uses a **GROUPED layout** instead (all nine rotation entries first, then the three
    ///   translation entries last: `[r00...r22, tx, ty, tz]`). It IS the same layout
    ///   ``gTransformed(matrix:)`` uses, but `gTransformed` drives a general `gp_GTrsf`
    ///   (supports non-uniform scale/shear) where this method is restricted to a rigid
    ///   `gp_Trsf`. Feeding a `transformed(matrix:)`-shaped array to this method (or vice versa)
    ///   silently produces a garbled rotation/translation split — `matrix.count == 12` is the
    ///   only validation any of the three methods performs. See #835.
    ///
    /// - Parameter matrix: 12-element array in INTERLEAVED row-major layout (see above).
    /// - Returns: Transformed shape, or `nil` if `matrix.count != 12` or the operation fails.
    ///
    /// ```swift
    /// // Pure translation by (5, 10, 15): identity rotation, translation folded into each row.
    /// let matrix: [Double] = [
    ///     1, 0, 0, 5,    // a11 a12 a13 a14(tx)
    ///     0, 1, 0, 10,   // a21 a22 a23 a24(ty)
    ///     0, 0, 1, 15    // a31 a32 a33 a34(tz)
    /// ]
    /// if let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
    ///    let moved = box.transformed(byMatrix: matrix),
    ///    let bb = moved.boundingBox {
    ///     print(bb.min.x, bb.min.y, bb.min.z)  // 5.0 10.0 15.0
    /// }
    /// ```
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
