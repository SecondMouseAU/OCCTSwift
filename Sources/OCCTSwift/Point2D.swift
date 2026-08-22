import Foundation
import OCCTBridge
import simd

/// A 2D geometric point backed by `Geom2d_CartesianPoint`.
public final class Point2D: @unchecked Sendable {
    internal let handle: OCCTPoint2DRef

    internal init(handle: OCCTPoint2DRef) {
        self.handle = handle
    }

    deinit {
        OCCTPoint2DRelease(handle)
    }

    // MARK: - Creation

    /// Create a 2D point at the given coordinates.
    public init?(x: Double, y: Double) {
        guard let h = OCCTPoint2DCreate(x, y) else { return nil }
        self.handle = h
    }

    /// Create a 2D point from a SIMD2 vector.
    public convenience init?(position: SIMD2<Double>) {
        self.init(x: position.x, y: position.y)
    }

    /// Create a 2D point from a SIMD2 vector (convenience alias).
    public convenience init?(_ coords: SIMD2<Double>) {
        self.init(x: coords.x, y: coords.y)
    }

    // MARK: - Properties

    /// The X coordinate.
    public var x: Double {
        OCCTPoint2DGetX(handle)
    }

    /// The Y coordinate.
    public var y: Double {
        OCCTPoint2DGetY(handle)
    }

    /// The coordinates as a SIMD2 vector.
    public var coords: SIMD2<Double> {
        SIMD2(x, y)
    }

    /// The position as a SIMD2 vector (alias for coords).
    public var position: SIMD2<Double> {
        SIMD2(x, y)
    }

    // MARK: - Mutation

    /// Set both coordinates.
    public func setCoords(x: Double, y: Double) {
        OCCTPoint2DSetCoords(handle, x, y)
    }

    // MARK: - Distance

    /// Euclidean distance to another point.
    public func distance(to other: Point2D) -> Double {
        OCCTPoint2DDistance(handle, other.handle)
    }

    /// Squared distance to another point (avoids sqrt).
    public func squareDistance(to other: Point2D) -> Double {
        OCCTPoint2DSquareDistance(handle, other.handle)
    }

    /// Minimum distance from this point to a 2D curve.
    ///
    /// - Parameter curve: Curve to measure to.
    /// - Returns: The distance to the nearest point of the curve, or `.infinity` if there is no
    ///   curve to measure to.
    ///
    /// Measured over the curve's own domain, ends included, so it is the true minimum rather than
    /// the nearest perpendicular foot. A point beyond the end of a bounded curve is measured to
    /// that end, and a circle's centre to the radius. Agrees exactly with
    /// `Curve2D.project(point:)` and `Curve2D.nearestParameter(to:)`, which share its bridge path.
    ///
    /// ```swift
    /// let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
    /// let above = Point2D(x: 5, y: 3)!
    /// #expect(abs(above.distance(to: segment) - 3) < 1e-9)
    ///
    /// let pastTheEnd = Point2D(x: 100, y: 0)!
    /// #expect(pastTheEnd.distance(to: segment) == 90)   // to the end at (10, 0)
    /// ```
    ///
    /// Two sentinels have been retired from this one method. It first returned the bridge's raw
    /// `-1` for a point with no perpendicular foot, which any threshold test (`distance < tolerance`)
    /// read as "touching" — the opposite of the truth (#413). `.infinity` replaced it, which was
    /// safe but still discarded a real, finite distance; #615 measures it instead. `.infinity` now
    /// means only that the curve could not be read at all.
    public func distance(to curve: Curve2D) -> Double {
        let d = OCCTPoint2DDistanceToCurve(handle, curve.handle)
        return d < 0 ? .infinity : d
    }

    // MARK: - Transforms (return new Point2D)

    /// Translate by (dx, dy), returns a new point.
    public func translated(dx: Double, dy: Double) -> Point2D? {
        guard let h = OCCTPoint2DTranslated(handle, dx, dy) else { return nil }
        return Point2D(handle: h)
    }

    /// Rotate around a center by angle (radians), returns a new point.
    public func rotated(center: SIMD2<Double>, angle: Double) -> Point2D? {
        guard let h = OCCTPoint2DRotated(handle, center.x, center.y, angle) else { return nil }
        return Point2D(handle: h)
    }

    /// Scale from a center by factor, returns a new point.
    public func scaled(center: SIMD2<Double>, factor: Double) -> Point2D? {
        guard let h = OCCTPoint2DScaled(handle, center.x, center.y, factor) else { return nil }
        return Point2D(handle: h)
    }

    /// Mirror across a point, returns a new point.
    public func mirrored(point: SIMD2<Double>) -> Point2D? {
        guard let h = OCCTPoint2DMirroredPoint(handle, point.x, point.y) else { return nil }
        return Point2D(handle: h)
    }

    /// Mirror across an axis (origin + direction), returns a new point.
    public func mirrored(axisOrigin: SIMD2<Double>, axisDirection: SIMD2<Double>) -> Point2D? {
        guard
            let h = OCCTPoint2DMirroredAxis(
                handle, axisOrigin.x, axisOrigin.y,
                axisDirection.x, axisDirection.y)
        else { return nil }
        return Point2D(handle: h)
    }

    /// Translate by a vector, returns a new point.
    public func translated(by delta: SIMD2<Double>) -> Point2D? {
        translated(dx: delta.x, dy: delta.y)
    }

    /// Apply a 2D transformation, returns a new point.
    public func transformed(by transform: Transform2D) -> Point2D? {
        guard let h = OCCTPoint2DTransformed(handle, transform.handle) else { return nil }
        return Point2D(handle: h)
    }
}
