import Foundation
import OCCTBridge
import simd

/// Shared validation for ``TransformMatrix3D`` and ``Matrix12Grouped``, both of which wrap a
/// fixed 12-element `[Double]` (row-major 3x4) in a distinct, non-interchangeable element order.
///
/// Returns `values` unchanged if it has exactly 12 elements, `nil` otherwise. Extracted so the
/// count check — and its nil-on-mismatch behavior — lives in one place rather than being
/// duplicated (with only the panic-message text differing) across both initializers (review
/// finding on PR #870).
private func validated12(_ values: [Double]) -> [Double]? {
    values.count == 12 ? values : nil
}

/// A 12-element 3D transformation matrix (row-major 3x4) in **INTERLEAVED** layout: each row is
/// stored together, with that row's translation component folded in as its 4th entry —
/// `[r00,r01,r02,tx, r10,r11,r12,ty, r20,r21,r22,tz]`. Positionally, this is
/// `gp_Trsf::SetValues(a11...a34)`'s own parameter order (`values[i]` = `a(row)(col)`), and what
/// `gp_GTrsf::SetValue(row, col, ...)` takes one entry at a time — no re-shuffling either way.
///
/// Returned by `TransformFactory3D`'s mirror/rotation/scale/translation builders, and accepted by
/// ``Shape/transformed(byMatrix:)`` and ``Shape/gTransformed(matrix:)``.
///
/// - Important: This layout is **NOT interchangeable** with ``Matrix12Grouped``, which
///   ``Shape/transformed(matrix:)`` uses instead (all nine rotation entries first, then the
///   three translation entries last: `[r00...r22, tx, ty, tz]`). Before #835 all three `Shape`
///   transform methods took a plain `[Double]`, so a caller could feed one method's array shape
///   to another and silently get a garbled rotation/translation split, with no error. These two
///   distinct types make that a compile error instead — convert between them with ``grouped`` /
///   `Matrix12Grouped.interleaved`.
///
/// ```swift
/// // INTERLEAVED: identity rotation, translate by (5, 10, 15).
/// if let m = TransformMatrix3D([
///        1, 0, 0, 5,    // a11 a12 a13 a14(tx)
///        0, 1, 0, 10,   // a21 a22 a23 a24(ty)
///        0, 0, 1, 15    // a31 a32 a33 a34(tz)
///    ]),
///    let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
///    let moved = box.transformed(byMatrix: m),
///    let bb = moved.boundingBox {
///     print(bb.min.x, bb.min.y, bb.min.z)  // 5.0 10.0 15.0
/// }
/// ```
public struct TransformMatrix3D: Sendable {
    public let values: [Double]  // 12 elements: row-major 3x4, INTERLEAVED (see type doc)

    /// Creates a matrix from exactly 12 elements in INTERLEAVED row-major order (see type doc).
    ///
    /// - Returns: `nil` if `values.count != 12` — matching the graceful-`nil`-on-bad-count
    ///   contract the three `Shape` transform methods this type replaces (`transformed(matrix:)`,
    ///   `transformed(byMatrix:)`, `gTransformed(matrix:)`) used to guarantee for any `[Double]`
    ///   input, before #835 split them into typed matrices. A trapping `precondition` here would
    ///   crash the whole process (debug *and* release, with no way to catch it in-process) on a
    ///   caller-supplied array of the wrong length — e.g. deserialized data, or a generic
    ///   matrix-conversion utility producing 9 or 16 elements instead of 12 — exactly the
    ///   situation a caller migrating off the deprecated `[Double]`-taking overloads is trying to
    ///   handle gracefully. See the review finding on PR #870.
    public init?(_ values: [Double]) {
        guard let validated = validated12(values) else { return nil }
        self.values = validated
    }

    /// Apply this transform to a 3D point.
    public func apply(to point: SIMD3<Double>) -> SIMD3<Double> {
        let x = values[0] * point.x + values[1] * point.y + values[2] * point.z + values[3]
        let y = values[4] * point.x + values[5] * point.y + values[6] * point.z + values[7]
        let z = values[8] * point.x + values[9] * point.y + values[10] * point.z + values[11]
        return SIMD3(x, y, z)
    }
    /// This matrix converted to Matrix12Grouped's GROUPED layout, for use with Shape.transformed(matrix:).
    public var grouped: Matrix12Grouped {
        Matrix12Grouped([
            values[0], values[1], values[2],
            values[4], values[5], values[6],
            values[8], values[9], values[10],
            values[3], values[7], values[11],
        ])!  // always 12 elements — reshuffled from self.values, itself always 12
    }
}

/// A 12-element rigid transformation matrix (3x3 rotation + translation) in **GROUPED** layout:
/// all nine rotation entries first, then the three translation entries last —
/// `[r00,r01,r02, r10,r11,r12, r20,r21,r22, tx,ty,tz]`.
///
/// Accepted by ``Shape/transformed(matrix:)``, which re-shuffles these into
/// `gp_Trsf::SetValues(a11...a34)`'s own INTERLEAVED parameter order internally — the array
/// itself is grouped, not what `SetValues` takes positionally.
///
/// - Important: This layout is **NOT interchangeable** with ``TransformMatrix3D``, which
///   ``Shape/transformed(byMatrix:)`` and ``Shape/gTransformed(matrix:)`` use instead (each
///   row's translation folded in right after that row's own rotation entries:
///   `[r00,r01,r02,tx, r10,r11,r12,ty, r20,r21,r22,tz]`). Before #835 all three `Shape` transform
///   methods took a plain `[Double]`, so a caller could feed one method's array shape to another
///   and silently get a garbled rotation/translation split, with no error. These two distinct
///   types make that a compile error instead — convert between them with ``interleaved`` /
///   `TransformMatrix3D.grouped`.
///
/// ```swift
/// // GROUPED: identity rotation, translate by (5, 0, 0).
/// if let m = Matrix12Grouped([
///        1, 0, 0,   // r00 r01 r02
///        0, 1, 0,   // r10 r11 r12
///        0, 0, 1,   // r20 r21 r22
///        5, 0, 0    // tx  ty  tz
///    ]),
///    let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
///    let moved = box.transformed(matrix: m),
///    let bb = moved.boundingBox {
///     print(bb.min.x, bb.max.x)  // 5.0 15.0 — box shifted +5 along X, matching tx = 5
/// }
/// ```
public struct Matrix12Grouped: Sendable {
    public let values: [Double]  // 12 elements: GROUPED (see type doc)

