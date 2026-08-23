import Foundation
import OCCTBridge
import simd

/// 2D conic section coefficient representation.
///
/// The coefficients are OCCT's, in OCCT's order: the conic is the point set satisfying
/// `a·x² + b·y² + 2c·x·y + 2d·x + 2e·y + f = 0`.
///
/// Note that b is the y² coefficient and c.
/// the `x·y` one, and that the cross and linear terms carry a factor of 2.
///
/// ```swift.
/// // The circle of radius 5 about the origin: x² + y² - 25 = 0
/// if let c = Conic2D.circle(center: .zero, direction: SIMD2(1, 0), radius: 5) {
///     print(c.a, c.b, c.c, c.f)   // 1.0 1.0 0.0 -25.0.
/// }.
/// ```.
public struct Conic2D: Sendable {
    /// Coefficients a, b, c, d, e, f of `a*x^2 + b*y^2 + 2c*x*y + 2d*x + 2e*y + f = 0`.
    public let a, b, c, d, e, f: Double

    /// The implicit conic of a 2D circle, or nil if the circle is degenerate.
    ///
    /// - Parameters:
    ///   - center: circle centre.
    ///   - direction: local X axis direction.
    ///
    ///   Must be non-zero.
    ///   - radius: circle radius.
    ///
    ///   Must be greater than zero.
    /// - Returns: the six implicit coefficients, or nil when a dimension is degenerate.
    ///
    /// ```swift.
    /// if let c = Conic2D.circle(center: .zero, direction: SIMD2(1, 0), radius: 3) {
    ///     print(c.a, c.b, c.f)   // 1.0 1.0 -9.0.
    /// }.
    /// ```.
    public static func circle(
        center: SIMD2<Double>, direction: SIMD2<Double>, radius: Double
    ) -> Conic2D? {
        var coeffs = [Double](repeating: 0, count: 6)
        guard
            OCCTConic2dFromCircle(
                center.x, center.y, direction.x, direction.y,
                radius, &coeffs)
        else { return nil }
        return Conic2D(
            a: coeffs[0], b: coeffs[1], c: coeffs[2],
            d: coeffs[3], e: coeffs[4], f: coeffs[5])
    }

    /// The implicit conic of a 2D line, or nil if the direction is degenerate.
    ///
    /// - Parameters:
    ///   - point: any point on the line.
    ///   - direction: line direction.
    ///
    ///   Must be non-zero.
    /// - Returns: the six implicit coefficients, or nil for a zero direction.
    ///
    /// ```swift.
    /// if let l = Conic2D.line(point: .zero, direction: SIMD2(1, 0)) {
    ///     print(l.e)   // non-zero: the y term of the line y = 0
    /// }.
    /// ```.
    public static func line(
        point: SIMD2<Double>, direction: SIMD2<Double>
    ) -> Conic2D? {
        var coeffs = [Double](repeating: 0, count: 6)
        guard
            OCCTConic2dFromLine(
                point.x, point.y, direction.x, direction.y,
                &coeffs)
        else { return nil }
        return Conic2D(
            a: coeffs[0], b: coeffs[1], c: coeffs[2],
            d: coeffs[3], e: coeffs[4], f: coeffs[5])
    }

    /// The implicit conic of a 2D ellipse, or nil if the ellipse is degenerate.
    ///
    /// - Parameters:
    ///   - center: ellipse centre.
    ///   - direction: local X axis, along the major radius.
    ///
    ///   Must be non-zero.
    ///   - majorRadius: semi-major axis.
    ///
    ///   Must be greater than zero.
    ///   - minorRadius: semi-minor axis.
    ///
    ///   Must be greater than zero and no larger than.
    ///     majorRadius; equal radii are a circle and are valid.
    /// - Returns: the six implicit coefficients, or nil when a dimension is degenerate.
    ///
    /// ```swift.
    /// if let e = Conic2D.ellipse(center: .zero, direction: SIMD2(1, 0),
    ///                            majorRadius: 5, minorRadius: 3) {
    ///     print(e.a, e.b, e.f)   // 0.04 0.111... -1.0  (x²/25 + y²/9 - 1 = 0).
    /// }.
    /// ```.
    public static func ellipse(
        center: SIMD2<Double>, direction: SIMD2<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> Conic2D? {
        var coeffs = [Double](repeating: 0, count: 6)
        guard
            OCCTConic2dFromEllipse(
                center.x, center.y, direction.x, direction.y,
                majorRadius, minorRadius, &coeffs)
        else { return nil }
        return Conic2D(
            a: coeffs[0], b: coeffs[1], c: coeffs[2],
            d: coeffs[3], e: coeffs[4], f: coeffs[5])
    }

    /// Intersect a 2D line with a 2D circle.
    ///
    /// - Parameter radius: circle radius.
    ///
    /// Must be greater than zero; a radius of zero is a.
    ///   point-on-line test, not an intersection, and returns an empty array.
    /// - Returns: 0, 1, or 2 intersection points.
    ///
    /// ```swift.
    /// let pts = Conic2D.lineCircleIntersection(.
    ///     linePoint: SIMD2(-5, 0), lineDir: SIMD2(1, 0),
    ///     circleCenter: .zero, circleDir: SIMD2(1, 0), radius: 3)
    /// // pts.count == 2 → [-3, 0] and [3, 0].
    /// ```.
    public static func lineCircleIntersection(
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        circleCenter: SIMD2<Double>, circleDir: SIMD2<Double>, radius: Double
    ) -> [SIMD2<Double>] {
        var xs = [Double](repeating: 0, count: 10)
        var ys = [Double](repeating: 0, count: 10)
        let n = OCCTConic2dLineCircleIntersect(
            linePoint.x, linePoint.y, lineDir.x, lineDir.y,
            circleCenter.x, circleCenter.y, circleDir.x, circleDir.y, radius,
            &xs, &ys, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { SIMD2(xs[$0], ys[$0]) }
    }
}
