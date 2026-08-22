import Foundation
import OCCTBridge
import simd

/// A parametric 2D curve backed by `Geom2d_Curve`.
///
/// `Curve2D` wraps the full OpenCASCADE `Geom2d` package polymorphically:
/// lines, segments, circles, arcs, ellipses, parabolas, hyperbolas,
/// B-splines, and Bezier curves are all represented by this single type.
///
/// ## Creating Curves
///
/// ```swift
/// let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))
/// let circle = Curve2D.circle(center: .zero, radius: 5)
/// let arc = Curve2D.arcOfCircle(center: .zero, radius: 5,
///                               startAngle: 0, endAngle: .pi / 2)
/// ```
///
/// ## Discretizing for Metal Rendering
///
/// ```swift
/// let polyline = circle!.drawAdaptive()  // → [SIMD2<Double>]
/// let uniform  = circle!.drawUniform(pointCount: 64)
/// ```
public final class Curve2D: @unchecked Sendable {
    internal let handle: OCCTCurve2DRef

    internal init(handle: OCCTCurve2DRef) {
        self.handle = handle
    }

    deinit {
        OCCTCurve2DRelease(handle)
    }

    // MARK: - Properties

    /// The parameter domain of the curve as a closed range `[first, last]`.
    public var domain: ClosedRange<Double> {
        var first: Double = 0
        var last: Double = 0
        OCCTCurve2DGetDomain(handle, &first, &last)
        return first...last
    }

    /// Whether the curve forms a closed loop.
    public var isClosed: Bool {
        OCCTCurve2DIsClosed(handle)
    }

    /// Whether the curve is periodic (e.g. a full circle or ellipse).
    public var isPeriodic: Bool {
        OCCTCurve2DIsPeriodic(handle)
    }

    /// The period of the curve, or `nil` if the curve is not periodic.
    public var period: Double? {
        guard isPeriodic else { return nil }
        return OCCTCurve2DGetPeriod(handle)
    }

    /// The point at the start of the parameter domain.
    public var startPoint: SIMD2<Double> {
        point(at: domain.lowerBound)
    }

    /// The point at the end of the parameter domain.
    public var endPoint: SIMD2<Double> {
        point(at: domain.upperBound)
    }

    // MARK: - Evaluation

    /// Evaluate the curve position at parameter `u`.
    public func point(at u: Double) -> SIMD2<Double> {
        var x: Double = 0
        var y: Double = 0
        OCCTCurve2DGetPoint(handle, u, &x, &y)
        return SIMD2(x, y)
    }

    /// Evaluate position and first derivative (tangent) at parameter `u`.
    public func d1(at u: Double) -> (point: SIMD2<Double>, tangent: SIMD2<Double>) {
        var px: Double = 0
        var py: Double = 0
        var vx: Double = 0
        var vy: Double = 0
        OCCTCurve2DD1(handle, u, &px, &py, &vx, &vy)
        return (SIMD2(px, py), SIMD2(vx, vy))
    }

    /// Evaluate position, first derivative, and second derivative at parameter `u`.
    public func d2(at u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>, d2: SIMD2<Double>) {
        var px: Double = 0
        var py: Double = 0
        var v1x: Double = 0
        var v1y: Double = 0
        var v2x: Double = 0
        var v2y: Double = 0
        OCCTCurve2DD2(handle, u, &px, &py, &v1x, &v1y, &v2x, &v2y)
        return (SIMD2(px, py), SIMD2(v1x, v1y), SIMD2(v2x, v2y))
    }

    // MARK: - Primitive Curves

    /// Create an infinite line through a point in a given direction.
    public static func line(through point: SIMD2<Double>, direction: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTCurve2DCreateLine(point.x, point.y, direction.x, direction.y) else {
            return nil
        }
        return Curve2D(handle: h)
    }

