import Foundation
import OCCTBridge
import simd

/// A 2D geometric transformation backed by Geom2d_Transformation.
///
/// Supports translation, rotation, scaling, mirroring, and composition.
public final class Transform2D: @unchecked Sendable {
    internal let handle: OCCTTransform2DRef

    internal init(handle: OCCTTransform2DRef) {
        self.handle = handle
    }

    deinit {
        OCCTTransform2DRelease(handle)
    }

    // MARK: - Factory Methods

    /// Create an identity transformation.
    public static func identity() -> Transform2D? {
        guard let h = OCCTTransform2DCreateIdentity() else { return nil }
        return Transform2D(handle: h)
    }

    /// Create a translation by (dx, dy).
    public static func translation(dx: Double, dy: Double) -> Transform2D? {
        guard let h = OCCTTransform2DCreateTranslation(dx, dy) else { return nil }
        return Transform2D(handle: h)
    }

    /// Create a rotation around a center point by angle (radians).
    public static func rotation(center: SIMD2<Double>, angle: Double) -> Transform2D? {
        guard let h = OCCTTransform2DCreateRotation(center.x, center.y, angle) else { return nil }
        return Transform2D(handle: h)
    }

    /// Create a uniform scale from a center point.
    public static func scale(center: SIMD2<Double>, factor: Double) -> Transform2D? {
        guard let h = OCCTTransform2DCreateScale(center.x, center.y, factor) else { return nil }
        return Transform2D(handle: h)
    }

    /// Create a mirror about a point.
    public static func mirrorPoint(_ point: SIMD2<Double>) -> Transform2D? {
        guard let h = OCCTTransform2DCreateMirrorPoint(point.x, point.y) else { return nil }
        return Transform2D(handle: h)
    }

    /// Create a mirror about an axis (origin + direction).
    public static func mirrorAxis(origin: SIMD2<Double>, direction: SIMD2<Double>) -> Transform2D? {
        guard
            let h = OCCTTransform2DCreateMirrorAxis(
                origin.x, origin.y,
                direction.x, direction.y)
        else { return nil }
        return Transform2D(handle: h)
    }

    // MARK: - Properties

    /// The scale factor of this transformation.
    public var scaleFactor: Double {
        OCCTTransform2DScaleFactor(handle)
    }

    /// Whether this transformation involves a reflection (negative determinant).
    public var isNegative: Bool {
        OCCTTransform2DIsNegative(handle)
    }

    /// The 2×3 matrix values `[a11, a12, a13, a21, a22, a23]`.
    public var matrixValues:
        (
            a11: Double, a12: Double, a13: Double,
            a21: Double, a22: Double, a23: Double
        )
    {
        var a11: Double = 0
        var a12: Double = 0
        var a13: Double = 0
        var a21: Double = 0
        var a22: Double = 0
        var a23: Double = 0
        OCCTTransform2DGetValues(handle, &a11, &a12, &a13, &a21, &a22, &a23)
        return (a11, a12, a13, a21, a22, a23)
    }

    // MARK: - Composition

    /// The inverse of this transformation.
    public func inverted() -> Transform2D? {
        guard let h = OCCTTransform2DInverted(handle) else { return nil }
        return Transform2D(handle: h)
    }

    /// Compose this transformation with another: `self * other`.
    public func composed(with other: Transform2D) -> Transform2D? {
        guard let h = OCCTTransform2DComposed(handle, other.handle) else { return nil }
        return Transform2D(handle: h)
    }

    /// Raise this transformation to the n-th power.
    public func powered(_ n: Int32) -> Transform2D? {
        guard let h = OCCTTransform2DPowered(handle, n) else { return nil }
        return Transform2D(handle: h)
    }

    // MARK: - Application

    /// Apply this transformation to a 2D coordinate, returning the result.
    public func apply(to point: SIMD2<Double>) -> SIMD2<Double> {
        var x = point.x
        var y = point.y
        OCCTTransform2DApply(handle, &x, &y)
        return SIMD2(x, y)
    }

    /// Apply this transformation to a 2D curve, returning a new curve.
    public func apply(to curve: Curve2D) -> Curve2D? {
        guard let h = OCCTTransform2DApplyToCurve(handle, curve.handle) else { return nil }
        return Curve2D(handle: h)
    }
}
