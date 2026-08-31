import Foundation
import OCCTBridge
import simd

/// 3D geometric transformation (Handle-wrapped).
///
/// `@unchecked Sendable` reflects that `ref` is a plain bridge handle, not that concurrent use of
/// one instance is safe, it isn't: `setTranslation`/`setRotation`/`setScale`/`setMirrorPoint`/
/// `setMirrorAxis` all mutate the same underlying `gp_Trsf`-backed handle in place with no lock,
/// so calling any of them concurrently with each other or with a read races. This is not the
/// "Likely true - value type" issue #1162 originally guessed: a `GeomTransformation` is a
/// reference to shared, mutable OCCT state, not a Swift value type. Serialize access to a shared
/// instance with `OCCTSerial.withLock { }`.
public final class GeomTransformation: @unchecked Sendable {
    internal let ref: OCCTGeomTransformRef

    /// Create an identity transformation.
    public init?() {
        guard let r = OCCTGeomTransformCreate() else { return nil }
        self.ref = r
    }

    internal init(ref: OCCTGeomTransformRef) {
        self.ref = ref
    }

    deinit {
        OCCTGeomTransformRelease(ref)
    }

    /// Set translation by vector.
    public func setTranslation(dx: Double, dy: Double, dz: Double) {
        OCCTGeomTransformSetTranslation(ref, dx, dy, dz)
    }

    /// Set rotation about an axis.
    public func setRotation(
        originX: Double, originY: Double, originZ: Double,
        dirX: Double, dirY: Double, dirZ: Double,
        angle: Double
    ) {
        OCCTGeomTransformSetRotation(ref, originX, originY, originZ, dirX, dirY, dirZ, angle)
    }

    /// Set scale about a point.
    public func setScale(centerX: Double, centerY: Double, centerZ: Double, factor: Double) {
        OCCTGeomTransformSetScale(ref, centerX, centerY, centerZ, factor)
    }

    /// Set point mirror.
    public func setMirrorPoint(x: Double, y: Double, z: Double) {
        OCCTGeomTransformSetMirrorPoint(ref, x, y, z)
    }

    /// Set axis mirror.
    public func setMirrorAxis(
        originX: Double, originY: Double, originZ: Double,
        dirX: Double, dirY: Double, dirZ: Double
    ) {
        OCCTGeomTransformSetMirrorAxis(ref, originX, originY, originZ, dirX, dirY, dirZ)
    }

    /// Get scale factor.
    public var scaleFactor: Double {
        OCCTGeomTransformScaleFactor(ref)
    }

    /// Check if negative (reflection).
    public var isNegative: Bool {
        OCCTGeomTransformIsNegative(ref)
    }

    /// Transform a point and return the result.
    public func apply(x: Double, y: Double, z: Double) -> (x: Double, y: Double, z: Double) {
        var px = x
        var py = y
        var pz = z
        OCCTGeomTransformApply(ref, &px, &py, &pz)
        return (px, py, pz)
    }

    /// Get matrix value (row 1-3, col 1-4).
    public func value(row: Int, col: Int) -> Double {
        OCCTGeomTransformValue(ref, Int32(row), Int32(col))
    }

    /// Multiply with another transformation, return new.
    public func multiplied(by other: GeomTransformation) -> GeomTransformation? {
        guard let r = OCCTGeomTransformMultiplied(ref, other.ref) else { return nil }
        return GeomTransformation(ref: r)
    }

    /// Return inverse transformation.
    public func inverted() -> GeomTransformation? {
        guard let r = OCCTGeomTransformInverted(ref) else { return nil }
        return GeomTransformation(ref: r)
    }
}