    /// Create a line segment between two points.
    public static func segment(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTCurve2DCreateSegment(p1.x, p1.y, p2.x, p2.y) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a full circle.
    ///
    /// - Parameters:
    ///   - center: Circle centre.
    ///   - radius: Circle radius. Must be `> 0`; zero and negative radii return `nil`.
    /// - Returns: The circle, or `nil` if `radius <= 0`.
    ///
    /// `circleFromCenterRadius(center:radius:)` builds the identical circle through OCCT's
    /// `gce_MakeCirc2d` algorithm and enforces the same radius contract.
    ///
    /// ```swift
    /// let c = Curve2D.circle(center: .zero, radius: 5)
    /// #expect(c?.isPeriodic == true)
    /// #expect(Curve2D.circle(center: .zero, radius: 0) == nil)
    /// ```
    public static func circle(center: SIMD2<Double>, radius: Double) -> Curve2D? {
        guard let h = OCCTCurve2DCreateCircle(center.x, center.y, radius) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create an arc of a circle between two angles (in radians).
    public static func arcOfCircle(
        center: SIMD2<Double>, radius: Double,
        startAngle: Double, endAngle: Double
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DCreateArcOfCircle(
                center.x, center.y, radius,
                startAngle, endAngle)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a circular arc passing through three points.
    public static func arcThrough(
        _ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
        _ p3: SIMD2<Double>
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DCreateArcThrough(
                p1.x, p1.y, p2.x, p2.y,
                p3.x, p3.y)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a circle involute curve (gear tooth profile).
    ///
    /// The involute is defined by C(t) = O + R*(cos(t) + t*sin(t))*XDir + R*(sin(t) - t*cos(t))*YDir
    /// where O is the origin, XDir/YDir form the placement coordinate system, and R is the base radius.
    ///
    /// - Parameters:
    ///   - origin: The origin point O of the involute's coordinate system.
    ///   - direction: The X direction vector (YDir is computed as perpendicular, i.e., rotated 90° CCW).
    ///   - radius: The base circle radius. Must be `> 0`; zero and negative radii return `nil`.
    /// - Returns: The circle involute curve, or `nil` if `radius <= 0`.
    ///
    /// ```swift
    /// // Standard involute at origin with X axis
    /// let involute = Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: 5)
    ///
    /// // Involute at (10, 20) rotated 45 degrees
    /// let angle = .pi / 4
    /// let dir = SIMD2(cos(angle), sin(angle))
    /// let involute = Curve2D.circleInvolute(origin: SIMD2(10, 20), direction: dir, radius: 5)
    ///
    /// // Mirror for opposite flank (negate X direction to flip YDir)
    /// let mirrored = Curve2D.circleInvolute(origin: .zero, direction: SIMD2(-1, 0), radius: 5)
    /// // YDir becomes (0, -1) - this produces the mirrored flank
    /// ```
    public static func circleInvolute(
        origin: SIMD2<Double>, direction: SIMD2<Double>,
        radius: Double
    ) -> Curve2D? {
        guard radius > 0 else { return nil }
        let dirLen = hypot(direction.x, direction.y)
        guard dirLen > 1e-12 else { return nil }
        let normDir = SIMD2(direction.x / dirLen, direction.y / dirLen)
        guard
            let ref = OCCTGeom2dEvalCircleInvoluteCurveCreate(
                origin.x, origin.y,
                normDir.x, normDir.y,
                radius)
        else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a full ellipse.
    ///
    /// - Parameters:
    ///   - center: Center point
    ///   - majorRadius: Semi-major axis length. Must be `> 0` and `>= minorRadius`.
    ///   - minorRadius: Semi-minor axis length. Must be `> 0`.
    ///   - rotation: Rotation of the major axis from the X axis (radians)
    /// - Returns: The ellipse, or `nil` if either radius is not positive or `minorRadius` exceeds
    ///   `majorRadius`.
    ///
    /// ```swift
    /// let e = Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5)
    /// #expect(e != nil)
    /// #expect(Curve2D.ellipse(center: .zero, majorRadius: 0, minorRadius: 0) == nil)
    /// #expect(Curve2D.ellipse(center: .zero, majorRadius: 5, minorRadius: 10) == nil)
    /// ```
    public static func ellipse(
        center: SIMD2<Double>, majorRadius: Double,
        minorRadius: Double, rotation: Double = 0
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DCreateEllipse(
                center.x, center.y,
                majorRadius, minorRadius, rotation)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Create an arc of an ellipse between two angles.
    public static func arcOfEllipse(
        center: SIMD2<Double>, majorRadius: Double,
        minorRadius: Double, rotation: Double = 0,
        startAngle: Double, endAngle: Double
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DCreateArcOfEllipse(
                center.x, center.y,
                majorRadius, minorRadius, rotation,
                startAngle, endAngle)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a parabola.
    ///
    /// - Parameters:
    ///   - focus: Focus point of the parabola
    ///   - direction: Axis direction (from vertex toward focus)
    ///   - focalLength: Distance from vertex to focus. Must be `> 0`; at zero the parabola
    ///     degenerates into a line parallel to its own axis.
    /// - Returns: The parabola, or `nil` if `focalLength <= 0`.
    ///
    /// ```swift
    /// let p = Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 1)
    /// #expect(p != nil)
    /// #expect(Curve2D.parabola(focus: .zero, direction: SIMD2(1, 0), focalLength: 0) == nil)
    /// ```
    public static func parabola(
        focus: SIMD2<Double>, direction: SIMD2<Double>,
        focalLength: Double
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DCreateParabola(
                focus.x, focus.y,
                direction.x, direction.y,
                focalLength)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a hyperbola.
    ///
    /// Unlike an ellipse, a hyperbola puts no ordering on its radii: a minor radius larger than the
    /// major one is an ordinary hyperbola and is accepted.
    ///
    /// - Parameters:
    ///   - center: Center point
    ///   - majorRadius: Semi-major axis length. Must be `> 0`.
    ///   - minorRadius: Semi-minor axis length. Must be `> 0`.
    ///   - rotation: Rotation of the major axis from the X axis (radians)
    /// - Returns: The hyperbola, or `nil` if either radius is not positive.
    ///
    /// ```swift
    /// let h = Curve2D.hyperbola(center: .zero, majorRadius: 5, minorRadius: 3)
    /// #expect(h != nil)
    /// #expect(Curve2D.hyperbola(center: .zero, majorRadius: 3, minorRadius: 5) != nil)
    /// #expect(Curve2D.hyperbola(center: .zero, majorRadius: 0, minorRadius: 0) == nil)
    /// ```
    public static func hyperbola(
        center: SIMD2<Double>, majorRadius: Double,
        minorRadius: Double, rotation: Double = 0
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DCreateHyperbola(
                center.x, center.y,
                majorRadius, minorRadius, rotation)
        else { return nil }
        return Curve2D(handle: h)
    }

    // MARK: - Draw (Discretization for Metal)

    /// Adaptively discretize the curve using angular and chordal deflection criteria.
    ///
    /// Produces more points where curvature is high and fewer where the curve is straight.
    /// - Parameters:
    ///   - angularDeflection: Maximum angular deflection in radians (default 0.1)
    ///   - chordalDeflection: Maximum chordal deflection (default 0.01)
    ///   - maxPoints: Output *capacity* (default 4096), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#558). The deflection
    ///     criteria decide the actual point count, so clamping an unservable capacity returns the
    ///     same points rather than a coarser sampling.
    /// - Returns: Array of 2D points approximating the curve
    public func drawAdaptive(
        angularDeflection: Double = 0.1,
        chordalDeflection: Double = 0.01,
        maxPoints: Int = 4096
    ) -> [SIMD2<Double>] {
        let capacity = Sampling.capacity(maxPoints)
        guard capacity > 0 else { return [] }
        var buffer = [Double](repeating: 0, count: capacity * 2)
        let n = Int(
            OCCTCurve2DDrawAdaptive(
                handle, angularDeflection, chordalDeflection,
                &buffer, Int32(capacity)))
        return (0..<n).map { SIMD2(buffer[$0 * 2], buffer[$0 * 2 + 1]) }
    }

    /// Discretize the curve with at most `pointCount` uniformly-spaced-by-arc-length points.
    ///
    /// The first point is always the start of the curve and the last is always its end.
    ///
    /// ```swift
    /// let seg = Curve2D.segment(from: .zero, to: SIMD2(10, 0))!
    /// let pts = seg.drawUniform(pointCount: 11)
    /// // pts[5] ≈ SIMD2(5, 0)
    /// ```
    ///
    /// - Parameter pointCount: Desired number of output points, honoured within `2...`
    ///   ``Sampling/maximumSampleCount``; outside that range the result is empty. This is a
    ///   *request*, so a count past the ceiling fails visibly rather than coming back coarser
    ///   than what was asked for (#558). Before that bound the documented "at least 2, else
    ///   empty" was only true of counts down to 0: a negative aborted the process.
    /// - Returns: Array of 2D points, never more than `pointCount` of them, or empty on failure
    public func drawUniform(pointCount: Int) -> [SIMD2<Double>] {
        guard let pointCount = Sampling.requested(pointCount) else { return [] }
        var buffer = [Double](repeating: 0, count: pointCount * 2)
        let n = Int(OCCTCurve2DDrawUniform(handle, Int32(pointCount), &buffer))
        return (0..<n).map { SIMD2(buffer[$0 * 2], buffer[$0 * 2 + 1]) }
    }

    /// Discretize the curve with a maximum chordal deflection.
    ///
    /// - Parameters:
    ///   - deflection: Maximum distance between the curve and the chord joining two consecutive
    ///     output points.
    ///   - maxPoints: Output *capacity* (default 4096), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#558).
    /// - Returns: The sampled points, or an empty array if the sampler fails.
    public func drawDeflection(
        deflection: Double = 0.01,
        maxPoints: Int = 4096
    ) -> [SIMD2<Double>] {
        let capacity = Sampling.capacity(maxPoints)
        guard capacity > 0 else { return [] }
        var buffer = [Double](repeating: 0, count: capacity * 2)
        let n = Int(OCCTCurve2DDrawDeflection(handle, deflection, &buffer, Int32(capacity)))
        return (0..<n).map { SIMD2(buffer[$0 * 2], buffer[$0 * 2 + 1]) }
    }

    // MARK: - BSpline & Bezier

    /// Create a B-spline curve from control points, knots, and multiplicities.
    public static func bspline(
        poles: [SIMD2<Double>], weights: [Double]? = nil,
        knots: [Double], multiplicities: [Int32],
        degree: Int
    ) -> Curve2D? {
        let flatPoles = poles.flatMap { [$0.x, $0.y] }
        let h = flatPoles.withUnsafeBufferPointer { polesPtr in
            knots.withUnsafeBufferPointer { knotsPtr in
                multiplicities.withUnsafeBufferPointer { multsPtr in
                    if let w = weights {
                        return w.withUnsafeBufferPointer { wPtr in
                            OCCTCurve2DCreateBSpline(
                                polesPtr.baseAddress, Int32(poles.count),
                                wPtr.baseAddress,
                                knotsPtr.baseAddress, Int32(knots.count),
                                multsPtr.baseAddress, Int32(degree))
                        }
                    } else {
                        return OCCTCurve2DCreateBSpline(
                            polesPtr.baseAddress, Int32(poles.count),
                            nil,
                            knotsPtr.baseAddress, Int32(knots.count),
                            multsPtr.baseAddress, Int32(degree))
                    }
                }
            }
        }
        guard let h = h else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a Bezier curve from control points with optional weights.
    public static func bezier(poles: [SIMD2<Double>], weights: [Double]? = nil) -> Curve2D? {
        let flatPoles = poles.flatMap { [$0.x, $0.y] }
        let h: OCCTCurve2DRef?
        if let w = weights {
            h = flatPoles.withUnsafeBufferPointer { pp in
                w.withUnsafeBufferPointer { wp in
                    OCCTCurve2DCreateBezier(pp.baseAddress, Int32(poles.count), wp.baseAddress)
                }
            }
        } else {
            h = flatPoles.withUnsafeBufferPointer { pp in
                OCCTCurve2DCreateBezier(pp.baseAddress, Int32(poles.count), nil)
            }
        }
        guard let h = h else { return nil }
        return Curve2D(handle: h)
    }

    /// Interpolate a smooth B-spline curve through the given points.
    ///
    /// - Parameters:
    ///   - points: Points to interpolate. At least 2.
    ///   - closed: Pass `true` for a periodic loop that closes back to `points[0]`; do not repeat
    ///     the first point at the end. `interpolatePeriodic(points:tolerance:)` is a spelling of
    ///     this case and delegates here.
    ///   - tolerance: Interpolation tolerance.
    /// - Returns: The interpolated curve, or `nil` if interpolation fails.
    ///
    /// ```swift
    /// let open = Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(5, 3), SIMD2(10, 0)])
    /// #expect(open?.isPeriodic == false)
    ///
    /// let loop = Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(5, 8)],
    ///                                closed: true, tolerance: 1e-4)
    /// #expect(loop?.isPeriodic == true)
    /// ```
    public static func interpolate(
        through points: [SIMD2<Double>], closed: Bool = false,
        tolerance: Double = 1e-6
    ) -> Curve2D? {
        let flat = points.flatMap { [$0.x, $0.y] }
        guard
            let h = flat.withUnsafeBufferPointer({ ptr in
                OCCTCurve2DInterpolate(ptr.baseAddress, Int32(points.count), closed, tolerance)
            })
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Interpolate through points with specified start and end tangents.
    ///
    /// `interpolate(points:startTangent:endTangent:tolerance:)` is a spelling of this with the
    /// `points:` argument label, and delegates here.
    public static func interpolate(
        through points: [SIMD2<Double>],
        startTangent: SIMD2<Double>,
        endTangent: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> Curve2D? {
        let flat = points.flatMap { [$0.x, $0.y] }
        guard
            let h = flat.withUnsafeBufferPointer({ ptr in
                OCCTCurve2DInterpolateWithTangents(
                    ptr.baseAddress, Int32(points.count),
                    startTangent.x, startTangent.y,
                    endTangent.x, endTangent.y, tolerance)
            })
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Interpolate through points with per-point tangent constraints at arbitrary indices.
    ///
    /// Use this when you need tangent continuity at specific interior transition points,
    /// for example where a straight section meets a circular arc in a composite curve.
    ///
    /// - Parameters:
    ///   - points: The interpolation points the curve must pass through.
    ///   - tangents: A dictionary mapping point index → unit tangent direction.
    ///               Indices not present in the dictionary are unconstrained (C2 computed).
    ///   - closed: Whether the resulting curve should be closed/periodic.
    ///   - tolerance: Point coincidence tolerance (default 1e-6).
    /// - Returns: A B-spline interpolating curve, or `nil` on failure.
    /// - Note: Resolves GitHub issue #38.
    public static func interpolate(
        through points: [SIMD2<Double>],
        tangents: [Int: SIMD2<Double>],
        closed: Bool = false,
        tolerance: Double = 1e-6
    ) -> Curve2D? {
        guard points.count >= 2 else { return nil }
        let n = points.count
        let flatPoints = points.flatMap { [$0.x, $0.y] }
        // Build parallel tangent and flag arrays
        var flatTangents = [Double](repeating: 0, count: n * 2)
        var flags = [Bool](repeating: false, count: n)
        for (idx, tan) in tangents where idx >= 0 && idx < n {
            flatTangents[idx * 2] = tan.x
            flatTangents[idx * 2 + 1] = tan.y
            flags[idx] = true
        }
        guard
            let h = flatPoints.withUnsafeBufferPointer({ ptsPtr in
                flatTangents.withUnsafeBufferPointer { tanPtr in
                    flags.withUnsafeBufferPointer { flagPtr in
                        OCCTCurve2DInterpolateWithInteriorTangents(
                            ptsPtr.baseAddress, Int32(n),
                            tanPtr.baseAddress, flagPtr.baseAddress,
                            closed, tolerance)
                    }
                }
            })
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Approximate a B-spline curve fitting through points within tolerance.
    public static func fit(
        through points: [SIMD2<Double>], minDegree: Int = 3,
        maxDegree: Int = 8, tolerance: Double = 1e-3
    ) -> Curve2D? {
        let flat = points.flatMap { [$0.x, $0.y] }
        guard
            let h = flat.withUnsafeBufferPointer({ ptr in
                OCCTCurve2DFitPoints(
                    ptr.baseAddress, Int32(points.count),
                    Int32(minDegree), Int32(maxDegree), tolerance)
            })
        else { return nil }
        return Curve2D(handle: h)
    }

    // MARK: - BSpline Queries

    /// The number of control points (poles), or `nil` if not a BSpline/Bezier.
    public var poleCount: Int? {
        let n = Int(OCCTCurve2DGetPoleCount(handle))
        return n > 0 ? n : nil
    }

    /// The control points (poles), or `nil` if not a BSpline/Bezier.
    public var poles: [SIMD2<Double>]? {
        guard let count = poleCount else { return nil }
        var buffer = [Double](repeating: 0, count: count * 2)
        let n = Int(OCCTCurve2DGetPoles(handle, &buffer))
        guard n > 0 else { return nil }
        return (0..<n).map { SIMD2(buffer[$0 * 2], buffer[$0 * 2 + 1]) }
    }

    /// The curve degree, or `nil` if not a BSpline/Bezier.
    public var degree: Int? {
        let d = Int(OCCTCurve2DGetDegree(handle))
        return d >= 0 ? d : nil
    }

    // MARK: - Operations

    /// Create a trimmed copy of this curve between parameters `from` and `to`.
    public func trimmed(from u1: Double, to u2: Double) -> Curve2D? {
        guard let h = OCCTCurve2DTrim(handle, u1, u2) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create an offset curve at the given distance.
    ///
    /// Positive distance offsets to the left of the curve direction.
    public func offset(by distance: Double) -> Curve2D? {
        guard let h = OCCTCurve2DOffset(handle, distance) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a reversed copy of this curve (parameter direction flipped).
    public func reversed() -> Curve2D? {
        guard let h = OCCTCurve2DReversed(handle) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a translated copy of this curve.
    public func translated(by delta: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTCurve2DTranslate(handle, delta.x, delta.y) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a rotated copy of this curve.
    public func rotated(around center: SIMD2<Double>, angle: Double) -> Curve2D? {
        guard let h = OCCTCurve2DRotate(handle, center.x, center.y, angle) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a scaled copy of this curve.
    public func scaled(from center: SIMD2<Double>, factor: Double) -> Curve2D? {
        guard let h = OCCTCurve2DScale(handle, center.x, center.y, factor) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a copy mirrored across an axis line.
    public func mirrored(acrossLine point: SIMD2<Double>, direction: SIMD2<Double>) -> Curve2D? {
        guard
            let h = OCCTCurve2DMirrorAxis(
                handle, point.x, point.y,
                direction.x, direction.y)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a copy mirrored across a point.
    public func mirrored(acrossPoint point: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTCurve2DMirrorPoint(handle, point.x, point.y) else { return nil }
        return Curve2D(handle: h)
    }

    /// The total arc length of the curve, or `nil` on error.
    ///
    /// Measured per `GeomAbs_CN` interval and subdivided until two successive levels agree to
    /// 1e-9 relative. A whole 2D ellipse used to measure 0.337% long on the single Gauss
    /// quadrature `GCPnts_AbscissaPoint::Length` hands a one-interval curve, the same defect and
    /// the same numbers as the 3D spelling, since both reach one shared template (#603).
    ///
    /// ```swift
    /// let e = Curve2D.ellipse(center: .zero, majorRadius: 8, minorRadius: 3)!
    /// let circumference = e.length!   // 36.36686, not 36.48943
    /// ```
    public var length: Double? {
        let l = OCCTCurve2DGetLength(handle)
        return l >= 0 ? l : nil
    }

    /// Arc length between two parameter values.
    ///
    /// This is the canonical, failure-distinguishing entry point: `nil` when the computation
    /// fails, rather than a number that could be mistaken for a real zero-length segment.
    /// `arcLength(from:to:)` delegates to this and collapses failure back to `-1.0`.
    ///
    /// The range may be given in either order; equal parameters measure `0`.
    ///
    /// Both bounds must also be finite: `.nan` and `±.infinity` report `nil`. OCCT's integrator
    /// does not check them itself, and on a multi-span BSpline a NaN upper bound measured `0`
    /// and a NaN lower bound the curve's whole length; see ``Curve3D/length(from:to:)`` for the
    /// mechanism (#548).
    ///
    /// A range reaching outside the curve's domain measures the part of it that lies on the curve,
    /// so a range wholly outside measures `0`. A curve whose domain covers a whole period exists at
    /// every parameter, so a periodic one measures the whole range and winds (#600). The 3D
    /// spelling answers identically on the same geometry.
    ///
    /// ```swift
    /// let c = Curve2D.interpolate(through: [SIMD2(0, 0), SIMD2(10, 5), SIMD2(20, 0)])!
    /// let d = c.domain
    /// let half = c.length(from: d.lowerBound, to: (d.lowerBound + d.upperBound) / 2)
    /// let bad = c.length(from: d.lowerBound, to: .nan)   // nil
    ///
    /// let circle = Curve2D.circle(center: .zero, radius: 5)!
    /// let quarter = circle.length(from: 0, to: .pi / 2)   // ≈ 7.854
    /// let reversed = circle.length(from: .pi / 2, to: 0)  // the same 7.854
    /// let two = circle.length(from: 0, to: 4 * .pi)       // two circumferences
    /// ```
    public func length(from u1: Double, to u2: Double) -> Double? {
        let l = OCCTCurve2DGetLengthBetween(handle, u1, u2)
        return l >= 0 ? l : nil
    }

    /// Returns the curve parameter at the given arc-length distance from `fromParameter`.
    ///
    /// Use this to trim a curve to a specific arc length, or to place features at
    /// measured positions along a composite curve.
    ///
    /// - Parameters:
    ///   - arcLength: The desired arc-length distance to travel from `fromParameter`.
    ///                May be negative to travel in the reverse direction.
    ///   - fromParameter: The starting parameter. Defaults to `domain.lowerBound`
    ///                    (the start of the curve).
    /// - Returns: The parameter value at the given arc-length distance,
    ///            or `nil` if the computation fails (e.g. distance exceeds the curve).
    /// - Note: Shares the subdivided measurement with `length`, so the two agree:
    ///         `curve.parameterAtLength(curve.length!)` lands on `domain.upperBound`. OCCT's own
    ///         root finder inverts a single quadrature and would not (#603).
    /// - Note: Resolves GitHub issue #37.
    public func parameterAtLength(_ arcLength: Double, from fromParameter: Double? = nil) -> Double?
    {
        let start = fromParameter ?? domain.lowerBound
        let result = OCCTCurve2DParameterAtLength(handle, arcLength, start)
        return result > -Double.greatestFiniteMagnitude ? result : nil
    }

    // MARK: - Local Properties (Curvature, Normal, Inflection)

    /// The curvature (1/radius) at parameter `u`, or `nil` where the curve has none.
    ///
    /// - Parameter u: Curve parameter.
    /// - Returns: The curvature (`0` for a straight segment, which is a real answer), or `nil` at
    ///   a parameter the curve cannot be evaluated at and where
    ///   `GeomLProp_CLProps2d::IsTangentDefined()` is false. Straight and undefined used to be the
    ///   same `0` (#595).
    ///
    /// A **cusp** is still reported, as `Double.greatestFiniteMagnitude` (OCCT's `RealLast()`,
    /// meaning infinite curvature): an answer, not an absence. Matches ``Curve3D/curvature(at:)``.
    ///
    /// ```swift
    /// let circle = Curve2D.circle(center: .zero, radius: 4)!
    /// if let k = circle.curvature(at: 1) { #expect(abs(k - 0.25) < 1e-12) }
    /// ```
    public func curvature(at u: Double) -> Double? {
        var k = 0.0
        guard OCCTCurve2DGetCurvature(handle, u, &k) else { return nil }
        return k
    }

    /// The unit normal vector at parameter `u`, or `nil` if undefined (e.g. on a straight line).
    public func normal(at u: Double) -> SIMD2<Double>? {
        var nx: Double = 0
        var ny: Double = 0
        guard OCCTCurve2DGetNormal(handle, u, &nx, &ny) else { return nil }
        return SIMD2(nx, ny)
    }

    /// The unit tangent direction at parameter `u`, or `nil` if undefined.
    public func tangentDirection(at u: Double) -> SIMD2<Double>? {
        var tx: Double = 0
        var ty: Double = 0
        guard OCCTCurve2DGetTangentDir(handle, u, &tx, &ty) else { return nil }
        return SIMD2(tx, ty)
    }

    /// The center of curvature (osculating circle center) at parameter `u`,
    /// or `nil` if curvature is zero (straight segment).
    public func centerOfCurvature(at u: Double) -> SIMD2<Double>? {
        var cx: Double = 0
        var cy: Double = 0
        guard OCCTCurve2DGetCenterOfCurvature(handle, u, &cx, &cy) else { return nil }
        return SIMD2(cx, cy)
    }

    /// Find all inflection points (where curvature changes sign).
    ///
    /// Returns an array of parameter values.
    public func inflectionPoints() -> [Double] {
        var buffer = [Double](repeating: 0, count: 256)
        let n = Int(OCCTCurve2DGetInflectionPoints(handle, &buffer, 256))
        return Array(buffer.prefix(n))
    }

    /// Find curvature extrema (local min/max of curvature magnitude).
    public func curvatureExtrema() -> [Curve2DSpecialPoint] {
        var buffer = [OCCTCurve2DCurvePoint](repeating: OCCTCurve2DCurvePoint(), count: 256)
        let n = Int(OCCTCurve2DGetCurvatureExtrema(handle, &buffer, 256))
        return (0..<n).map {
            Curve2DSpecialPoint(
                parameter: buffer[$0].parameter,
                type: Curve2DSpecialPointType(rawValue: buffer[$0].type) ?? .minCurvature)
        }
    }

    /// Find all special points: inflection points and curvature extrema.
    public func allSpecialPoints() -> [Curve2DSpecialPoint] {
        var buffer = [OCCTCurve2DCurvePoint](repeating: OCCTCurve2DCurvePoint(), count: 256)
        let n = Int(OCCTCurve2DGetAllSpecialPoints(handle, &buffer, 256))
        return (0..<n).map {
            Curve2DSpecialPoint(
                parameter: buffer[$0].parameter,
                type: Curve2DSpecialPointType(rawValue: buffer[$0].type) ?? .inflection)
        }
    }

    // MARK: - Bounding Box

    /// The axis-aligned bounding box of this curve.
    public var boundingBox: (min: SIMD2<Double>, max: SIMD2<Double>)? {
        var xMin: Double = 0
        var yMin: Double = 0
        var xMax: Double = 0
        var yMax: Double = 0
        guard OCCTCurve2DGetBoundingBox(handle, &xMin, &yMin, &xMax, &yMax) else { return nil }
        return (min: SIMD2(xMin, yMin), max: SIMD2(xMax, yMax))
    }

    // MARK: - Additional Arc Types

    /// Create a trimmed arc of a hyperbola.
    public static func arcOfHyperbola(
        center: SIMD2<Double>, majorRadius: Double,
        minorRadius: Double, rotation: Double = 0,
        startAngle: Double, endAngle: Double
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DCreateArcOfHyperbola(
                center.x, center.y,
                majorRadius, minorRadius, rotation,
                startAngle, endAngle)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a trimmed arc of a parabola.
    public static func arcOfParabola(
        focus: SIMD2<Double>, direction: SIMD2<Double>,
        focalLength: Double,
        startParam: Double, endParam: Double
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DCreateArcOfParabola(
                focus.x, focus.y,
                direction.x, direction.y, focalLength,
                startParam, endParam)
        else { return nil }
        return Curve2D(handle: h)
    }

    // MARK: - Conversion Extras

    /// Re-approximate this curve's whole parameter domain as a B-spline, with a single
    /// scalar tolerance and explicit continuity control.
    ///
    /// Wraps `Geom2dConvert_ApproxCurve`, which fits the curve's entire native range in one
    /// pass. This is a **different OCCT algorithm** from
    /// ``approximatedInRange(first:last:toleranceU:toleranceV:maxDegree:maxSegments:)``, not a
    /// whole-domain shorthand for it: the two aren't interchangeable by adding or dropping a
    /// range, and their tolerance defaults (`1e-3` here vs. `1e-6` there) are not comparable:
    /// this one bounds a single whole-curve error, the other bounds independent per-axis error
    /// on a restricted range.
    ///
    /// - Parameters:
    ///   - tolerance: Maximum approximation error, applied over the whole curve
    ///   - continuity: A ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2). The
    ///     approximator accepts nothing stricter: `AdvApprox` throws for C3 and above, which
    ///     surfaces here as `nil`.
    ///   - maxSegments: Maximum number of B-spline segments
    ///   - maxDegree: Maximum polynomial degree
    ///
    /// Defaults (`tolerance: 1e-3`, `maxDegree: 8`) are shared with `Curve3D.approximated` and
    /// `Surface.approximated` (#406). All three wrap the same `GeomConvert_Approx*`/
    /// `Geom2dConvert_ApproxCurve` family applied to a different OCCT geometry hierarchy, not
    /// independent algorithms that would justify independently-tuned numeric defaults.
    ///
    /// - Returns: Approximated BSpline curve, or `nil` on failure
    ///
    /// ```swift
    /// let circle = Curve2D.circle(center: .zero, radius: 5)!
    /// let approx = circle.approximated(tolerance: 1e-3, continuity: 2)
    /// ```
    public func approximated(
        tolerance: Double = 1e-3, continuity: Int = 2,
        maxSegments: Int = 100, maxDegree: Int = 8
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DApproximate(
                handle, tolerance, Int32(continuity),
                Int32(maxSegments), Int32(maxDegree))
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Find knot indices where a B-spline has continuity discontinuities.
    ///
    /// Indices are 1-based into the curve's own knot table, so `bsplineKnot(index:)` turns
    /// each one into a parameter. The first and last knots are always included, so a curve
    /// that never drops below `continuity` reports exactly those two.
    ///
    /// ```swift
    /// // A cubic 2D BSpline with simple interior knots is already C2 there, so .c3 is the
    /// // order that reports its interior knots.
    /// let indices = curve.splitIndicesAtDiscontinuities(continuity: .c3)
    /// let params = indices?.map { curve.bsplineKnot(index: $0) }
    /// ```
    ///
    /// - Parameter continuity: Minimum continuity to require of each arc. This is a derivative
    ///   order, and `Geom2dConvert_BSplineCurveKnotSplitting` splits a knot only when
    ///   `degree - multiplicity < continuity`, so the meaningful range is 0...degree and it
    ///   saturates there (#480).
    /// - Returns: Array of knot indices where the curve drops below the requested continuity, or nil if not a B-spline.
    public func splitIndicesAtDiscontinuities(continuity: ParametricContinuity = .c1) -> [Int]? {
        // Read-then-retry, the #481 pattern the rest of this family shares: the bridge reports the
        // true split count even when it wrote fewer, so one retry sized to it is always enough.
        // Before #562 this read a fixed 256 entries and took whatever came back, so a curve with
        // more splits than that was silently cut off at 256 with nothing to notice it by.
        func read(capacity: Int) -> (count: Int, buffer: [Int32]) {
            var buffer = [Int32](repeating: 0, count: capacity)
            let n = Int(
                OCCTCurve2DSplitAtDiscontinuities(
                    handle, continuity.rawValue,
                    &buffer, Int32(capacity)))
            return (n, buffer)
        }

        var (n, buffer) = read(capacity: 256)
        guard n > 0 else { return nil }
        if n > 256 { (n, buffer) = read(capacity: n) }
        return buffer.prefix(n).map(Int.init)
    }

    /// Approximate this curve as a sequence of arcs and line segments.
    ///
    /// Useful for CNC G-code generation.
    public func toArcsAndSegments(
        tolerance: Double = 0.01,
        angleTolerance: Double = 0.04
    ) -> [Curve2D]? {
        var buffer = [OCCTCurve2DRef?](repeating: nil, count: 256)
        let n = Int(
            buffer.withUnsafeMutableBufferPointer { ptr in
                OCCTCurve2DToArcsAndSegments(
                    handle, tolerance, angleTolerance, ptr.baseAddress, 256)
            })
        guard n > 0 else { return nil }
        return (0..<n).compactMap { i in
            guard let h = buffer[i] else { return nil }
            return Curve2D(handle: h)
        }
    }

    // MARK: - Bisector

    /// Compute the bisector curve between this curve and another.
    ///
    /// The bisector is the locus of points equidistant from both curves.
    public func bisector(
        with other: Curve2D, origin: SIMD2<Double>,
        side: Bool = true
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DBisectorCC(
                handle, other.handle,
                origin.x, origin.y, side)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Compute the bisector curve between a point and this curve.
    public func bisector(
        withPoint point: SIMD2<Double>, origin: SIMD2<Double>,
        side: Bool = true
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DBisectorPC(
                point.x, point.y, handle,
                origin.x, origin.y, side)
        else { return nil }
        return Curve2D(handle: h)
    }

    // MARK: - Analysis

    /// Find intersection points between this curve and another.
    public func intersections(with other: Curve2D, tolerance: Double = 1e-6)
        -> [Curve2DIntersection]
    {
        var buffer = [OCCTCurve2DIntersection](repeating: OCCTCurve2DIntersection(), count: 128)
        let n = Int(OCCTCurve2DIntersect(handle, other.handle, tolerance, &buffer, 128))
        return (0..<n).map {
            Curve2DIntersection(
                point: SIMD2(buffer[$0].x, buffer[$0].y),
                parameter1: buffer[$0].u1, parameter2: buffer[$0].u2)
        }
    }

    /// Find self-intersection points of this curve.
    public func selfIntersections(tolerance: Double = 1e-6) -> [Curve2DIntersection] {
        var buffer = [OCCTCurve2DIntersection](repeating: OCCTCurve2DIntersection(), count: 128)
        let n = Int(OCCTCurve2DSelfIntersect(handle, tolerance, &buffer, 128))
        return (0..<n).map {
            Curve2DIntersection(
                point: SIMD2(buffer[$0].x, buffer[$0].y),
                parameter1: buffer[$0].u1, parameter2: buffer[$0].u2)
        }
    }

    /// Project a point onto this curve, returning the nearest projection.
    ///
    /// - Parameter p: Point to project.
    /// - Returns: The nearest projection, or `nil` if there is no curve to answer about.
    ///
    /// The answer is always inside this curve's own ``domain``, and always the true nearest point:
    /// where the point has no perpendicular foot on the curve (anything past the end of a trimmed
    /// curve, or off to one side of an arc), the nearest point is an end, and that is what comes
    /// back. `project(_:)` (the `Point2D` overload), `Point2D.distance(to:)` and
    /// ``nearestParameter(to:)`` compute the same nearest solution through the same shared bridge
    /// path and agree with it exactly.
    ///
    /// ```swift
    /// let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
    /// let hit = segment.project(point: SIMD2(5, 3))
    /// #expect(hit?.distance == 3)
    /// #expect(segment.project(point: SIMD2(100, 0))?.distance == 90)   // past the end: the end
    ///
    /// let arc = Curve2D.circle(center: .zero, radius: 5)!.trimmed(from: 0, to: .pi)!
    /// #expect(arc.project(point: SIMD2(0, -6))?.parameter == 0)        // the near end, 7.81 away
    /// ```
    ///
    /// Before #615 this reported `Geom2dAPI_ProjectPointOnCurve`'s extremum instead: the arc above
    /// answered π/2, the far side, 11 away, and `nil` for the segment. ``allProjections(of:)`` asks
    /// for the extrema, which is a different question, and still reports none in both cases.
    public func project(point p: SIMD2<Double>) -> Curve2DProjection? {
        let r = OCCTCurve2DProjectPoint(handle, p.x, p.y)
        guard r.distance >= 0 else { return nil }
        return Curve2DProjection(
            point: SIMD2(r.x, r.y), parameter: r.parameter, distance: r.distance)
    }

    /// The parameter of the point on this curve nearest to `point`.
    ///
    /// - Parameter point: Point to project.
    /// - Returns: The nearest parameter, always inside this curve's own ``domain``, or `nil` if
    ///     there is no curve to answer about.
    ///
    /// The scalar form of ``project(point:)``, computed by the same shared bridge path and agreeing
    /// with it and with `Point2D.distance(to:)` exactly. Like them it reports the true nearest
    /// point rather than the nearest perpendicular foot, so a point past the end of a bounded curve
    /// answers with that end.
    ///
    /// This replaces the deprecated `parameterAtPoint(_:)` because no `Double` can carry a failure
    /// signal: `0` is a legitimate parameter on any curve whose domain includes it, and so is every
    /// other value.
    ///
    /// ```swift
    /// let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
    /// #expect(segment.nearestParameter(to: SIMD2(5, 3)) == 5)
    /// #expect(segment.nearestParameter(to: SIMD2(100, 0)) == 10)   // past the end: the end
    ///
    /// let circle = Curve2D.circle(center: .zero, radius: 5)!
    /// // Equidistant everywhere, so every point is a nearest one; it names a tied parameter
    /// // rather than refusing to answer (#615).
    /// #expect(circle.nearestParameter(to: .zero) != nil)
    /// ```
    public func nearestParameter(to point: SIMD2<Double>) -> Double? {
        var parameter = 0.0
        guard OCCTCurve2DNearestParameter(handle, point.x, point.y, &parameter) else { return nil }
        return parameter
    }

    /// Project a point onto this curve, returning every projection.
    ///
    /// This asks for the **extrema** of the distance function (the perpendicular feet), which is a
    /// different question from "the nearest point", and since #615 gives a visibly different answer.
    /// A bounded curve queried from beyond its end has no perpendicular foot at all, so this
    /// correctly returns empty where ``project(point:)`` and ``nearestParameter(to:)`` answer with
    /// the end. An extremum may also be a local *maximum*: on a half arc queried from the far side
    /// the only element here is the point furthest away.
    ///
    /// ```swift
    /// let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
    /// #expect(segment.allProjections(of: SIMD2(5, 3)).count == 1)      // a foot at (5, 0)
    /// #expect(segment.allProjections(of: SIMD2(100, 0)).isEmpty)       // no foot past the end
    /// #expect(segment.project(point: SIMD2(100, 0))?.parameter == 10)  // but a nearest point
    /// ```
    public func allProjections(of p: SIMD2<Double>) -> [Curve2DProjection] {
        var buffer = [OCCTCurve2DProjection](repeating: OCCTCurve2DProjection(), count: 64)
        let n = Int(OCCTCurve2DProjectPointAll(handle, p.x, p.y, &buffer, 64))
        return (0..<n).map {
            Curve2DProjection(
                point: SIMD2(buffer[$0].x, buffer[$0].y),
                parameter: buffer[$0].parameter, distance: buffer[$0].distance)
        }
    }

    /// Find the minimum distance between this curve and another.
    public func minDistance(to other: Curve2D) -> Curve2DExtremaResult? {
        let r = OCCTCurve2DMinDistance(handle, other.handle)
        guard r.distance >= 0 else { return nil }
        return Curve2DExtremaResult(
            pointOnCurve1: SIMD2(r.p1x, r.p1y),
            pointOnCurve2: SIMD2(r.p2x, r.p2y),
            parameter1: r.u1, parameter2: r.u2,
            distance: r.distance)
    }

    /// Find all extrema (local min/max distances) between this curve and another.
    public func allExtrema(with other: Curve2D) -> [Curve2DExtremaResult] {
        var buffer = [OCCTCurve2DExtrema](repeating: OCCTCurve2DExtrema(), count: 64)
        let n = Int(OCCTCurve2DAllExtrema(handle, other.handle, &buffer, 64))
        return (0..<n).map {
            Curve2DExtremaResult(
                pointOnCurve1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                pointOnCurve2: SIMD2(buffer[$0].p2x, buffer[$0].p2y),
                parameter1: buffer[$0].u1, parameter2: buffer[$0].u2,
                distance: buffer[$0].distance)
        }
    }

    // MARK: - Conversion

    /// Convert this curve to an equivalent B-spline representation.
    public func toBSpline(tolerance: Double = 1e-6) -> Curve2D? {
        guard let h = OCCTCurve2DToBSpline(handle, tolerance) else { return nil }
        return Curve2D(handle: h)
    }

    /// Split a B-spline curve into its constituent Bezier segments.
    public func toBezierSegments() -> [Curve2D]? {
        var buffer = [OCCTCurve2DRef?](repeating: nil, count: 64)
        let n = Int(
            buffer.withUnsafeMutableBufferPointer { ptr in
                OCCTCurve2DBSplineToBeziers(handle, ptr.baseAddress, 64)
            })
        guard n > 0 else { return nil }
        return (0..<n).compactMap { i in
            guard let h = buffer[i] else { return nil }
            return Curve2D(handle: h)
        }
    }

    /// Join multiple curves into a single B-spline.
    public static func join(_ curves: [Curve2D], tolerance: Double = 1e-6) -> Curve2D? {
        let handles = curves.map { $0.handle as OCCTCurve2DRef? }
        let h = handles.withUnsafeBufferPointer { ptr in
            OCCTCurve2DJoinToBSpline(ptr.baseAddress, Int32(curves.count), tolerance)
        }
        guard let h = h else { return nil }
        return Curve2D(handle: h)
    }
}

// MARK: - Result Types

/// An intersection point between two 2D curves.
public struct Curve2DIntersection: Sendable {
    /// The intersection point in 2D space.
    public let point: SIMD2<Double>
    /// Parameter on the first curve at the intersection.
    public let parameter1: Double
    /// Parameter on the second curve at the intersection.
    public let parameter2: Double
}

/// A projection of a point onto a 2D curve.
public struct Curve2DProjection: Sendable {
    /// The projected point on the curve.
    public let point: SIMD2<Double>
    /// The curve parameter at the projected point.
    public let parameter: Double
    /// The distance from the original point to the projected point.
    public let distance: Double
}

/// A distance extremum between two 2D curves.
public struct Curve2DExtremaResult: Sendable {
    /// The point on the first curve at the extremum.
    public let pointOnCurve1: SIMD2<Double>
    /// The point on the second curve at the extremum.
    public let pointOnCurve2: SIMD2<Double>
    /// Parameter on the first curve.
    public let parameter1: Double
    /// Parameter on the second curve.
    public let parameter2: Double
    /// The distance between the two points.
    public let distance: Double
}

/// Type of a special point on a curve (inflection or curvature extremum).
public enum Curve2DSpecialPointType: Int32, Sendable {
    case inflection = 0
    case minCurvature = 1
    case maxCurvature = 2
}

/// A special point on a 2D curve: inflection or curvature extremum.
public struct Curve2DSpecialPoint: Sendable {
    /// The parameter value on the curve.
    public let parameter: Double
    /// The type of special point.
    public let type: Curve2DSpecialPointType
}

// MARK: - Gcc Constraint Solver

/// Qualifier for how a curve participates in a geometric constraint.
public enum Curve2DQualifier: Int32, Sendable {
    /// The solution position is unspecified relative to the curve.
    case unqualified = 0
    /// The solution encloses the curve.
    case enclosing = 1
    /// The solution is enclosed by the curve.
    case enclosed = 2
    /// The solution is outside the curve.
    case outside = 3
}

/// A circle solution from the Gcc constraint solver.
public struct Curve2DCircleSolution: Sendable {
    /// Center of the solution circle.
    public let center: SIMD2<Double>
    /// Radius of the solution circle.
    public let radius: Double
}

/// A line solution from the Gcc constraint solver.
public struct Curve2DLineSolution: Sendable {
    /// A point on the solution line.
    public let point: SIMD2<Double>
    /// Direction of the solution line (unit vector).
    public let direction: SIMD2<Double>
}

/// A hatch segment produced by the hatching algorithm.
public struct Curve2DHatchSegment: Sendable {
    /// Start point of the hatch line segment.
    public let start: SIMD2<Double>
    /// End point of the hatch line segment.
    public let end: SIMD2<Double>
}

/// Constraint-based 2D geometric construction (circle/line solver).
///
/// Wraps the OpenCASCADE `Geom2dGcc` package: given tangency, passing-through,
/// and radius constraints, finds all circles or lines satisfying them.
///
/// ## Examples
///
/// ```swift
/// // Circle tangent to two circles with a given radius
/// let solutions = Curve2DGcc.circlesTangentToTwoCurves(
///     c1, .unqualified, c2, .unqualified, radius: 3)
///
/// // Line tangent to a circle through a point
/// let lines = Curve2DGcc.linesTangentToPoint(circle, .outside,
///                                            point: SIMD2(10, 0))
/// ```
public enum Curve2DGcc {

    // MARK: - Circle Construction

    /// Find circles tangent to three curves.
    public static func circlesTangentTo(
        _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
        _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
        _ c3: Curve2D, _ q3: Curve2DQualifier = .unqualified,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2d3Tan(
                c1.handle, q1.rawValue,
                c2.handle, q2.rawValue,
                c3.handle, q3.rawValue,
                tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find circles tangent to two curves and passing through a point.
    public static func circlesTangentToTwoCurvesAndPoint(
        _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
        _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
        point: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2d2TanPt(
                c1.handle, q1.rawValue,
                c2.handle, q2.rawValue,
                point.x, point.y,
                tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find circles tangent to a curve with a given center point.
    public static func circlesTangentWithCenter(
        _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
        center: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2dTanCen(
                curve.handle, qualifier.rawValue,
                center.x, center.y, tolerance,
                &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find circles tangent to two curves with a given radius.
    public static func circlesTangentToTwoCurves(
        _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
        _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
        radius: Double,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2d2TanRad(
                c1.handle, q1.rawValue,
                c2.handle, q2.rawValue,
                radius, tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find circles tangent to a curve, passing through a point, with a given radius.
    public static func circlesTangentToPointWithRadius(
        _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
        point: SIMD2<Double>, radius: Double,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2dTanPtRad(
                curve.handle, qualifier.rawValue,
                point.x, point.y, radius, tolerance,
                &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find circles through two points with a given radius.
    public static func circlesThroughTwoPoints(
        _ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
        radius: Double,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2d2PtRad(
                p1.x, p1.y, p2.x, p2.y,
                radius, tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Find the circle through three points.
    public static func circleThroughThreePoints(
        _ p1: SIMD2<Double>, _ p2: SIMD2<Double>, _ p3: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccCircle2d3Pt(
                p1.x, p1.y, p2.x, p2.y, p3.x, p3.y,
                tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    // MARK: - Line Construction

    /// Find lines tangent to two curves.
    public static func linesTangentTo(
        _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
        _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
        tolerance: Double = 1e-6
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 32)
        let n = Int(
            OCCTGccLine2d2Tan(
                c1.handle, q1.rawValue,
                c2.handle, q2.rawValue,
                tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Find lines tangent to a curve and passing through a point.
    public static func linesTangentToPoint(
        _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
        point: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 32)
        let n = Int(
            OCCTGccLine2dTanPt(
                curve.handle, qualifier.rawValue,
                point.x, point.y, tolerance,
                &buffer, 32))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    // MARK: - Hatching

    /// Generate parallel hatch lines clipped to a region bounded by curves.
    /// - Parameters:
    ///   - boundaries: Closed boundary curves defining the region
    ///   - origin: Origin point for the hatch pattern
    ///   - direction: Direction of hatch lines
    ///   - spacing: Distance between hatch lines
    ///   - tolerance: Intersection tolerance
    /// - Returns: Array of hatch line segments
    public static func hatch(
        boundaries: [Curve2D],
        origin: SIMD2<Double> = .zero,
        direction: SIMD2<Double> = SIMD2(1, 0),
        spacing: Double,
        tolerance: Double = 1e-6
    ) -> [Curve2DHatchSegment] {
        let maxSegments = 4096
        var buffer = [Double](repeating: 0, count: maxSegments * 4)
        let handles = boundaries.map { $0.handle as OCCTCurve2DRef? }
        let n = Int(
            handles.withUnsafeBufferPointer { ptr in
                OCCTCurve2DHatch(
                    ptr.baseAddress, Int32(boundaries.count),
                    origin.x, origin.y, direction.x, direction.y,
                    spacing, tolerance, &buffer, Int32(maxSegments))
            })
        return (0..<n).map { i in
            let base = i * 4
            return Curve2DHatchSegment(
                start: SIMD2(buffer[base], buffer[base + 1]),
                end: SIMD2(buffer[base + 2], buffer[base + 3]))
        }
    }
}

// MARK: - Batch Evaluation (v0.28.0)

extension Curve2D {
    /// Evaluate the curve at multiple parameters in one call.
    ///
    /// Uses OCCT's optimized grid evaluator for better performance than
    /// calling `point(at:)` repeatedly.
    ///
    /// - Parameter parameters: Array of parameter values
    /// - Returns: Array of evaluated 2D points
    ///
    /// ## Example
    ///
    /// ```swift
    /// let circle = Curve2D.circle(center: .zero, radius: 5)!
    /// let params = stride(from: 0.0, through: 2 * .pi, by: 0.01).map { $0 }
    /// let points = circle.evaluateGrid(params)
    /// ```
    public func evaluateGrid(_ parameters: [Double]) -> [SIMD2<Double>] {
        guard !parameters.isEmpty else { return [] }
        var outXY = [Double](repeating: 0, count: parameters.count * 2)
        let n = Int(OCCTCurve2DEvaluateGrid(handle, parameters, Int32(parameters.count), &outXY))
        return (0..<n).map { i in SIMD2(outXY[i * 2], outXY[i * 2 + 1]) }
    }

    /// Evaluate the curve and its first derivative at multiple parameters in one call.
    ///
    /// - Parameter parameters: Array of parameter values
    /// - Returns: Array of tuples with point and tangent vector
    public func evaluateGridD1(_ parameters: [Double]) -> [(
        point: SIMD2<Double>, tangent: SIMD2<Double>
    )] {
        guard !parameters.isEmpty else { return [] }
        var outXY = [Double](repeating: 0, count: parameters.count * 2)
        var outDXDY = [Double](repeating: 0, count: parameters.count * 2)
        let n = Int(
            OCCTCurve2DEvaluateGridD1(handle, parameters, Int32(parameters.count), &outXY, &outDXDY)
        )
        return (0..<n).map { i in
            (
                point: SIMD2(outXY[i * 2], outXY[i * 2 + 1]),
                tangent: SIMD2(outDXDY[i * 2], outDXDY[i * 2 + 1])
            )
        }
    }

    // MARK: - v0.51.0: GC_MakeLine2d variants

    /// Create a 2D infinite line passing through two points.
    ///
    /// Unlike `segment(from:to:)` which creates a finite segment, this creates
    /// an infinite line through the two points.
    ///
    /// - Parameters:
    ///   - p1: First point on the line
    ///   - p2: Second point on the line
    /// - Returns: 2D line curve, or nil if points coincide
    public static func lineThroughPoints(_ p1: SIMD2<Double>, _ p2: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTCurve2DMakeLineThroughPoints(p1.x, p1.y, p2.x, p2.y) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a 2D line parallel to a reference line at a given distance.
    ///
    /// - Parameters:
    ///   - point: A point on the reference line
    ///   - direction: Direction of the reference line
    ///   - distance: Signed offset distance (positive = left of direction)
    /// - Returns: 2D line curve, or nil on failure
    public static func lineParallel(
        point: SIMD2<Double>, direction: SIMD2<Double>, distance: Double
    ) -> Curve2D? {
        guard
            let h = OCCTCurve2DMakeLineParallel(
                point.x, point.y, direction.x, direction.y, distance)
        else { return nil }
        return Curve2D(handle: h)
    }
}

// MARK: - ShapeCustom_Curve2d & Approx_Curve2d (v0.52.0)

extension Curve2D {

    /// Check if this 2D BSpline curve is nearly linear (collinear control points).
    ///
    /// - Parameter tolerance: Maximum allowed deviation from a straight line
    /// - Returns: Tuple of (isLinear, deviation) where deviation is the actual maximum
    ///   deviation from the line, or nil if not a BSpline curve
    public func isLinear(tolerance: Double = 1e-6) -> (isLinear: Bool, deviation: Double)? {
        var deviation: Double = 0
        let result = OCCTCurve2DIsLinear(handle, tolerance, &deviation)
        return (isLinear: result, deviation: deviation)
    }

    /// Convert a nearly-linear 2D curve to a line.
    ///
    /// If this curve is within tolerance of a straight line, returns the equivalent
    /// line curve along with reparametrized bounds.
    ///
    /// - Parameters:
    ///   - first: First parameter of the range to check
    ///   - last: Last parameter of the range to check
    ///   - tolerance: Maximum allowed deviation
    /// - Returns: Tuple of (line, newFirst, newLast, deviation), or nil if not linear
    public func convertToLine(
        first: Double, last: Double, tolerance: Double = 1e-3
    ) -> (line: Curve2D, newFirst: Double, newLast: Double, deviation: Double)? {
        var newFirst: Double = 0
        var newLast: Double = 0
        var deviation: Double = 0
        guard
            let h = OCCTCurve2DConvertToLine(
                handle, first, last, tolerance, &newFirst, &newLast, &deviation)
        else { return nil }
        return (
            line: Curve2D(handle: h), newFirst: newFirst, newLast: newLast, deviation: deviation
        )
    }

    /// Simplify a 2D BSpline curve by removing unnecessary knots.
    ///
    /// Modifies this curve in place by removing knots that don't affect the
    /// shape within the given tolerance.
    ///
    /// - Parameter tolerance: Maximum allowed deviation
    /// - Returns: true if the curve was simplified
    @discardableResult
    public func simplifyBSpline(tolerance: Double = 1e-6) -> Bool {
        OCCTCurve2DSimplifyBSpline(handle, tolerance)
    }

    /// Approximate an explicit parameter sub-range of this 2D curve as a BSpline, with
    /// independent U/V tolerances.
    ///
    /// Wraps `Approx_Curve2d`, which fits only `[first, last]` and tracks separate U/V error
    /// bounds. This is a **different OCCT algorithm** from
    /// ``approximated(tolerance:continuity:maxSegments:maxDegree:)``, not that method with an
    /// added range. A caller cannot migrate incrementally between the two by adding
    /// `first`/`last`, since switching overloads changes the algorithm, the tolerance
    /// semantics, and the default tolerance magnitude (`1e-6` here vs. `1e-3` there) all at
    /// once. Continuity is fixed at C2 and is not configurable through this overload; use
    /// ``approximated(tolerance:continuity:maxSegments:maxDegree:)`` if you need a different
    /// continuity order.
    ///
    /// - Parameters:
    ///   - first: First parameter of the sub-range to approximate
    ///   - last: Last parameter of the sub-range to approximate
    ///   - toleranceU: Tolerance in U direction (default 1e-6)
    ///   - toleranceV: Tolerance in V direction (default 1e-6)
    ///   - maxDegree: Maximum BSpline degree (default 8)
    ///   - maxSegments: Maximum number of segments (default 100)
    /// - Returns: Approximated BSpline curve, or `nil` on failure
    ///
    /// ```swift
    /// let circle = Curve2D.circle(center: .zero, radius: 10)!
    /// let d = circle.domain
    /// let approx = circle.approximatedInRange(first: d.lowerBound, last: d.upperBound,
    ///                                          toleranceU: 1e-6, toleranceV: 1e-6)
    /// ```
    public func approximatedInRange(
        first: Double, last: Double,
        toleranceU: Double = 1e-6, toleranceV: Double = 1e-6,
        maxDegree: Int = 8, maxSegments: Int = 100
    ) -> Curve2D? {
        guard
            let h = OCCTApproxCurve2d(
                handle, first, last, toleranceU, toleranceV,
                Int32(maxDegree), Int32(maxSegments))
        else { return nil }
        return Curve2D(handle: h)
    }

}

// ============================================================================
// MARK: - 2D Geometry Completions (v0.53.0)
// ============================================================================

// MARK: - GccAna Bisectors

/// Bisector curve type classification.
public enum BisecType: Int32, Sendable {
    case line = 0
    case circle = 1
    case ellipse = 2
    case hyperbola = 3
    case parabola = 4
    case point = 5
}

/// A bisector solution from an analytical bisector computation.
public struct BisecSolution: Sendable {
    /// The type of bisector curve.
    public let type: BisecType
    /// Primary position (depends on type: center, point on line, focus).
    public let position: SIMD2<Double>
    /// Secondary values (direction for line, radii for conics).
    public let secondary: SIMD2<Double>
    /// Radius (for circle type).
    public let radius: Double
}

/// Analytical 2D bisector computations (GccAna module).
///
/// Computes bisectors between combinations of points, lines, and circles.
/// Bisectors are the loci of points equidistant from two geometric elements.
public enum GccAnaBisector {

    /// Perpendicular bisector of two points.
    ///
    /// Returns the line equidistant from both points.
    public static func ofPoints(
        _ p1: SIMD2<Double>, _ p2: SIMD2<Double>
    ) -> Curve2DLineSolution? {
        var px: Double = 0
        var py: Double = 0
        var dx: Double = 0
        var dy: Double = 0
        guard OCCTGccAnaPnt2dBisec(p1.x, p1.y, p2.x, p2.y, &px, &py, &dx, &dy) else {
            return nil
        }
        return Curve2DLineSolution(point: SIMD2(px, py), direction: SIMD2(dx, dy))
    }

    /// Angle bisectors of two lines.
    ///
    /// Two intersecting lines have two angle bisectors.
    public static func ofLines(
        line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>,
        line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dBisec(
                line1Point.x, line1Point.y, line1Dir.x, line1Dir.y,
                line2Point.x, line2Point.y, line2Dir.x, line2Dir.y,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Bisector between a line and a point.
    ///
    /// The result is typically a parabola with the point as focus
    /// and the line as directrix.
    public static func ofLineAndPoint(
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        point: SIMD2<Double>
    ) -> BisecSolution? {
        var sol = OCCTBisecSolution()
        guard
            OCCTGccAnaLinPnt2dBisec(
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                point.x, point.y, &sol)
        else { return nil }
        return BisecSolution(
            type: BisecType(rawValue: Int32(sol.type.rawValue)) ?? .point,
            position: SIMD2(sol.px, sol.py),
            secondary: SIMD2(sol.dx, sol.dy),
            radius: sol.radius)
    }

    /// Bisectors between two circles.
    ///
    /// Returns curves equidistant from both circles (up to 4 solutions).
    ///
    /// Both radii must be positive. A radius of zero describes a point rather than a circle, and
    /// the solver does not answer the point question when it is given one: measured (#553), it
    /// returns each solution twice, and with both radii zero two of the three solutions are
    /// hyperbolas of major radius zero, a conic this API refuses to construct. Ask about points
    /// through ``ofPoints(_:_:)`` or ``ofCircleAndPoint(center:radius:point:)`` instead. A
    /// non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let bisectors = GccAnaBisector.ofCircles(center1: SIMD2(0, 0), radius1: 3,
    ///                                          center2: SIMD2(10, 0), radius2: 2)
    /// print(bisectors.count)   // 4
    ///
    /// // A point is not a zero-radius circle here:
    /// GccAnaBisector.ofCircles(center1: SIMD2(0, 0), radius1: 0,
    ///                          center2: SIMD2(10, 0), radius2: 2)   // []
    /// GccAnaBisector.ofPoints(SIMD2(0, 0), SIMD2(10, 0))            // the perpendicular bisector
    /// ```
    public static func ofCircles(
        center1: SIMD2<Double>, radius1: Double,
        center2: SIMD2<Double>, radius2: Double
    ) -> [BisecSolution] {
        var buffer = [OCCTBisecSolution](repeating: OCCTBisecSolution(), count: 8)
        let n = Int(
            OCCTGccAnaCirc2dBisec(
                center1.x, center1.y, radius1,
                center2.x, center2.y, radius2,
                &buffer, 8))
        return (0..<n).map {
            BisecSolution(
                type: BisecType(rawValue: Int32(buffer[$0].type.rawValue)) ?? .point,
                position: SIMD2(buffer[$0].px, buffer[$0].py),
                secondary: SIMD2(buffer[$0].dx, buffer[$0].dy),
                radius: buffer[$0].radius)
        }
    }

    /// Bisectors between a circle and a line.
    ///
    /// The radius must be positive. With a radius of zero the solver returns the point/line
    /// parabola twice rather than once (#553); ask about a point through
    /// ``ofLineAndPoint(linePoint:lineDir:point:)``. A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let bisectors = GccAnaBisector.ofCircleAndLine(center: SIMD2(0, 5), radius: 2,
    ///                                                linePoint: SIMD2(0, 0),
    ///                                                lineDir: SIMD2(1, 0))
    /// print(bisectors.count)   // 2 parabolas
    /// ```
    public static func ofCircleAndLine(
        center: SIMD2<Double>, radius: Double,
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
    ) -> [BisecSolution] {
        var buffer = [OCCTBisecSolution](repeating: OCCTBisecSolution(), count: 8)
        let n = Int(
            OCCTGccAnaCircLin2dBisec(
                center.x, center.y, radius,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                &buffer, 8))
        return (0..<n).map {
            BisecSolution(
                type: BisecType(rawValue: Int32(buffer[$0].type.rawValue)) ?? .point,
                position: SIMD2(buffer[$0].px, buffer[$0].py),
                secondary: SIMD2(buffer[$0].dx, buffer[$0].dy),
                radius: buffer[$0].radius)
        }
    }

    /// Bisectors between a circle and a point.
    ///
    /// The radius must be positive. This is the family where a zero radius is furthest from the
    /// point reading: measured (#553), it returns two hyperbolas of major radius zero, where the
    /// bisector of two points is a straight line. Use ``ofPoints(_:_:)`` for that. A non-positive
    /// radius returns an empty array.
    ///
    /// ```swift
    /// let bisectors = GccAnaBisector.ofCircleAndPoint(center: SIMD2(0, 0), radius: 2,
    ///                                                 point: SIMD2(6, 0))
    /// print(bisectors.count)   // 2 hyperbola branches
    /// ```
    public static func ofCircleAndPoint(
        center: SIMD2<Double>, radius: Double,
        point: SIMD2<Double>
    ) -> [BisecSolution] {
        var buffer = [OCCTBisecSolution](repeating: OCCTBisecSolution(), count: 8)
        let n = Int(
            OCCTGccAnaCircPnt2dBisec(
                center.x, center.y, radius,
                point.x, point.y,
                &buffer, 8))
        return (0..<n).map {
            BisecSolution(
                type: BisecType(rawValue: Int32(buffer[$0].type.rawValue)) ?? .point,
                position: SIMD2(buffer[$0].px, buffer[$0].py),
                secondary: SIMD2(buffer[$0].dx, buffer[$0].dy),
                radius: buffer[$0].radius)
        }
    }
}

// MARK: - GccAna Line Solvers

extension Curve2DGcc {

    /// Line through a point parallel to a reference line.
    public static func lineParallelThrough(
        point: SIMD2<Double>,
        parallelTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dTanParPt(
                point.x, point.y,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Lines tangent to a circle, parallel to a reference line.
    ///
    /// `circleRadius` must be positive. With a radius of zero the solver returns the single line
    /// through the centre twice (#553); ``lineParallelThrough(point:parallelTo:lineDir:)`` is the
    /// entry point for that question and returns it once. A non-positive radius returns an empty
    /// array.
    ///
    /// ```swift
    /// let tangents = Curve2DGcc.linesTangentParallel(circleCenter: SIMD2(0, 0), circleRadius: 4,
    ///                                                parallelTo: SIMD2(0, 0),
    ///                                                lineDir: SIMD2(1, 0))
    /// print(tangents.count)   // 2, at y = 4 and y = -4
    /// ```
    public static func linesTangentParallel(
        circleCenter: SIMD2<Double>, circleRadius: Double,
        qualifier: Curve2DQualifier = .unqualified,
        parallelTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dTanParCirc(
                circleCenter.x, circleCenter.y, circleRadius,
                qualifier.rawValue,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Line through a point perpendicular to a reference line.
    public static func linePerpendicularThrough(
        point: SIMD2<Double>,
        perpendicularTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dTanPerPtLin(
                point.x, point.y,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Lines tangent to a circle, perpendicular to a reference line.
    ///
    /// `circleRadius` must be positive. With a radius of zero the solver returns the single line
    /// through the centre twice (#553); use
    /// ``linePerpendicularThrough(point:perpendicularTo:lineDir:)`` for the point question. A
    /// non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let tangents = Curve2DGcc.linesTangentPerpendicular(circleCenter: SIMD2(0, 0),
    ///                                                     circleRadius: 4,
    ///                                                     perpendicularTo: SIMD2(0, 0),
    ///                                                     lineDir: SIMD2(1, 0))
    /// print(tangents.count)   // 2, at x = 4 and x = -4
    /// ```
    public static func linesTangentPerpendicular(
        circleCenter: SIMD2<Double>, circleRadius: Double,
        qualifier: Curve2DQualifier = .unqualified,
        perpendicularTo linePoint: SIMD2<Double>, lineDir: SIMD2<Double>
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dTanPerCircLin(
                circleCenter.x, circleCenter.y, circleRadius,
                qualifier.rawValue,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Line through a point at a given angle to a reference line.
    public static func lineAtAngleThrough(
        point: SIMD2<Double>,
        referenceLine linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        angle: Double
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 4)
        let n = Int(
            OCCTGccAnaLin2dTanOblPt(
                point.x, point.y,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                angle,
                &buffer, 4))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    /// Lines tangent to a curve at a given angle to a reference line (Geom2dGcc).
    public static func linesTangentAtAngle(
        _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
        referenceLine linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        angle: Double, tolerance: Double = 1e-6
    ) -> [Curve2DLineSolution] {
        var buffer = [OCCTGccLineSolution](repeating: OCCTGccLineSolution(), count: 32)
        let n = Int(
            OCCTGeom2dGccLin2dTanObl(
                curve.handle, qualifier.rawValue,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                tolerance, angle,
                &buffer, 32))
        return (0..<n).map {
            Curve2DLineSolution(
                point: SIMD2(buffer[$0].px, buffer[$0].py),
                direction: SIMD2(buffer[$0].dx, buffer[$0].dy))
        }
    }

    // MARK: - GccAna Circle On-Constraint Solvers

    /// Circles tangent to two lines with center on a third line.
    public static func circlesTangentToTwoLinesOnLine(
        line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>, q1: Curve2DQualifier = .unqualified,
        line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>, q2: Curve2DQualifier = .unqualified,
        centerOnPoint: SIMD2<Double>, centerOnDir: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccAnaCirc2d2TanOnLinLin(
                line1Point.x, line1Point.y, line1Dir.x, line1Dir.y, q1.rawValue,
                line2Point.x, line2Point.y, line2Dir.x, line2Dir.y, q2.rawValue,
                centerOnPoint.x, centerOnPoint.y, centerOnDir.x, centerOnDir.y,
                tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Circles tangent to a line, center on a line, with given radius.
    ///
    /// `radius` is the radius of the circles to find, and it must be positive. Asked for zero the
    /// solver obliges and returns solution circles of radius zero (#553), which is a point rather
    /// than the circle the caller asked for. A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let circles = Curve2DGcc.circlesTangentToLineOnLineWithRadius(
    ///     linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
    ///     centerOnPoint: SIMD2(0, 0), centerOnDir: SIMD2(1, 1), radius: 2)
    /// print(circles.map(\.radius))   // every solution has radius 2
    /// ```
    public static func circlesTangentToLineOnLineWithRadius(
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        qualifier: Curve2DQualifier = .unqualified,
        centerOnPoint: SIMD2<Double>, centerOnDir: SIMD2<Double>,
        radius: Double, tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGccAnaCirc2dTanOnRadLin(
                linePoint.x, linePoint.y, lineDir.x, lineDir.y, qualifier.rawValue,
                centerOnPoint.x, centerOnPoint.y, centerOnDir.x, centerOnDir.y,
                radius, tolerance, &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    // MARK: - Geom2dGcc Circle On-Constraint Solvers

    /// Circles tangent to two curves with center on a third curve (Geom2dGcc).
    public static func circlesTangentToTwoCurvesOnCurve(
        _ c1: Curve2D, _ q1: Curve2DQualifier = .unqualified,
        _ c2: Curve2D, _ q2: Curve2DQualifier = .unqualified,
        centerOn: Curve2D,
        tolerance: Double = 1e-6,
        initParam1: Double = 0, initParam2: Double = 0, initParamOn: Double = 0
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGeom2dGccCirc2d2TanOn(
                c1.handle, q1.rawValue,
                c2.handle, q2.rawValue,
                centerOn.handle,
                tolerance, initParam1, initParam2, initParamOn,
                &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }

    /// Circles tangent to a curve, center on a curve, with given radius (Geom2dGcc).
    ///
    /// `radius` is the radius of the circles to find, and it must be positive; zero would ask for
    /// a solution circle that is a point (#553). A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// guard let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)),
    ///       let centerOn = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 1)) else { return }
    /// let circles = Curve2DGcc.circlesTangentOnCurveWithRadius(line, centerOn: centerOn, radius: 2)
    /// ```
    public static func circlesTangentOnCurveWithRadius(
        _ curve: Curve2D, _ qualifier: Curve2DQualifier = .unqualified,
        centerOn: Curve2D,
        radius: Double, tolerance: Double = 1e-6
    ) -> [Curve2DCircleSolution] {
        var buffer = [OCCTGccCircleSolution](repeating: OCCTGccCircleSolution(), count: 32)
        let n = Int(
            OCCTGeom2dGccCirc2dTanOnRad(
                curve.handle, qualifier.rawValue,
                centerOn.handle,
                radius, tolerance,
                &buffer, 32))
        return (0..<n).map {
            Curve2DCircleSolution(
                center: SIMD2(buffer[$0].cx, buffer[$0].cy),
                radius: buffer[$0].radius)
        }
    }
}

// MARK: - IntAna2d Analytical Intersections

/// 2D intersection point result.
public struct Intersection2DPoint: Sendable {
    /// The intersection point.
    public let point: SIMD2<Double>
    /// Parameter on the first curve.
    public let param1: Double
    /// Parameter on the second curve.
    public let param2: Double
}

/// Analytical 2D intersections between elementary curves.
public enum IntAna2d {

    /// Intersect two 2D lines.
    public static func intersectLines(
        line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>,
        line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>
    ) -> [Intersection2DPoint] {
        var buffer = [OCCTIntAna2dPoint](repeating: OCCTIntAna2dPoint(), count: 4)
        let n = Int(
            OCCTIntAna2dLinLin(
                line1Point.x, line1Point.y, line1Dir.x, line1Dir.y,
                line2Point.x, line2Point.y, line2Dir.x, line2Dir.y,
                &buffer, 4))
        return (0..<n).map {
            Intersection2DPoint(
                point: SIMD2(buffer[$0].x, buffer[$0].y),
                param1: buffer[$0].param1, param2: buffer[$0].param2)
        }
    }

    /// Intersect a 2D line and circle.
    ///
    /// `circleRadius` must be positive. A zero-radius circle is a point, and asking whether a
    /// point lies on a line is not an intersection query: measured (#553), OCCT answers with the
    /// centre and a `param2` of NaN, since a point has no parameter on a circle that is not
    /// there. A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let hits = IntAna2d.intersectLineCircle(linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
    ///                                         circleCenter: SIMD2(0, 0), circleRadius: 3)
    /// print(hits.map(\.point))   // (3, 0) and (-3, 0)
    /// ```
    public static func intersectLineCircle(
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        circleCenter: SIMD2<Double>, circleRadius: Double
    ) -> [Intersection2DPoint] {
        var buffer = [OCCTIntAna2dPoint](repeating: OCCTIntAna2dPoint(), count: 4)
        let n = Int(
            OCCTIntAna2dLinCirc(
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                circleCenter.x, circleCenter.y, circleRadius,
                &buffer, 4))
        return (0..<n).map {
            Intersection2DPoint(
                point: SIMD2(buffer[$0].x, buffer[$0].y),
                param1: buffer[$0].param1, param2: buffer[$0].param2)
        }
    }

    /// Intersect two 2D circles.
    ///
    /// Both radii must be positive, for the same reason as
    /// ``intersectLineCircle(linePoint:lineDir:circleCenter:circleRadius:)``: a zero radius makes
    /// the argument a point, not a curve to intersect (#553). A non-positive radius returns an
    /// empty array.
    ///
    /// ```swift
    /// let hits = IntAna2d.intersectCircles(center1: SIMD2(0, 0), radius1: 3,
    ///                                      center2: SIMD2(4, 0), radius2: 3)
    /// print(hits.count)   // 2
    /// ```
    public static func intersectCircles(
        center1: SIMD2<Double>, radius1: Double,
        center2: SIMD2<Double>, radius2: Double
    ) -> [Intersection2DPoint] {
        var buffer = [OCCTIntAna2dPoint](repeating: OCCTIntAna2dPoint(), count: 4)
        let n = Int(
            OCCTIntAna2dCircCirc(
                center1.x, center1.y, radius1,
                center2.x, center2.y, radius2,
                &buffer, 4))
        return (0..<n).map {
            Intersection2DPoint(
                point: SIMD2(buffer[$0].x, buffer[$0].y),
                param1: buffer[$0].param1, param2: buffer[$0].param2)
        }
    }
}

// MARK: - Extrema 2D

/// 2D extrema result between curves or point-curve.
public struct Extrema2DResult: Sendable {
    /// Squared distance at this extremum.
    public let squareDistance: Double
    /// Distance at this extremum.
    public var distance: Double { squareDistance.squareRoot() }
    /// Parameter on the first curve.
    public let param1: Double
    /// Parameter on the second curve.
    public let param2: Double
    /// Closest point on the first curve.
    public let point1: SIMD2<Double>
    /// Closest point on the second curve.
    public let point2: SIMD2<Double>
}

/// 2D extrema (closest/farthest distances) between elementary curves.
public enum Extrema2d {

    /// Distance between two parallel 2D lines.
    ///
    /// - Returns: Tuple of (isParallel, results). If parallel, one result with distance is returned.
    public static func distanceBetweenLines(
        line1Point: SIMD2<Double>, line1Dir: SIMD2<Double>,
        line2Point: SIMD2<Double>, line2Dir: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> (isParallel: Bool, results: [Extrema2DResult]) {
        var buffer = [OCCTExtrema2dResult](repeating: OCCTExtrema2dResult(), count: 4)
        var isParallel = false
        let n = Int(
            OCCTExtremaExtElC2dLinLin(
                line1Point.x, line1Point.y, line1Dir.x, line1Dir.y,
                line2Point.x, line2Point.y, line2Dir.x, line2Dir.y,
                tolerance, &isParallel, &buffer, 4))
        let results = (0..<max(n, 0)).map {
            Extrema2DResult(
                squareDistance: buffer[$0].squareDistance,
                param1: buffer[$0].param1, param2: buffer[$0].param2,
                point1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                point2: SIMD2(buffer[$0].p2x, buffer[$0].p2y))
        }
        return (isParallel: isParallel, results: results)
    }

    /// Distance between a 2D line and circle.
    ///
    /// `circleRadius` must be positive. With a radius of zero the extrema come back correct but
    /// duplicated (#553); ``distanceFromPointToLine(point:linePoint:lineDir:)`` answers the point
    /// question directly. A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let extrema = Extrema2d.distanceBetweenLineAndCircle(linePoint: SIMD2(0, 10),
    ///                                                      lineDir: SIMD2(1, 0),
    ///                                                      circleCenter: SIMD2(0, 0),
    ///                                                      circleRadius: 3)
    /// print(extrema.map(\.distance))   // 7 and 13
    /// ```
    public static func distanceBetweenLineAndCircle(
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        circleCenter: SIMD2<Double>, circleRadius: Double,
        tolerance: Double = 1e-6
    ) -> [Extrema2DResult] {
        var buffer = [OCCTExtrema2dResult](repeating: OCCTExtrema2dResult(), count: 4)
        let n = Int(
            OCCTExtremaExtElC2dLinCirc(
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                circleCenter.x, circleCenter.y, circleRadius,
                tolerance, &buffer, 4))
        return (0..<max(n, 0)).map {
            Extrema2DResult(
                squareDistance: buffer[$0].squareDistance,
                param1: buffer[$0].param1, param2: buffer[$0].param2,
                point1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                point2: SIMD2(buffer[$0].p2x, buffer[$0].p2y))
        }
    }

    /// Closest/farthest points on a 2D circle from a point.
    ///
    /// `circleRadius` must be positive. This is the family where a zero radius loses the answer
    /// outright: measured (#553), OCCT reports no extremum at all rather than the distance to the
    /// centre. A non-positive radius returns an empty array.
    ///
    /// ```swift
    /// let extrema = Extrema2d.distanceFromPointToCircle(point: SIMD2(0, 10),
    ///                                                   circleCenter: SIMD2(0, 0),
    ///                                                   circleRadius: 3)
    /// print(extrema.map(\.distance))   // 7 and 13
    /// ```
    public static func distanceFromPointToCircle(
        point: SIMD2<Double>,
        circleCenter: SIMD2<Double>, circleRadius: Double,
        tolerance: Double = 1e-6
    ) -> [Extrema2DResult] {
        var buffer = [OCCTExtrema2dResult](repeating: OCCTExtrema2dResult(), count: 4)
        let n = Int(
            OCCTExtremaExtPElC2dCirc(
                point.x, point.y,
                circleCenter.x, circleCenter.y, circleRadius,
                tolerance, &buffer, 4))
        return (0..<max(n, 0)).map {
            Extrema2DResult(
                squareDistance: buffer[$0].squareDistance,
                param1: buffer[$0].param1, param2: buffer[$0].param2,
                point1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                point2: SIMD2(buffer[$0].p2x, buffer[$0].p2y))
        }
    }

    /// Closest point on a 2D line from a point.
    public static func distanceFromPointToLine(
        point: SIMD2<Double>,
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> [Extrema2DResult] {
        var buffer = [OCCTExtrema2dResult](repeating: OCCTExtrema2dResult(), count: 4)
        let n = Int(
            OCCTExtremaExtPElC2dLin(
                point.x, point.y,
                linePoint.x, linePoint.y, lineDir.x, lineDir.y,
                tolerance, &buffer, 4))
        return (0..<max(n, 0)).map {
            Extrema2DResult(
                squareDistance: buffer[$0].squareDistance,
                param1: buffer[$0].param1, param2: buffer[$0].param2,
                point1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                point2: SIMD2(buffer[$0].p2x, buffer[$0].p2y))
        }
    }

    /// Distance between two 2D curves.
    public static func distanceBetweenCurves(
        _ c1: Curve2D, first1: Double, last1: Double,
        _ c2: Curve2D, first2: Double, last2: Double
    ) -> [Extrema2DResult] {
        var buffer = [OCCTExtrema2dResult](repeating: OCCTExtrema2dResult(), count: 32)
        let n = Int(
            OCCTExtremaExtCC2d(
                c1.handle, first1, last1,
                c2.handle, first2, last2,
                &buffer, 32))
        return (0..<max(n, 0)).map {
            Extrema2DResult(
                squareDistance: buffer[$0].squareDistance,
                param1: buffer[$0].param1, param2: buffer[$0].param2,
                point1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                point2: SIMD2(buffer[$0].p2x, buffer[$0].p2y))
        }
    }
}

// MARK: - Geom2dLProp: Curvature Inflection/Extrema

/// Type of curvature feature point.
///
/// A same-cases, different-ordering vocabulary for `Curve2DSpecialPointType`, kept for
/// callers of `curvatureExtremaDetailed()`/`inflectionPointsDetailed()`. Both are derived
/// from a single `GeomLProp_CurAndInf2d` computation (`curvatureExtrema()`/`inflectionPoints()`);
/// see `CurInfType.init(_:)` for the (test-pinned) mapping between the two.
public enum CurInfType: Int32, Sendable {
    case curvatureMinimum = 0
    case curvatureMaximum = 1
    case inflection = 2
}

extension CurInfType {
    /// Maps from the `Curve2DSpecialPointType` vocabulary used by the plain family.
    public init(_ type: Curve2DSpecialPointType) {
        switch type {
        case .inflection: self = .inflection
        case .minCurvature: self = .curvatureMinimum
        case .maxCurvature: self = .curvatureMaximum
        }
    }
}

/// A curvature feature point on a 2D curve.
public struct CurInfPoint: Sendable {
    /// Parameter value on the curve.
    public let parameter: Double
    /// Type of feature (min/max curvature, or inflection).
    public let type: CurInfType
}

extension Curve2D {
    /// Find curvature extrema (min/max) on this 2D curve with type classification.
    ///
    /// Delegates to `curvatureExtrema()`, the same `GeomLProp_CurAndInf2d` computation,
    /// translating its results into the `CurInfPoint`/`CurInfType` vocabulary.
    public func curvatureExtremaDetailed() -> [CurInfPoint] {
        curvatureExtrema().map { CurInfPoint(parameter: $0.parameter, type: CurInfType($0.type)) }
    }

    /// Find inflection points on this 2D curve with type information.
    ///
    /// Delegates to `inflectionPoints()`, the same `GeomLProp_CurAndInf2d` computation,
    /// translating its results into the `CurInfPoint`/`CurInfType` vocabulary.
    public func inflectionPointsDetailed() -> [CurInfPoint] {
        inflectionPoints().map { CurInfPoint(parameter: $0, type: .inflection) }
    }
}

// MARK: - Bisector_BisecAna

extension Curve2D {
    /// Compute analytical bisector between this curve and another.
    ///
    /// The bisector is the locus of points equidistant from both curves.
    ///
    /// - Parameters:
    ///   - other: The other 2D curve
    ///   - referencePoint: Point near the desired bisector branch
    ///   - direction1: Tangent direction of this curve at the reference
    ///   - direction2: Tangent direction of the other curve at the reference
    ///   - sense: Orientation sense (1.0 or -1.0)
    ///   - tolerance: Geometric tolerance
    /// - Returns: The bisector as a 2D curve, or nil on failure
    public func bisector(
        with other: Curve2D,
        referencePoint: SIMD2<Double>,
        direction1: SIMD2<Double>, direction2: SIMD2<Double>,
        sense: Double = 1.0, tolerance: Double = 1e-6
    ) -> Curve2D? {
        guard
            let h = OCCTBisectorBisecAnaCurveCurve(
                handle, other.handle,
                referencePoint.x, referencePoint.y,
                direction1.x, direction1.y, direction2.x, direction2.y,
                sense, tolerance)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Compute analytical bisector between this curve and a point.
    ///
    /// - Parameters:
    ///   - point: The point
    ///   - referencePoint: Point near the desired bisector branch
    ///   - direction1: Tangent direction of this curve at the reference
    ///   - direction2: Direction from the point at the reference
    ///   - sense: Orientation sense
    ///   - tolerance: Geometric tolerance
    /// - Returns: The bisector as a 2D curve, or nil on failure
    public func bisector(
        withPoint point: SIMD2<Double>,
        referencePoint: SIMD2<Double>,
        direction1: SIMD2<Double>, direction2: SIMD2<Double>,
        sense: Double = 1.0, tolerance: Double = 1e-6
    ) -> Curve2D? {
        guard
            let h = OCCTBisectorBisecAnaCurvePoint(
                handle,
                point.x, point.y,
                referencePoint.x, referencePoint.y,
                direction1.x, direction1.y, direction2.x, direction2.y,
                sense, tolerance)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Compute analytical bisector between two points (perpendicular bisector line).
    ///
    /// - Parameters:
    ///   - p1: First point
    ///   - p2: Second point
    ///   - referencePoint: Point near the desired bisector
    ///   - direction1: Direction from first point
    ///   - direction2: Direction from second point
    ///   - sense: Orientation sense
    ///   - tolerance: Geometric tolerance
    /// - Returns: The bisector as a 2D curve (line), or nil on failure
    public static func bisectorBetweenPoints(
        _ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
        referencePoint: SIMD2<Double>,
        direction1: SIMD2<Double>, direction2: SIMD2<Double>,
        sense: Double = 1.0, tolerance: Double = 1e-6
    ) -> Curve2D? {
        guard
            let h = OCCTBisectorBisecAnaPointPoint(
                p1.x, p1.y, p2.x, p2.y,
                referencePoint.x, referencePoint.y,
                direction1.x, direction1.y, direction2.x, direction2.y,
                sense, tolerance)
        else { return nil }
        return Curve2D(handle: h)
    }

    // MARK: - Point2D Integration

    /// Evaluate the curve at parameter `t`, returning a `Point2D`.
    public func pointAt(_ t: Double) -> Point2D? {
        guard let h = OCCTCurve2DPointAt(handle, t) else { return nil }
        return Point2D(handle: h)
    }

    /// Create a line segment between two `Point2D` instances.
    public static func segment(from p1: Point2D, to p2: Point2D) -> Curve2D? {
        guard let h = OCCTCurve2DSegmentFromPoints(p1.handle, p2.handle) else { return nil }
        return Curve2D(handle: h)
    }

    /// Project a `Point2D` onto this curve.
    ///
    /// - Parameter point: Point to project.
    /// - Returns: `(parameter, distance)` of the nearest solution, or `nil` if there is no curve to
    ///   answer about.
    ///
    /// The same nearest-solution computation as ``project(point:)``, returned without the projected
    /// point itself, so it reports the true nearest point over the curve's own domain: a point past
    /// the end answers with that end (#615). Note that a parameter of `0` is a perfectly ordinary
    /// success (projecting a segment's own start point onto it returns exactly that), so `nil` is
    /// the only failure signal.
    ///
    /// ```swift
    /// let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
    /// let start = Point2D(x: 0, y: 0)!
    /// #expect(segment.project(start)?.parameter == 0)                    // success, at parameter 0
    /// #expect(segment.project(Point2D(x: 100, y: 0)!)?.parameter == 10)  // past the end: the end
    /// ```
    public func project(_ point: Point2D) -> (parameter: Double, distance: Double)? {
        var dist: Double = 0
        let param = OCCTCurve2DProjectPoint2D(handle, point.handle, &dist)
        if dist < 0 { return nil }
        return (param, dist)
    }

    // MARK: - FairCurve

    /// FairCurve analysis code indicating computation result.
    public enum FairCurveCode: Int32, Sendable {
        case ok = 0
        case notConverged = 1
        case infiniteSliding = 2
        case nullHeight = 3
    }

    /// Create a fair curve (batten) between two 2D points.
    ///
    /// A batten is a curve of minimal energy passing through two points with specified
    /// constraint orders, height, slope, and angles.
    ///
    /// - Parameters:
    ///   - p1: First point (x, y)
    ///   - p2: Second point (x, y)
    ///   - height: Height of the batten cross-section
    ///   - slope: Slope parameter (0 = no slope)
    ///   - angle1: Angle constraint at first point (radians)
    ///   - angle2: Angle constraint at second point (radians)
    ///   - constraintOrder1: Order at first point (0=point, 1=tangent, 2=curvature)
    ///   - constraintOrder2: Order at second point
    ///   - freeSliding: Whether the batten slides freely
    /// - Returns: Tuple of (curve, code) or nil on failure
    public static func fairCurveBatten(
        p1: SIMD2<Double>, p2: SIMD2<Double>,
        height: Double = 1.0, slope: Double = 0.0,
        angle1: Double = 0.0, angle2: Double = 0.0,
        constraintOrder1: Int = 1, constraintOrder2: Int = 1,
        freeSliding: Bool = true
    ) -> (curve: Curve2D, code: FairCurveCode)? {
        var outCode: Int32 = 0
        guard
            let h = OCCTFairCurveBatten(
                p1.x, p1.y, p2.x, p2.y,
                height, slope, angle1, angle2,
                Int32(constraintOrder1), Int32(constraintOrder2), freeSliding,
                &outCode)
        else { return nil }
        let code = FairCurveCode(rawValue: outCode) ?? .ok
        return (Curve2D(handle: h), code)
    }

    /// Create a fair curve with minimal variation between two 2D points.
    ///
    /// Like a batten but minimizes curvature variation, producing smoother curves.
    /// Supports additional curvature and physical ratio constraints.
    ///
    /// - Parameters:
    ///   - p1: First point (x, y)
    ///   - p2: Second point (x, y)
    ///   - height: Height of the cross-section
    ///   - slope: Slope parameter
    ///   - angle1: Angle at first point (radians)
    ///   - angle2: Angle at second point (radians)
    ///   - constraintOrder1: Order at first point (0=point, 1=tangent, 2=curvature)
    ///   - constraintOrder2: Order at second point
    ///   - freeSliding: Whether sliding is free
    ///   - physicalRatio: Physical ratio (0..1), blends between batten and minimal variation
    ///   - curvature1: Curvature at first point (used when constraintOrder >= 2)
    ///   - curvature2: Curvature at second point
    /// - Returns: Tuple of (curve, code) or nil on failure
    public static func fairCurveMinimalVariation(
        p1: SIMD2<Double>, p2: SIMD2<Double>,
        height: Double = 1.0, slope: Double = 0.0,
        angle1: Double = 0.0, angle2: Double = 0.0,
        constraintOrder1: Int = 1, constraintOrder2: Int = 1,
        freeSliding: Bool = true,
        physicalRatio: Double = 0.0,
        curvature1: Double = 0.0, curvature2: Double = 0.0
    ) -> (curve: Curve2D, code: FairCurveCode)? {
        var outCode: Int32 = 0
        guard
            let h = OCCTFairCurveMinimalVariation(
                p1.x, p1.y, p2.x, p2.y,
                height, slope, angle1, angle2,
                Int32(constraintOrder1), Int32(constraintOrder2), freeSliding,
                physicalRatio, curvature1, curvature2,
                &outCode)
        else { return nil }
        let code = FairCurveCode(rawValue: outCode) ?? .ok
        return (Curve2D(handle: h), code)
    }

    // MARK: - v0.80.0: Extrema, gce factories, GeomTools persistence

    /// Result of local 2D curve-curve extrema search.
    public struct LocalExtrema2dResult: Sendable {
        public let isDone: Bool
        public let squareDistance: Double
        public let point1: SIMD2<Double>
        public let param1: Double
        public let point2: SIMD2<Double>
        public let param2: Double
    }

    /// Find local 2D curve-curve extremum near seed parameters.
    public func locateExtremaCC(
        range1: ClosedRange<Double>? = nil,
        other: Curve2D,
        range2: ClosedRange<Double>? = nil,
        seedU: Double, seedV: Double
    ) -> LocalExtrema2dResult {
        let d1 = range1 ?? domain
        let d2 = range2 ?? other.domain
        let r = OCCTExtremaLocateExtCC2d(
            handle, d1.lowerBound, d1.upperBound,
            other.handle, d2.lowerBound, d2.upperBound,
            seedU, seedV)
        return LocalExtrema2dResult(
            isDone: r.isDone, squareDistance: r.squareDistance,
            point1: SIMD2(r.x1, r.y1), param1: r.param1,
            point2: SIMD2(r.x2, r.y2), param2: r.param2)
    }

    /// Create a 2D circle from center + radius (`gce_MakeCirc2d`).
    ///
    /// Geometrically identical to `circle(center:radius:)` (both produce a `Geom2d_Circle` on the
    /// same X-axis-oriented frame) and, since #411, enforces the same radius contract.
    ///
    /// - Parameters:
    ///   - center: Circle centre.
    ///   - radius: Circle radius. Must be `> 0`; zero and negative radii return `nil`.
    /// - Returns: The circle, or `nil` if `radius <= 0`.
    ///
    /// ```swift
    /// let c = Curve2D.circleFromCenterRadius(center: .zero, radius: 5)
    /// #expect(c != nil)
    /// // Same rejection as the direct factory: no degenerate zero-radius circle.
    /// #expect(Curve2D.circleFromCenterRadius(center: .zero, radius: 0) == nil)
    /// ```
    public static func circleFromCenterRadius(
        center: SIMD2<Double>,
        radius: Double
    ) -> Curve2D? {
        guard let h = OCCTGceMakeCirc2dFromCenterRadius(center.x, center.y, radius) else {
            return nil
        }
        return Curve2D(handle: h)
    }

    /// Create a 2D circle through 3 points (gce_MakeCirc2d).
    public static func circleThrough3Points(
        _ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
        _ p3: SIMD2<Double>
    ) -> Curve2D? {
        guard
            let h = OCCTGceMakeCirc2dFrom3Points(
                p1.x, p1.y, p2.x, p2.y,
                p3.x, p3.y)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a 2D line from 2 points (gce_MakeLin2d).
    public static func lineFrom2Points(_ p1: SIMD2<Double>, _ p2: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTGceMakeLin2dFrom2Points(p1.x, p1.y, p2.x, p2.y) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a 2D line from equation Ax+By+C=0 (gce_MakeLin2d).
    public static func lineFromEquation(a: Double, b: Double, c: Double) -> Curve2D? {
        guard let h = OCCTGceMakeLin2dFromEquation(a, b, c) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a 2D ellipse from centre, major-axis direction and radii (`gce_MakeElips2d`).
    ///
    /// Geometrically identical to `ellipse(center:majorRadius:minorRadius:rotation:)`, which takes
    /// the major-axis direction as a rotation angle instead of a vector, and since #487 enforces the
    /// same radius contract.
    ///
    /// - Parameters:
    ///   - center: Ellipse centre.
    ///   - direction: Major-axis direction.
    ///   - majorRadius: Semi-major axis length. Must be `> 0` and `>= minorRadius`.
    ///   - minorRadius: Semi-minor axis length. Must be `> 0`.
    /// - Returns: The ellipse, or `nil` if either radius is not positive or `minorRadius` exceeds
    ///   `majorRadius`.
    ///
    /// ```swift
    /// let e = Curve2D.ellipseFromCenterDir(center: .zero, direction: SIMD2(1, 0),
    ///                                      majorRadius: 8, minorRadius: 4)
    /// #expect(e != nil)
    /// // Same rejections as the direct factory: no degenerate ellipse, no negative minor radius.
    /// #expect(Curve2D.ellipseFromCenterDir(center: .zero, direction: SIMD2(1, 0),
    ///                                      majorRadius: 0, minorRadius: 0) == nil)
    /// #expect(Curve2D.ellipseFromCenterDir(center: .zero, direction: SIMD2(1, 0),
    ///                                      majorRadius: 5, minorRadius: -3) == nil)
    /// ```
    public static func ellipseFromCenterDir(
        center: SIMD2<Double>, direction: SIMD2<Double>,
        majorRadius: Double,
        minorRadius: Double
    ) -> Curve2D? {
        guard
            let h = OCCTGceMakeElips2d(
                center.x, center.y, direction.x, direction.y,
                majorRadius, minorRadius)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a 2D hyperbola from centre, major-axis direction and radii (`gce_MakeHypr2d`).
    ///
    /// Geometrically identical to `hyperbola(center:majorRadius:minorRadius:rotation:)`, which takes
    /// the major-axis direction as a rotation angle instead of a vector, and since #487 enforces the
    /// same radius contract.
    ///
    /// Unlike an ellipse, a hyperbola puts no ordering on its radii: a minor radius larger than the
    /// major one is an ordinary hyperbola and is accepted.
    ///
    /// - Parameters:
    ///   - center: Hyperbola centre.
    ///   - direction: Major-axis direction.
    ///   - majorRadius: Semi-major axis length. Must be `> 0`.
    ///   - minorRadius: Semi-minor axis length. Must be `> 0`.
    /// - Returns: The hyperbola, or `nil` if either radius is not positive.
    ///
    /// ```swift
    /// let h = Curve2D.hyperbolaFromCenterDir(center: .zero, direction: SIMD2(1, 0),
    ///                                        majorRadius: 6, minorRadius: 3)
    /// #expect(h != nil)
    /// // Minor larger than major is a valid hyperbola, unlike for an ellipse.
    /// #expect(Curve2D.hyperbolaFromCenterDir(center: .zero, direction: SIMD2(1, 0),
    ///                                        majorRadius: 3, minorRadius: 6) != nil)
    /// // Same rejection as the direct factory: no degenerate zero-radius hyperbola.
    /// #expect(Curve2D.hyperbolaFromCenterDir(center: .zero, direction: SIMD2(1, 0),
    ///                                        majorRadius: 0, minorRadius: 0) == nil)
    /// ```
    public static func hyperbolaFromCenterDir(
        center: SIMD2<Double>, direction: SIMD2<Double>,
        majorRadius: Double,
        minorRadius: Double
    ) -> Curve2D? {
        guard
            let h = OCCTGceMakeHypr2d(
                center.x, center.y, direction.x, direction.y,
                majorRadius, minorRadius)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a 2D parabola from a point on its axis of symmetry, that axis' direction, and the
    /// focal length (`gce_MakeParab2d`).
    ///
    /// `center` is the parabola's vertex, so this places the curve the same way
    /// `parabola(focus:direction:focalLength:)` does once that factory has stepped back from the
    /// focus to the vertex. Since #487 both enforce the same focal-length contract.
    ///
    /// - Parameters:
    ///   - center: Vertex of the parabola.
    ///   - direction: Direction of the axis of symmetry.
    ///   - focal: Distance from vertex to focus. Must be `> 0`; at zero the parabola degenerates
    ///     into a line parallel to its own axis.
    /// - Returns: The parabola, or `nil` if `focal <= 0`.
    ///
    /// ```swift
    /// let p = Curve2D.parabolaFromCenterDir(center: .zero, direction: SIMD2(1, 0), focal: 3)
    /// #expect(p != nil)
    /// // Same rejection as the direct factory: a zero focal length is a line, not a parabola.
    /// #expect(Curve2D.parabolaFromCenterDir(center: .zero, direction: SIMD2(1, 0), focal: 0) == nil)
    /// ```
    public static func parabolaFromCenterDir(
        center: SIMD2<Double>, direction: SIMD2<Double>,
        focal: Double
    ) -> Curve2D? {
        guard
            let h = OCCTGceMakeParab2d(
                center.x, center.y, direction.x, direction.y,
                focal)
        else { return nil }
        return Curve2D(handle: h)
    }

    /// Serialize 2D curves to string via GeomTools_Curve2dSet.
    public static func serializeCurves(_ curves: [Curve2D]) -> String? {
        let handles = curves.map { $0.handle as OCCTCurve2DRef }
        guard
            let cStr = handles.withUnsafeBufferPointer({
                OCCTGeomToolsCurve2dSetWrite($0.baseAddress!, Int32(curves.count))
            })
        else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(cStr)
        return result
    }

    /// Deserialize 2D curves from string via GeomTools_Curve2dSet.
    public static func deserializeCurves(_ data: String) -> [Curve2D]? {
        var count: Int32 = 0
        guard let arr = OCCTGeomToolsCurve2dSetRead(data, &count), count > 0 else { return nil }
        var curves: [Curve2D] = []
        for i in 0..<Int(count) {
            if let h = arr[i] {
                curves.append(Curve2D(handle: h))
            }
        }
        free(arr)
        return curves.isEmpty ? nil : curves
    }

    // MARK: - Geom2d_Circle Properties (v0.108.0)

    /// Access 2D circle-specific properties.
    public struct CircleProperties: Sendable, NativeHandleView {
        let owner: Curve2D

        /// The radius.
        public var radius: Double { OCCTCurve2DCircleRadius(handle) }

        /// Set the radius.
        @discardableResult
        public func setRadius(_ r: Double) -> Bool { OCCTCurve2DCircleSetRadius(handle, r) }

        /// The eccentricity (always 0).
        public var eccentricity: Double { OCCTCurve2DCircleEccentricity(handle) }

        /// The center point.
        public var center: SIMD2<Double> {
            var x = 0.0
            var y = 0.0
            OCCTCurve2DCircleCenter(handle, &x, &y)
            return SIMD2(x, y)
        }

        /// The X axis (position + direction).
        public var xAxis: (position: SIMD2<Double>, direction: SIMD2<Double>) {
            var px = 0.0
            var py = 0.0
            var dx = 0.0
            var dy = 0.0
            OCCTCurve2DCircleXAxis(handle, &px, &py, &dx, &dy)
            return (SIMD2(px, py), SIMD2(dx, dy))
        }
    }

    /// Circle-specific properties (meaningful only when the underlying curve is a Geom2d_Circle).
    public var circleProperties: CircleProperties { CircleProperties(owner: self) }

    // MARK: - Geom2d_Ellipse Properties (v0.108.0)

    /// Access 2D ellipse-specific properties.
    public struct EllipseProperties: Sendable, NativeHandleView {
        let owner: Curve2D

        /// The major radius.
        public var majorRadius: Double { OCCTCurve2DEllipseMajorRadius(handle) }

        /// The minor radius.
        public var minorRadius: Double { OCCTCurve2DEllipseMinorRadius(handle) }

        /// Set the major radius.
        @discardableResult
        public func setMajorRadius(_ r: Double) -> Bool {
            OCCTCurve2DEllipseSetMajorRadius(handle, r)
        }

        /// Set the minor radius.
        @discardableResult
        public func setMinorRadius(_ r: Double) -> Bool {
            OCCTCurve2DEllipseSetMinorRadius(handle, r)
        }

        /// The eccentricity.
        public var eccentricity: Double { OCCTCurve2DEllipseEccentricity(handle) }

        /// The focal distance.
        public var focal: Double { OCCTCurve2DEllipseFocal(handle) }

        /// The first focus.
        public var focus1: SIMD2<Double> {
            var x = 0.0
            var y = 0.0
            OCCTCurve2DEllipseFocus1(handle, &x, &y)
            return SIMD2(x, y)
        }
    }

    /// Ellipse-specific properties (meaningful only when the underlying curve is a Geom2d_Ellipse).
    public var ellipseProperties: EllipseProperties { EllipseProperties(owner: self) }

    // MARK: - Geom2d_Hyperbola Properties (v0.108.0)

    /// Access 2D hyperbola-specific properties.
    public struct HyperbolaProperties: Sendable, NativeHandleView {
        let owner: Curve2D

        /// The major radius.
        public var majorRadius: Double { OCCTCurve2DHyperbolaMajorRadius(handle) }

        /// The minor radius.
        public var minorRadius: Double { OCCTCurve2DHyperbolaMinorRadius(handle) }

        /// The eccentricity.
        public var eccentricity: Double { OCCTCurve2DHyperbolaEccentricity(handle) }

        /// The focal distance.
        public var focal: Double { OCCTCurve2DHyperbolaFocal(handle) }

        /// The first focus.
        public var focus1: SIMD2<Double> {
            var x = 0.0
            var y = 0.0
            OCCTCurve2DHyperbolaFocus1(handle, &x, &y)
            return SIMD2(x, y)
        }
    }

    /// Hyperbola-specific properties (meaningful only when the underlying curve is a Geom2d_Hyperbola).
    public var hyperbolaProperties: HyperbolaProperties { HyperbolaProperties(owner: self) }

    // MARK: - Geom2d_Parabola Properties (v0.108.0)

    /// Access 2D parabola-specific properties.
    public struct ParabolaProperties: Sendable, NativeHandleView {
        let owner: Curve2D

        /// The focal distance.
        public var focal: Double { OCCTCurve2DParabolaFocal(handle) }

        /// Set the focal distance.
        @discardableResult
        public func setFocal(_ f: Double) -> Bool { OCCTCurve2DParabolaSetFocal(handle, f) }

        /// The focus point.
        public var focus: SIMD2<Double> {
            var x = 0.0
            var y = 0.0
            OCCTCurve2DParabolaFocus(handle, &x, &y)
            return SIMD2(x, y)
        }

        /// The eccentricity (always 1).
        public var eccentricity: Double { OCCTCurve2DParabolaEccentricity(handle) }

        /// The parameter (2 * focal).
        public var parameter: Double { OCCTCurve2DParabolaParameter(handle) }
    }

    /// Parabola-specific properties (meaningful only when the underlying curve is a Geom2d_Parabola).
    public var parabolaProperties: ParabolaProperties { ParabolaProperties(owner: self) }

    // MARK: - Geom2d_Line Properties (v0.108.0)

    /// Access 2D line-specific properties.
    public struct LineProperties: Sendable, NativeHandleView {
        let owner: Curve2D

        /// The direction.
        public var direction: SIMD2<Double> {
            var dx = 0.0
            var dy = 0.0
            OCCTCurve2DLineDirection(handle, &dx, &dy)
            return SIMD2(dx, dy)
        }

        /// The location (origin).
        public var location: SIMD2<Double> {
            var x = 0.0
            var y = 0.0
            OCCTCurve2DLineLocation(handle, &x, &y)
            return SIMD2(x, y)
        }

        /// Set the direction.
        @discardableResult
        public func setDirection(_ d: SIMD2<Double>) -> Bool {
            OCCTCurve2DLineSetDirection(handle, d.x, d.y)
        }

        /// Set the location.
        @discardableResult
        public func setLocation(_ p: SIMD2<Double>) -> Bool {
            OCCTCurve2DLineSetLocation(handle, p.x, p.y)
        }

        /// Distance from the line to a point.
        public func distance(to point: SIMD2<Double>) -> Double {
            OCCTCurve2DLineDistance(handle, point.x, point.y)
        }

        /// The gp_Lin2d representation (location + direction).
        public var lin2d: (location: SIMD2<Double>, direction: SIMD2<Double>) {
            var px = 0.0
            var py = 0.0
            var dx = 0.0
            var dy = 0.0
            OCCTCurve2DLineLin2d(handle, &px, &py, &dx, &dy)
            return (SIMD2(px, py), SIMD2(dx, dy))
        }
    }

    /// Line-specific properties (meaningful only when the underlying curve is a Geom2d_Line).
    public var lineProperties: LineProperties { LineProperties(owner: self) }

    // MARK: - Geom2d_OffsetCurve Properties (v0.108.0)

    /// Access 2D offset curve-specific properties.
    public struct OffsetProperties: Sendable, NativeHandleView {
        let owner: Curve2D

        /// The offset value.
        public var offset: Double { OCCTCurve2DOffsetValue(handle) }

        /// Set the offset value.
        @discardableResult
        public func setOffset(_ v: Double) -> Bool { OCCTCurve2DOffsetSetValue(handle, v) }

        /// The basis curve.
        public var basisCurve: Curve2D? {
            guard let h = OCCTCurve2DOffsetBasisCurve(handle) else { return nil }
            return Curve2D(handle: h)
        }
    }

    /// Offset curve properties (meaningful only when the underlying curve is a Geom2d_OffsetCurve).
    public var offsetProperties: OffsetProperties { OffsetProperties(owner: self) }

    // MARK: - v0.115.0: Interpolation expansion, trim, length

    /// Interpolate a 2D BSpline through points with endpoint tangents.
    ///
    /// A spelling of `interpolate(through:startTangent:endTangent:tolerance:)` with the `points:`
    /// argument label, and it delegates to it, so the two cannot produce different curves for the
    /// same input.
    ///
    /// - Parameters:
    ///   - points: Points to interpolate. At least 2.
    ///   - startTangent: Tangent direction at the first point.
    ///   - endTangent: Tangent direction at the last point.
    ///   - tolerance: Interpolation tolerance. Defaults to `1e-6`, which is what this method used
    ///     to hardcode with no way to change it (#410).
    /// - Returns: The interpolated curve, or `nil` if interpolation fails.
    ///
    /// ```swift
    /// let curve = Curve2D.interpolate(points: [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)],
    ///                                  startTangent: SIMD2(1, 1), endTangent: SIMD2(1, -1),
    ///                                  tolerance: 1e-4)
    /// #expect(curve != nil)
    /// ```
    public static func interpolate(
        points: [SIMD2<Double>],
        startTangent: SIMD2<Double>,
        endTangent: SIMD2<Double>,
        tolerance: Double = 1e-6
    ) -> Curve2D? {
        interpolate(
            through: points, startTangent: startTangent, endTangent: endTangent,
            tolerance: tolerance)
    }

    /// Interpolate a periodic (closed) 2D BSpline through points.
    ///
    /// A spelling of `interpolate(through:closed:tolerance:)` with `closed: true`, and it
    /// delegates to it, so the two cannot produce different curves for the same input.
    ///
    /// - Parameters:
    ///   - points: Points to interpolate. At least 2; the curve closes back to `points[0]`, so
    ///     do not repeat the first point at the end.
    ///   - tolerance: Interpolation tolerance. Defaults to `1e-6`, which is what this method used
    ///     to hardcode with no way to change it (#412).
    /// - Returns: The periodic curve, or `nil` if interpolation fails.
    ///
    /// ```swift
    /// let loop = Curve2D.interpolatePeriodic(points: [
    ///     SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10),
    /// ])
    /// #expect(loop?.isPeriodic == true)
    ///
    /// // Identical to spelling it out on the general factory:
    /// let same = Curve2D.interpolate(through: [
    ///     SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10),
    /// ], closed: true)
    /// #expect(loop?.domain == same?.domain)
    /// ```
    public static func interpolatePeriodic(
        points: [SIMD2<Double>],
        tolerance: Double = 1e-6
    ) -> Curve2D? {
        interpolate(through: points, closed: true, tolerance: tolerance)
    }

    /// Approximate a 2D BSpline through points with degree and continuity control.
    ///
    /// `continuity` is a ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2, 3=C3). Unlike the
    /// `approximated` family, the fitter accepts every value without failing: it treats the
    /// request as an upper bound on what it will try to achieve.
    public static func approximate(
        points: [SIMD2<Double>],
        degMin: Int = 3, degMax: Int = 8,
        continuity: Int = 2, tolerance: Double = 1e-3
    ) -> Curve2D? {
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y]) }
        guard
            let ref = flat.withUnsafeBufferPointer({ buf in
                OCCTPoints2DToBSplineWithParams(
                    buf.baseAddress!, Int32(points.count),
                    Int32(degMin), Int32(degMax),
                    Int32(continuity), tolerance)
            })
        else { return nil }
        return Curve2D(handle: ref)
    }

    /// Compute the arc length of this curve between parameters `u1` and `u2` (non-optional).
    ///
    /// Delegates to ``length(from:to:)``, the failure-distinguishing entry point, and shares its
    /// contract: the range may be given in either order, equal parameters measure `0`, an
    /// out-of-domain range measures only the part that lies on the curve (winding a periodic
    /// one, #600), and a non-finite bound (`.nan` or `±.infinity`) fails rather than propagating
    /// (#548). Returns `-1.0` if the computation fails. Arc length is otherwise always
    /// non-negative, so this is an unambiguous failure sentinel, never confusable with a genuine
    /// zero-length segment. Use ``length(from:to:)`` directly if you need an optional rather
    /// than a sentinel value.
    ///
    /// ```swift
    /// let circle = Curve2D.circle(center: .zero, radius: 5)!
    /// let half = circle.arcLength(from: 0, to: .pi)      // ≈ 15.71
    /// let same = circle.arcLength(from: .pi, to: 0)      // the same 15.71
    /// ```
    ///
    /// - Note: Until #549 this measured through a pre-bounded `Geom2dAdaptor_Curve`, which
    ///   reported a reversed range as `-1.0` and extrapolated past a multi-span curve's knots:
    ///   4771.88 for a BSpline 457.26 long, past what #600 fixed on the surviving delegate.
    ///   `Curve3D.arcLength(from:to:)` dropped the same adaptor in #506.
    public func arcLength(from u1: Double, to u2: Double) -> Double {
        length(from: u1, to: u2) ?? -1.0
    }

    /// Split this curve at C1 discontinuities.
    ///
    /// - Parameters:
    ///   - continuity: `1` or less splits at C1 discontinuities; above `1` returns the curve
    ///     unsplit, as a single segment.
    ///   - tolerance: Knot-removal tolerance passed to the underlying conversion.
    ///   - maxSegments: Output *capacity* (default 32), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: The segments, or an empty array if the curve cannot be converted.
    public func splitAtContinuity(
        continuity: Int = 1, tolerance: Double = 1e-6,
        maxSegments: Int = 32
    ) -> [Curve2D] {
        let maxSegments = Sampling.capacity(maxSegments)
        guard maxSegments > 0 else { return [] }
        var refs = [OCCTCurve2DRef?](repeating: nil, count: maxSegments)
        let n = refs.withUnsafeMutableBufferPointer { buf in
            OCCTCurve2DSplitAtContinuity(
                handle, Int32(continuity), tolerance,
                buf.baseAddress!, Int32(maxSegments))
        }
        var result = [Curve2D]()
        for i in 0..<Int(n) {
            if let ref = refs[i] {
                result.append(Curve2D(handle: ref))
            }
        }
        return result
    }

    // MARK: - v0.125.0: Geom2d_BSplineCurve deep method completion

    /// Local D0 within a specific knot span.
    public func bsplineLocalD0(u: Double, fromK1: Int, toK2: Int) -> SIMD2<Double> {
        var x = 0.0
        var y = 0.0
        OCCTCurve2DBSplineLocalD0(handle, u, Int32(fromK1), Int32(toK2), &x, &y)
        return SIMD2(x, y)
    }

    /// Local D1 within a specific knot span.
    public func bsplineLocalD1(u: Double, fromK1: Int, toK2: Int)
        -> (point: SIMD2<Double>, v1: SIMD2<Double>)
    {
        var px = 0.0
        var py = 0.0
        var v1x = 0.0
        var v1y = 0.0
        OCCTCurve2DBSplineLocalD1(
            handle, u, Int32(fromK1), Int32(toK2),
            &px, &py, &v1x, &v1y)
        return (SIMD2(px, py), SIMD2(v1x, v1y))
    }

    /// Local D2 within a specific knot span.
    public func bsplineLocalD2(u: Double, fromK1: Int, toK2: Int)
        -> (point: SIMD2<Double>, v1: SIMD2<Double>, v2: SIMD2<Double>)
    {
        var px = 0.0
        var py = 0.0
        var v1x = 0.0
        var v1y = 0.0
        var v2x = 0.0
        var v2y = 0.0
        OCCTCurve2DBSplineLocalD2(
            handle, u, Int32(fromK1), Int32(toK2),
            &px, &py, &v1x, &v1y, &v2x, &v2y)
        return (SIMD2(px, py), SIMD2(v1x, v1y), SIMD2(v2x, v2y))
    }

    /// Local D3 within a specific knot span.
    public func bsplineLocalD3(u: Double, fromK1: Int, toK2: Int)
        -> (point: SIMD2<Double>, v1: SIMD2<Double>, v2: SIMD2<Double>, v3: SIMD2<Double>)
    {
        var px = 0.0
        var py = 0.0
        var v1x = 0.0
        var v1y = 0.0
        var v2x = 0.0
        var v2y = 0.0
        var v3x = 0.0
        var v3y = 0.0
        OCCTCurve2DBSplineLocalD3(
            handle, u, Int32(fromK1), Int32(toK2),
            &px, &py, &v1x, &v1y, &v2x, &v2y, &v3x, &v3y)
        return (SIMD2(px, py), SIMD2(v1x, v1y), SIMD2(v2x, v2y), SIMD2(v3x, v3y))
    }

    /// Local DN within a specific knot span.
    public func bsplineLocalDN(u: Double, fromK1: Int, toK2: Int, n: Int) -> SIMD2<Double> {
        var vx = 0.0
        var vy = 0.0
        OCCTCurve2DBSplineLocalDN(handle, u, Int32(fromK1), Int32(toK2), Int32(n), &vx, &vy)
        return SIMD2(vx, vy)
    }

    /// Local value within a specific knot span.
    public func bsplineLocalValue(u: Double, fromK1: Int, toK2: Int) -> SIMD2<Double> {
        var x = 0.0
        var y = 0.0
        OCCTCurve2DBSplineLocalValue(handle, u, Int32(fromK1), Int32(toK2), &x, &y)
        return SIMD2(x, y)
    }

    /// Locate U knot span.
    ///
    /// Returns (i1, i2) indices.
    public func bsplineLocateU(u: Double, paramTol: Double) -> (i1: Int, i2: Int) {
        var i1: Int32 = 0
        var i2: Int32 = 0
        OCCTCurve2DBSplineLocateU(handle, u, paramTol, &i1, &i2)
        return (Int(i1), Int(i2))
    }

    /// First U knot index.
    public var bsplineFirstUKnotIndex: Int {
        Int(OCCTCurve2DBSplineFirstUKnotIndex(handle))
    }

    /// Last U knot index.
    public var bsplineLastUKnotIndex: Int {
        Int(OCCTCurve2DBSplineLastUKnotIndex(handle))
    }

    /// Get a single knot value by index (1-based).
    public func bsplineKnot(index: Int) -> Double {
        OCCTCurve2DBSplineKnot(handle, Int32(index))
    }

    /// Knot distribution (0=NonUniform, 1=Uniform, 2=QuasiUniform, 3=PiecewiseBezier).
    public var bsplineKnotDistribution: Int {
        Int(OCCTCurve2DBSplineKnotDistribution(handle))
    }

    /// Get multiplicity by index (1-based).
    public func bsplineMultiplicity(index: Int) -> Int {
        Int(OCCTCurve2DBSplineMultiplicity(handle, Int32(index)))
    }

    /// Get all multiplicities.
    public var bsplineMultiplicities: [Int] {
        let count = Int(OCCTCurve2DBSplineKnotCount(handle))
        guard count > 0 else { return [] }
        var mults = [Int32](repeating: 0, count: count)
        OCCTCurve2DBSplineGetMultiplicities(handle, &mults)
        return mults.map { Int($0) }
    }

    /// BSpline start point.
    public var bsplineStartPoint: SIMD2<Double> {
        var x = 0.0
        var y = 0.0
        OCCTCurve2DBSplineStartPoint(handle, &x, &y)
        return SIMD2(x, y)
    }

    /// BSpline end point.
    public var bsplineEndPoint: SIMD2<Double> {
        var x = 0.0
        var y = 0.0
        OCCTCurve2DBSplineEndPoint(handle, &x, &y)
        return SIMD2(x, y)
    }

    /// Get all BSpline poles.
    public var bsplinePoles: [SIMD2<Double>] {
        let count = Int(OCCTCurve2DBSplinePoleCount(handle))
        guard count > 0 else { return [] }
        var flat = [Double](repeating: 0, count: count * 2)
        OCCTCurve2DBSplineGetPoles(handle, &flat)
        var result = [SIMD2<Double>]()
        result.reserveCapacity(count)
        for i in stride(from: 0, to: flat.count, by: 2) {
            result.append(SIMD2(flat[i], flat[i + 1]))
        }
        return result
    }

    /// Is the BSpline curve closed?
    public var bsplineIsClosed: Bool {
        OCCTCurve2DBSplineIsClosed(handle)
    }

    /// Is the BSpline curve periodic?
    public var bsplineIsPeriodic: Bool {
        OCCTCurve2DBSplineIsPeriodic(handle)
    }

    /// BSpline curve continuity, as a raw `GeomAbs_Shape` ordinal
    /// (`0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=C3, 6=CN`), so a C2 cubic reports `4`, not `2`.
    ///
    /// `0` if the curve is not a BSpline. Prefer ``ContinuityClass`` (#619).
    public var bsplineContinuity: Int {
        Int(OCCTCurve2DBSplineContinuity(handle))
    }

    /// Is the BSpline curve at least CN continuous?
    public func bsplineIsCN(_ n: Int) -> Bool {
        OCCTCurve2DBSplineIsCN(handle, Int32(n))
    }

    // MARK: - Bezier 2D completions (v0.126.0)

    /// Insert a pole after index in a 2D Bezier curve (1-based index).
    @discardableResult
    public func bezierInsertPoleAfter(_ index: Int, point: SIMD2<Double>) -> Bool {
        OCCTCurve2DBezierInsertPoleAfter(handle, Int32(index), point.x, point.y)
    }

    /// Remove a pole at index from a 2D Bezier curve (1-based index).
    @discardableResult
    public func bezierRemovePole(_ index: Int) -> Bool {
        OCCTCurve2DBezierRemovePole(handle, Int32(index))
    }

    /// Segment a 2D Bezier curve to [u1, u2].
    @discardableResult
    public func bezierSegment(u1: Double, u2: Double) -> Bool {
        OCCTCurve2DBezierSegment(handle, u1, u2)
    }

    /// Increase degree of a 2D Bezier curve.
    @discardableResult
    public func bezierIncreaseDegree(_ degree: Int) -> Bool {
        OCCTCurve2DBezierIncreaseDegree(handle, Int32(degree))
    }

    /// Get start point of a 2D Bezier curve.
    public var bezierStartPoint: SIMD2<Double> {
        var x = 0.0
        var y = 0.0
        OCCTCurve2DBezierStartPoint(handle, &x, &y)
        return SIMD2(x, y)
    }

    /// Get end point of a 2D Bezier curve.
    public var bezierEndPoint: SIMD2<Double> {
        var x = 0.0
        var y = 0.0
        OCCTCurve2DBezierEndPoint(handle, &x, &y)
        return SIMD2(x, y)
    }

    /// Get all poles of a 2D Bezier curve.
    public var bezierPoles: [SIMD2<Double>] {
        let count = Int(OCCTCurve2DBezierPoleCount(handle))
        guard count > 0 else { return [] }
        var flat = [Double](repeating: 0, count: count * 2)
        OCCTCurve2DBezierGetPoles(handle, &flat)
        return (0..<count).map { SIMD2(flat[$0 * 2], flat[$0 * 2 + 1]) }
    }

    /// Reverse the parameterization of a 2D Bezier curve.
    @discardableResult
    public func bezierReverse() -> Bool {
        OCCTCurve2DBezierReverse(handle)
    }
}

// MARK: - Curve2D Transform (v0.128.0)

extension Curve2D {

    /// Transform type for 2D geometry.
    public enum TransformType2D: Int32, Sendable {
        case translation = 0
        case rotation = 1
        case scale = 2
        case mirrorPoint = 3
        case mirrorAxis = 4
    }

    /// Translate the 2D curve in place by (dx, dy).
    @discardableResult
    public func translate(dx: Double, dy: Double) -> Bool {
        OCCTCurve2DTransform(handle, TransformType2D.translation.rawValue, dx, dy, 0, 0, 0)
    }

    /// Rotate the 2D curve in place around a center point by the given angle (radians).
    @discardableResult
    public func rotate(center: SIMD2<Double>, angle: Double) -> Bool {
        OCCTCurve2DTransform(
            handle, TransformType2D.rotation.rawValue, center.x, center.y, angle, 0, 0)
    }

    /// Scale the 2D curve in place from a center point by the given factor.
    @discardableResult
    public func scale(center: SIMD2<Double>, factor: Double) -> Bool {
        OCCTCurve2DTransform(
            handle, TransformType2D.scale.rawValue, center.x, center.y, factor, 0, 0)
    }

    /// Mirror the 2D curve in place through a point.
    @discardableResult
    public func mirrorPoint(_ point: SIMD2<Double>) -> Bool {
        OCCTCurve2DTransform(
            handle, TransformType2D.mirrorPoint.rawValue, point.x, point.y, 0, 0, 0)
    }

    /// Mirror the 2D curve in place through an axis.
    @discardableResult
    public func mirrorAxis(origin: SIMD2<Double>, direction: SIMD2<Double>) -> Bool {
        OCCTCurve2DTransform(
            handle, TransformType2D.mirrorAxis.rawValue,
            origin.x, origin.y, direction.x, direction.y, 0)
    }
}

// MARK: - Geom2dEval TBezier / AHTBezier Curves (v0.131.0)

extension Curve2D {

    /// Create a 2D Trigonometric Bezier curve.
    ///
    /// Uses a trigonometric Bernstein-like basis: {1, sin(alpha*t), cos(alpha*t), ...}.
    /// Parameter domain is [0, pi/alpha].
    /// - Parameters:
    ///   - poles: 2D control points (count must be odd >= 3)
    ///   - alpha: frequency parameter (> 0)
    /// - Returns: Curve2D or nil on error
    public static func tBezier(poles: [SIMD2<Double>], alpha: Double) -> Curve2D? {
        guard poles.count >= 3, poles.count % 2 == 1 else { return nil }
        var flat = [Double](repeating: 0, count: poles.count * 2)
        for (i, p) in poles.enumerated() {
            flat[i * 2] = p.x
            flat[i * 2 + 1] = p.y
        }
        guard let ref = OCCTGeom2dEvalTBezierCurveCreate(&flat, Int32(poles.count), alpha) else {
            return nil
        }
        return Curve2D(handle: ref)
    }

    /// Create a 2D Algebraic-Hyperbolic-Trigonometric (AHT) Bezier curve.
    ///
    /// Uses a mixed basis: {1, t, ..., t^k, sinh(alpha*t), cosh(alpha*t), sin(beta*t), cos(beta*t)}.
    /// Number of poles must equal algDegree+1 + 2*(alpha>0) + 2*(beta>0).
    /// Parameter range: [0, 1].
    /// - Parameters:
    ///   - poles: 2D control points
    ///   - algDegree: algebraic polynomial degree (>= 0)
    ///   - alpha: hyperbolic frequency (>= 0, 0 = no hyperbolic terms)
    ///   - beta: trigonometric frequency (>= 0, 0 = no trig terms)
    /// - Returns: Curve2D or nil on error
    public static func ahtBezier(
        poles: [SIMD2<Double>], algDegree: Int, alpha: Double, beta: Double
    ) -> Curve2D? {
        guard !poles.isEmpty else { return nil }
        var flat = [Double](repeating: 0, count: poles.count * 2)
        for (i, p) in poles.enumerated() {
            flat[i * 2] = p.x
            flat[i * 2 + 1] = p.y
        }
        guard
            let ref = OCCTGeom2dEvalAHTBezierCurveCreate(
                &flat, Int32(poles.count),
                Int32(algDegree), alpha, beta)
        else { return nil }
        return Curve2D(handle: ref)
    }
}

extension Curve2D {
    /// Convert this 2D curve segment to a BSpline using ShapeConstruct_Curve.
    public func convertSegmentToBSpline(first: Double, last: Double, precision: Double = 1e-6)
        -> Curve2D?
    {
        guard let ref = OCCTShapeConstructConvertToBSpline2D(handle, first, last, precision) else {
            return nil
        }
        return Curve2D(handle: ref)
    }

    /// Adjust 2D curve endpoints to match given points.
    public func adjustEndpoints(start: (Double, Double), end: (Double, Double)) -> Bool {
        OCCTShapeConstructAdjustCurve2D(handle, start.0, start.1, end.0, end.1)
    }
}

extension Curve2D {
    /// Find the parameter of a 2D point on this curve.
    ///
    /// Returns nil if the point is beyond maxDistance from the curve.
    public func parameterOf(point: SIMD2<Double>, maxDistance: Double = 1.0) -> Double? {
        var param: Double = 0
        let ok = OCCTGeomLibToolParameter2D(handle, point.x, point.y, maxDistance, &param)
        return ok ? param : nil
    }
}

extension Curve2D {
    /// Check if this BSpline 2D curve has reversed end tangents.
    ///
    /// Returns (needFixFirst, needFixLast) or nil if not a BSpline or check failed.
    public func checkBSplineTangents(tolerance: Double = 0.01, angularTolerance: Double = 0.1) -> (
        fixFirst: Bool, fixLast: Bool
    )? {
        var first = false
        var last = false
        let ok = OCCTGeomLibCheckBSpline2D(handle, tolerance, angularTolerance, &first, &last)
        return ok ? (first, last) : nil
    }

    /// Fix reversed end tangents on a BSpline 2D curve.
    ///
    /// Returns new curve or nil.
    public func fixBSplineTangents(
        fixFirst: Bool, fixLast: Bool,
        tolerance: Double = 0.01, angularTolerance: Double = 0.1
    ) -> Curve2D? {
        guard
            let ref = OCCTGeomLibFixBSpline2D(
                handle, tolerance, angularTolerance, fixFirst, fixLast)
        else { return nil }
        return Curve2D(handle: ref)
    }
}

extension Curve2D {
    /// Split this 2D curve at continuity breaks.
    ///
    /// Criterion is a ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2, 3=C3); anything above
    /// asks for CN, i.e. split at every break. `ShapeUpgrade_Split*Continuity::SetCriterion` is
    /// the one consumer of this vocabulary that recognises the whole ladder including CN.
    public func splitByContinuity(criterion: Int = 2, tolerance: Double = 1e-6) -> [Curve2D] {
        var refs = [OCCTCurve2DRef?](repeating: nil, count: 32)
        let n = refs.withUnsafeMutableBufferPointer { buf in
            OCCTSplitCurve2dContinuity(
                handle, Int32(criterion), tolerance,
                buf.baseAddress, Int32(buf.count))
        }
        return (0..<Int(n)).compactMap { i in
            guard let ref = refs[i] else { return nil }
            return Curve2D(handle: ref)
        }
    }

    /// Convert this 2D curve to Bezier segments (via ShapeUpgrade).
    public func convertToBezierSegments() -> [Curve2D] {
        var refs = [OCCTCurve2DRef?](repeating: nil, count: 64)
        let n = refs.withUnsafeMutableBufferPointer { buf in
            OCCTConvertCurve2dToBezier(handle, buf.baseAddress, Int32(buf.count))
        }
        return (0..<Int(n)).compactMap { i in
            guard let ref = refs[i] else { return nil }
            return Curve2D(handle: ref)
        }
    }

    /// Approximate this 2D curve as arcs and line segments.
    public func approxArcsAndSegments(tolerance: Double, angleTolerance: Double) -> [Curve2D] {
        var refs = [OCCTCurve2DRef?](repeating: nil, count: 256)
        let n = refs.withUnsafeMutableBufferPointer { buf in
            OCCTGeom2dConvertApproxArcsSegments(
                handle, tolerance, angleTolerance,
                buf.baseAddress, Int32(buf.count))
        }
        return (0..<Int(n)).compactMap { i in
            guard let ref = refs[i] else { return nil }
            return Curve2D(handle: ref)
        }
    }
}

extension Curve2D {

    /// Interpolate a 2D BSpline curve through points.
    /// - Parameters:
    ///   - points: Array of 2D points (x, y)
    ///   - periodic: If true, create a periodic (closed) curve
    ///   - tolerance: Interpolation tolerance
    /// - Returns: The interpolated curve, or nil on failure
    public static func interpolate2D(
        points: [(Double, Double)], periodic: Bool = false, tolerance: Double = 1e-6
    ) -> Curve2D? {
        let xs = points.map(\.0)
        let ys = points.map(\.1)
        return xs.withUnsafeBufferPointer { xBuf in
            ys.withUnsafeBufferPointer { yBuf in
                guard
                    let ref = OCCTCurve2DInterpolate2D(
                        xBuf.baseAddress!, yBuf.baseAddress!,
                        Int32(points.count), periodic, tolerance)
                else {
                    return nil
                }
                return Curve2D(handle: ref)
            }
        }
    }
}

extension Curve2D {

    /// Approximate a 2D BSpline curve through points.
    /// - Parameter points: Array of 2D points (x, y)
    /// - Returns: The approximated curve, or nil on failure
    public static func approximate2D(points: [(Double, Double)]) -> Curve2D? {
        let xs = points.map(\.0)
        let ys = points.map(\.1)
        return xs.withUnsafeBufferPointer { xBuf in
            ys.withUnsafeBufferPointer { yBuf in
                guard
                    let ref = OCCTCurve2DApproximate2D(
                        xBuf.baseAddress!, yBuf.baseAddress!,
                        Int32(points.count))
                else {
                    return nil
                }
                return Curve2D(handle: ref)
            }
        }
    }
}

extension Curve2D {

    /// Convert a 2D circle arc to a BSpline curve.
    ///
    /// - Parameters:
    ///   - centerX: centre X.
    ///   - centerY: centre Y.
    ///   - radius: circle radius. Must be greater than zero.
    ///   - u1: start angle, in radians.
    ///   - u2: end angle, in radians.
    /// - Returns: the converted curve, or `nil` if the circle is degenerate.
    ///
    /// ```swift
    /// if let c = Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 5, u1: 0, u2: .pi) {
    ///     print(c.degree)
    /// }
    /// ```
    public static func fromCircleArc(
        centerX: Double, centerY: Double, radius: Double,
        u1: Double, u2: Double
    ) -> Curve2D? {
        guard let ref = OCCTConvertCircleToBSpline2D(centerX, centerY, radius, u1, u2) else {
            return nil
        }
        return Curve2D(handle: ref)
    }
}

extension Curve2D {

    /// Convert a 2D ellipse arc to a BSpline curve.
    ///
    /// - Parameters:
    ///   - centerX: centre X.
    ///   - centerY: centre Y.
    ///   - majorRadius: semi-major axis. Must be greater than zero.
    ///   - minorRadius: semi-minor axis. Must be greater than zero and no larger than
    ///     `majorRadius`; equal radii are a circle and are valid.
    ///   - u1: start angle, in radians.
    ///   - u2: end angle, in radians.
    /// - Returns: the converted curve, or `nil` if the ellipse is degenerate.
    ///
    /// ```swift
    /// if let c = Curve2D.fromEllipseArc(centerX: 0, centerY: 0,
    ///                                   majorRadius: 20, minorRadius: 10,
    ///                                   u1: 0, u2: .pi) {
    ///     print(c.degree)
    /// }
    /// ```
    public static func fromEllipseArc(
        centerX: Double, centerY: Double,
        majorRadius: Double, minorRadius: Double,
        u1: Double, u2: Double
    ) -> Curve2D? {
        guard
            let ref = OCCTConvertEllipseToBSpline2D(
                centerX, centerY, majorRadius, minorRadius, u1, u2)
        else { return nil }
        return Curve2D(handle: ref)
    }

    /// Convert a 2D hyperbola arc to a BSpline curve.
    ///
    /// - Parameters:
    ///   - centerX: centre X.
    ///   - centerY: centre Y.
    ///   - majorRadius: major radius. Must be greater than zero.
    ///   - minorRadius: minor radius. Must be greater than zero. A hyperbola puts no ordering on
    ///     its radii, so a minor radius larger than the major is an ordinary hyperbola.
    ///   - u1: start parameter on the hyperbola.
    ///   - u2: end parameter on the hyperbola.
    /// - Returns: the converted curve, or `nil` if the hyperbola is degenerate.
    ///
    /// ```swift
    /// if let c = Curve2D.fromHyperbolaArc(centerX: 0, centerY: 0,
    ///                                     majorRadius: 10, minorRadius: 5,
    ///                                     u1: -1, u2: 1) {
    ///     print(c.degree)
    /// }
    /// ```
    public static func fromHyperbolaArc(
        centerX: Double, centerY: Double,
        majorRadius: Double, minorRadius: Double,
        u1: Double, u2: Double
    ) -> Curve2D? {
        guard
            let ref = OCCTConvertHyperbolaToBSpline2D(
                centerX, centerY, majorRadius, minorRadius, u1, u2)
        else { return nil }
        return Curve2D(handle: ref)
    }

    /// Convert a 2D parabola arc to a BSpline curve.
    ///
    /// - Parameters:
    ///   - centerX: apex X.
    ///   - centerY: apex Y.
    ///   - focal: focal length. Must be greater than zero: OCCT converts a focal length of zero
    ///     without complaint, into a curve whose poles are all NaN.
    ///   - u1: start parameter on the parabola.
    ///   - u2: end parameter on the parabola.
    /// - Returns: the converted curve, or `nil` if the parabola is degenerate.
    ///
    /// ```swift
    /// if let c = Curve2D.fromParabolaArc(centerX: 0, centerY: 0, focal: 5, u1: -2, u2: 2) {
    ///     print(c.degree)
    /// }
    /// ```
    public static func fromParabolaArc(
        centerX: Double, centerY: Double, focal: Double,
        u1: Double, u2: Double
    ) -> Curve2D? {
        guard let ref = OCCTConvertParabolaToBSpline2D(centerX, centerY, focal, u1, u2) else {
            return nil
        }
        return Curve2D(handle: ref)
    }
}

extension Curve2D {
    /// Create a 2D circle from center and radius.
    public static func gceCircle(center: SIMD2<Double>, radius: Double) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeCircleCenterRadius(center.x, center.y, radius) else {
            return nil
        }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle through 3 points.
    public static func gceCircle(p1: SIMD2<Double>, p2: SIMD2<Double>, p3: SIMD2<Double>)
        -> Curve2D?
    {
        guard let ref = OCCTCurve2DMakeCircle3Points(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y) else {
            return nil
        }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle from center and point on circle.
    public static func gceCircle(center: SIMD2<Double>, pointOn: SIMD2<Double>) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeCircleCenterPoint(center.x, center.y, pointOn.x, pointOn.y)
        else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle parallel to existing circle at distance.
    public static func gceCircleParallel(
        center: SIMD2<Double>, direction: SIMD2<Double>,
        radius: Double, distance: Double
    ) -> Curve2D? {
        guard
            let ref = OCCTCurve2DMakeCircleParallel(
                center.x, center.y,
                direction.x, direction.y,
                radius, distance)
        else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle from axis and radius.
    public static func gceCircle(
        axisCenter: SIMD2<Double>, axisDirection: SIMD2<Double>,
        radius: Double
    ) -> Curve2D? {
        guard
            let ref = OCCTCurve2DMakeCircleAxis(
                axisCenter.x, axisCenter.y,
                axisDirection.x, axisDirection.y,
                radius)
        else { return nil }
        return Curve2D(handle: ref)
    }
}

extension Curve2D {
    /// Create a 2D ellipse from axis and radii.
    public static func gceEllipse(
        center: SIMD2<Double>, xDirection: SIMD2<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> Curve2D? {
        guard
            let ref = OCCTCurve2DMakeEllipse(
                center.x, center.y,
                xDirection.x, xDirection.y,
                majorRadius, minorRadius)
        else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D ellipse from 3 points (S1, S2, center).
    public static func gceEllipse(s1: SIMD2<Double>, s2: SIMD2<Double>, center: SIMD2<Double>)
        -> Curve2D?
    {
        guard
            let ref = OCCTCurve2DMakeEllipse3Points(
                s1.x, s1.y, s2.x, s2.y,
                center.x, center.y)
        else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D ellipse from full Ax22d and radii.
    public static func gceEllipse(
        center: SIMD2<Double>, xDirection: SIMD2<Double>,
        yDirection: SIMD2<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> Curve2D? {
        guard
            let ref = OCCTCurve2DMakeEllipseAxis22d(
                center.x, center.y,
                xDirection.x, xDirection.y,
                yDirection.x, yDirection.y,
                majorRadius, minorRadius)
        else { return nil }
        return Curve2D(handle: ref)
    }
}

extension Curve2D {
    /// Create a 2D hyperbola from axis and radii.
    public static func gceHyperbola(
        center: SIMD2<Double>, xDirection: SIMD2<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> Curve2D? {
        guard
            let ref = OCCTCurve2DMakeHyperbola(
                center.x, center.y,
                xDirection.x, xDirection.y,
                majorRadius, minorRadius)
        else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D hyperbola from 3 points (S1, S2, center).
    public static func gceHyperbola(s1: SIMD2<Double>, s2: SIMD2<Double>, center: SIMD2<Double>)
        -> Curve2D?
    {
        guard
            let ref = OCCTCurve2DMakeHyperbola3Points(
                s1.x, s1.y, s2.x, s2.y,
                center.x, center.y)
        else { return nil }
        return Curve2D(handle: ref)
    }
}

extension Curve2D {
    /// Create a 2D parabola from axis and focal distance.
    public static func gceParabola(
        center: SIMD2<Double>, direction: SIMD2<Double>,
        focalDistance: Double
    ) -> Curve2D? {
        guard
            let ref = OCCTCurve2DMakeParabola(
                center.x, center.y,
                direction.x, direction.y, focalDistance)
        else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D parabola from directrix and focus.
    public static func gceParabola(
        directrixPoint: SIMD2<Double>, directrixDirection: SIMD2<Double>,
        focus: SIMD2<Double>
    ) -> Curve2D? {
        guard
            let ref = OCCTCurve2DMakeParabolaDirectrixFocus(
                directrixPoint.x, directrixPoint.y,
                directrixDirection.x, directrixDirection.y,
                focus.x, focus.y)
        else { return nil }
        return Curve2D(handle: ref)
    }
}

extension Curve2D {
    /// Concatenate multiple bounded 2D curves into a single BSpline.
    public static func concatenate(_ curves: [Curve2D], tolerance: Double = 1e-4) -> Curve2D? {
        guard !curves.isEmpty else { return nil }
        var handles = curves.map { $0.handle as OCCTCurve2DRef }
        guard let ref = OCCTConcatenateCurves2D(&handles, Int32(curves.count), tolerance) else {
            return nil
        }
        return Curve2D(handle: ref)
    }
}

extension Curve2D {
    /// Measured global continuity of the 2D curve, as a raw `GeomAbs_Shape` ordinal.
    ///
    /// The ordinals are `GeomAbs_Shape`'s own declared order (`0=C0, 1=G1, 2=C1, 3=G2,
    /// 4=C2, 5=C3, 6=CN`), not a 0/1/2 order. Prefer ``continuityClass``, which names them.
    ///
    /// - Warning: The migration target for the retired `continuityOrder`, but not a drop-in one;
    ///   see ``Curve3D/continuity`` for the constants that shift (#619).
    public var continuity: Int {
        Int(OCCTCurve2DGetContinuity(handle))
    }

    /// Measured global continuity of the 2D curve.
    ///
    /// ```swift
    /// let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))
    /// print(segment?.continuityClass)   // .cN
    /// ```
    public var continuityClass: ContinuityClass {
        ContinuityClass(rawValue: OCCTCurve2DGetContinuity(handle)) ?? .c0
    }
}

extension Curve2D {

    /// BSpline-specific 2D curve operations.
    public struct BSpline {
        let curve: Curve2D

        /// Number of knots.
        public var knotCount: Int { Int(OCCTCurve2DBSplineKnotCount(curve.handle)) }

        /// Number of poles.
        public var poleCount: Int { Int(OCCTCurve2DBSplinePoleCount(curve.handle)) }

        /// Degree.
        public var degree: Int { Int(OCCTCurve2DBSplineDegree(curve.handle)) }

        /// Whether rational.
        public var isRational: Bool { OCCTCurve2DBSplineIsRational(curve.handle) }

        /// Get a pole at 1-based index.
        public func pole(at index: Int) -> SIMD2<Double> {
            var x = 0.0
            var y = 0.0
            OCCTCurve2DBSplineGetPole(curve.handle, Int32(index), &x, &y)
            return SIMD2(x, y)
        }

        /// Set a pole at 1-based index.
        @discardableResult
        public func setPole(at index: Int, to point: SIMD2<Double>) -> Bool {
            OCCTCurve2DBSplineSetPole(curve.handle, Int32(index), point.x, point.y)
        }

        /// Set the weight at 1-based index.
        @discardableResult
        public func setWeight(at index: Int, to weight: Double) -> Bool {
            OCCTCurve2DBSplineSetWeight(curve.handle, Int32(index), weight)
        }

        /// Insert a knot.
        @discardableResult
        public func insertKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool {
            OCCTCurve2DBSplineInsertKnot(curve.handle, u, Int32(multiplicity), tolerance)
        }

        /// Remove a knot at 1-based index.
        @discardableResult
        public func removeKnot(at index: Int, multiplicity: Int, tolerance: Double) -> Bool {
            OCCTCurve2DBSplineRemoveKnot(curve.handle, Int32(index), Int32(multiplicity), tolerance)
        }

        /// Segment to [u1, u2].
        @discardableResult
        public func segment(u1: Double, u2: Double) -> Bool {
            OCCTCurve2DBSplineSegment(curve.handle, u1, u2)
        }

        /// Increase degree.
        @discardableResult
        public func increaseDegree(to degree: Int) -> Bool {
            OCCTCurve2DBSplineIncreaseDegree(curve.handle, Int32(degree))
        }

        /// Compute parametric resolution for a given tolerance.
        public func resolution(tolerance: Double) -> Double {
            OCCTCurve2DBSplineResolution(curve.handle, tolerance)
        }
    }

    /// Access BSpline-specific operations.
    ///
    /// Works only if the underlying curve is a Geom2d_BSplineCurve.
    public var bspline: BSpline { BSpline(curve: self) }
}

extension Curve2D {

    /// Reverse the curve in-place.
    @discardableResult
    public func reverse() -> Bool {
        OCCTCurve2DReverse(handle)
    }

    /// Create a deep copy of this curve.
    public func copy() -> Curve2D? {
        guard let ref = OCCTCurve2DCopy(handle) else { return nil }
        return Curve2D(handle: ref)
    }
}

extension Curve2D {

    /// Evaluate the 2D curve point at parameter u.
    public func evalD0(at u: Double) -> SIMD2<Double> {
        var x = 0.0
        var y = 0.0
        OCCTCurve2DEvalD0(handle, u, &x, &y)
        return SIMD2(x, y)
    }

    /// Evaluate the 2D curve point and first derivative at parameter u.
    public func evalD1(at u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>) {
        var px = 0.0
        var py = 0.0
        var d1x = 0.0
        var d1y = 0.0
        OCCTCurve2DEvalD1(handle, u, &px, &py, &d1x, &d1y)
        return (SIMD2(px, py), SIMD2(d1x, d1y))
    }

    /// Evaluate the 2D curve point, first and second derivatives at parameter u.
    public func evalD2(at u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>, d2: SIMD2<Double>)
    {
        var px = 0.0
        var py = 0.0
        var d1x = 0.0
        var d1y = 0.0
        var d2x = 0.0
        var d2y = 0.0
        OCCTCurve2DEvalD2(handle, u, &px, &py, &d1x, &d1y, &d2x, &d2y)
        return (SIMD2(px, py), SIMD2(d1x, d1y), SIMD2(d2x, d2y))
    }

}

extension Curve2D {

    /// The geometric curve type.
    public var curveType: Int {
        Int(OCCTCurve2DCurveType(handle))
    }
}

extension Curve2D {

    /// Whether this curve is bounded (Geom2d_BoundedCurve subclass).
    public var isBounded: Bool { OCCTCurve2DIsBounded(handle) }
}

extension Curve2D {

    /// Evaluate the N-th derivative at parameter u.
    public func dn(at u: Double, order n: Int) -> SIMD2<Double> {
        var x = 0.0
        var y = 0.0
        OCCTCurve2DDN(handle, u, Int32(n), &x, &y)
        return SIMD2(x, y)
    }

    /// The type name of this curve (e.g. "Geom2d_Line", "Geom2d_Circle").
    public var typeName: String? {
        guard let ptr = OCCTCurve2DTypeName(handle) else { return nil }
        return String(cString: ptr)
    }
}

extension Curve2D {
    /// 2D Bezier curve properties (meaningful only when the underlying curve is Geom2d_BezierCurve).
    public struct BezierProperties: Sendable, NativeHandleView {
        let owner: Curve2D

        /// Degree of the Bezier curve.
        public var degree: Int { Int(OCCTCurve2DBezierDegree(handle)) }

        /// Number of poles.
        public var poleCount: Int { Int(OCCTCurve2DBezierPoleCount(handle)) }

        /// Whether the Bezier curve is rational.
        public var isRational: Bool { OCCTCurve2DBezierIsRational(handle) }

        /// Get a pole (1-based index).
        public func pole(at index: Int) -> SIMD2<Double> {
            var x = 0.0
            var y = 0.0
            OCCTCurve2DBezierGetPole(handle, Int32(index), &x, &y)
            return SIMD2(x, y)
        }

        /// Set a pole (1-based index).
        @discardableResult
        public func setPole(at index: Int, point: SIMD2<Double>) -> Bool {
            OCCTCurve2DBezierSetPole(handle, Int32(index), point.x, point.y)
        }

        /// Set a weight (1-based index).
        @discardableResult
        public func setWeight(at index: Int, weight: Double) -> Bool {
            OCCTCurve2DBezierSetWeight(handle, Int32(index), weight)
        }

        /// Compute parameter resolution from 2D tolerance.
        public func resolution(tolerance: Double) -> Double {
            OCCTCurve2DBezierResolution(handle, tolerance)
        }
    }

    /// 2D Bezier curve-specific properties.
    public var bezierProperties: BezierProperties { BezierProperties(owner: self) }

    // --- Curve2D BSpline extras ---

    /// Set periodic/non-periodic on a 2D BSpline curve.
    @discardableResult
    public func bsplineSetPeriodic(_ periodic: Bool) -> Bool {
        OCCTCurve2DBSplineSetPeriodic(handle, periodic)
    }

    /// Get weight at index (1-based) from a 2D BSpline curve.
    public func bsplineWeight(at index: Int) -> Double {
        OCCTCurve2DBSplineGetWeight(handle, Int32(index))
    }

    /// Get all weights from a 2D BSpline curve.
    public func bsplineWeights() -> [Double] {
        let count = Int(OCCTCurve2DBSplinePoleCount(handle))
        guard count > 0 else { return [] }
        var weights = [Double](repeating: 0, count: count)
        weights.withUnsafeMutableBufferPointer { buf in
            OCCTCurve2DBSplineGetWeights(handle, buf.baseAddress!)
        }
        return weights
    }
}

extension Curve2D {

    /// Unavailable: this `Int` reported a hand-invented encoding, and the numbers changed
    /// underneath it.
    ///
    /// Use ``continuityClass`` (named cases) or ``continuity`` (raw ordinal).
    ///
    /// Same retirement, same reasons, as ``Curve3D/continuityOrder``: the pre-#485 encoding was
    /// `C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3` and the value is now the real
    /// `GeomAbs_Shape` ordinal (`C0=0, G1=1, C1=2, G2=3, C2=4, C3=5, CN=6`), so every threshold
    /// check kept compiling and quietly changed meaning (#619).
    ///
    /// ```swift
    /// // Before: `2` was C2. After: `2` is C1.
    /// if pcurve.continuityOrder >= 2 { treatAsC2() }
    ///
    /// // Ask it so it cannot drift again:
    /// if pcurve.continuityClass.satisfies(.c2) { treatAsC2() }
    /// ```
    @available(
        *, unavailable,
        message: """
            continuityOrder reported a hand-invented encoding (C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, \
            G2=-3) and #485 changed it to the real GeomAbs_Shape ordinal (C0=0, G1=1, C1=2, G2=3, \
            C2=4, C3=5, CN=6), so every threshold check silently changed meaning. Use \
            continuityClass.satisfies(_:) for a continuity floor, continuityClass == .cN for the \
            analytic fast path, or continuity for the raw ordinal, after re-checking the constant \
            you compare against. Note there is no longer an error sentinel: this returned -1 for a \
            null or unreadable handle, whereas continuity returns 0, which is an ordinary C0, so a \
            migrated `< 0` error check can never fire (#619).
            """
    )
    public var continuityOrder: Int { Int(OCCTCurve2DGetContinuity(handle)) }

    /// Check if this curve has at least Cn continuity.
    public func isCN(_ n: Int) -> Bool {
        OCCTCurve2DIsCN(handle, Int32(n))
    }

    /// Get the parameter on the reversed curve corresponding to parameter u on this curve.
    public func reversedParameter(_ u: Double) -> Double {
        OCCTCurve2DReversedParameter(handle, u)
    }

    /// Maximum degree for 2D Bezier curves (static).
    public static var bezierMaxDegree: Int { Int(OCCTCurve2DBezierMaxDegree()) }

    /// Maximum degree for 2D BSpline curves (static).
    public static var bsplineMaxDegree: Int { Int(OCCTCurve2DBSplineMaxDegree()) }
}

extension Curve2D {

    /// Remove periodicity from 2D BSpline curve.
    @discardableResult
    public func bsplineSetNotPeriodic() -> Bool {
        OCCTCurve2DBSplineSetNotPeriodic(handle)
    }

    /// Set origin knot index (1-based) on periodic 2D BSpline curve.
    @discardableResult
    public func bsplineSetOrigin(index: Int) -> Bool {
        OCCTCurve2DBSplineSetOrigin(handle, Int32(index))
    }

    /// Increase multiplicity of knot at index to at least mult (1-based).
    @discardableResult
    public func bsplineIncreaseMultiplicity(index: Int, multiplicity: Int) -> Bool {
        OCCTCurve2DBSplineIncreaseMultiplicity(handle, Int32(index), Int32(multiplicity))
    }

    /// Increment multiplicity of all knots from index1 to index2 by step (1-based).
    @discardableResult
    public func bsplineIncrementMultiplicity(from: Int, to: Int, step: Int = 1) -> Bool {
        OCCTCurve2DBSplineIncrementMultiplicity(handle, Int32(from), Int32(to), Int32(step))
    }

    /// Set all knot values at once (count must match NbKnots).
    @discardableResult
    public func bsplineSetKnots(_ knots: [Double]) -> Bool {
        OCCTCurve2DBSplineSetKnots(handle, knots, Int32(knots.count))
    }

    /// Reverse parameterization of 2D BSpline curve.
    @discardableResult
    public func bsplineReverse() -> Bool {
        OCCTCurve2DBSplineReverse(handle)
    }

    /// Move point and tangent at parameter u on 2D BSpline curve.
    @discardableResult
    public func bsplineMovePointAndTangent(
        u: Double, point: SIMD2<Double>, tangent: SIMD2<Double>,
        tolerance: Double, poleRange: ClosedRange<Int>
    ) -> Bool {
        OCCTCurve2DBSplineMovePointAndTangent(
            handle, u, point.x, point.y,
            tangent.x, tangent.y,
            tolerance,
            Int32(poleRange.lowerBound), Int32(poleRange.upperBound))
    }
}