    /// Creates a matrix from exactly 12 elements in GROUPED order (see type doc).
    ///
    /// - Returns: `nil` if `values.count != 12` — see ``TransformMatrix3D/init(_:)``'s doc
    ///   comment for why this is failable rather than trapping (review finding on PR #870).
    public init?(_ values: [Double]) {
        guard let validated = validated12(values) else { return nil }
        self.values = validated
    }

    /// This matrix converted to TransformMatrix3D's INTERLEAVED layout, for use with Shape.transformed(byMatrix:) or Shape.gTransformed(matrix:).
    public var interleaved: TransformMatrix3D {
        TransformMatrix3D([
            values[0], values[1], values[2], values[9],
            values[3], values[4], values[5], values[10],
            values[6], values[7], values[8], values[11],
        ])!  // always 12 elements — reshuffled from self.values, itself always 12
    }
}

/// 2D transformation matrix (row-major 2x3) from gce factories.
public struct TransformMatrix2D: Sendable {
    public let values: [Double]  // 6 elements: row-major 2x3

    /// Apply this transform to a 2D point.
    public func apply(to point: SIMD2<Double>) -> SIMD2<Double> {
        let x = values[0] * point.x + values[1] * point.y + values[2]
        let y = values[3] * point.x + values[4] * point.y + values[5]
        return SIMD2(x, y)
    }
}

/// Factory methods for creating 3D transformation matrices.
public enum TransformFactory3D {

    /// Mirror about a point (central symmetry).
    public static func mirrorPoint(_ point: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeMirrorPoint(point.x, point.y, point.z, &m)
        return TransformMatrix3D(m)!  // always 12 elements — freshly allocated above
    }

    /// Mirror about an axis (line).
    public static func mirrorAxis(point: SIMD3<Double>, direction: SIMD3<Double>)
        -> TransformMatrix3D
    {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeMirrorAxis(point.x, point.y, point.z, direction.x, direction.y, direction.z, &m)
        return TransformMatrix3D(m)!  // always 12 elements — freshly allocated above
    }

    /// Mirror about a plane.
    public static func mirrorPlane(point: SIMD3<Double>, normal: SIMD3<Double>) -> TransformMatrix3D
    {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeMirrorPlane(point.x, point.y, point.z, normal.x, normal.y, normal.z, &m)
        return TransformMatrix3D(m)!  // always 12 elements — freshly allocated above
    }

    /// Rotation about an axis by angle (radians).
    public static func rotation(point: SIMD3<Double>, direction: SIMD3<Double>, angle: Double)
        -> TransformMatrix3D
    {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeRotation(
            point.x, point.y, point.z, direction.x, direction.y, direction.z, angle, &m)
        return TransformMatrix3D(m)!  // always 12 elements — freshly allocated above
    }

    /// Uniform scale about a point.
    public static func scale(center: SIMD3<Double>, factor: Double) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeScaleTransform(center.x, center.y, center.z, factor, &m)
        return TransformMatrix3D(m)!  // always 12 elements — freshly allocated above
    }

    /// Translation by a vector.
    public static func translation(_ vector: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeTranslationVec(vector.x, vector.y, vector.z, &m)
        return TransformMatrix3D(m)!  // always 12 elements — freshly allocated above
    }

    /// Translation from one point to another.
    public static func translation(from p1: SIMD3<Double>, to p2: SIMD3<Double>)
        -> TransformMatrix3D
    {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeTranslationPoints(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, &m)
        return TransformMatrix3D(m)!  // always 12 elements — freshly allocated above
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
    public static func mirrorAxis(point: SIMD2<Double>, direction: SIMD2<Double>)
        -> TransformMatrix2D
    {
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
    public static func translation(from p1: SIMD2<Double>, to p2: SIMD2<Double>)
        -> TransformMatrix2D
    {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeTranslation2dPoints(p1.x, p1.y, p2.x, p2.y, &m)
        return TransformMatrix2D(values: m)
    }

    /// Create a 2D direction from coordinates.
    ///
    /// Returns nil if zero vector.
    public static func direction(x: Double, y: Double) -> SIMD2<Double>? {
        var ox = 0.0
        var oy = 0.0
        guard OCCTMakeDir2d(x, y, &ox, &oy) else { return nil }
        return SIMD2(ox, oy)
    }

    /// Create a 2D direction from two points.
    ///
    /// Returns nil if coincident.
    public static func direction(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> SIMD2<Double>? {
        var ox = 0.0
        var oy = 0.0
        guard OCCTMakeDir2dFromPoints(p1.x, p1.y, p2.x, p2.y, &ox, &oy) else { return nil }
        return SIMD2(ox, oy)
    }
}
