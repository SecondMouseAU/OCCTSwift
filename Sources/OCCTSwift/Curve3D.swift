import Foundation
import simd
import OCCTBridge

/// A 3D parametric curve backed by OpenCASCADE Handle(Geom_Curve).
///
/// Mirrors the Curve2D API for 3D space. Wraps lines, circles, ellipses, arcs,
/// BSplines, Bezier curves, and trimmed/offset curves polymorphically.
public final class Curve3D: @unchecked Sendable {
    internal let handle: OCCTCurve3DRef

    internal init(handle: OCCTCurve3DRef) {
        self.handle = handle
    }

    deinit {
        OCCTCurve3DRelease(handle)
    }

    // MARK: - Properties

    /// Parameter domain [first, last]
    public var domain: ClosedRange<Double> {
        var first: Double = 0, last: Double = 0
        OCCTCurve3DGetDomain(handle, &first, &last)
        return first...last
    }

    /// Whether the curve forms a closed loop
    public var isClosed: Bool {
        OCCTCurve3DIsClosed(handle)
    }

    /// Whether the curve is periodic (repeats)
    public var isPeriodic: Bool {
        OCCTCurve3DIsPeriodic(handle)
    }

    /// Period of the curve (nil if not periodic)
    public var period: Double? {
        guard isPeriodic else { return nil }
        return OCCTCurve3DGetPeriod(handle)
    }

    /// Point at start of domain
    public var startPoint: SIMD3<Double> {
        point(at: domain.lowerBound)
    }

    /// Point at end of domain
    public var endPoint: SIMD3<Double> {
        point(at: domain.upperBound)
    }

    // MARK: - Evaluation

    /// Evaluate point at parameter u
    public func point(at u: Double) -> SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTCurve3DGetPoint(handle, u, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// First derivative: point and tangent vector at parameter u
    public func d1(at u: Double) -> (point: SIMD3<Double>, tangent: SIMD3<Double>) {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        var vx: Double = 0, vy: Double = 0, vz: Double = 0
        OCCTCurve3DD1(handle, u, &px, &py, &pz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(vx, vy, vz))
    }

    /// Second derivative: point, first and second derivative vectors
    public func d2(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>) {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        var v1x: Double = 0, v1y: Double = 0, v1z: Double = 0
        var v2x: Double = 0, v2y: Double = 0, v2z: Double = 0
        OCCTCurve3DD2(handle, u, &px, &py, &pz, &v1x, &v1y, &v1z, &v2x, &v2y, &v2z)
        return (SIMD3(px, py, pz), SIMD3(v1x, v1y, v1z), SIMD3(v2x, v2y, v2z))
    }

    // MARK: - Primitive Curves

    /// Infinite line through a point in a direction
    public static func line(through point: SIMD3<Double>, direction: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DCreateLine(point.x, point.y, point.z,
                                             direction.x, direction.y, direction.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Line segment between two points
    public static func segment(from p1: SIMD3<Double>, to p2: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DCreateSegment(p1.x, p1.y, p1.z,
                                                p2.x, p2.y, p2.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Full circle in a plane defined by center and normal.
    ///
    /// - Parameters:
    ///   - center: Circle centre.
    ///   - normal: Normal of the plane the circle lies in.
    ///   - radius: Circle radius. Must be `> 0`; zero and negative radii return `nil`.
    /// - Returns: The circle, or `nil` if `radius <= 0`.
    ///
    /// `circleFromCenterNormal(center:normal:radius:)` builds the identical circle through
    /// OCCT's `gce_MakeCirc` algorithm and enforces the same radius contract.
    ///
    /// ```swift
    /// let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)
    /// #expect(c != nil)
    /// #expect(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 0) == nil)
    /// ```
    public static func circle(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> Curve3D? {
        guard let h = OCCTCurve3DCreateCircle(center.x, center.y, center.z,
                                               normal.x, normal.y, normal.z,
                                               radius) else { return nil }
        return Curve3D(handle: h)
    }

    /// Circular arc through three points (start, interior, end)
    public static func arcOfCircle(start: SIMD3<Double>, interior: SIMD3<Double>, end: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DCreateArcOfCircle(start.x, start.y, start.z,
                                                    interior.x, interior.y, interior.z,
                                                    end.x, end.y, end.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Circular arc through three points.
    ///
    /// A spelling of `arcOfCircle(start:interior:end:)` and delegates to it — the two cannot
    /// produce different curves for the same input (#415).
    ///
    /// - Parameters:
    ///   - p1: First endpoint (maps to `arcOfCircle`'s `start`).
    ///   - pm: A point on the arc (maps to `arcOfCircle`'s `interior`).
    ///   - p2: Second endpoint (maps to `arcOfCircle`'s `end`).
    /// - Returns: Arc curve, or `nil` if the three points are collinear or coincident.
    ///
    /// ```swift
    /// let arc = Curve3D.arc(through: SIMD3(5, 0, 0), SIMD3(0, 5, 0), SIMD3(-5, 0, 0))
    /// #expect(arc != nil)
    /// ```
    public static func arc(through p1: SIMD3<Double>, _ pm: SIMD3<Double>, _ p2: SIMD3<Double>) -> Curve3D? {
        arcOfCircle(start: p1, interior: pm, end: p2)
    }

    /// Ellipse in a plane defined by center and normal.
    ///
    /// - Parameters:
    ///   - center: Ellipse centre.
    ///   - normal: Normal of the plane the ellipse lies in.
    ///   - majorRadius: Major radius. Must be `> 0` and `>= minorRadius`.
    ///   - minorRadius: Minor radius. Must be `> 0`.
    /// - Returns: The ellipse, or `nil` if the radii violate that contract.
    ///
    /// `ellipseFromCenterNormal(center:normal:majorRadius:minorRadius:)` builds the identical
    /// ellipse through OCCT's `gce_MakeElips` algorithm and enforces the same radius contract.
    ///
    /// ```swift
    /// let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                         majorRadius: 10, minorRadius: 5)
    /// #expect(e != nil)
    /// // minor > major, and a zero minor radius, are both rejected
    /// #expect(Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                         majorRadius: 5, minorRadius: 10) == nil)
    /// #expect(Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                         majorRadius: 10, minorRadius: 0) == nil)
    /// ```
    public static func ellipse(center: SIMD3<Double>, normal: SIMD3<Double>,
                               majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let h = OCCTCurve3DCreateEllipse(center.x, center.y, center.z,
                                                normal.x, normal.y, normal.z,
                                                majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: h)
    }

    /// Parabola in a plane defined by center/normal with given focal length.
    ///
    /// - Parameters:
    ///   - center: Parabola apex.
    ///   - normal: Normal of the plane the parabola lies in.
    ///   - focal: Focal length. Must be `> 0`; zero and negative focal lengths return `nil`.
    /// - Returns: The parabola, or `nil` if `focal <= 0`.
    ///
    /// `parabolaFromCenterNormal(center:normal:focal:)` builds the identical parabola through
    /// OCCT's `gce_MakeParab` algorithm and enforces the same focal-length contract.
    ///
    /// ```swift
    /// let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 4)
    /// #expect(p != nil)
    /// #expect(Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 0) == nil)
    /// ```
    public static func parabola(center: SIMD3<Double>, normal: SIMD3<Double>,
                                focal: Double) -> Curve3D? {
        guard let h = OCCTCurve3DCreateParabola(center.x, center.y, center.z,
                                                 normal.x, normal.y, normal.z,
                                                 focal) else { return nil }
        return Curve3D(handle: h)
    }

    /// Hyperbola in a plane defined by center/normal.
    ///
    /// - Parameters:
    ///   - center: Hyperbola centre.
    ///   - normal: Normal of the plane the hyperbola lies in.
    ///   - majorRadius: Major radius. Must be `> 0`.
    ///   - minorRadius: Minor radius. Must be `> 0`. There is no ordering constraint between
    ///     the two, unlike `ellipse(center:normal:majorRadius:minorRadius:)`.
    /// - Returns: The hyperbola, or `nil` if either radius is `<= 0`.
    ///
    /// `hyperbolaFromCenterNormal(center:normal:majorRadius:minorRadius:)` builds the identical
    /// hyperbola through OCCT's `gce_MakeHypr` algorithm and enforces the same radius contract.
    ///
    /// ```swift
    /// let h = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
    ///                           majorRadius: 8, minorRadius: 3)
    /// #expect(h != nil)
    /// #expect(Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
    ///                           majorRadius: 0, minorRadius: 3) == nil)
    /// ```
    public static func hyperbola(center: SIMD3<Double>, normal: SIMD3<Double>,
                                 majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let h = OCCTCurve3DCreateHyperbola(center.x, center.y, center.z,
                                                  normal.x, normal.y, normal.z,
                                                  majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: h)
    }

    // MARK: - BSpline & Bezier

    /// Create a BSpline curve from poles, knots, and multiplicities
    public static func bspline(poles: [SIMD3<Double>], weights: [Double]? = nil,
                               knots: [Double], multiplicities: [Int32],
                               degree: Int) -> Curve3D? {
        let flatPoles = poles.flatMap { [$0.x, $0.y, $0.z] }
        let h = flatPoles.withUnsafeBufferPointer { polesPtr in
            knots.withUnsafeBufferPointer { knotsPtr in
                multiplicities.withUnsafeBufferPointer { multsPtr in
                    if let w = weights {
                        return w.withUnsafeBufferPointer { wPtr in
                            OCCTCurve3DCreateBSpline(polesPtr.baseAddress, Int32(poles.count),
                                                      wPtr.baseAddress,
                                                      knotsPtr.baseAddress, Int32(knots.count),
                                                      multsPtr.baseAddress, Int32(degree))
                        }
                    } else {
                        return OCCTCurve3DCreateBSpline(polesPtr.baseAddress, Int32(poles.count),
                                                         nil,
                                                         knotsPtr.baseAddress, Int32(knots.count),
                                                         multsPtr.baseAddress, Int32(degree))
                    }
                }
            }
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    /// Create a Bezier curve from control points
    public static func bezier(poles: [SIMD3<Double>], weights: [Double]? = nil) -> Curve3D? {
        let flatPoles = poles.flatMap { [$0.x, $0.y, $0.z] }
        let h: OCCTCurve3DRef?
        if let w = weights {
            h = flatPoles.withUnsafeBufferPointer { pp in
                w.withUnsafeBufferPointer { wp in
                    OCCTCurve3DCreateBezier(pp.baseAddress, Int32(poles.count), wp.baseAddress)
                }
            }
        } else {
            h = flatPoles.withUnsafeBufferPointer { pp in
                OCCTCurve3DCreateBezier(pp.baseAddress, Int32(poles.count), nil)
            }
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    /// Interpolate through 3D points
    public static func interpolate(points: [SIMD3<Double>], closed: Bool = false,
                                   tolerance: Double = 1e-6) -> Curve3D? {
        let flat = points.flatMap { [$0.x, $0.y, $0.z] }
        let h = flat.withUnsafeBufferPointer { ptr in
            OCCTCurve3DInterpolate(ptr.baseAddress, Int32(points.count), closed, tolerance)
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    /// Interpolate a BSpline through points with constrained start/end tangents.
    ///
    /// - Parameters:
    ///   - points: Points the curve must pass through (minimum 2).
    ///   - startTangent: Tangent vector at the first point.
    ///   - endTangent: Tangent vector at the last point.
    ///   - tolerance: Interpolation precision; also the minimum allowed distance between
    ///     consecutive points. Defaults to `1e-6` and is honored on every call, including
    ///     the bare 3-argument form.
    /// - Returns: Interpolated BSpline curve, or `nil` on failure.
    ///
    /// ```swift
    /// let pts: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(5, 5, 5), SIMD3(10, 0, 0)]
    /// let curve = Curve3D.interpolate(points: pts,
    ///                                 startTangent: SIMD3(1, 1, 1),
    ///                                 endTangent: SIMD3(1, -1, -1),
    ///                                 tolerance: 1e-9)
    /// ```
    public static func interpolate(points: [SIMD3<Double>],
                                   startTangent: SIMD3<Double>,
                                   endTangent: SIMD3<Double>,
                                   tolerance: Double = 1e-6) -> Curve3D? {
        let flat = points.flatMap { [$0.x, $0.y, $0.z] }
        let h = flat.withUnsafeBufferPointer { ptr in
            OCCTCurve3DInterpolateWithTangents(ptr.baseAddress, Int32(points.count),
                                                startTangent.x, startTangent.y, startTangent.z,
                                                endTangent.x, endTangent.y, endTangent.z,
                                                tolerance)
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    /// Fit a BSpline curve through points (least-squares approximation)
    public static func fit(points: [SIMD3<Double>], minDegree: Int = 3, maxDegree: Int = 8,
                           tolerance: Double = 1e-3) -> Curve3D? {
        let flat = points.flatMap { [$0.x, $0.y, $0.z] }
        let h = flat.withUnsafeBufferPointer { ptr in
            OCCTCurve3DFitPoints(ptr.baseAddress, Int32(points.count),
                                  Int32(minDegree), Int32(maxDegree), tolerance)
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    // MARK: - BSpline Queries

    /// Number of poles (control points), or `nil` if not a BSpline/Bezier.
    public var poleCount: Int? {
        let n = Int(OCCTCurve3DGetPoleCount(handle))
        return n > 0 ? n : nil
    }

    /// Get poles (control points) for BSpline/Bezier curves
    public var poles: [SIMD3<Double>]? {
        guard let n = poleCount else { return nil }
        var buffer = [Double](repeating: 0, count: n * 3)
        let actual = Int(OCCTCurve3DGetPoles(handle, &buffer))
        guard actual > 0 else { return nil }
        return unpackSIMD3(buffer, count: actual)
    }

    /// Degree of BSpline/Bezier curve (-1 if not applicable)
    public var degree: Int {
        Int(OCCTCurve3DGetDegree(handle))
    }

    // MARK: - Operations

    /// Trim curve to parameter range [u1, u2]
    public func trimmed(from u1: Double, to u2: Double) -> Curve3D? {
        guard let h = OCCTCurve3DTrim(handle, u1, u2) else { return nil }
        return Curve3D(handle: h)
    }

    /// Reverse curve parameterization
    public func reversed() -> Curve3D? {
        guard let h = OCCTCurve3DReversed(handle) else { return nil }
        return Curve3D(handle: h)
    }

    /// Translate curve by a displacement vector
    public func translated(by delta: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DTranslate(handle, delta.x, delta.y, delta.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Rotate curve around an axis
    public func rotated(around axisOrigin: SIMD3<Double>, direction: SIMD3<Double>,
                        angle: Double) -> Curve3D? {
        guard let h = OCCTCurve3DRotate(handle,
                                         axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                         direction.x, direction.y, direction.z,
                                         angle) else { return nil }
        return Curve3D(handle: h)
    }

    /// Scale curve from a center point
    public func scaled(from center: SIMD3<Double>, factor: Double) -> Curve3D? {
        guard let h = OCCTCurve3DScale(handle, center.x, center.y, center.z,
                                        factor) else { return nil }
        return Curve3D(handle: h)
    }

    /// Mirror curve across a point
    public func mirrored(acrossPoint point: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DMirrorPoint(handle, point.x, point.y, point.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Mirror curve across an axis (line)
    public func mirrored(acrossAxis point: SIMD3<Double>, direction: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DMirrorAxis(handle, point.x, point.y, point.z,
                                             direction.x, direction.y, direction.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Mirror curve across a plane
    public func mirrored(acrossPlane point: SIMD3<Double>, normal: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DMirrorPlane(handle, point.x, point.y, point.z,
                                              normal.x, normal.y, normal.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Arc length of the full curve.
    ///
    /// This is the canonical, failure-distinguishing entry point: returns `nil` if the curve
    /// is invalid or the underlying computation fails, rather than collapsing failure into a
    /// numeric result. `totalArcLength` delegates to this and collapses failure back to `-1.0`
    /// for source compatibility — prefer this property when you need to tell "failed" apart
    /// from "genuinely zero".
    ///
    /// Backed by `GCPnts_AbscissaPoint::Length`, applied to each of the curve's `GeomAbs_CN`
    /// intervals and then to that interval halved, quartered, ... until two successive levels
    /// agree to 1e-9 relative. One fixed-order Gauss rule per interval is not enough wherever the
    /// speed `|C'(u)|` varies across it: a whole ellipse measured up to 1.7% long, a parabola over
    /// `[-100, 100]` 3.1% short and a 5-point interpolation 6.0e-5 out (#603, completing #477's
    /// per-span split). A line, a circle and a 2-pole Bezier/BSpline keep their exact closed form.
    ///
    /// The measurement costs roughly 5x what a single quadrature did — an 8 x 3 ellipse 0.11 us to
    /// 3.5 us, a 200-span BSpline 89 us to 452 us; a line or circle is unchanged at 0.02 us.
    ///
    /// An unbounded curve reports its parametric extent (an untrimmed line spans ±2e100), so
    /// trim before measuring if that is not what you want.
    ///
    /// - Returns: Arc length in model units, or `nil` if the OCCT computation fails.
    ///
    /// ```swift
    /// let path = Curve3D.interpolate(points: waypoints)!
    /// if let total = path.length {
    ///     let steps = Int((total / stepOver).rounded(.up))
    /// }
    /// ```
    public var length: Double? {
        let l = OCCTCurve3DGetLength(handle)
        return l >= 0 ? l : nil
    }

    /// Arc length between two parameters.
    ///
    /// This is the canonical, failure-distinguishing entry point: returns `nil` if the curve
    /// is invalid or the underlying computation fails, rather than collapsing failure into a
    /// numeric result. `arcLength(from:to:)` and `arcLengthBetween(_:_:)` both delegate to this
    /// and collapse failure back to `-1.0` for source compatibility — prefer this method when
    /// you need to tell "failed" apart from a genuine zero-length interval (e.g. `u1 == u2`).
    ///
    /// Same composite integrator as ``length``. The range may be given in either order; equal
    /// parameters measure `0`.
    ///
    /// Both bounds must be finite: `.nan` and `±.infinity` are rejected and report `nil`. OCCT
    /// itself does not check, and answered them differently per curve type — on an interpolated
    /// BSpline a NaN upper bound measured `0` and a NaN lower bound measured the curve's whole
    /// length, neither distinguishable from a real result (#548).
    ///
    /// A finite range reaching outside the curve's domain is *not* rejected: it measures the part
    /// of the range that lies on the curve, so a range wholly outside measures `0` and one
    /// overhanging an end measures up to that end. A curve whose parameter domain covers a whole
    /// period exists at every parameter, so a *periodic* curve measures the whole range and winds:
    /// a circle over `[0, 4π]` travels two circumferences. An arc trimmed from a circle covers
    /// half a period, so it stops at its own trim (#600).
    ///
    /// - Parameters:
    ///   - u1: Start parameter. Must be finite.
    ///   - u2: End parameter. Must be finite.
    /// - Returns: Arc length in model units, or `nil` if a bound is not finite or the OCCT
    ///   computation fails.
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 1)!
    /// let d = circle.domain
    /// let half = circle.length(from: d.lowerBound, to: d.lowerBound + .pi)  // ~= pi
    /// let two = circle.length(from: 0, to: 4 * .pi)   // ~= 4pi, two turns: the circle is periodic
    /// let bad = circle.length(from: d.lowerBound, to: .nan)                 // nil, not a number
    ///
    /// let seg = Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0))!
    /// let clipped = seg.length(from: 0, to: 20)       // 10, the segment: it is not a whole line
    /// let outside = seg.length(from: 20, to: 30)      // 0, the segment is not there
    /// ```
    public func length(from u1: Double, to u2: Double) -> Double? {
        let l = OCCTCurve3DGetLengthBetween(handle, u1, u2)
        return l >= 0 ? l : nil
    }

    // MARK: - Conversion (GeomConvert)

    /// Convert to BSpline representation
    public func toBSpline() -> Curve3D? {
        guard let h = OCCTCurve3DToBSpline(handle) else { return nil }
        return Curve3D(handle: h)
    }

    /// Split BSpline into Bezier segments
    public func toBezierSegments() -> [Curve3D]? {
        var buffer = [OCCTCurve3DRef?](repeating: nil, count: 128)
        let n = buffer.withUnsafeMutableBufferPointer { ptr in
            OCCTCurve3DBSplineToBeziers(handle, ptr.baseAddress, 128)
        }
        guard n > 0 else { return nil }
        var result = [Curve3D]()
        for i in 0..<Int(n) {
            if let h = buffer[i] {
                result.append(Curve3D(handle: h))
            }
        }
        return result.isEmpty ? nil : result
    }

    /// Join multiple curves into a single BSpline
    public static func join(_ curves: [Curve3D], tolerance: Double = 1e-6) -> Curve3D? {
        let handles: [OCCTCurve3DRef?] = curves.map { $0.handle }
        let h = handles.withUnsafeBufferPointer { ptr in
            OCCTCurve3DJoinToBSpline(ptr.baseAddress, Int32(curves.count), tolerance)
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    /// Approximate the curve with a BSpline of specified continuity.
    ///
    /// Defaults (`tolerance: 1e-3`, `maxDegree: 8`) are shared with `Curve2D.approximated` and
    /// `Surface.approximated` (#406) — all three wrap the same `GeomConvert_Approx*`/
    /// `Geom2dConvert_ApproxCurve` family applied to a different OCCT geometry hierarchy, not
    /// independent algorithms that would justify independently-tuned numeric defaults.
    ///
    /// Returns the fitted curve whenever OCCT produced one, which — per `HasResult()`, the
    /// accessor this shares with ``Curve3D/approxWithDetails(tolerance:continuity:maxSegments:maxDegree:)``
    /// since #491 — includes a best-effort fit that did *not* reach `tolerance`. A non-nil result
    /// is therefore not a promise that `tolerance` was met: `approxWithDetails` reports the actual
    /// `maxError` and an `isDone` flag for that. (Gating on `IsDone()` would not have helped here;
    /// measured against this kernel it never rejects an over-tolerance fit — a circle fitted with
    /// one segment at degree 3 against a 1e-9 tolerance reports `maxError` 5.1 and `isDone` true.)
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10)!
    /// let bspline = circle.approximated(tolerance: 1e-4)
    /// ```
    ///
    /// - Parameter continuity: A ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2). The
    ///   approximator accepts nothing stricter: `AdvApprox` throws for C3 and above, which
    ///   surfaces here as `nil`.
    public func approximated(tolerance: Double = 1e-3, continuity: Int = 2,
                             maxSegments: Int = 100, maxDegree: Int = 8) -> Curve3D? {
        guard let h = OCCTCurve3DApproximate(handle, tolerance, Int32(continuity),
                                              Int32(maxSegments), Int32(maxDegree)) else { return nil }
        return Curve3D(handle: h)
    }

    // MARK: - Draw (Discretization for Metal)

    /// Adaptive discretization using angular and chordal deflection criteria.
    ///
    /// - Parameter maxPoints: Output *capacity*, clamped into `0...`
    ///   ``Sampling/maximumSampleCount`` (#558). The deflection criteria decide the actual point
    ///   count; `maxPoints` only truncates, so clamping an unservable capacity returns the same
    ///   points rather than a coarser sampling. A capacity of 0 or less returns empty.
    public func drawAdaptive(angularDeflection: Double = 0.1,
                             chordalDeflection: Double = 0.01,
                             maxPoints: Int = 4096) -> [SIMD3<Double>] {
        let capacity = Sampling.capacity(maxPoints)
        guard capacity > 0 else { return [] }
        var buffer = [Double](repeating: 0, count: capacity * 3)
        let n = Int(OCCTCurve3DDrawAdaptive(handle, angularDeflection, chordalDeflection,
                                             &buffer, Int32(capacity)))
        return unpackSIMD3(buffer, count: n)
    }

    /// Uniform arc-length spacing discretization.
    ///
    /// The first point is always the start of the curve and the last is always its end.
    ///
    /// ```swift
    /// let seg = Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0))!
    /// let pts = seg.drawUniform(pointCount: 11)
    /// // pts[5] ≈ SIMD3(5, 0, 0)
    /// ```
    ///
    /// - Parameter pointCount: Desired number of output points, honoured within `2...`
    ///   ``Sampling/maximumSampleCount``; outside that range the result is empty. This is a
    ///   *request*, so a count past the ceiling fails visibly rather than coming back coarser
    ///   than what was asked for (#558). Before that bound the documented "at least 2, else
    ///   empty" was only true of counts down to 0: a negative aborted the process.
    /// - Returns: Array of 3D points, never more than `pointCount` of them, or empty on failure
    public func drawUniform(pointCount: Int) -> [SIMD3<Double>] {
        guard let pointCount = Sampling.requested(pointCount) else { return [] }
        var buffer = [Double](repeating: 0, count: pointCount * 3)
        let n = Int(OCCTCurve3DDrawUniform(handle, Int32(pointCount), &buffer))
        return unpackSIMD3(buffer, count: n)
    }

    /// Chordal deflection discretization.
    ///
    /// - Parameter maxPoints: Output *capacity*, clamped into `0...`
    ///   ``Sampling/maximumSampleCount``; 0 or less returns empty (#558).
    public func drawDeflection(deflection: Double = 0.01,
                               maxPoints: Int = 4096) -> [SIMD3<Double>] {
        let capacity = Sampling.capacity(maxPoints)
        guard capacity > 0 else { return [] }
        var buffer = [Double](repeating: 0, count: capacity * 3)
        let n = Int(OCCTCurve3DDrawDeflection(handle, deflection, &buffer, Int32(capacity)))
        return unpackSIMD3(buffer, count: n)
    }

    // MARK: - Local Properties

    /// Curvature (1/radius) at parameter `u`, or `nil` where the curve has none.
    ///
    /// - Parameter u: Curve parameter.
    /// - Returns: The curvature, or `nil` at a parameter the curve cannot be evaluated at or where
    ///   `GeomLProp_CLProps::IsTangentDefined()` is false — a point with no significant derivative
    ///   of any order, such as a Bezier whose control points all coincide. This used to be `0`,
    ///   which is also every straight curve's real curvature (#595).
    ///
    /// A **cusp** is not an absence and is still reported: OCCT calls the curvature there infinite
    /// and returns `Double.greatestFiniteMagnitude` (`RealLast()`), which passes through as a value.
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
    /// if let k = circle.curvature(at: 0) { print(k) }   // 0.2, i.e. 1/5
    ///
    /// let line = Curve3D.line(origin: .zero, direction: SIMD3(1, 0, 0))!
    /// line.curvature(at: 3)   // 0 — straight, and that is the answer, not a failure
    /// ```
    public func curvature(at u: Double) -> Double? {
        var k = 0.0
        guard OCCTCurve3DGetCurvature(handle, u, &k) else { return nil }
        return k
    }

    /// Unit tangent direction at parameter u
    public func tangentDirection(at u: Double) -> SIMD3<Double>? {
        var tx: Double = 0, ty: Double = 0, tz: Double = 0
        guard OCCTCurve3DGetTangent(handle, u, &tx, &ty, &tz) else { return nil }
        return SIMD3(tx, ty, tz)
    }

    /// Principal normal direction at parameter u
    public func normal(at u: Double) -> SIMD3<Double>? {
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTCurve3DGetNormal(handle, u, &nx, &ny, &nz) else { return nil }
        return SIMD3(nx, ny, nz)
    }

    /// Center of curvature at parameter u
    public func centerOfCurvature(at u: Double) -> SIMD3<Double>? {
        var cx: Double = 0, cy: Double = 0, cz: Double = 0
        guard OCCTCurve3DGetCenterOfCurvature(handle, u, &cx, &cy, &cz) else { return nil }
        return SIMD3(cx, cy, cz)
    }

    /// Torsion at parameter `u` — the rate the curve twists out of its osculating plane — or `nil`
    /// where there is no osculating plane to twist out of.
    ///
    /// - Parameter u: Curve parameter.
    /// - Returns: The torsion, or `nil` at a parameter the curve cannot be evaluated at or where
    ///   the first two derivatives are parallel (a straight stretch), so no osculating plane is
    ///   defined. That case used to be `0`, which is also every **planar** curve's real torsion —
    ///   a circle and a straight line reported the same answer (#595).
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 4)!
    /// circle.torsion(at: 1)   // 0 — planar, and that is the answer
    ///
    /// let line = Curve3D.line(origin: .zero, direction: SIMD3(1, 0, 0))!
    /// line.torsion(at: 5)     // nil — no osculating plane at all
    /// ```
    public func torsion(at u: Double) -> Double? {
        var t = 0.0
        guard OCCTCurve3DGetTorsion(handle, u, &t) else { return nil }
        return t
    }

    // MARK: - Bounding Box

    /// Axis-aligned bounding box of the curve
    public var boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>)? {
        var xMin: Double = 0, yMin: Double = 0, zMin: Double = 0
        var xMax: Double = 0, yMax: Double = 0, zMax: Double = 0
        guard OCCTCurve3DGetBoundingBox(handle, &xMin, &yMin, &zMin,
                                         &xMax, &yMax, &zMax) else { return nil }
        return (min: SIMD3(xMin, yMin, zMin), max: SIMD3(xMax, yMax, zMax))
    }

    // MARK: - Projection (v0.22.0)

    /// Project this curve onto a plane along a given direction.
    ///
    /// Uses `GeomProjLib::ProjectOnPlane`. The result is a 3D curve
    /// lying in the target plane.
    /// - Parameters:
    ///   - origin: A point on the target plane
    ///   - normal: Normal direction of the target plane
    ///   - direction: Projection direction (must not be parallel to the plane normal)
    /// - Returns: The projected 3D curve, or nil if projection fails
    public func projectedOnPlane(origin: SIMD3<Double>,
                                  normal: SIMD3<Double>,
                                  direction: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DProjectOnPlane(handle,
                                                 origin.x, origin.y, origin.z,
                                                 normal.x, normal.y, normal.z,
                                                 direction.x, direction.y, direction.z)
        else { return nil }
        return Curve3D(handle: h)
    }
}

// MARK: - Batch Evaluation (v0.29.0)

extension Curve3D {
    /// Evaluate the curve at multiple parameters in one call.
    ///
    /// - Parameter parameters: Array of parameter values
    /// - Returns: Array of evaluated 3D points
    public func evaluateGrid(_ parameters: [Double]) -> [SIMD3<Double>] {
        guard !parameters.isEmpty else { return [] }
        var outXYZ = [Double](repeating: 0, count: parameters.count * 3)
        let n = Int(OCCTCurve3DEvaluateGrid(handle, parameters, Int32(parameters.count), &outXYZ))
        return unpackSIMD3(outXYZ, count: n)
    }

    /// Evaluate the curve and its first derivative at multiple parameters in one call.
    ///
    /// - Parameter parameters: Array of parameter values
    /// - Returns: Array of tuples with point and tangent vector
    public func evaluateGridD1(_ parameters: [Double]) -> [(point: SIMD3<Double>, tangent: SIMD3<Double>)] {
        guard !parameters.isEmpty else { return [] }
        var outXYZ = [Double](repeating: 0, count: parameters.count * 3)
        var outDXDYDZ = [Double](repeating: 0, count: parameters.count * 3)
        let n = Int(OCCTCurve3DEvaluateGridD1(handle, parameters, Int32(parameters.count), &outXYZ, &outDXDYDZ))
        let points: [SIMD3<Double>] = unpackSIMD3(outXYZ, count: n)
        let tangents: [SIMD3<Double>] = unpackSIMD3(outDXDYDZ, count: n)
        return zip(points, tangents).map { (point: $0, tangent: $1) }
    }

    /// Check if this curve is planar.
    ///
    /// - Parameter tolerance: Planarity tolerance (default: 0)
    /// - Returns: The plane normal if planar, or nil if not planar
    public func planeNormal(tolerance: Double = 0) -> SIMD3<Double>? {
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTCurve3DIsPlanar(handle, tolerance, &nx, &ny, &nz) else { return nil }
        return SIMD3(nx, ny, nz)
    }
}

// MARK: - Curve Distance & Intersection (v0.30.0)

/// Extremal distance result between two curves.
public struct CurveExtremaResult: Sendable {
    public let distance: Double
    public let point1: SIMD3<Double>
    public let point2: SIMD3<Double>
    public let parameter1: Double
    public let parameter2: Double
}

/// Curve-surface intersection point.
public struct CurveSurfaceHit: Sendable {
    public let point: SIMD3<Double>
    public let curveParameter: Double
    public let surfaceU: Double
    public let surfaceV: Double
}

extension Curve3D {
    /// Minimum distance from this curve to another curve.
    ///
    /// - Parameter other: The other curve
    /// - Returns: The minimum distance, or nil on failure
    public func minDistance(to other: Curve3D) -> Double? {
        let d = OCCTCurve3DMinDistanceToCurve(handle, other.handle)
        return d >= 0 ? d : nil
    }

    /// Find all extremal distances between this curve and another.
    ///
    /// Returns closest and farthest point pairs between two curves.
    ///
    /// - Parameters:
    ///   - other: The other curve
    ///   - maxCount: Output *capacity* (default 20), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of extremal distance results. Empty when the curves are parallel: OCCT
    ///   represents that case as a single unbounded family of equidistant solutions rather than a
    ///   finite set of point pairs, so there is no `(point1, point2)` pair to report (#636). Use
    ///   ``minDistance(to:)`` to get the (well-defined) distance in that case.
    ///
    /// An empty array therefore means one of two different things, and this method cannot tell you
    /// which: the curves are parallel, or they simply have no extremal relationship. If you need to
    /// distinguish them, ``extremaCC(range1:other:range2:)`` returns a `CurveCurveExtrema` carrying
    /// `isParallel` alongside the count, from the same underlying computation.
    ///
    /// ```swift
    /// let a = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))!
    /// let b = Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0))!
    ///
    /// let pairs = a.extrema(with: b)              // [], but why?
    /// if pairs.isEmpty {
    ///     let info = a.extremaCC(other: b)
    ///     print(info.isParallel)                  // true: an infinite equidistant family
    ///     print(a.minDistance(to: b) ?? 0)        // 5.0, the well-defined separation
    /// }
    /// ```
    ///
    /// "Parallel" here is OCCT's own predicate, which is narrower than "the tangent directions are
    /// parallel". Two parallel segments whose parameter ranges do not overlap have a single
    /// well-defined nearest-endpoint pair; `isParallel` is false for them, and this method returns
    /// that pair normally.
    public func extrema(with other: Curve3D, maxCount: Int = 20) -> [CurveExtremaResult] {
        let maxCount = Sampling.capacity(maxCount)
        guard maxCount > 0 else { return [] }
        var buffer = [OCCTCurveExtrema](repeating: OCCTCurveExtrema(), count: maxCount)
        let n = Int(OCCTCurve3DExtrema(handle, other.handle, &buffer, Int32(maxCount)))
        return (0..<n).map { i in
            let e = buffer[i]
            return CurveExtremaResult(
                distance: e.distance,
                point1: SIMD3(e.point1.0, e.point1.1, e.point1.2),
                point2: SIMD3(e.point2.0, e.point2.1, e.point2.2),
                parameter1: e.param1, parameter2: e.param2
            )
        }
    }

    /// Find intersection points between this curve and a surface.
    ///
    /// - Parameters:
    ///   - surface: The surface to intersect with
    ///   - maxHits: Output *capacity* (default 100), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of intersection points with parameters
    public func intersections(with surface: Surface, maxHits: Int = 100) -> [CurveSurfaceHit] {
        let maxHits = Sampling.capacity(maxHits)
        guard maxHits > 0 else { return [] }
        var buffer = [OCCTCurveSurfaceIntersection](repeating: OCCTCurveSurfaceIntersection(), count: maxHits)
        let n = Int(OCCTCurve3DIntersectSurface(handle, surface.handle, &buffer, Int32(maxHits)))
        return (0..<n).map { i in
            let h = buffer[i]
            return CurveSurfaceHit(
                point: SIMD3(h.point.0, h.point.1, h.point.2),
                curveParameter: h.paramCurve,
                surfaceU: h.paramU, surfaceV: h.paramV
            )
        }
    }

    /// Minimum distance from this curve to a surface.
    ///
    /// - Parameter surface: The surface
    /// - Returns: The minimum distance, or nil on failure
    public func minDistance(to surface: Surface) -> Double? {
        let d = OCCTCurve3DDistanceToSurface(handle, surface.handle)
        return d >= 0 ? d : nil
    }

    /// Convert this curve to an analytical curve if possible.
    ///
    /// Recognizes if the curve is actually a line, circle, or ellipse within the given tolerance
    /// and returns the analytical representation. A curve that is already analytical converts to an
    /// equal, independent curve rather than being rejected.
    ///
    /// Examines the curve's whole domain. Use ``toAnalytical(tolerance:first:last:)`` to examine a
    /// sub-range, or ``toAnalyticalWithGap(tolerance:)`` to also get the deviation.
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
    /// if let analytical = circle.toBSpline()?.toAnalytical(tolerance: 1e-4) {
    ///     print(analytical.curveKind)   // .circle
    /// }
    /// ```
    ///
    /// - Parameter tolerance: Recognition tolerance
    /// - Returns: The analytical curve, or nil if not recognizable
    public func toAnalytical(tolerance: Double = 1e-4) -> Curve3D? {
        toAnalyticalWithGap(tolerance: tolerance)?.curve
    }

    // MARK: - Quasi-Uniform Sampling (v0.31.0)

    /// Sample parameter values at quasi-uniform arc-length intervals.
    ///
    /// Uses `GCPnts_QuasiUniformAbscissa` to distribute sample points
    /// approximately evenly along the curve's arc length. The first parameter is always the start
    /// of the curve's domain and the last is always its end.
    ///
    /// ```swift
    /// if let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
    ///     let params = c.quasiUniformParameters(count: 8)
    ///     #expect(params.count == 8)
    ///     #expect(params.last == c.domain.upperBound)
    /// }
    /// ```
    ///
    /// - Parameter count: Desired number of sample points, honoured within `2...`
    ///   ``Sampling/maximumSampleCount``; outside that range the result is empty. OCCT's samplers
    ///   document the lower bound but cannot enforce it in a Release kernel, and below 2 they
    ///   misbehave rather than fail; the upper bound is this layer's, since `count` sizes a Swift
    ///   allocation and is cast to the bridge's `int32_t`, and both ends used to abort the
    ///   process (#558).
    /// - Returns: Array of parameter values, never more than `count` of them, or empty on failure
    public func quasiUniformParameters(count: Int) -> [Double] {
        guard let count = Sampling.requested(count) else { return [] }
        var params = [Double](repeating: 0, count: count)
        let n = Int(OCCTCurve3DQuasiUniformAbscissa(handle, Int32(count), &params))
        return Array(params.prefix(n))
    }

    /// Sample points at quasi-uniform deflection intervals.
    ///
    /// Uses `GCPnts_QuasiUniformDeflection` to distribute sample points
    /// such that the chord deviation from the curve stays within the
    /// given deflection tolerance.
    ///
    /// - Parameters:
    ///   - deflection: Maximum allowed chord deviation
    ///   - maxPoints: Output *capacity*, clamped into `0`...``Sampling/maximumSampleCount``;
    ///     0 or less returns empty (#558). The deflection decides the actual point count.
    /// - Returns: Array of 3D points, or empty array on failure
    public func quasiUniformDeflectionPoints(deflection: Double, maxPoints: Int = 500) -> [SIMD3<Double>] {
        let capacity = Sampling.capacity(maxPoints)
        guard capacity > 0 else { return [] }
        var xyz = [Double](repeating: 0, count: capacity * 3)
        let n = Int(OCCTCurve3DQuasiUniformDeflection(handle, deflection, &xyz, Int32(capacity)))
        return unpackSIMD3(xyz, count: n)
    }

    // MARK: - BSpline Knot Splitting (v0.40.0)

    // Continuity order for knot splitting is `ParametricContinuity` (Continuity.swift); the
    // nested `ContinuityOrder` copy declared here is now a deprecated alias of it. See #398.

    /// Knot parameters at which to split a BSpline so every arc is at least `minContinuity`
    ///
    /// Only works on BSpline curves. The result is a set of *split* parameters, not a set of
    /// defects: the curve's own first and last knots are always included, so a curve that never
    /// drops below `minContinuity` returns exactly those two rather than an empty array. Any
    /// further entries are interior knots where the curve really is less continuous than asked.
    ///
    /// A curve's discontinuities are inherently 1D, so parameter values are the natural (and
    /// only sensible) shape here -- unlike `Surface.knotSplitting` (2D, per-direction counts
    /// *and* parameters) or `LawFunction.knotSplitting`/`knotSplitParameters` (1D, but split
    /// across two methods for backward compatibility). See #403 for why these three siblings
    /// return different shapes.
    ///
    /// ```swift
    /// // A cubic interpolated BSpline is already C2 at its interior knots, so nothing
    /// // below C3 reports anything beyond the two end knots.
    /// let ends   = bspline.continuityBreaks(minContinuity: .c2)  // [first, last]
    /// let breaks = bspline.continuityBreaks(minContinuity: .c3)  // + interior knots
    /// ```
    ///
    /// - Parameter minContinuity: Minimum continuity to require of each resulting arc. This is a
    ///   derivative order, and `GeomConvert_BSplineCurveKnotSplitting` splits a knot only when
    ///   `degree - multiplicity < minContinuity`, so the meaningful range is 0...degree and it
    ///   saturates there. On a degree-4-or-higher curve ``ParametricContinuity/c3`` is the
    ///   strictest question this vocabulary can ask; `toBezierSegments()` is the dedicated API
    ///   for the every-knot split at the far end of that ladder (#480).
    /// - Returns: Split parameters in ascending order, bounded by the curve's end knots, or
    ///   nil if the curve is not a BSpline
    public func continuityBreaks(minContinuity: ParametricContinuity = .c1) -> [Double]? {
        // The bridge returns the true split count even when it writes fewer, so one retry at
        // that count is always enough. Worth doing since #398: the old c0...c2 range could not
        // report interior knots at all on an ordinary cubic, and .c3 can, which brought a fixed
        // 256-entry buffer within reach of real imported geometry.
        func read(capacity: Int32) -> (count: Int32, params: [Double]) {
            var params = [Double](repeating: 0, count: Int(capacity))
            let count = OCCTCurve3DBSplineKnotSplits(handle, minContinuity.rawValue,
                                                     &params, capacity)
            return (count, params)
        }

        var (count, params) = read(capacity: 256)
        guard count >= 0 else { return nil }
        if count > 256 {
            (count, params) = read(capacity: count)
            guard count >= 0 else { return nil }
        }
        return Array(params.prefix(Int(count)))
    }

    // MARK: - Ellipse Arcs

    /// Create an elliptical arc from angular parameters.
    ///
    /// Creates an arc of an ellipse in the plane defined by center and normal.
    /// The major axis is oriented perpendicular to the normal (determined automatically).
    ///
    /// - Parameters:
    ///   - center: Center of the ellipse
    ///   - normal: Normal direction of the ellipse plane
    ///   - majorRadius: Major radius of the ellipse
    ///   - minorRadius: Minor radius of the ellipse
    ///   - startAngle: Start angle in radians
    ///   - endAngle: End angle in radians
    ///   - counterclockwise: Arc direction (default: true)
    /// - Returns: The elliptical arc curve, or `nil` on failure, including when the radii do not
    ///   describe an ellipse.
    ///
    /// `majorRadius` and `minorRadius` must both be `> 0` with `minorRadius <= majorRadius`, the
    /// same contract `ellipse(center:normal:majorRadius:minorRadius:)` enforces. A zero minor
    /// radius is rejected rather than collapsed onto the major axis.
    ///
    /// ```swift
    /// let arc = Curve3D.arcOfEllipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                                majorRadius: 10, minorRadius: 5,
    ///                                startAngle: 0, endAngle: .pi)
    /// #expect(arc != nil)
    /// #expect(Curve3D.arcOfEllipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                              majorRadius: 10, minorRadius: 0,
    ///                              startAngle: 0, endAngle: .pi) == nil)
    /// ```
    public static func arcOfEllipse(center: SIMD3<Double>, normal: SIMD3<Double>,
                                     majorRadius: Double, minorRadius: Double,
                                     startAngle: Double, endAngle: Double,
                                     counterclockwise: Bool = true) -> Curve3D? {
        guard let ref = OCCTCurve3DArcOfEllipse(
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            majorRadius, minorRadius,
            startAngle, endAngle, counterclockwise
        ) else {
            return nil
        }
        return Curve3D(handle: ref)
    }

    /// Create an elliptical arc passing through two points on the ellipse.
    ///
    /// - Parameters:
    ///   - center: Center of the ellipse
    ///   - normal: Normal direction of the ellipse plane
    ///   - majorRadius: Major radius of the ellipse
    ///   - minorRadius: Minor radius of the ellipse
    ///   - from: Start point (must lie on the ellipse)
    ///   - to: End point (must lie on the ellipse)
    ///   - counterclockwise: Arc direction (default: true)
    /// - Returns: The elliptical arc curve, or `nil` on failure, including when the radii do not
    ///   describe an ellipse.
    ///
    /// Same radius contract as the angular form. It matters more here: this form inverts each
    /// point back to a parameter, and with a zero minor radius that inversion is `NaN`, which
    /// OCCT reports as a *successful* construction. Before the radii were checked, this returned
    /// a live curve whose parameter range and every evaluation were `NaN` (#554).
    ///
    /// ```swift
    /// let arc = Curve3D.arcOfEllipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                                majorRadius: 10, minorRadius: 5,
    ///                                from: SIMD3(10, 0, 0), to: SIMD3(-10, 0, 0))
    /// #expect(arc != nil)
    /// #expect(Curve3D.arcOfEllipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                              majorRadius: 10, minorRadius: 0,
    ///                              from: SIMD3(10, 0, 0), to: SIMD3(-10, 0, 0)) == nil)
    /// ```
    public static func arcOfEllipse(center: SIMD3<Double>, normal: SIMD3<Double>,
                                     majorRadius: Double, minorRadius: Double,
                                     from: SIMD3<Double>, to: SIMD3<Double>,
                                     counterclockwise: Bool = true) -> Curve3D? {
        guard let ref = OCCTCurve3DArcOfEllipsePoints(
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            majorRadius, minorRadius,
            from.x, from.y, from.z,
            to.x, to.y, to.z, counterclockwise
        ) else {
            return nil
        }
        return Curve3D(handle: ref)
    }

    // MARK: - Curve joining (v0.49.0)

    /// Join multiple curves into a single BSpline curve.
    ///
    /// Uses GeomConvert_CompCurveToBSplineCurve to concatenate curves
    /// in order into a single BSpline. Curves must meet end-to-end
    /// within the given tolerance.
    ///
    /// - Parameters:
    ///   - curves: Array of curves to join (in order)
    ///   - tolerance: Gap tolerance for joining endpoints (default: 1e-6)
    /// - Returns: Joined BSpline curve, or nil on failure
    public static func joined(curves: [Curve3D], tolerance: Double = 1e-6) -> Curve3D? {
        guard !curves.isEmpty else { return nil }
        var handles: [OCCTCurve3DRef?] = curves.map { $0.handle }
        guard let ref = OCCTCurve3DJoinCurves(&handles, Int32(curves.count), tolerance) else {
            return nil
        }
        return Curve3D(handle: ref)
    }

    // MARK: - ShapeAnalysis_Curve expansion (v0.49.0)

    /// Result of projecting a point onto a curve
    public struct PointProjection: Sendable {
        /// Distance from the original point to the projection
        public let distance: Double
        /// Parameter on the curve at the closest point
        public let parameter: Double
        /// Projected point on the curve
        public let point: SIMD3<Double>
    }

    /// Project a point onto this curve to find the closest point on it.
    ///
    /// The answer is always inside this curve's own ``domain``, and always the true nearest point:
    /// where the point has no perpendicular foot on the curve — anything past the end of a trimmed
    /// curve, or off to one side of an arc — the nearest point is an end, and that is what comes
    /// back. ``nearestParameter(to:)`` is the scalar spelling of this and agrees with it exactly
    /// (#615); ``distance(to:precision:)`` is the distance-only one.
    ///
    /// ```swift
    /// let segment = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))!
    ///     .trimmed(from: 3, to: 8)!
    ///
    /// let inside = segment.projectPoint(SIMD3(5, 2, 0))
    /// #expect(inside.parameter == 5)         // the perpendicular foot
    /// #expect(inside.distance == 2)
    ///
    /// let beyond = segment.projectPoint(SIMD3(100, 0, 0))
    /// #expect(beyond.parameter == 8)         // the end of the curve, not of its basis line
    /// #expect(beyond.distance == 92)
    /// ```
    ///
    /// Before #539 this projected onto the curve's *underlying basis* curve, so the point above came
    /// back at parameter 100, distance 0 — a `distance < tolerance` proximity test read a point 92
    /// units away as lying on the curve.
    ///
    /// - Parameters:
    ///   - point: 3D point to project
    ///   - precision: Projection precision (default: 1e-6)
    /// - Returns: Projection result with distance, parameter, and projected point
    public func projectPoint(_ point: SIMD3<Double>, precision: Double = 1e-6) -> PointProjection {
        let result = OCCTCurve3DProjectPoint(handle, point.x, point.y, point.z, precision)
        return PointProjection(
            distance: result.distance,
            parameter: result.parameter,
            point: SIMD3(result.projX, result.projY, result.projZ)
        )
    }

    /// Shortest distance from a 3D point to this curve.
    ///
    /// Convenience one-liner around ``projectPoint(_:precision:)`` when you only need the scalar
    /// distance and don't care about the projected point or parameter, so it measures to the same
    /// nearest point: over this curve's own ``domain``, ends included.
    ///
    /// ```swift
    /// let arc = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
    ///     .trimmed(from: 0, to: .pi)!
    ///
    /// // On the full circle, but not on this half of it: 4.47 from the arc's start.
    /// #expect(abs(arc.distance(to: SIMD3(3, -4, 0)) - 4.47214) < 1e-5)
    /// ```
    public func distance(to point: SIMD3<Double>, precision: Double = 1e-6) -> Double {
        projectPoint(point, precision: precision).distance
    }

    /// Result of validating a curve parameter range
    public struct ValidatedRange: Sendable {
        /// Validated first parameter
        public let first: Double
        /// Validated last parameter
        public let last: Double
        /// Whether the range was adjusted
        public let wasAdjusted: Bool
    }

    /// Validate and optionally adjust a parameter range for this curve.
    ///
    /// Uses ShapeAnalysis_Curve::ValidateRange to ensure the range
    /// falls within the curve's actual parametric domain.
    ///
    /// - Parameters:
    ///   - first: Desired first parameter
    ///   - last: Desired last parameter
    ///   - precision: Tolerance (default: 1e-6)
    /// - Returns: Validated range (potentially adjusted)
    public func validateRange(first: Double, last: Double, precision: Double = 1e-6) -> ValidatedRange {
        let result = OCCTCurve3DValidateRange(handle, first, last, precision)
        return ValidatedRange(first: result.first, last: result.last, wasAdjusted: result.wasAdjusted)
    }

    /// Get sample points along this curve.
    ///
    /// Uses ShapeAnalysis_Curve::GetSamplePoints to generate points
    /// distributed along the curve between the given parameters.
    ///
    /// - Parameters:
    ///   - first: Start parameter
    ///   - last: End parameter
    ///   - maxPoints: Output *capacity* (default: 1000), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#558).
    /// - Returns: Array of 3D sample points
    public func samplePoints(first: Double, last: Double, maxPoints: Int = 1000) -> [SIMD3<Double>] {
        let capacity = Sampling.capacity(maxPoints)
        guard capacity > 0 else { return [] }
        var buffer = [Double](repeating: 0, count: capacity * 3)
        let count = OCCTCurve3DGetSamplePoints3D(handle, first, last, &buffer, Int32(capacity))
        return unpackSIMD3(buffer, count: Int(count))
    }

    // MARK: - v0.50.0: Arc construction, periodic conversion, splitting

    /// Create an arc of a hyperbola between two parameter values.
    ///
    /// - Parameters:
    ///   - center: Center of the hyperbola
    ///   - direction: Normal direction of the plane containing the hyperbola
    ///   - majorRadius: Major radius (a) of the hyperbola
    ///   - minorRadius: Minor radius (b) of the hyperbola
    ///   - alpha1: Start parameter value
    ///   - alpha2: End parameter value
    ///   - sense: Direction of parameterization (true = natural)
    /// - Returns: Trimmed curve representing the arc, or `nil` on failure, including when either
    ///   radius is `<= 0`.
    ///
    /// Both radii must be `> 0`. Unlike an ellipse there is no ordering constraint between them:
    /// a minor radius larger than the major is an ordinary hyperbola.
    ///
    /// ```swift
    /// let arc = Curve3D.arcOfHyperbola(majorRadius: 8, minorRadius: 3, alpha1: 0, alpha2: 1)
    /// #expect(arc != nil)
    /// #expect(Curve3D.arcOfHyperbola(majorRadius: 8, minorRadius: 0,
    ///                                alpha1: 0, alpha2: 1) == nil)
    /// ```
    public static func arcOfHyperbola(
        center: SIMD3<Double> = .zero,
        direction: SIMD3<Double> = SIMD3(0, 0, 1),
        majorRadius: Double,
        minorRadius: Double,
        alpha1: Double,
        alpha2: Double,
        sense: Bool = true
    ) -> Curve3D? {
        guard let ref = OCCTCurve3DArcOfHyperbola(
            majorRadius, minorRadius,
            center.x, center.y, center.z,
            direction.x, direction.y, direction.z,
            alpha1, alpha2, sense) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create an arc of a parabola between two parameter values.
    ///
    /// - Parameters:
    ///   - center: Center (vertex) of the parabola
    ///   - direction: Normal direction of the plane containing the parabola
    ///   - focalDistance: Focal distance of the parabola
    ///   - alpha1: Start parameter value
    ///   - alpha2: End parameter value
    ///   - sense: Direction of parameterization (true = natural)
    /// - Returns: Trimmed curve representing the arc, or `nil` on failure, including when
    ///   `focalDistance` is `<= 0`.
    ///
    /// `focalDistance` must be `> 0`. At zero the parabola degenerates to a straight line along
    /// its own axis of symmetry, which is `gp_Parab`'s documented behaviour rather than an error
    /// it reports, so the arc would build and read as a curve.
    ///
    /// ```swift
    /// let arc = Curve3D.arcOfParabola(focalDistance: 4, alpha1: 0, alpha2: 1)
    /// #expect(arc != nil)
    /// #expect(Curve3D.arcOfParabola(focalDistance: 0, alpha1: 0, alpha2: 1) == nil)
    /// ```
    public static func arcOfParabola(
        center: SIMD3<Double> = .zero,
        direction: SIMD3<Double> = SIMD3(0, 0, 1),
        focalDistance: Double,
        alpha1: Double,
        alpha2: Double,
        sense: Bool = true
    ) -> Curve3D? {
        guard let ref = OCCTCurve3DArcOfParabola(
            focalDistance,
            center.x, center.y, center.z,
            direction.x, direction.y, direction.z,
            alpha1, alpha2, sense) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Convert a closed BSpline curve to periodic form.
    ///
    /// The curve must be closed (first point == last point). The result is a periodic
    /// BSpline curve that seamlessly wraps around.
    ///
    /// - Returns: Periodic curve, or nil if conversion is not possible
    public func convertToPeriodic() -> Curve3D? {
        guard let ref = OCCTCurve3DConvertToPeriodic(handle) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Split result containing the two curve segments.
    public struct SplitResult {
        /// First segment (before split parameter)
        public let first: Curve3D
        /// Second segment (after split parameter)
        public let second: Curve3D
    }

    /// Split this curve at a parameter value into two segments.
    ///
    /// - Parameter parameter: Parameter value at which to split
    /// - Returns: Two curve segments, or nil if split fails
    public func splitAt(parameter: Double) -> SplitResult? {
        var ref1: OCCTCurve3DRef?
        var ref2: OCCTCurve3DRef?
        guard OCCTCurve3DSplitAt(handle, parameter, &ref1, &ref2),
              let r1 = ref1, let r2 = ref2 else { return nil }
        return SplitResult(first: Curve3D(handle: r1), second: Curve3D(handle: r2))
    }

    // MARK: - v0.51.0: GC_MakeEllipse/Hyperbola three-point constructors

    /// Create an ellipse defined by three points.
    ///
    /// - Parameters:
    ///   - s1: End point of the major axis
    ///   - s2: Point defining the minor axis extent
    ///   - center: Center of the ellipse
    /// - Returns: Ellipse curve, or nil on failure
    public static func ellipseThreePoints(
        s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>
    ) -> Curve3D? {
        guard let h = OCCTCurve3DMakeEllipseThreePoints(
            s1.x, s1.y, s1.z, s2.x, s2.y, s2.z,
            center.x, center.y, center.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Create a hyperbola defined by three points.
    ///
    /// - Parameters:
    ///   - s1: End point of the major axis
    ///   - s2: Point defining the minor axis extent
    ///   - center: Center of the hyperbola
    /// - Returns: Hyperbola curve, or nil on failure
    public static func hyperbolaThreePoints(
        s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>
    ) -> Curve3D? {
        guard let h = OCCTCurve3DMakeHyperbolaThreePoints(
            s1.x, s1.y, s1.z, s2.x, s2.y, s2.z,
            center.x, center.y, center.z) else { return nil }
        return Curve3D(handle: h)
    }

    // MARK: - LocalAnalysis

    /// Result of curve continuity analysis at a junction point.
    public struct ContinuityAnalysis: Sendable {
        /// The order the junction was actually analysed at: the requested ``ContinuityClass``
        /// after saturation at ``ContinuityClass/c2``.
        ///
        /// This is the request, not a finding. `LocalAnalysis_CurveContinuity::ContinuityStatus()`
        /// returns the order it was constructed with verbatim, so the only thing it can tell you
        /// is where a saturated request landed. The findings are ``measured`` and ``holds(_:)``.
        public let order: ContinuityClass
        /// The continuity classes this ``order`` actually measured.
        ///
        /// Each order computes only its own branch — `.c0` measures C0; `.g1` measures C0 and G1;
        /// `.c1` measures C0 and C1; `.g2` measures C0, G1 and G2; `.c2` measures C0, C1 and C2.
        /// No order measures all five, not even the `.c2` default, which never looks at G1 or G2.
        public let measured: Set<ContinuityClass>
        /// Distance between curve endpoints at junction
        public let c0Value: Double
        /// Angle between tangents (radians), or -1 if G1 was not measured or does not hold
        public let g1Angle: Double
        /// Angle between first derivatives, or -1
        public let c1Angle: Double
        /// Ratio of first derivative magnitudes, or -1
        public let c1Ratio: Double
        /// Angle between second derivatives, or -1
        public let c2Angle: Double
        /// Ratio of second derivative magnitudes, or -1
        public let c2Ratio: Double
        /// Angle between osculating planes, or -1
        public let g2Angle: Double
        /// Variation of curvature at junction, or -1
        public let g2CurvatureVariation: Double
        /// Bitmask of the classes that hold: bit0=C0, bit1=G1, bit2=C1, bit3=G2, bit4=C2.
        ///
        /// Only ever sets bits for classes in ``measured``, so a clear bit means "does not hold
        /// *or* was not measured". Prefer ``holds(_:)``, which separates the two.
        public let flags: Int

        /// Whether `continuity` holds at the junction, or `nil` if this ``order`` never measured
        /// it.
        ///
        /// ```swift
        /// let a = corner.continuityWith(other, u1: e1, u2: s2, order: .c1)!
        /// a.holds(.c1)   // false — measured, and the junction is not C1
        /// a.holds(.g1)   // nil   — order .c1 never computes G1
        /// ```
        ///
        /// - Note: This asks *exact-class membership* — "did this analysis report this one
        ///   class?" — not a floor. It never infers one class from another, so a `true` for
        ///   ``ContinuityClass/g2`` implies nothing about ``ContinuityClass/c1``. To test a
        ///   *measured* class against a continuity floor instead, use
        ///   ``ContinuityClass/satisfies(_:)``; to rank two measured classes, compare them with
        ///   `<`/`>=`. Three different questions (#623).
        public func holds(_ continuity: ContinuityClass) -> Bool? {
            guard measured.contains(continuity) else { return nil }
            return flags & continuity.analysisFlagBit != 0
        }

        /// Whether the junction is positionally continuous (C0). Always measured.
        public var isC0: Bool? { holds(.c0) }
        /// Whether the junction is geometrically tangent-continuous (G1), or nil if ``order``
        /// did not measure G1 (only `.g1` and `.g2` do).
        public var isG1: Bool? { holds(.g1) }
        /// Whether the junction is parametrically tangent-continuous (C1), or nil if ``order``
        /// did not measure C1 (only `.c1` and `.c2` do).
        public var isC1: Bool? { holds(.c1) }
        /// Whether the junction is geometrically curvature-continuous (G2), or nil if ``order``
        /// was not `.g2`.
        public var isG2: Bool? { holds(.g2) }
        /// Whether the junction is parametrically curvature-continuous (C2), or nil if ``order``
        /// was not `.c2`.
        public var isC2: Bool? { holds(.c2) }

    }

    /// Analyze continuity between this curve at parameter `u1` and another curve at `u2`.
    ///
    /// ```swift
    /// // Is this junction tangent-continuous? Ask for G1 — the .c2 default never measures it.
    /// let a = leftArc.continuityWith(rightArc, u1: leftArc.domain.upperBound,
    ///                                u2: rightArc.domain.lowerBound, order: .g1)
    /// if a?.holds(.g1) == true { print("tangent, angle \(a!.g1Angle)") }
    /// ```
    ///
    /// - Parameters:
    ///   - u1: Parameter on this curve
    ///   - other: Second curve
    ///   - u2: Parameter on second curve
    ///   - order: Which continuity class to measure. This selects the analysis, not just a
    ///     ceiling: `LocalAnalysis_CurveContinuity` computes one branch of a switch, so the
    ///     classes outside it are never measured and ``ContinuityAnalysis/holds(_:)`` reports
    ///     `nil` for them. `.c2` is the strictest question the class can answer — it implements
    ///     no predicate above C2/G2 — so `.c3` and `.cN` saturate to `.c2`, which
    ///     ``ContinuityAnalysis/order`` reports back.
    /// - Returns: Continuity analysis result, or nil on failure
    public func continuityWith(_ other: Curve3D, u1: Double, u2: Double,
                               order: ContinuityClass = .c2) -> ContinuityAnalysis? {
        continuityAnalysis(with: other, u1: u1, u2: u2, rawOrder: order.rawValue)
    }

    private func continuityAnalysis(with other: Curve3D, u1: Double, u2: Double,
                                    rawOrder: Int32) -> ContinuityAnalysis? {
        var outEffectiveOrder: Int32 = 0
        var outC0: Double = 0, outG1: Double = 0
        var outC1A: Double = 0, outC1R: Double = 0
        var outC2A: Double = 0, outC2R: Double = 0
        var outG2A: Double = 0, outG2CV: Double = 0
        let ok = OCCTLocalAnalysisCurveContinuity(
            handle, u1, other.handle, u2, rawOrder,
            &outEffectiveOrder, &outC0, &outG1, &outC1A, &outC1R,
            &outC2A, &outC2R, &outG2A, &outG2CV)
        guard ok else { return nil }
        var outMeasured: Int32 = 0
        let flags = Int(OCCTLocalAnalysisCurveContinuityFlags(
            handle, u1, other.handle, u2, rawOrder, &outMeasured))
        return ContinuityAnalysis(
            order: ContinuityClass(rawValue: outEffectiveOrder) ?? .c2,
            measured: ContinuityClass.set(fromAnalysisMask: outMeasured),
            c0Value: outC0, g1Angle: outG1,
            c1Angle: outC1A, c1Ratio: outC1R,
            c2Angle: outC2A, c2Ratio: outC2R,
            g2Angle: outG2A, g2CurvatureVariation: outG2CV,
            flags: flags)
    }

    // MARK: - v0.80.0: Extrema, ProjLib, gce factories

    /// Result of curve-to-curve extrema computation
    public struct CurveCurveExtrema: Sendable {
        public let isDone: Bool
        public let isParallel: Bool
        public let count: Int
    }

    /// A point pair from an extrema result
    public struct ExtremaPointPair: Sendable {
        public let squareDistance: Double
        public let point1: SIMD3<Double>
        public let param1: Double
        public let point2: SIMD3<Double>
        public let param2: Double
    }

    /// Compute curve-to-curve extrema (closest/farthest distances)
    public func extremaCC(range1: ClosedRange<Double>? = nil,
                          other: Curve3D,
                          range2: ClosedRange<Double>? = nil) -> CurveCurveExtrema {
        let d1 = range1 ?? domain
        let d2 = range2 ?? other.domain
        let r = OCCTExtremaExtCC(handle, d1.lowerBound, d1.upperBound,
                                  other.handle, d2.lowerBound, d2.upperBound)
        return CurveCurveExtrema(isDone: r.isDone, isParallel: r.isParallel, count: Int(r.nbExt))
    }

    /// Get Nth extremum point pair from curve-curve computation (1-based)
    public func extremaCCPoint(range1: ClosedRange<Double>? = nil,
                               other: Curve3D,
                               range2: ClosedRange<Double>? = nil,
                               index: Int) -> ExtremaPointPair {
        let d1 = range1 ?? domain
        let d2 = range2 ?? other.domain
        let r = OCCTExtremaExtCCPoint(handle, d1.lowerBound, d1.upperBound,
                                       other.handle, d2.lowerBound, d2.upperBound,
                                       Int32(index))
        return ExtremaPointPair(squareDistance: r.squareDistance,
                                point1: SIMD3(r.x1, r.y1, r.z1), param1: r.param1,
                                point2: SIMD3(r.x2, r.y2, r.z2), param2: r.param2)
    }

    /// Result of local curve-curve extrema search
    public struct LocalExtremaResult: Sendable {
        public let isDone: Bool
        public let squareDistance: Double
        public let point1: SIMD3<Double>
        public let param1: Double
        public let point2: SIMD3<Double>
        public let param2: Double
    }

    /// Find local curve-curve extremum near seed parameters
    public func locateExtremaCC(range1: ClosedRange<Double>? = nil,
                                other: Curve3D,
                                range2: ClosedRange<Double>? = nil,
                                seedU: Double, seedV: Double) -> LocalExtremaResult {
        let d1 = range1 ?? domain
        let d2 = range2 ?? other.domain
        let r = OCCTExtremaLocateExtCC(handle, d1.lowerBound, d1.upperBound,
                                        other.handle, d2.lowerBound, d2.upperBound,
                                        seedU, seedV)
        return LocalExtremaResult(isDone: r.isDone, squareDistance: r.squareDistance,
                                  point1: SIMD3(r.x1, r.y1, r.z1), param1: r.param1,
                                  point2: SIMD3(r.x2, r.y2, r.z2), param2: r.param2)
    }

    /// Result of curve-to-surface extrema
    public struct CurveSurfaceExtrema: Sendable {
        public let isDone: Bool
        public let isParallel: Bool
        public let count: Int
    }

    /// Compute curve-to-surface extrema
    public func extremaCS(range: ClosedRange<Double>? = nil,
                          surface: Surface) -> CurveSurfaceExtrema {
        let d = range ?? domain
        let r = OCCTExtremaExtCS(handle, d.lowerBound, d.upperBound, surface.handle)
        return CurveSurfaceExtrema(isDone: r.isDone, isParallel: r.isParallel, count: Int(r.nbExt))
    }

    /// Get Nth extremum from curve-surface computation
    public func extremaCSPoint(range: ClosedRange<Double>? = nil,
                               surface: Surface,
                               index: Int) -> ExtremaPointPair {
        let d = range ?? domain
        let r = OCCTExtremaExtCSPoint(handle, d.lowerBound, d.upperBound,
                                       surface.handle, Int32(index))
        return ExtremaPointPair(squareDistance: r.squareDistance,
                                point1: SIMD3(r.x1, r.y1, r.z1), param1: r.param1,
                                point2: SIMD3(r.x2, r.y2, r.z2), param2: r.param2)
    }

    /// Project this curve onto a surface, returning BSpline approximation
    public func projectOnSurface(_ surface: Surface, range: ClosedRange<Double>? = nil,
                                 tolerance: Double = 1e-3) -> Curve3D? {
        let d = range ?? domain
        guard let h = OCCTProjLibProjectOnSurface(handle, d.lowerBound, d.upperBound,
                                                   surface.handle, tolerance) else { return nil }
        return Curve3D(handle: h)
    }

    /// Create a circle through 3 points (gce_MakeCirc)
    public static func circleThrough3Points(_ p1: SIMD3<Double>, _ p2: SIMD3<Double>,
                                            _ p3: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTGceMakeCircFrom3Points(p1.x, p1.y, p1.z,
                                                  p2.x, p2.y, p2.z,
                                                  p3.x, p3.y, p3.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Create a circle from center, normal, and radius (`gce_MakeCirc`).
    ///
    /// Geometrically identical to `circle(center:normal:radius:)` — `gce_MakeCirc` builds the
    /// same `gp_Ax2(center, normal)` frame — and, since #399, enforces the same radius contract.
    ///
    /// - Parameters:
    ///   - center: Circle centre.
    ///   - normal: Normal of the plane the circle lies in.
    ///   - radius: Circle radius. Must be `> 0`; zero and negative radii return `nil`.
    /// - Returns: The circle, or `nil` if `radius <= 0`.
    ///
    /// ```swift
    /// let c = Curve3D.circleFromCenterNormal(center: .zero, normal: SIMD3(0, 0, 1), radius: 7)
    /// #expect(c != nil)
    /// // Same rejection as the direct factory: no degenerate zero-radius circle.
    /// #expect(Curve3D.circleFromCenterNormal(center: .zero, normal: SIMD3(0, 0, 1),
    ///                                        radius: 0) == nil)
    /// ```
    public static func circleFromCenterNormal(center: SIMD3<Double>, normal: SIMD3<Double>,
                                              radius: Double) -> Curve3D? {
        guard let h = OCCTGceMakeCircFromCenterNormal(center.x, center.y, center.z,
                                                       normal.x, normal.y, normal.z,
                                                       radius) else { return nil }
        return Curve3D(handle: h)
    }

    /// Create a line from 2 points (gce_MakeLin)
    public static func lineFrom2Points(_ p1: SIMD3<Double>, _ p2: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTGceMakeLinFrom2Points(p1.x, p1.y, p1.z,
                                                 p2.x, p2.y, p2.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Create a direction from 2 points (gce_MakeDir)
    public static func directionFrom2Points(_ p1: SIMD3<Double>,
                                            _ p2: SIMD3<Double>) -> SIMD3<Double>? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTGceMakeDir(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Create an ellipse (`gce_MakeElips`).
    ///
    /// Geometrically identical to `ellipse(center:normal:majorRadius:minorRadius:)` and, since
    /// #399, enforces the same radius contract.
    ///
    /// - Parameters:
    ///   - center: Ellipse centre.
    ///   - normal: Normal of the plane the ellipse lies in.
    ///   - majorRadius: Major radius. Must be `> 0` and `>= minorRadius`.
    ///   - minorRadius: Minor radius. Must be `> 0`.
    /// - Returns: The ellipse, or `nil` if the radii violate that contract.
    ///
    /// ```swift
    /// let e = Curve3D.ellipseFromCenterNormal(center: .zero, normal: SIMD3(0, 0, 1),
    ///                                         majorRadius: 10, minorRadius: 5)
    /// #expect(e != nil)
    /// #expect(Curve3D.ellipseFromCenterNormal(center: .zero, normal: SIMD3(0, 0, 1),
    ///                                         majorRadius: 10, minorRadius: 0) == nil)
    /// ```
    public static func ellipseFromCenterNormal(center: SIMD3<Double>, normal: SIMD3<Double>,
                                               majorRadius: Double,
                                               minorRadius: Double) -> Curve3D? {
        guard let h = OCCTGceMakeElips(center.x, center.y, center.z,
                                        normal.x, normal.y, normal.z,
                                        majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: h)
    }

    /// Create a hyperbola (`gce_MakeHypr`).
    ///
    /// Geometrically identical to `hyperbola(center:normal:majorRadius:minorRadius:)` and, since
    /// #399, enforces the same radius contract.
    ///
    /// - Parameters:
    ///   - center: Hyperbola centre.
    ///   - normal: Normal of the plane the hyperbola lies in.
    ///   - majorRadius: Major radius. Must be `> 0`.
    ///   - minorRadius: Minor radius. Must be `> 0`.
    /// - Returns: The hyperbola, or `nil` if either radius is `<= 0`.
    ///
    /// ```swift
    /// let h = Curve3D.hyperbolaFromCenterNormal(center: .zero, normal: SIMD3(0, 0, 1),
    ///                                           majorRadius: 8, minorRadius: 3)
    /// #expect(h != nil)
    /// #expect(Curve3D.hyperbolaFromCenterNormal(center: .zero, normal: SIMD3(0, 0, 1),
    ///                                           majorRadius: 8, minorRadius: 0) == nil)
    /// ```
    public static func hyperbolaFromCenterNormal(center: SIMD3<Double>, normal: SIMD3<Double>,
                                                 majorRadius: Double,
                                                 minorRadius: Double) -> Curve3D? {
        guard let h = OCCTGceMakeHypr(center.x, center.y, center.z,
                                       normal.x, normal.y, normal.z,
                                       majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: h)
    }

    /// Create a parabola (`gce_MakeParab`).
    ///
    /// Geometrically identical to `parabola(center:normal:focal:)` and, since #399, enforces the
    /// same focal-length contract.
    ///
    /// - Parameters:
    ///   - center: Parabola apex.
    ///   - normal: Normal of the plane the parabola lies in.
    ///   - focal: Focal length. Must be `> 0`; zero and negative focal lengths return `nil`.
    /// - Returns: The parabola, or `nil` if `focal <= 0`.
    ///
    /// ```swift
    /// let p = Curve3D.parabolaFromCenterNormal(center: .zero, normal: SIMD3(0, 0, 1), focal: 4)
    /// #expect(p != nil)
    /// #expect(Curve3D.parabolaFromCenterNormal(center: .zero, normal: SIMD3(0, 0, 1),
    ///                                          focal: 0) == nil)
    /// ```
    public static func parabolaFromCenterNormal(center: SIMD3<Double>, normal: SIMD3<Double>,
                                                focal: Double) -> Curve3D? {
        guard let h = OCCTGceMakeParab(center.x, center.y, center.z,
                                        normal.x, normal.y, normal.z,
                                        focal) else { return nil }
        return Curve3D(handle: h)
    }

    /// Serialize curves to string via GeomTools_CurveSet
    public static func serializeCurves(_ curves: [Curve3D]) -> String? {
        let handles = curves.map { $0.handle as OCCTCurve3DRef }
        guard let cStr = handles.withUnsafeBufferPointer({
            OCCTGeomToolsCurveSetWrite($0.baseAddress!, Int32(curves.count))
        }) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(cStr)
        return result
    }

    /// Deserialize curves from string via GeomTools_CurveSet
    public static func deserializeCurves(_ data: String) -> [Curve3D]? {
        var count: Int32 = 0
        guard let arr = OCCTGeomToolsCurveSetRead(data, &count), count > 0 else { return nil }
        var curves: [Curve3D] = []
        for i in 0..<Int(count) {
            if let h = arr[i] {
                curves.append(Curve3D(handle: h))
            }
        }
        free(arr)
        return curves.isEmpty ? nil : curves
    }

    // MARK: - Geom_Circle Properties (v0.108.0)

    /// Access circle-specific properties. Returns meaningful values only if the underlying curve is a Geom_Circle.
    public struct CircleProperties: @unchecked Sendable {
        fileprivate let handle: OCCTCurve3DRef

        /// The radius of the circle.
        public var radius: Double { OCCTCurve3DCircleRadius(handle) }

        /// Set the radius of the circle.
        ///
        /// - Parameter r: New radius. Must be `> 0`; zero collapses the circle onto its centre.
        /// - Returns: `true` if the radius was written, `false` if the curve is not a circle or
        ///   `r` is not a valid radius. On `false` the curve is left as it was.
        ///
        /// ```swift
        /// if let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) {
        ///     #expect(c.circleProperties.setRadius(8) == true)
        ///     #expect(c.circleProperties.setRadius(0) == false)
        /// }
        /// ```
        @discardableResult
        public func setRadius(_ r: Double) -> Bool { OCCTCurve3DCircleSetRadius(handle, r) }

        /// The eccentricity (always 0 for a circle).
        public var eccentricity: Double { OCCTCurve3DCircleEccentricity(handle) }

        /// The center point of the circle.
        public var center: SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DCircleCenter(handle, &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// The X axis of the circle (position + direction).
        public var xAxis: (position: SIMD3<Double>, direction: SIMD3<Double>) {
            var px = 0.0, py = 0.0, pz = 0.0, dx = 0.0, dy = 0.0, dz = 0.0
            OCCTCurve3DCircleXAxis(handle, &px, &py, &pz, &dx, &dy, &dz)
            return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
        }

        /// The Y axis of the circle (position + direction).
        public var yAxis: (position: SIMD3<Double>, direction: SIMD3<Double>) {
            var px = 0.0, py = 0.0, pz = 0.0, dx = 0.0, dy = 0.0, dz = 0.0
            OCCTCurve3DCircleYAxis(handle, &px, &py, &pz, &dx, &dy, &dz)
            return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
        }
    }

    /// Circle-specific properties (meaningful only when the underlying curve is a Geom_Circle).
    public var circleProperties: CircleProperties { CircleProperties(handle: handle) }

    // MARK: - Geom_Ellipse Properties (v0.108.0)

    /// Access ellipse-specific properties. Returns meaningful values only if the underlying curve is a Geom_Ellipse.
    public struct EllipseProperties: @unchecked Sendable {
        fileprivate let handle: OCCTCurve3DRef

        /// The major radius.
        public var majorRadius: Double { OCCTCurve3DEllipseMajorRadius(handle) }

        /// The minor radius.
        public var minorRadius: Double { OCCTCurve3DEllipseMinorRadius(handle) }

        /// Set the major radius.
        ///
        /// - Parameter r: New major radius. Judged against the minor radius already on the
        ///   curve, so it must be `> 0` and no smaller than the current `minorRadius`.
        /// - Returns: `true` if the radius was written, `false` if the curve is not an ellipse or
        ///   the pair would not describe one. On `false` the curve is left as it was.
        ///
        /// ```swift
        /// if let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
        ///                            majorRadius: 10, minorRadius: 5) {
        ///     #expect(e.ellipseProperties.setMajorRadius(12) == true)
        ///     #expect(e.ellipseProperties.setMajorRadius(3) == false)  // below the minor
        /// }
        /// ```
        @discardableResult
        public func setMajorRadius(_ r: Double) -> Bool { OCCTCurve3DEllipseSetMajorRadius(handle, r) }

        /// Set the minor radius.
        ///
        /// - Parameter r: New minor radius. Judged against the major radius already on the curve,
        ///   so it must be `> 0` and no larger than the current `majorRadius`.
        /// - Returns: `true` if the radius was written, `false` if the curve is not an ellipse or
        ///   the pair would not describe one. On `false` the curve is left as it was.
        ///
        /// Zero is rejected here as it is at construction: it would leave a live `Geom_Ellipse`
        /// that evaluates onto its own major axis at every parameter.
        ///
        /// ```swift
        /// if let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
        ///                            majorRadius: 10, minorRadius: 5) {
        ///     #expect(e.ellipseProperties.setMinorRadius(3) == true)
        ///     #expect(e.ellipseProperties.setMinorRadius(0) == false)
        /// }
        /// ```
        @discardableResult
        public func setMinorRadius(_ r: Double) -> Bool { OCCTCurve3DEllipseSetMinorRadius(handle, r) }

        /// The eccentricity (0 < e < 1 for an ellipse).
        public var eccentricity: Double { OCCTCurve3DEllipseEccentricity(handle) }

        /// The focal distance (2c, distance between foci).
        public var focal: Double { OCCTCurve3DEllipseFocal(handle) }

        /// The first focus.
        public var focus1: SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DEllipseFocus1(handle, &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// The second focus.
        public var focus2: SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DEllipseFocus2(handle, &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// The semi-latus rectum (parameter).
        public var parameter: Double { OCCTCurve3DEllipseParameter(handle) }

        /// The first directrix (position + direction).
        public var directrix1: (position: SIMD3<Double>, direction: SIMD3<Double>) {
            var px = 0.0, py = 0.0, pz = 0.0, dx = 0.0, dy = 0.0, dz = 0.0
            OCCTCurve3DEllipseDirectrix1(handle, &px, &py, &pz, &dx, &dy, &dz)
            return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
        }
    }

    /// Ellipse-specific properties (meaningful only when the underlying curve is a Geom_Ellipse).
    public var ellipseProperties: EllipseProperties { EllipseProperties(handle: handle) }

    // MARK: - Geom_Hyperbola Properties (v0.108.0)

    /// Access hyperbola-specific properties. Returns meaningful values only if the underlying curve is a Geom_Hyperbola.
    public struct HyperbolaProperties: @unchecked Sendable {
        fileprivate let handle: OCCTCurve3DRef

        /// The major radius (real semi-axis).
        public var majorRadius: Double { OCCTCurve3DHyperbolaMajorRadius(handle) }

        /// The minor radius (imaginary semi-axis).
        public var minorRadius: Double { OCCTCurve3DHyperbolaMinorRadius(handle) }

        /// Set the major radius.
        ///
        /// - Parameter r: New major radius. Must be `> 0`. Unlike an ellipse there is no ordering
        ///   constraint against the minor radius.
        /// - Returns: `true` if the radius was written, `false` if the curve is not a hyperbola or
        ///   `r` is not a valid radius. On `false` the curve is left as it was.
        ///
        /// ```swift
        /// if let h = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
        ///                              majorRadius: 8, minorRadius: 3) {
        ///     #expect(h.hyperbolaProperties.setMajorRadius(7) == true)
        ///     #expect(h.hyperbolaProperties.setMajorRadius(0) == false)
        /// }
        /// ```
        @discardableResult
        public func setMajorRadius(_ r: Double) -> Bool { OCCTCurve3DHyperbolaSetMajorRadius(handle, r) }

        /// Set the minor radius.
        ///
        /// - Parameter r: New minor radius. Must be `> 0`; it may exceed the major radius.
        /// - Returns: `true` if the radius was written, `false` if the curve is not a hyperbola or
        ///   `r` is not a valid radius. On `false` the curve is left as it was.
        ///
        /// ```swift
        /// if let h = Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
        ///                              majorRadius: 8, minorRadius: 3) {
        ///     #expect(h.hyperbolaProperties.setMinorRadius(4) == true)
        ///     #expect(h.hyperbolaProperties.setMinorRadius(0) == false)
        /// }
        /// ```
        @discardableResult
        public func setMinorRadius(_ r: Double) -> Bool { OCCTCurve3DHyperbolaSetMinorRadius(handle, r) }

        /// The eccentricity (e > 1 for a hyperbola).
        public var eccentricity: Double { OCCTCurve3DHyperbolaEccentricity(handle) }

        /// The focal distance.
        public var focal: Double { OCCTCurve3DHyperbolaFocal(handle) }

        /// The first focus.
        public var focus1: SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DHyperbolaFocus1(handle, &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// The first asymptote (position + direction).
        public var asymptote1: (position: SIMD3<Double>, direction: SIMD3<Double>) {
            var px = 0.0, py = 0.0, pz = 0.0, dx = 0.0, dy = 0.0, dz = 0.0
            OCCTCurve3DHyperbolaAsymptote1(handle, &px, &py, &pz, &dx, &dy, &dz)
            return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
        }
    }

    /// Hyperbola-specific properties (meaningful only when the underlying curve is a Geom_Hyperbola).
    public var hyperbolaProperties: HyperbolaProperties { HyperbolaProperties(handle: handle) }

    // MARK: - Geom_Parabola Properties (v0.108.0)

    /// Access parabola-specific properties. Returns meaningful values only if the underlying curve is a Geom_Parabola.
    public struct ParabolaProperties: @unchecked Sendable {
        fileprivate let handle: OCCTCurve3DRef

        /// The focal distance.
        public var focal: Double { OCCTCurve3DParabolaFocal(handle) }

        /// Set the focal distance.
        ///
        /// - Parameter f: New focal distance. Must be `> 0`; at zero the parabola degenerates to
        ///   a straight line along its own axis of symmetry.
        /// - Returns: `true` if the value was written, `false` if the curve is not a parabola or
        ///   `f` is not a valid focal distance. On `false` the curve is left as it was.
        ///
        /// ```swift
        /// if let p = Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1), focal: 4) {
        ///     #expect(p.parabolaProperties.setFocal(5) == true)
        ///     #expect(p.parabolaProperties.setFocal(0) == false)
        /// }
        /// ```
        @discardableResult
        public func setFocal(_ f: Double) -> Bool { OCCTCurve3DParabolaSetFocal(handle, f) }

        /// The focus point.
        public var focus: SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DParabolaFocus(handle, &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// The eccentricity (always 1 for a parabola).
        public var eccentricity: Double { OCCTCurve3DParabolaEccentricity(handle) }

        /// The parameter (2 * focal).
        public var parameter: Double { OCCTCurve3DParabolaParameter(handle) }

        /// The directrix (position + direction).
        public var directrix: (position: SIMD3<Double>, direction: SIMD3<Double>) {
            var px = 0.0, py = 0.0, pz = 0.0, dx = 0.0, dy = 0.0, dz = 0.0
            OCCTCurve3DParabolaDirectrix(handle, &px, &py, &pz, &dx, &dy, &dz)
            return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
        }
    }

    /// Parabola-specific properties (meaningful only when the underlying curve is a Geom_Parabola).
    public var parabolaProperties: ParabolaProperties { ParabolaProperties(handle: handle) }

    // MARK: - Geom_Line Properties (v0.108.0)

    /// Access line-specific properties. Returns meaningful values only if the underlying curve is a Geom_Line.
    public struct LineProperties: @unchecked Sendable {
        fileprivate let handle: OCCTCurve3DRef

        /// The direction of the line.
        public var direction: SIMD3<Double> {
            var dx = 0.0, dy = 0.0, dz = 0.0
            OCCTCurve3DLineDirection(handle, &dx, &dy, &dz)
            return SIMD3(dx, dy, dz)
        }

        /// The location (origin point) of the line.
        public var location: SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DLineLocation(handle, &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// Set the direction of the line.
        @discardableResult
        public func setDirection(_ d: SIMD3<Double>) -> Bool {
            OCCTCurve3DLineSetDirection(handle, d.x, d.y, d.z)
        }

        /// Set the location of the line.
        @discardableResult
        public func setLocation(_ p: SIMD3<Double>) -> Bool {
            OCCTCurve3DLineSetLocation(handle, p.x, p.y, p.z)
        }

        /// The position axis (location + direction).
        public var position: (location: SIMD3<Double>, direction: SIMD3<Double>) {
            var px = 0.0, py = 0.0, pz = 0.0, dx = 0.0, dy = 0.0, dz = 0.0
            OCCTCurve3DLinePosition(handle, &px, &py, &pz, &dx, &dy, &dz)
            return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
        }

        /// The gp_Lin representation (location + direction).
        public var lin: (location: SIMD3<Double>, direction: SIMD3<Double>) {
            var px = 0.0, py = 0.0, pz = 0.0, dx = 0.0, dy = 0.0, dz = 0.0
            OCCTCurve3DLineLin(handle, &px, &py, &pz, &dx, &dy, &dz)
            return (SIMD3(px, py, pz), SIMD3(dx, dy, dz))
        }
    }

    /// Line-specific properties (meaningful only when the underlying curve is a Geom_Line).
    public var lineProperties: LineProperties { LineProperties(handle: handle) }

    // MARK: - v0.115.0: Interpolation expansion, length, closest point

    /// Interpolate a 3D BSpline with per-point tangent constraints.
    public static func interpolate(points: [SIMD3<Double>],
                                   tangents: [SIMD3<Double>],
                                   tangentFlags: [Bool]) -> Curve3D? {
        guard points.count == tangents.count, points.count == tangentFlags.count else { return nil }
        var flatPts = [Double]()
        for p in points { flatPts.append(contentsOf: [p.x, p.y, p.z]) }
        var flatTans = [Double]()
        for t in tangents { flatTans.append(contentsOf: [t.x, t.y, t.z]) }
        guard let ref = flatPts.withUnsafeBufferPointer({ pBuf in
            flatTans.withUnsafeBufferPointer({ tBuf in
                tangentFlags.withUnsafeBufferPointer({ fBuf in
                    OCCTInterpolateWithAllTangents(pBuf.baseAddress!, Int32(points.count),
                                                   tBuf.baseAddress!, fBuf.baseAddress!)
                })
            })
        }) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Interpolate a 3D BSpline with explicit parameter values.
    public static func interpolate(points: [SIMD3<Double>],
                                   parameters: [Double]) -> Curve3D? {
        guard points.count == parameters.count else { return nil }
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y, p.z]) }
        guard let ref = flat.withUnsafeBufferPointer({ pBuf in
            parameters.withUnsafeBufferPointer({ paramBuf in
                OCCTInterpolateWithParameters(pBuf.baseAddress!, Int32(points.count), paramBuf.baseAddress!)
            })
        }) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Interpolate a periodic (closed) 3D BSpline through points.
    ///
    /// A spelling of `interpolate(points:closed:tolerance:)` with `closed: true`, and it
    /// delegates to it: the two cannot produce different curves for the same input.
    ///
    /// - Parameters:
    ///   - points: Points to interpolate. At least 2; the curve closes back to `points[0]`, so
    ///     do not repeat the first point at the end.
    ///   - tolerance: Interpolation tolerance. Defaults to `1e-6`, which is what this method used
    ///     to hardcode with no way to change it (#493).
    /// - Returns: The periodic curve, or `nil` if interpolation fails.
    ///
    /// ```swift
    /// let loop = Curve3D.interpolatePeriodic(points: [
    ///     SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-1, 0, 0), SIMD3(0, -1, 0),
    /// ])
    /// #expect(loop?.isPeriodic == true)
    ///
    /// // Identical to spelling it out on the general factory:
    /// let same = Curve3D.interpolate(points: [
    ///     SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-1, 0, 0), SIMD3(0, -1, 0),
    /// ], closed: true)
    /// #expect(loop?.domain == same?.domain)
    /// ```
    public static func interpolatePeriodic(points: [SIMD3<Double>],
                                           tolerance: Double = 1e-6) -> Curve3D? {
        interpolate(points: points, closed: true, tolerance: tolerance)
    }

    /// Approximate a 3D BSpline through points with degree and continuity control.
    ///
    /// `continuity` is a ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2, 3=C3). Unlike the
    /// `approximated` family, the fitter accepts every value without failing — it treats the
    /// request as an upper bound on what it will try to achieve.
    public static func approximate(points: [SIMD3<Double>],
                                   degMin: Int = 3, degMax: Int = 8,
                                   continuity: Int = 2, tolerance: Double = 1e-3) -> Curve3D? {
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y, p.z]) }
        guard let ref = flat.withUnsafeBufferPointer({ buf in
            OCCTPointsToBSplineWithParams(buf.baseAddress!, Int32(points.count),
                                          Int32(degMin), Int32(degMax),
                                          Int32(continuity), tolerance)
        }) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Approximate a 3D BSpline with explicit parameter values.
    public static func approximate(points: [SIMD3<Double>],
                                   parameters: [Double],
                                   degMin: Int = 3, degMax: Int = 8,
                                   continuity: Int = 2, tolerance: Double = 1e-3) -> Curve3D? {
        guard points.count == parameters.count else { return nil }
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y, p.z]) }
        guard let ref = flat.withUnsafeBufferPointer({ pBuf in
            parameters.withUnsafeBufferPointer({ paramBuf in
                OCCTPointsToBSplineWithParameters(pBuf.baseAddress!, paramBuf.baseAddress!,
                                                   Int32(points.count),
                                                   Int32(degMin), Int32(degMax),
                                                   Int32(continuity), tolerance)
            })
        }) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Compute the arc length of this curve between parameters u1 and u2 (non-optional).
    ///
    /// Delegates to `length(from:to:)`, the failure-distinguishing entry point. Returns `-1.0`
    /// if a bound is not finite (`.nan`, `±.infinity`) or the underlying computation fails — arc
    /// length is otherwise always non-negative, so this is an unambiguous failure sentinel, never
    /// confusable with a genuine zero-length result (e.g. `u1 == u2`). Use `length(from:to:)`
    /// directly if you need an optional rather than a sentinel value.
    public func arcLength(from u1: Double, to u2: Double) -> Double {
        length(from: u1, to: u2) ?? -1.0
    }

    /// Find the parameter at a given arc length distance from a starting parameter.
    ///
    /// Measured with the same subdivided quadratures `length` uses, so this and the length it
    /// inverts always agree: `curve.parameterAtLength(curve.length!)` lands on
    /// `domain.upperBound`. OCCT's own root finder inverts a *single* Gauss quadrature over
    /// `[startParam, u]`, and fed the accurate total length of an 8 x 3 ellipse it answers 6.2438
    /// for a domain ending at 6.2832 (#603).
    ///
    /// A distance longer than the curve keeps OCCT's answer, which reports success with a
    /// parameter outside the curve's own domain rather than failing.
    ///
    /// - Parameters:
    ///   - arcLength: Distance along the curve (positive = forward, negative = backward).
    ///   - from: Starting parameter (defaults to curve start).
    /// - Returns: The parameter value at the specified arc length.
    ///
    /// ```swift
    /// let e = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                         majorRadius: 10, minorRadius: 1)!
    /// let half = e.parameterAtLength(e.length! / 2)   // halfway along by arc, not by parameter
    /// let end = e.parameterAtLength(e.length!)        // e.domain.upperBound
    /// ```
    public func parameterAtLength(_ arcLength: Double, from startParam: Double? = nil) -> Double {
        let start = startParam ?? domain.lowerBound
        return OCCTCurve3DParameterAtLength(handle, arcLength, start)
    }

    /// Total arc length of the curve within its domain.
    ///
    /// Delegates to `length`, the failure-distinguishing entry point. Returns `-1.0` if the
    /// underlying computation fails — arc length is otherwise always non-negative, so this is
    /// an unambiguous failure sentinel, never confusable with a genuine zero-length curve. Use
    /// `length` directly if you need an optional rather than a sentinel value.
    public var totalArcLength: Double {
        length ?? -1.0
    }

    /// Arc length between two parameters.
    ///
    /// Delegates to `length(from:to:)`, the failure-distinguishing entry point. Returns `-1.0`
    /// if a bound is not finite (`.nan`, `±.infinity`) or the underlying computation fails — arc
    /// length is otherwise always non-negative, so this is an unambiguous failure sentinel, never
    /// confusable with a genuine zero-length interval (e.g. `param1 == param2`). Use
    /// `length(from:to:)` directly if you need an optional rather than a sentinel value.
    public func arcLengthBetween(_ param1: Double, _ param2: Double) -> Double {
        length(from: param1, to: param2) ?? -1.0
    }

    /// The parameter of the point on this curve nearest to `point`.
    ///
    /// - Parameter point: Point to project.
    /// - Returns: The nearest parameter, always inside this curve's own ``domain``, or `nil` if
    ///     there is no curve to answer about.
    ///
    /// The answer is the true nearest point, not the nearest perpendicular foot. Where the point has
    /// no foot at all — anything past the end of a trimmed curve, or off to one side of an arc — the
    /// nearest point is an end, and that is what comes back. This is the scalar spelling of
    /// ``projectPoint(_:precision:)`` and agrees with it exactly; it is the 3D counterpart of
    /// `Curve2D.nearestParameter(to:)`, and it replaces both `closestParameter(to:)` and
    /// `parameterAtPoint(_:)`, which ran the identical projection and disagreed about how to
    /// report its absence.
    ///
    /// ```swift
    /// let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))!
    /// let segment = line.trimmed(from: 3, to: 8)!
    /// #expect(segment.nearestParameter(to: SIMD3(5, 2, 0)) == 5)
    /// #expect(segment.nearestParameter(to: SIMD3(100, 0, 0)) == 8)   // past the end: the end
    ///
    /// let arc = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
    ///     .trimmed(from: 0, to: .pi)!
    /// #expect(arc.nearestParameter(to: SIMD3(0, -6, 0)) == 0)        // the near end, 7.81 away
    /// ```
    ///
    /// Before #615 this reported `GeomAPI_ProjectPointOnCurve`'s extremum instead: the arc above
    /// answered π/2, the far side, 11 away, and the segment answered `nil`. `Optional` remains
    /// because no `Double` can carry a failure signal — every value is a legitimate parameter on
    /// some curve — not because a point can fail to have a nearest one.
    public func nearestParameter(to point: SIMD3<Double>) -> Double? {
        var parameter = 0.0
        guard OCCTCurve3DNearestParameter(handle, point.x, point.y, point.z, &parameter) else {
            return nil
        }
        return parameter
    }

    /// Split this curve at C1 discontinuities.
    ///
    /// - Parameter maxSegments: Output *capacity* (default 32), clamped into `0...`
    ///   ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    /// - Returns: Array of BSpline segments.
    public func splitAtContinuity(continuity: Int = 1, tolerance: Double = 1e-6,
                                  maxSegments: Int = 32) -> [Curve3D] {
        let maxSegments = Sampling.capacity(maxSegments)
        guard maxSegments > 0 else { return [] }
        var refs = [OCCTCurve3DRef?](repeating: nil, count: maxSegments)
        let n = refs.withUnsafeMutableBufferPointer { buf in
            OCCTCurve3DSplitAtContinuity(handle, Int32(continuity), tolerance,
                                          buf.baseAddress!, Int32(maxSegments))
        }
        var result = [Curve3D]()
        for i in 0..<Int(n) {
            if let ref = refs[i] {
                result.append(Curve3D(handle: ref))
            }
        }
        return result
    }

    /// Concatenate an array of curves into a single BSpline with G1 continuity.
    public static func concatenateG1(curves: [Curve3D], tolerance: Double = 1e-6) -> Curve3D? {
        let refs = curves.map { $0.handle as OCCTCurve3DRef }
        guard let ref = refs.withUnsafeBufferPointer({ buf in
            OCCTCurve3DConcatenateG1(buf.baseAddress!, Int32(curves.count), tolerance)
        }) else { return nil }
        return Curve3D(handle: ref)
    }

    // MARK: - v0.125.0: Bezier Curve deep method completion

    /// Bezier start point.
    public var bezierStartPoint: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTCurve3DBezierStartPoint(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Bezier end point.
    public var bezierEndPoint: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTCurve3DBezierEndPoint(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get all Bezier poles as flat array.
    public var bezierPoles: [SIMD3<Double>] {
        let count = Int(OCCTCurve3DBezierPoleCount(handle))
        guard count > 0 else { return [] }
        var flat = [Double](repeating: 0, count: count * 3)
        OCCTCurve3DBezierGetPoles(handle, &flat)
        var result = [SIMD3<Double>]()
        result.reserveCapacity(count)
        for i in stride(from: 0, to: flat.count, by: 3) {
            result.append(SIMD3(flat[i], flat[i + 1], flat[i + 2]))
        }
        return result
    }

    /// Get all Bezier weights. Returns nil if non-rational.
    public var bezierWeights: [Double]? {
        let count = Int(OCCTCurve3DBezierPoleCount(handle))
        guard count > 0 else { return nil }
        var weights = [Double](repeating: 0, count: count)
        guard OCCTCurve3DBezierGetWeights(handle, &weights) else { return nil }
        return weights
    }

    /// Is the Bezier curve closed?
    public var bezierIsClosed: Bool {
        OCCTCurve3DBezierIsClosed(handle)
    }

    /// Is the Bezier curve periodic?
    public var bezierIsPeriodic: Bool {
        OCCTCurve3DBezierIsPeriodic(handle)
    }

    /// Bezier curve continuity, as a raw `GeomAbs_Shape` ordinal
    /// (`0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=C3, 6=CN`). A Bezier curve is CN by construction, so
    /// this is `6`; `0` if the curve is not a Bezier. Prefer ``ContinuityClass`` for a named
    /// result (#619).
    public var bezierContinuity: Int {
        Int(OCCTCurve3DBezierContinuity(handle))
    }

    /// Is the Bezier curve at least CN continuous?
    public func bezierIsCN(_ n: Int) -> Bool {
        OCCTCurve3DBezierIsCN(handle, Int32(n))
    }

    // MARK: - Bezier 3D completions (v0.126.0)

    /// Insert a pole before index in a 3D Bezier curve (1-based index).
    @discardableResult
    public func bezierInsertPoleBefore(_ index: Int, point: SIMD3<Double>) -> Bool {
        OCCTCurve3DBezierInsertPoleBefore(handle, Int32(index), point.x, point.y, point.z)
    }

    /// Reverse the parameterization of a 3D Bezier curve.
    @discardableResult
    public func bezierReverse() -> Bool {
        OCCTCurve3DBezierReverse(handle)
    }

    /// Set pole with weight for a 3D Bezier curve.
    @discardableResult
    public func bezierSetPoleWithWeight(index: Int, point: SIMD3<Double>, weight: Double) -> Bool {
        OCCTCurve3DBezierSetPoleWithWeight(handle, Int32(index), point.x, point.y, point.z, weight)
    }

    // MARK: - v0.127.0: BSpline completions

    /// Normalize a parameter value for a periodic BSpline curve.
    /// Returns the normalized parameter, or nil if the curve is not periodic.
    public func bsplinePeriodicNormalization(_ u: Double) -> Double? {
        var param = u
        guard OCCTCurve3DBSplinePeriodicNormalization(handle, &param) else { return nil }
        return param
    }

    /// Check G1 (tangent) continuity of a BSpline curve on a parameter range.
    /// - Parameters:
    ///   - tFirst: Start of parameter range
    ///   - tLast: End of parameter range
    ///   - angularTolerance: Angular tolerance for tangent comparison (radians)
    /// - Returns: true if the curve is G1 continuous on the given range
    public func bsplineIsG1(tFirst: Double, tLast: Double, angularTolerance: Double = 0.01) -> Bool {
        OCCTCurve3DBSplineIsG1(handle, tFirst, tLast, angularTolerance)
    }
}

// MARK: - Curve3D Transform (v0.128.0)

extension Curve3D {

    /// Transform type for 3D geometry.
    public enum TransformType: Int32, Sendable {
        case translation = 0
        case rotation = 1
        case scale = 2
        case mirrorPoint = 3
        case mirrorAxis = 4
        case mirrorPlane = 5
    }

    /// Translate the curve in place by (dx, dy, dz).
    @discardableResult
    public func translate(dx: Double, dy: Double, dz: Double) -> Bool {
        OCCTCurve3DTransform(handle, TransformType.translation.rawValue,
                              dx, dy, dz, 0, 0, 0, 0)
    }

    /// Rotate the curve in place around an axis by the given angle (radians).
    @discardableResult
    public func rotate(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, angle: Double) -> Bool {
        OCCTCurve3DTransform(handle, TransformType.rotation.rawValue,
                              axisOrigin.x, axisOrigin.y, axisOrigin.z,
                              axisDirection.x, axisDirection.y, axisDirection.z, angle)
    }

    /// Scale the curve in place from a center point by the given factor.
    @discardableResult
    public func scale(center: SIMD3<Double>, factor: Double) -> Bool {
        OCCTCurve3DTransform(handle, TransformType.scale.rawValue,
                              center.x, center.y, center.z, factor, 0, 0, 0)
    }

    /// Mirror the curve in place through a point.
    @discardableResult
    public func mirrorPoint(_ point: SIMD3<Double>) -> Bool {
        OCCTCurve3DTransform(handle, TransformType.mirrorPoint.rawValue,
                              point.x, point.y, point.z, 0, 0, 0, 0)
    }

    /// Mirror the curve in place through an axis.
    @discardableResult
    public func mirrorAxis(origin: SIMD3<Double>, direction: SIMD3<Double>) -> Bool {
        OCCTCurve3DTransform(handle, TransformType.mirrorAxis.rawValue,
                              origin.x, origin.y, origin.z,
                              direction.x, direction.y, direction.z, 0)
    }

    /// Mirror the curve in place through a plane.
    @discardableResult
    public func mirrorPlane(origin: SIMD3<Double>, normal: SIMD3<Double>) -> Bool {
        OCCTCurve3DTransform(handle, TransformType.mirrorPlane.rawValue,
                              origin.x, origin.y, origin.z,
                              normal.x, normal.y, normal.z, 0)
    }
}

// MARK: - GeomEval Analytical Curve Factories (v0.130.0)

extension Curve3D {

    /// Create a circular helix curve.
    /// C(t) = R*cos(t)*X + R*sin(t)*Y + (P*t/(2*Pi))*Z
    /// - Parameters:
    ///   - radius: helix radius (must be > 0)
    ///   - pitch: axial advance per 2*Pi turn (can be negative for left-handed)
    /// - Returns: Curve3D or nil on error
    public static func circularHelix(radius: Double, pitch: Double) -> Curve3D? {
        guard let ref = OCCTGeomEvalCircularHelixCurveCreate(radius, pitch) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D sine wave curve.
    /// C(t) = t*X + A*sin(omega*t + phi)*Y
    /// - Parameters:
    ///   - amplitude: wave amplitude (must be > 0)
    ///   - omega: angular frequency (must be > 0)
    ///   - phase: phase shift (default 0)
    /// - Returns: Curve3D or nil on error
    public static func sineWave(amplitude: Double, omega: Double, phase: Double = 0.0) -> Curve3D? {
        guard let ref = OCCTGeomEvalSineWaveCurveCreate(amplitude, omega, phase) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - ExtremaPC (Point-Curve Distance) (v0.130.0)

extension Curve3D {

    /// Result of a point-curve extrema computation.
    public struct ExtremumResult: Sendable {
        /// Parameter on the curve
        public let parameter: Double
        /// Distance from query point to curve point
        public let distance: Double
        /// Closest point on the curve
        public let point: SIMD3<Double>
    }

    /// Find all extrema (closest/farthest points) from a point to this curve.
    /// - Parameter point: the query point
    /// - Returns: array of extrema results, or empty on failure
    public func extrema(from point: SIMD3<Double>) -> [ExtremumResult] {
        let maxResults: Int32 = 64
        var params = [Double](repeating: 0, count: Int(maxResults))
        var dists = [Double](repeating: 0, count: Int(maxResults))
        var px = [Double](repeating: 0, count: Int(maxResults))
        var py = [Double](repeating: 0, count: Int(maxResults))
        var pz = [Double](repeating: 0, count: Int(maxResults))
        let n = OCCTExtremaPCCurve(handle, point.x, point.y, point.z,
                                    &params, &dists, &px, &py, &pz, maxResults)
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremumResult(parameter: params[i], distance: dists[i],
                          point: SIMD3(px[i], py[i], pz[i]))
        }
    }

    /// Find all extrema from a point to a bounded segment of this curve.
    /// - Parameters:
    ///   - point: the query point
    ///   - uMin: lower parameter bound
    ///   - uMax: upper parameter bound
    /// - Returns: array of extrema results
    public func extrema(from point: SIMD3<Double>, uMin: Double, uMax: Double) -> [ExtremumResult] {
        let maxResults: Int32 = 64
        var params = [Double](repeating: 0, count: Int(maxResults))
        var dists = [Double](repeating: 0, count: Int(maxResults))
        var px = [Double](repeating: 0, count: Int(maxResults))
        var py = [Double](repeating: 0, count: Int(maxResults))
        var pz = [Double](repeating: 0, count: Int(maxResults))
        let n = OCCTExtremaPCCurveBounded(handle, point.x, point.y, point.z,
                                           uMin, uMax,
                                           &params, &dists, &px, &py, &pz, maxResults)
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremumResult(parameter: params[i], distance: dists[i],
                          point: SIMD3(px[i], py[i], pz[i]))
        }
    }

    /// Find minimum distance from a point to this curve.
    /// - Parameter point: the query point
    /// - Returns: the minimum distance, or nil on failure
    public func minimumDistance(from point: SIMD3<Double>) -> Double? {
        let d = OCCTExtremaPCMinDistance(handle, point.x, point.y, point.z)
        return d >= 0 ? d : nil
    }
}

// MARK: - GeomEval TBezier / AHTBezier Curves, TransformedCurve (v0.131.0)

extension Curve3D {

    /// Create a transformed copy of this curve by applying a translation.
    /// - Parameters:
    ///   - tx: X translation
    ///   - ty: Y translation
    ///   - tz: Z translation
    /// - Returns: A new Curve3D with the translation applied, or nil on error
    public func translated(tx: Double, ty: Double, tz: Double) -> Curve3D? {
        guard let ref = OCCTGeomAdaptorTransformedCurveCreate(handle, tx, ty, tz) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D Trigonometric Bezier curve.
    ///
    /// Uses a trigonometric Bernstein-like basis: {1, sin(alpha*t), cos(alpha*t), ...}.
    /// Parameter domain is [0, pi/alpha].
    /// - Parameters:
    ///   - poles: control points (count must be odd >= 3)
    ///   - alpha: frequency parameter (> 0)
    /// - Returns: Curve3D or nil on error
    public static func tBezier(poles: [SIMD3<Double>], alpha: Double) -> Curve3D? {
        guard poles.count >= 3, poles.count % 2 == 1 else { return nil }
        var flat = [Double](repeating: 0, count: poles.count * 3)
        for (i, p) in poles.enumerated() {
            flat[i * 3] = p.x; flat[i * 3 + 1] = p.y; flat[i * 3 + 2] = p.z
        }
        guard let ref = OCCTGeomEvalTBezierCurveCreate(&flat, Int32(poles.count), alpha) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D rational Trigonometric Bezier curve.
    /// - Parameters:
    ///   - poles: control points (count must be odd >= 3)
    ///   - weights: weights for each pole (all > 0)
    ///   - alpha: frequency parameter (> 0)
    /// - Returns: Curve3D or nil on error
    public static func tBezierRational(poles: [SIMD3<Double>], weights: [Double], alpha: Double) -> Curve3D? {
        guard poles.count >= 3, poles.count % 2 == 1, poles.count == weights.count else { return nil }
        var flat = [Double](repeating: 0, count: poles.count * 3)
        for (i, p) in poles.enumerated() {
            flat[i * 3] = p.x; flat[i * 3 + 1] = p.y; flat[i * 3 + 2] = p.z
        }
        var wts = weights
        guard let ref = OCCTGeomEvalTBezierCurveCreateRational(&flat, &wts, Int32(poles.count), alpha) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D Algebraic-Hyperbolic-Trigonometric (AHT) Bezier curve.
    ///
    /// Uses a mixed basis: {1, t, ..., t^k, sinh(alpha*t), cosh(alpha*t), sin(beta*t), cos(beta*t)}.
    /// Number of poles must equal algDegree+1 + 2*(alpha>0) + 2*(beta>0).
    /// Parameter range: [0, 1].
    /// - Parameters:
    ///   - poles: control points
    ///   - algDegree: algebraic polynomial degree (>= 0)
    ///   - alpha: hyperbolic frequency (>= 0, 0 = no hyperbolic terms)
    ///   - beta: trigonometric frequency (>= 0, 0 = no trig terms)
    /// - Returns: Curve3D or nil on error
    public static func ahtBezier(poles: [SIMD3<Double>], algDegree: Int, alpha: Double, beta: Double) -> Curve3D? {
        guard !poles.isEmpty else { return nil }
        var flat = [Double](repeating: 0, count: poles.count * 3)
        for (i, p) in poles.enumerated() {
            flat[i * 3] = p.x; flat[i * 3 + 1] = p.y; flat[i * 3 + 2] = p.z
        }
        guard let ref = OCCTGeomEvalAHTBezierCurveCreate(&flat, Int32(poles.count),
                                                          Int32(algDegree), alpha, beta) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D rational AHT Bezier curve.
    /// - Parameters:
    ///   - poles: control points
    ///   - weights: weights for each pole (all > 0)
    ///   - algDegree: algebraic polynomial degree (>= 0)
    ///   - alpha: hyperbolic frequency (>= 0)
    ///   - beta: trigonometric frequency (>= 0)
    /// - Returns: Curve3D or nil on error
    public static func ahtBezierRational(poles: [SIMD3<Double>], weights: [Double],
                                          algDegree: Int, alpha: Double, beta: Double) -> Curve3D? {
        guard !poles.isEmpty, poles.count == weights.count else { return nil }
        var flat = [Double](repeating: 0, count: poles.count * 3)
        for (i, p) in poles.enumerated() {
            flat[i * 3] = p.x; flat[i * 3 + 1] = p.y; flat[i * 3 + 2] = p.z
        }
        var wts = weights
        guard let ref = OCCTGeomEvalAHTBezierCurveCreateRational(&flat, &wts, Int32(poles.count),
                                                                   Int32(algDegree), alpha, beta) else { return nil }
        return Curve3D(handle: ref)
    }
}

extension Curve3D {
    // Continuity level for approximation is `ParametricContinuity` (Continuity.swift); the
    // `ApproxContinuity` copy Shape.swift used to declare is now a deprecated alias of it. See #398.

    /// Approximate this curve as a BSpline, reporting the fit's error and completion status.
    ///
    /// The same approximation ``Curve3D/approximated(tolerance:continuity:maxSegments:maxDegree:)``
    /// performs — one shared `GeomConvert_ApproxCurve` run behind both (#491) — with the
    /// diagnostics OCCT already computed for it. For identical arguments the two return the same
    /// curve; use this one when you need to know how close the fit actually came.
    ///
    /// `hasResult` is what decides whether `curve` is populated, and OCCT documents it as true even
    /// for a fit that is *not* within `tolerance` — `isDone` and `maxError` are how you find out.
    /// So a non-nil `curve` is not by itself a promise that `tolerance` was met.
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10)!
    /// let fit = circle.approxWithDetails(tolerance: 1e-6)
    /// if let bspline = fit.curve, fit.isDone {
    ///     print("fitted to \(fit.maxError) with \(bspline.poleCount ?? 0) poles")
    /// }
    /// ```
    public func approxWithDetails(tolerance: Double, continuity: ParametricContinuity = .c2,
                                   maxSegments: Int = 100, maxDegree: Int = 8) -> ApproxCurveResult {
        let r = OCCTGeomConvertApproxCurve(handle, tolerance, continuity.rawValue,
                                            Int32(maxSegments), Int32(maxDegree))
        let curve: Curve3D? = r.curve.map { Curve3D(handle: $0) }
        return ApproxCurveResult(curve: curve, maxError: r.maxError, isDone: r.isDone, hasResult: r.hasResult)
    }
}

extension Curve3D {
    /// Project this 3D curve onto a surface as a 2D curve.
    public func projectOnSurface(_ surface: Surface, firstParam: Double? = nil,
                                  lastParam: Double? = nil, precision: Double = 1e-6) -> Curve2D? {
        let domain = self.domain
        let f = firstParam ?? domain.lowerBound
        let l = lastParam ?? domain.upperBound
        guard let ref = OCCTProjectCurveOnSurface(handle, surface.handle, f, l, precision) else { return nil }
        return Curve2D(handle: ref)
    }
}

extension Curve3D {
    /// Convert this curve segment to a BSpline using ShapeConstruct_Curve.
    public func convertSegmentToBSpline(first: Double, last: Double, precision: Double = 1e-6) -> Curve3D? {
        guard let ref = OCCTShapeConstructConvertToBSpline3D(handle, first, last, precision) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Adjust curve endpoints to match given points.
    public func adjustEndpoints(start: SIMD3<Double>, end: SIMD3<Double>) -> Bool {
        OCCTShapeConstructAdjustCurve3D(handle, start.x, start.y, start.z, end.x, end.y, end.z)
    }
}

extension Curve3D {
    /// Find the parameter of a 3D point on this curve.
    /// Returns nil if the point is beyond maxDistance from the curve.
    public func parameterOf(point: SIMD3<Double>, maxDistance: Double = 1.0) -> Double? {
        var param: Double = 0
        let ok = OCCTGeomLibToolParameter3D(handle, point.x, point.y, point.z, maxDistance, &param)
        return ok ? param : nil
    }
}

extension Curve3D {
    /// Check if this BSpline curve has reversed end tangents.
    /// Returns (needFixFirst, needFixLast) or nil if not a BSpline or check failed.
    public func checkBSplineTangents(tolerance: Double = 0.01, angularTolerance: Double = 0.1) -> (fixFirst: Bool, fixLast: Bool)? {
        var first = false, last = false
        let ok = OCCTGeomLibCheckBSpline3D(handle, tolerance, angularTolerance, &first, &last)
        return ok ? (first, last) : nil
    }

    /// Fix reversed end tangents on a BSpline curve. Returns new curve or nil.
    public func fixBSplineTangents(fixFirst: Bool, fixLast: Bool,
                                    tolerance: Double = 0.01, angularTolerance: Double = 0.1) -> Curve3D? {
        guard let ref = OCCTGeomLibFixBSpline3D(handle, tolerance, angularTolerance, fixFirst, fixLast) else { return nil }
        return Curve3D(handle: ref)
    }
}

extension Curve3D {
    /// Create a BSpline curve by polynomial interpolation of points at given parameters.
    public static func polynomialInterpolation(degree: Int, points: [SIMD3<Double>], parameters: [Double]) -> Curve3D? {
        guard points.count == parameters.count, points.count >= 2 else { return nil }
        var xyz = [Double]()
        xyz.reserveCapacity(points.count * 3)
        for p in points { xyz.append(p.x); xyz.append(p.y); xyz.append(p.z) }
        guard let ref = OCCTGeomLibInterpolate(Int32(degree), Int32(points.count), xyz, parameters) else { return nil }
        return Curve3D(handle: ref)
    }
}

extension Curve3D {
    /// Check if a 2D curve on a surface has the same parameterization as this 3D curve.
    public func checkSameParameter(curve2D: Curve2D, surface: Surface,
                                    tolerance: Double = 1e-6) -> SameParameterResult? {
        var isSame = false
        var tolReached: Double = 0
        let ok = OCCTApproxSameParameter(handle, curve2D.handle, surface.handle,
                                          tolerance, &isSame, &tolReached)
        guard ok else { return nil }
        return SameParameterResult(isSameParameter: isSame, toleranceReached: tolReached)
    }
}

extension Curve3D {
    /// Split this 3D curve at continuity breaks.
    ///
    /// Criterion is a ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2, 3=C3); anything above
    /// asks for CN, i.e. split at every break. `ShapeUpgrade_Split*Continuity::SetCriterion` is
    /// the one consumer of this vocabulary that recognises the whole ladder including CN.
    ///
    /// ```swift
    /// // A cubic interpolated BSpline is C2 at its interior knots, so .c3 is what splits it
    /// let pieces = curve.splitByContinuity(criterion: 3)
    /// ```
    public func splitByContinuity(criterion: Int = 2, tolerance: Double = 1e-6) -> [Curve3D] {
        var refs = [OCCTCurve3DRef?](repeating: nil, count: 32)
        let n = refs.withUnsafeMutableBufferPointer { buf in
            OCCTSplitCurve3dContinuity(handle, Int32(criterion), tolerance,
                                        buf.baseAddress, Int32(buf.count))
        }
        return (0..<Int(n)).compactMap { i in
            guard let ref = refs[i] else { return nil }
            return Curve3D(handle: ref)
        }
    }
}

extension Curve3D {
    /// Attempt to convert this curve to an analytical form (line, circle, ellipse).
    ///
    /// Recognition runs over `[first, last]` only, so a curve that is a circle along part of its
    /// domain can be recognized there even when the whole domain is not. The result carries the
    /// recognized curve's own parameterization: a BSpline circle examined over `[π/2, 3π/2]`
    /// reports a range starting at 0 on the `Geom_Circle` it returns.
    ///
    /// ```swift
    /// let bspline = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!.toBSpline()!
    /// let domain = bspline.domain
    /// if let r = bspline.toAnalytical(tolerance: 1e-4,
    ///                                 first: domain.lowerBound,
    ///                                 last: domain.upperBound) {
    ///     print(r.curve.curveKind, r.gap)   // .circle, ~1e-15
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - tolerance: Recognition tolerance.
    ///   - first: Start of the parameter range to examine.
    ///   - last: End of the parameter range to examine.
    /// - Returns: The recognized curve with its range and deviation, or nil if not recognizable.
    public func toAnalytical(tolerance: Double, first: Double, last: Double) -> CurveToAnalyticalResult? {
        let result = OCCTGeomConvertCurveToAnalytical(handle, tolerance, first, last)
        guard result.success, let curveRef = result.curve else { return nil }
        return CurveToAnalyticalResult(
            curve: Curve3D(handle: curveRef),
            newFirst: result.newFirst,
            newLast: result.newLast,
            gap: result.gap
        )
    }

    /// Attempt to convert this curve to an analytical form over its whole domain, reporting the
    /// deviation.
    ///
    /// The full-range spelling of ``toAnalytical(tolerance:first:last:)``, and the curve counterpart
    /// of ``Surface/toAnalyticalWithGap(tolerance:)``.
    ///
    /// ```swift
    /// let bspline = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!.toBSpline()!
    /// if let r = bspline.toAnalyticalWithGap(tolerance: 1e-4) {
    ///     print(r.gap)   // how far the BSpline strayed from the circle
    /// }
    /// ```
    ///
    /// - Parameter tolerance: Recognition tolerance.
    /// - Returns: The recognized curve with its range and deviation, or nil if not recognizable.
    public func toAnalyticalWithGap(tolerance: Double = 1e-4) -> CurveToAnalyticalResult? {
        let domain = self.domain
        return toAnalytical(tolerance: tolerance,
                            first: domain.lowerBound,
                            last: domain.upperBound)
    }

    /// Check if a set of 3D points are collinear within tolerance.
    public static func arePointsLinear(_ points: [SIMD3<Double>], tolerance: Double) -> (isLinear: Bool, deviation: Double) {
        var flat = [Double]()
        flat.reserveCapacity(points.count * 3)
        for p in points {
            flat.append(p.x); flat.append(p.y); flat.append(p.z)
        }
        var deviation: Double = 0
        let result = flat.withUnsafeBufferPointer { buf in
            OCCTGeomConvertIsLinear(buf.baseAddress!, Int32(points.count), tolerance, &deviation)
        }
        return (result, deviation)
    }
}

extension Curve3D {
    /// Result of section placement on a path.
    public struct SectionPlacementResult {
        public let parameterOnPath: Double
        public let parameterOnSection: Double
        public let distance: Double
        public let angle: Double
        public let isDone: Bool
    }

    /// Place a section curve on a path using a draft location law.
    public func sectionPlacement(section: Curve3D,
                                 direction: SIMD3<Double> = SIMD3(0, 0, 1),
                                 draftAngle: Double = 0,
                                 tolerance: Double = 1e-3) -> SectionPlacementResult {
        let r = OCCTGeomFillSectionPlacement(handle, section.handle,
                                              direction.x, direction.y, direction.z,
                                              draftAngle, tolerance)
        return SectionPlacementResult(parameterOnPath: r.parameterOnPath,
                                      parameterOnSection: r.parameterOnSection,
                                      distance: r.distance, angle: r.angle, isDone: r.isDone)
    }
}

public extension Curve3D {
    /// Create an offset curve.
    static func offset(basis: Curve3D, offset: Double,
                       dirX: Double, dirY: Double, dirZ: Double) -> Curve3D? {
        guard let ref = OCCTCurve3DCreateOffset(basis.handle, offset, dirX, dirY, dirZ) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Get the offset value (returns 0 if not an offset curve).
    var offsetValue: Double {
        OCCTCurve3DOffsetValue(handle)
    }

    /// Get the offset direction (returns nil if not an offset curve).
    var offsetDirection: (x: Double, y: Double, z: Double)? {
        var dx: Double = 0, dy: Double = 0, dz: Double = 0
        if OCCTCurve3DOffsetDirection(handle, &dx, &dy, &dz) {
            return (dx, dy, dz)
        }
        return nil
    }
}

extension Curve3D {

    /// Check if this curve is closed within the given precision.
    /// Uses ShapeAnalysis_Curve::IsClosed (static method).
    /// - Parameter precision: Tolerance for closure check.
    /// - Returns: true if the curve endpoints coincide within precision.
    public func isClosedWithPrecision(_ precision: Double) -> Bool {
        OCCTCurve3DIsClosedWithPreci(handle, precision)
    }

    /// Check if this curve is periodic using ShapeAnalysis_Curve::IsPeriodic.
    /// More robust than the basic isPeriodic property.
    public var isPeriodicSA: Bool {
        OCCTCurve3DIsPeriodicSA(handle)
    }

}

extension Curve3D {

    /// Get the basis curve of this offset curve.
    /// - Returns: The basis curve, or nil if this is not an offset curve.
    public var offsetBasisCurve: Curve3D? {
        guard let ref = OCCTCurve3DOffsetBasis(handle) else { return nil }
        return Curve3D(handle: ref)
    }
}

extension Curve3D {

    /// Create a trimmed curve from this curve between parameters u1 and u2.
    public func trimmed(u1: Double, u2: Double) -> Curve3D? {
        guard let ref = OCCTCurve3DTrimmed(handle, u1, u2) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Get the basis curve of a trimmed curve (nil if not trimmed).
    public var trimmedBasis: Curve3D? {
        guard let ref = OCCTCurve3DTrimmedBasis(handle) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Change the trim parameters on a trimmed curve.
    @discardableResult
    public func setTrim(u1: Double, u2: Double) -> Bool {
        OCCTCurve3DSetTrim(handle, u1, u2)
    }
}

extension Curve3D {
    /// Create a 3D circle from axis (center + normal) and radius.
    public static func gcCircle(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeCircle(center.x, center.y, center.z,
                                          normal.x, normal.y, normal.z, radius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D circle through 3 points.
    public static func gcCircle(p1: SIMD3<Double>, p2: SIMD3<Double>, p3: SIMD3<Double>) -> Curve3D? {
        guard let ref = OCCTGCMakeCircle3Points(p1.x, p1.y, p1.z,
                                                  p2.x, p2.y, p2.z,
                                                  p3.x, p3.y, p3.z) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D circle from center, normal, and radius (alias).
    public static func gcCircleCenterNormal(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeCircleCenterNormal(center.x, center.y, center.z,
                                                       normal.x, normal.y, normal.z, radius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D circle parallel to an existing circle at given distance.
    public static func gcCircleParallel(center: SIMD3<Double>, normal: SIMD3<Double>,
                                         radius: Double, distance: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeCircleParallel(center.x, center.y, center.z,
                                                   normal.x, normal.y, normal.z,
                                                   radius, distance) else { return nil }
        return Curve3D(handle: ref)
    }
}

extension Curve3D {
    /// Create a 3D ellipse from axis and major/minor radii.
    ///
    /// - Parameters:
    ///   - center: Ellipse centre.
    ///   - normal: Normal of the plane the ellipse lies in.
    ///   - majorRadius: Major radius. Must be `> 0`.
    ///   - minorRadius: Minor radius. Must be `> 0` and no larger than `majorRadius`.
    /// - Returns: The ellipse, or `nil` if the radii do not describe one.
    ///
    /// `GC_MakeEllipse` reports `!IsDone()` for negative and inverted radii on its own, but
    /// accepts zero; the radii are checked here so every route to an ellipse enforces the same
    /// contract as `Curve3D.ellipse(center:normal:majorRadius:minorRadius:)`.
    ///
    /// ```swift
    /// let e = Curve3D.gcEllipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                           majorRadius: 10, minorRadius: 5)
    /// #expect(e != nil)
    /// #expect(Curve3D.gcEllipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                           majorRadius: 10, minorRadius: 0) == nil)
    /// ```
    public static func gcEllipse(center: SIMD3<Double>, normal: SIMD3<Double>,
                                  majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeEllipse(center.x, center.y, center.z,
                                            normal.x, normal.y, normal.z,
                                            majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D ellipse from 3 points (S1, S2, center).
    public static func gcEllipse(s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>) -> Curve3D? {
        guard let ref = OCCTGCMakeEllipse3Points(s1.x, s1.y, s1.z,
                                                    s2.x, s2.y, s2.z,
                                                    center.x, center.y, center.z) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D ellipse from full Ax2 (center + normal + X direction) and radii.
    ///
    /// Same radius contract as `gcEllipse(center:normal:majorRadius:minorRadius:)`; this overload
    /// only adds control over where the major axis points.
    ///
    /// ```swift
    /// let e = Curve3D.gcEllipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                           xDirection: SIMD3(1, 0, 0),
    ///                           majorRadius: 10, minorRadius: 5)
    /// #expect(e != nil)
    /// ```
    public static func gcEllipse(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                                  majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeEllipseFromElips(center.x, center.y, center.z,
                                                      normal.x, normal.y, normal.z,
                                                      xDirection.x, xDirection.y, xDirection.z,
                                                      majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: ref)
    }
}

extension Curve3D {
    /// Create a 3D hyperbola from axis and major/minor radii.
    ///
    /// - Parameters:
    ///   - center: Hyperbola centre.
    ///   - normal: Normal of the plane the hyperbola lies in.
    ///   - majorRadius: Major radius. Must be `> 0`.
    ///   - minorRadius: Minor radius. Must be `> 0`. No ordering constraint against the major.
    /// - Returns: The hyperbola, or `nil` if either radius is `<= 0`.
    ///
    /// ```swift
    /// let h = Curve3D.gcHyperbola(center: .zero, normal: SIMD3(0, 0, 1),
    ///                             majorRadius: 8, minorRadius: 3)
    /// #expect(h != nil)
    /// #expect(Curve3D.gcHyperbola(center: .zero, normal: SIMD3(0, 0, 1),
    ///                             majorRadius: 0, minorRadius: 3) == nil)
    /// ```
    public static func gcHyperbola(center: SIMD3<Double>, normal: SIMD3<Double>,
                                    majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeHyperbola(center.x, center.y, center.z,
                                              normal.x, normal.y, normal.z,
                                              majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D hyperbola from 3 points (S1, S2, center).
    public static func gcHyperbola(s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>) -> Curve3D? {
        guard let ref = OCCTGCMakeHyperbola3Points(s1.x, s1.y, s1.z,
                                                      s2.x, s2.y, s2.z,
                                                      center.x, center.y, center.z) else { return nil }
        return Curve3D(handle: ref)
    }
}

extension Curve3D {
    /// Concatenate multiple bounded 3D curves into a single BSpline.
    public static func concatenate(_ curves: [Curve3D], tolerance: Double = 1e-4) -> Curve3D? {
        guard !curves.isEmpty else { return nil }
        var handles = curves.map { $0.handle as OCCTCurve3DRef }
        guard let ref = OCCTConcatenateCurves3D(&handles, Int32(curves.count), tolerance) else { return nil }
        return Curve3D(handle: ref)
    }
}

extension Curve3D {
    /// Measured global continuity of the 3D curve, as a raw `GeomAbs_Shape` ordinal.
    ///
    /// The ordinals are `GeomAbs_Shape`'s own declared order — `0=C0, 1=G1, 2=C1, 3=G2,
    /// 4=C2, 5=C3, 6=CN` — not a 0/1/2 order. Prefer ``continuityClass``, which names them.
    ///
    /// ```swift
    /// // A cubic BSpline with a doubled interior knot is C1, which is ordinal 2 (not 1).
    /// print(bspline.continuity)        // 2
    /// print(bspline.continuityClass)   // .c1
    /// ```
    ///
    /// - Warning: This is the migration target for the retired `continuityOrder`, but it is not a
    ///   drop-in one: `continuityOrder` used to answer a different set of numbers
    ///   (`C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3`). A threshold moved across unchanged
    ///   reads as one class too low — `>= 2` accepts C1 here and accepted C2 there — and `== 99`
    ///   is now unreachable. Prefer ``continuityClass`` and ``ContinuityClass/satisfies(_:)``,
    ///   which cannot be compared against the wrong constant at all (#619).
    public var continuity: Int {
        Int(OCCTCurve3DGetContinuity(handle))
    }

    /// Measured global continuity of the 3D curve.
    ///
    /// ```swift
    /// let line = Curve3D.line(origin: .zero, direction: SIMD3(1, 0, 0))
    /// print(line?.continuityClass)                  // .cN
    /// print(line?.continuityClass.satisfies(.c3))   // true
    /// ```
    public var continuityClass: ContinuityClass {
        ContinuityClass(rawValue: OCCTCurve3DGetContinuity(handle)) ?? .c0
    }
}

extension Curve3D {

    /// BSpline-specific operations. Returns nil values if the curve is not a BSpline.
    public struct BSpline {
        let curve: Curve3D

        /// Number of knots (0 if not a BSpline).
        public var knotCount: Int { Int(OCCTCurve3DBSplineKnotCount(curve.handle)) }

        /// Number of poles/control points (0 if not a BSpline).
        public var poleCount: Int { Int(OCCTCurve3DBSplinePoleCount(curve.handle)) }

        /// Degree (0 if not a BSpline).
        public var degree: Int { Int(OCCTCurve3DBSplineDegree(curve.handle)) }

        /// Whether the BSpline is rational.
        public var isRational: Bool { OCCTCurve3DBSplineIsRational(curve.handle) }

        /// Get all knot values.
        public var knots: [Double] {
            let n = knotCount
            guard n > 0 else { return [] }
            var arr = [Double](repeating: 0, count: n)
            OCCTCurve3DBSplineGetKnots(curve.handle, &arr)
            return arr
        }

        /// Get all knot multiplicities.
        public var multiplicities: [Int] {
            let n = knotCount
            guard n > 0 else { return [] }
            var arr = [Int32](repeating: 0, count: n)
            OCCTCurve3DBSplineGetMults(curve.handle, &arr)
            return arr.map { Int($0) }
        }

        /// Get a pole at 1-based index.
        public func pole(at index: Int) -> SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DBSplineGetPole(curve.handle, Int32(index), &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// Set a pole at 1-based index.
        @discardableResult
        public func setPole(at index: Int, to point: SIMD3<Double>) -> Bool {
            OCCTCurve3DBSplineSetPole(curve.handle, Int32(index), point.x, point.y, point.z)
        }

        /// Get the weight at 1-based index.
        public func weight(at index: Int) -> Double {
            OCCTCurve3DBSplineGetWeight(curve.handle, Int32(index))
        }

        /// Set the weight at 1-based index.
        @discardableResult
        public func setWeight(at index: Int, to weight: Double) -> Bool {
            OCCTCurve3DBSplineSetWeight(curve.handle, Int32(index), weight)
        }

        /// Insert a knot at parameter u with given multiplicity.
        @discardableResult
        public func insertKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool {
            OCCTCurve3DBSplineInsertKnot(curve.handle, u, Int32(multiplicity), tolerance)
        }

        /// Remove a knot at 1-based index down to given multiplicity.
        @discardableResult
        public func removeKnot(at index: Int, multiplicity: Int, tolerance: Double) -> Bool {
            OCCTCurve3DBSplineRemoveKnot(curve.handle, Int32(index), Int32(multiplicity), tolerance)
        }

        /// Segment the BSpline to [u1, u2].
        @discardableResult
        public func segment(u1: Double, u2: Double) -> Bool {
            OCCTCurve3DBSplineSegment(curve.handle, u1, u2)
        }

        /// Increase the degree to the given value.
        @discardableResult
        public func increaseDegree(to degree: Int) -> Bool {
            OCCTCurve3DBSplineIncreaseDegree(curve.handle, Int32(degree))
        }

        /// Compute parametric resolution for a given 3D tolerance.
        public func resolution(tolerance3d: Double) -> Double {
            OCCTCurve3DBSplineResolution(curve.handle, tolerance3d)
        }

        /// Set periodic or non-periodic.
        @discardableResult
        public func setPeriodic(_ periodic: Bool) -> Bool {
            OCCTCurve3DBSplineSetPeriodic(curve.handle, periodic)
        }
    }

    /// Access BSpline-specific operations. Works only if the underlying curve is a Geom_BSplineCurve.
    public var bspline: BSpline { BSpline(curve: self) }
}

extension Curve3D {

    /// Bezier-specific operations.
    public struct Bezier {
        let curve: Curve3D

        /// Get a pole at 1-based index.
        public func pole(at index: Int) -> SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DBezierGetPole(curve.handle, Int32(index), &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// Set a pole at 1-based index.
        @discardableResult
        public func setPole(at index: Int, to point: SIMD3<Double>) -> Bool {
            OCCTCurve3DBezierSetPole(curve.handle, Int32(index), point.x, point.y, point.z)
        }

        /// Set the weight at 1-based index.
        @discardableResult
        public func setWeight(at index: Int, to weight: Double) -> Bool {
            OCCTCurve3DBezierSetWeight(curve.handle, Int32(index), weight)
        }

        /// Insert a pole after given index.
        @discardableResult
        public func insertPoleAfter(index: Int, point: SIMD3<Double>) -> Bool {
            OCCTCurve3DBezierInsertPoleAfter(curve.handle, Int32(index), point.x, point.y, point.z)
        }

        /// Remove a pole at given index.
        @discardableResult
        public func removePole(at index: Int) -> Bool {
            OCCTCurve3DBezierRemovePole(curve.handle, Int32(index))
        }

        /// Segment to [u1, u2].
        @discardableResult
        public func segment(u1: Double, u2: Double) -> Bool {
            OCCTCurve3DBezierSegment(curve.handle, u1, u2)
        }

        /// Increase degree.
        @discardableResult
        public func increaseDegree(to degree: Int) -> Bool {
            OCCTCurve3DBezierIncreaseDegree(curve.handle, Int32(degree))
        }

        /// Whether the Bezier is rational.
        public var isRational: Bool { OCCTCurve3DBezierIsRational(curve.handle) }

        /// Degree.
        public var degree: Int { Int(OCCTCurve3DBezierDegree(curve.handle)) }

        /// Number of poles.
        public var poleCount: Int { Int(OCCTCurve3DBezierPoleCount(curve.handle)) }
    }

    /// Access Bezier-specific operations. Works only if the underlying curve is a Geom_BezierCurve.
    public var bezier: Bezier { Bezier(curve: self) }
}

extension Curve3D {

    /// Reverse the curve in-place.
    @discardableResult
    public func reverse() -> Bool {
        OCCTCurve3DReverse(handle)
    }

    /// Create a deep copy of this curve.
    public func copy() -> Curve3D? {
        guard let ref = OCCTCurve3DCopy(handle) else { return nil }
        return Curve3D(handle: ref)
    }
}

extension Curve3D {

    /// Evaluate the curve point at parameter u.
    public func evalD0(at u: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTCurve3DEvalD0(handle, u, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate the curve point and first derivative at parameter u.
    public func evalD1(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1x = 0.0, d1y = 0.0, d1z = 0.0
        OCCTCurve3DEvalD1(handle, u, &px, &py, &pz, &d1x, &d1y, &d1z)
        return (SIMD3(px, py, pz), SIMD3(d1x, d1y, d1z))
    }

    /// Evaluate the curve point, first and second derivatives at parameter u.
    public func evalD2(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1x = 0.0, d1y = 0.0, d1z = 0.0
        var d2x = 0.0, d2y = 0.0, d2z = 0.0
        OCCTCurve3DEvalD2(handle, u, &px, &py, &pz, &d1x, &d1y, &d1z, &d2x, &d2y, &d2z)
        return (SIMD3(px, py, pz), SIMD3(d1x, d1y, d1z), SIMD3(d2x, d2y, d2z))
    }

    /// Evaluate the curve point, first, second, and third derivatives at parameter u.
    public func evalD3(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>, d3: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1x = 0.0, d1y = 0.0, d1z = 0.0
        var d2x = 0.0, d2y = 0.0, d2z = 0.0
        var d3x = 0.0, d3y = 0.0, d3z = 0.0
        OCCTCurve3DEvalD3(handle, u, &px, &py, &pz, &d1x, &d1y, &d1z, &d2x, &d2y, &d2z, &d3x, &d3y, &d3z)
        return (SIMD3(px, py, pz), SIMD3(d1x, d1y, d1z), SIMD3(d2x, d2y, d2z), SIMD3(d3x, d3y, d3z))
    }

}

extension Curve3D {

    /// The geometric curve type (0=Line, 1=Circle, 2=Ellipse, 3=Hyperbola, 4=Parabola, 5=BezierCurve, 6=BSplineCurve, 7=OtherCurve).
    public var curveType: Int {
        Int(OCCTCurve3DCurveType(handle))
    }
}

extension Curve3D {

    /// Local point-on-curve search from an initial parameter guess. Returns `(parameter, distance)`.
    ///
    /// Searches a window of ±10% of the domain around `initParam` and reports the
    /// **lowest-distance extremum inside that window**. `initParam` bounds the window; it does not
    /// rank what is found in it, so the extremum you get back is not necessarily the one nearest
    /// your guess — where a window holds several, the one closest to the *query point* wins.
    ///
    /// The window is what makes the answer local, and a windowed minimum can still be a global
    /// *maximum*: on a half circle of radius 5 queried from `(0, -6, 0)` with a guess of `.pi / 2`,
    /// the window holds the far side of the arc and this reports 11, where the nearest point on the
    /// curve is 7.81 away. Use ``nearestParameter(to:)`` or ``projectPoint(_:precision:)`` when you
    /// want the global answer.
    ///
    /// When the window holds no extremum at all, the search falls back to the whole curve — and,
    /// since #615, to the whole curve's true nearest point, which is what those two report. Before
    /// #615 the fallback reported an extremum instead, so a guess sitting *on* the nearest point
    /// returned the point diametrically opposite it, and a bounded segment queried from past its own
    /// end returned `nil` for every guess.
    ///
    /// ```swift
    /// let arc = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
    ///     .trimmed(from: 0, to: .pi)!
    ///
    /// // Guess 0: no extremum nearby, so the whole curve is searched, correctly.
    /// #expect(arc.locateNearestPoint(SIMD3(0, -6, 0), initParam: 0)?.parameter == 0)
    ///
    /// // Guess .pi / 2: an extremum IS nearby, and it is the far side of the arc.
    /// #expect(arc.locateNearestPoint(SIMD3(0, -6, 0), initParam: .pi / 2)?.distance == 11)
    /// ```
    ///
    /// - Returns: `nil` only when the curve cannot be read.
    public func locateNearestPoint(_ point: SIMD3<Double>, initParam: Double, tolerance: Double = 1e-6) -> (parameter: Double, distance: Double)? {
        var param = 0.0, dist = 0.0
        let ok = OCCTExtremaLocateOnCurve(handle, point.x, point.y, point.z,
                                          initParam, tolerance, &param, &dist)
        return ok ? (param, dist) : nil
    }

    /// Global point-to-curve projection returning all extrema. Returns array of (parameter, distance).
    ///
    /// - Parameter maxResults: Output *capacity* (default 10), clamped into `0...`
    ///   ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    public func projectPointAll(_ point: SIMD3<Double>, maxResults: Int = 10) -> [(parameter: Double, distance: Double)] {
        let maxResults = Sampling.capacity(maxResults)
        guard maxResults > 0 else { return [] }
        var params = [Double](repeating: 0, count: maxResults)
        var distances = [Double](repeating: 0, count: maxResults)
        let n = Int(OCCTExtremaPointCurve(handle, point.x, point.y, point.z,
                                          &params, &distances, Int32(maxResults)))
        return (0..<n).map { (params[$0], distances[$0]) }
    }
}

extension Curve3D {

    /// Set the knot value at a given index (1-based).
    public func bsplineSetKnot(index: Int, value: Double) -> Bool {
        OCCTCurve3DBSplineSetKnot(handle, Int32(index), value)
    }

    /// Get the full knot sequence (with multiplicities expanded).
    public func bsplineKnotSequence() -> [Double] {
        let maxSize = 1024
        var seq = [Double](repeating: 0, count: maxSize)
        var count: Int32 = 0
        OCCTCurve3DBSplineGetKnotSequence(handle, &seq, &count)
        return Array(seq.prefix(Int(count)))
    }

    /// Get all weights (one per pole).
    public func bsplineWeights() -> [Double] {
        let nPoles = Int(OCCTCurve3DBSplinePoleCount(handle))
        guard nPoles > 0 else { return [] }
        var weights = [Double](repeating: 0, count: nPoles)
        OCCTCurve3DBSplineGetWeights(handle, &weights)
        return weights
    }

    /// Insert multiple knots at once.
    public func bsplineInsertKnots(_ knots: [Double], multiplicities: [Int], tolerance: Double = 1e-10) -> Bool {
        let count = min(knots.count, multiplicities.count)
        guard count > 0 else { return false }
        let mults = multiplicities.map { Int32($0) }
        return OCCTCurve3DBSplineInsertKnots(handle, knots, mults, Int32(count), tolerance)
    }

    /// Move a point on the BSpline curve to a new position.
    public func bsplineMovePoint(u: Double, to point: SIMD3<Double>, poleRange: ClosedRange<Int>) -> Bool {
        OCCTCurve3DBSplineMovePoint(handle, u, point.x, point.y, point.z,
                                     Int32(poleRange.lowerBound), Int32(poleRange.upperBound))
    }

    /// Evaluate the curve locally within a knot span.
    public func bsplineLocalValue(u: Double, fromKnot: Int, toKnot: Int) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTCurve3DBSplineLocalValue(handle, u, Int32(fromKnot), Int32(toKnot), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on BSpline curve within knot span [fromKnot, toKnot].
    public func bsplineLocalD0(u: Double, fromKnot: Int, toKnot: Int) -> SIMD3<Double> {
        var px = 0.0, py = 0.0, pz = 0.0
        OCCTCurve3DBSplineLocalD0(handle, u, Int32(fromKnot), Int32(toKnot), &px, &py, &pz)
        return SIMD3(px, py, pz)
    }

    /// Evaluate point + 1st derivative on BSpline curve within knot span.
    public func bsplineLocalD1(u: Double, fromKnot: Int, toKnot: Int)
        -> (point: SIMD3<Double>, d1: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var vx = 0.0, vy = 0.0, vz = 0.0
        OCCTCurve3DBSplineLocalD1(handle, u, Int32(fromKnot), Int32(toKnot),
                                   &px, &py, &pz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(vx, vy, vz))
    }

    /// Evaluate point + 1st + 2nd derivative on BSpline curve within knot span.
    public func bsplineLocalD2(u: Double, fromKnot: Int, toKnot: Int)
        -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var v1x = 0.0, v1y = 0.0, v1z = 0.0
        var v2x = 0.0, v2y = 0.0, v2z = 0.0
        OCCTCurve3DBSplineLocalD2(handle, u, Int32(fromKnot), Int32(toKnot),
                                   &px, &py, &pz, &v1x, &v1y, &v1z, &v2x, &v2y, &v2z)
        return (SIMD3(px, py, pz), SIMD3(v1x, v1y, v1z), SIMD3(v2x, v2y, v2z))
    }

    /// Evaluate point + 1st + 2nd + 3rd derivative on BSpline curve within knot span.
    public func bsplineLocalD3(u: Double, fromKnot: Int, toKnot: Int)
        -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>, d3: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var v1x = 0.0, v1y = 0.0, v1z = 0.0
        var v2x = 0.0, v2y = 0.0, v2z = 0.0
        var v3x = 0.0, v3y = 0.0, v3z = 0.0
        OCCTCurve3DBSplineLocalD3(handle, u, Int32(fromKnot), Int32(toKnot),
                                   &px, &py, &pz, &v1x, &v1y, &v1z,
                                   &v2x, &v2y, &v2z, &v3x, &v3y, &v3z)
        return (SIMD3(px, py, pz), SIMD3(v1x, v1y, v1z),
                SIMD3(v2x, v2y, v2z), SIMD3(v3x, v3y, v3z))
    }

    /// Evaluate Nth derivative on BSpline curve within knot span.
    public func bsplineLocalDN(u: Double, fromKnot: Int, toKnot: Int, n: Int) -> SIMD3<Double> {
        var vx = 0.0, vy = 0.0, vz = 0.0
        OCCTCurve3DBSplineLocalDN(handle, u, Int32(fromKnot), Int32(toKnot), Int32(n),
                                   &vx, &vy, &vz)
        return SIMD3(vx, vy, vz)
    }

    /// Maximum BSpline degree supported (static).
    public static var bsplineMaxDegree: Int { Int(OCCTCurve3DBSplineMaxDegree()) }

    /// Locate the knot span containing parameter u.
    public func bsplineLocateU(_ u: Double, tolerance: Double = 1e-10) -> Int {
        Int(OCCTCurve3DBSplineLocateU(handle, u, tolerance))
    }
}

extension Curve3D {

    /// Whether this curve is bounded (Geom_BoundedCurve subclass).
    public var isBounded: Bool { OCCTCurve3DIsBounded(handle) }
}

extension Curve3D {

    /// Evaluate the N-th derivative at parameter u.
    public func dn(at u: Double, order n: Int) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTCurve3DDN(handle, u, Int32(n), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// The type name of this curve (e.g. "Geom_Line", "Geom_Circle").
    public var typeName: String? {
        guard let ptr = OCCTCurve3DTypeName(handle) else { return nil }
        return String(cString: ptr)
    }
}

extension Curve3D {

    /// The unit tangent direction at a parameter value.
    ///
    /// Equivalent to ``Curve3D/tangentDirection(at:)``.
    ///
    /// - Parameter u: Curve parameter.
    /// - Returns: The unit tangent, or `nil` where every derivative up to order 3 is null.
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
    /// if let t = circle.localTangent(at: 0) { print(t) }   // (0, 1, 0)
    /// ```
    public func localTangent(at u: Double) -> SIMD3<Double>? {
        var tx = 0.0, ty = 0.0, tz = 0.0
        var isDefined = false
        OCCTCurve3DLocalTangent(handle, u, &tx, &ty, &tz, &isDefined)
        return isDefined ? SIMD3(tx, ty, tz) : nil
    }

    /// The principal normal direction at a parameter value.
    ///
    /// Equivalent to ``Curve3D/normal(at:)``.
    ///
    /// - Parameter u: Curve parameter.
    /// - Returns: The normal, or `nil` where the curvature is zero (a straight stretch, or an
    ///   inflection) or infinite (a cusp) — a normal needs a curvature to point away from.
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
    /// let n = circle.localNormal(at: 0)                    // points at the centre
    /// let straight = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))!
    /// #expect(straight.localNormal(at: 0) == nil)          // no curvature, no normal
    /// ```
    public func localNormal(at u: Double) -> SIMD3<Double>? {
        var nx = 0.0, ny = 0.0, nz = 0.0
        var isDefined = false
        OCCTCurve3DLocalNormal(handle, u, &nx, &ny, &nz, &isDefined)
        return isDefined ? SIMD3(nx, ny, nz) : nil
    }

    /// The centre of the osculating circle at a parameter value.
    ///
    /// Equivalent to ``Curve3D/centerOfCurvature(at:)``.
    ///
    /// - Parameter u: Curve parameter.
    /// - Returns: The centre of curvature, or `nil` where the curvature cannot be inverted into a
    ///   radius: zero (straight or inflecting) or infinite (a cusp). Both cases used to return a
    ///   point built from `NaN` and infinity rather than `nil` (#494).
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: SIMD3(1, 2, 0), normal: SIMD3(0, 0, 1), radius: 5)!
    /// let c = circle.localCentreOfCurvature(at: 0)   // (1, 2, 0), the circle's own centre
    /// ```
    public func localCentreOfCurvature(at u: Double) -> SIMD3<Double>? {
        var cx = 0.0, cy = 0.0, cz = 0.0
        var isDefined = false
        OCCTCurve3DLocalCentreOfCurvature(handle, u, &cx, &cy, &cz, &isDefined)
        return isDefined ? SIMD3(cx, cy, cz) : nil
    }
}

extension Curve3D {

    /// Unavailable: this `Int` reported a hand-invented encoding, and the numbers changed
    /// underneath it. Use ``continuityClass`` (named cases) or ``continuity`` (raw ordinal).
    ///
    /// Until #485 this property answered `C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3` — a
    /// scheme of OCCTSwift's own invention that matched neither `GeomAbs_Shape` nor its own doc
    /// comment, and disagreed with ``continuity`` on the same curve for every class except C0.
    /// #485 replaced it with the real `GeomAbs_Shape` ordinal (`C0=0, G1=1, C1=2, G2=3, C2=4,
    /// C3=5, CN=6`).
    ///
    /// Every existing threshold check kept compiling across that change and quietly changed
    /// meaning, which is why the spelling is retired rather than reinterpreted (#619):
    ///
    /// ```swift
    /// // Before: `2` was C2. After: `2` is C1, so a merely tangent-continuous curve passed.
    /// if curve.continuityOrder >= 2 { useAsC2Spline() }
    ///
    /// // The question that idiom meant to ask, asked so it cannot drift again:
    /// if curve.continuityClass.satisfies(.c2) { useAsC2Spline() }
    ///
    /// // And the old `== 99` fast path for analytic geometry, which can never fire again:
    /// if curve.continuityClass == .cN { useAnalyticFastPath() }
    /// ```
    ///
    /// ``continuity`` is the same `Int` under an honest name if a raw ordinal is genuinely what
    /// you want — but it is the *new* ordinal, so re-check any constant compared against it.
    ///
    /// - Important: The retired encoding had an eighth value the tables above do not show. It
    ///   signalled failure out of band, returning `-1` from its `default:` branch and for a null
    ///   or unreadable handle. ``continuity`` has no such sentinel: it returns `0` in the same
    ///   situations, and `0` is an ordinary C0 measurement. A migrated
    ///   `if continuityOrder < 0 { handleError() }` becomes a branch that can never be taken, and
    ///   an unreadable curve now reads as a genuinely C0 one. There is no in-band way to tell the
    ///   two apart; check the handle before asking.
    @available(*, unavailable, message: """
        continuityOrder reported a hand-invented encoding (C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, \
        G2=-3) and #485 changed it to the real GeomAbs_Shape ordinal (C0=0, G1=1, C1=2, G2=3, \
        C2=4, C3=5, CN=6), so every threshold check silently changed meaning. Use \
        continuityClass.satisfies(_:) for a continuity floor, continuityClass == .cN for the \
        analytic fast path, or continuity for the raw ordinal — after re-checking the constant \
        you compare against. Note there is no longer an error sentinel: this returned -1 for a \
        null or unreadable handle, whereas continuity returns 0, which is an ordinary C0, so a \
        migrated `< 0` error check can never fire (#619).
        """)
    public var continuityOrder: Int { Int(OCCTCurve3DGetContinuity(handle)) }

    /// Check if this curve has at least Cn continuity.
    public func isCN(_ n: Int) -> Bool {
        OCCTCurve3DIsCN(handle, Int32(n))
    }

    /// Get the parameter on the reversed curve corresponding to parameter u on this curve.
    public func reversedParameter(_ u: Double) -> Double {
        OCCTCurve3DReversedParameter(handle, u)
    }

    /// Get the parametric transformation scale factor under a geometric transform.
    /// The transform is specified as a 3x3 rotation matrix (row-major) + 3 translation values.
    public func parametricTransformation(rotation: [Double], translation: SIMD3<Double>) -> Double {
        guard rotation.count == 9 else { return 1.0 }
        let trsf12 = rotation + [translation.x, translation.y, translation.z]
        return trsf12.withUnsafeBufferPointer { buf in
            OCCTCurve3DParametricTransformation(handle, buf.baseAddress!)
        }
    }

    /// Resolution for 3D Bezier curves.
    public func bezierResolution(tolerance3d: Double) -> Double {
        OCCTCurve3DBezierResolution(handle, tolerance3d)
    }

    /// Maximum degree for 3D Bezier curves (static).
    public static var bezierMaxDegree: Int { Int(OCCTCurve3DBezierMaxDegree()) }

}

extension Curve3D {

    /// Remove periodicity from BSpline curve.
    @discardableResult
    public func bsplineSetNotPeriodic() -> Bool {
        OCCTCurve3DBSplineSetNotPeriodic(handle)
    }

    /// Set origin knot index (1-based) on periodic BSpline curve.
    @discardableResult
    public func bsplineSetOrigin(index: Int) -> Bool {
        OCCTCurve3DBSplineSetOrigin(handle, Int32(index))
    }

    /// Increase multiplicity of knot at index to at least mult (1-based).
    @discardableResult
    public func bsplineIncreaseMultiplicity(index: Int, multiplicity: Int) -> Bool {
        OCCTCurve3DBSplineIncreaseMultiplicity(handle, Int32(index), Int32(multiplicity))
    }

    /// Increment multiplicity of all knots from index1 to index2 by step (1-based).
    @discardableResult
    public func bsplineIncrementMultiplicity(from: Int, to: Int, step: Int = 1) -> Bool {
        OCCTCurve3DBSplineIncrementMultiplicity(handle, Int32(from), Int32(to), Int32(step))
    }

    /// Set all knot values at once (count must match NbKnots).
    @discardableResult
    public func bsplineSetKnots(_ knots: [Double]) -> Bool {
        OCCTCurve3DBSplineSetKnots(handle, knots, Int32(knots.count))
    }

    /// Reverse parameterization of BSpline curve.
    @discardableResult
    public func bsplineReverse() -> Bool {
        OCCTCurve3DBSplineReverse(handle)
    }

    /// Move point and tangent at parameter u on BSpline curve.
    @discardableResult
    public func bsplineMovePointAndTangent(u: Double, point: SIMD3<Double>, tangent: SIMD3<Double>,
                                           tolerance: Double, poleRange: ClosedRange<Int>) -> Bool {
        OCCTCurve3DBSplineMovePointAndTangent(handle, u, point.x, point.y, point.z,
                                               tangent.x, tangent.y, tangent.z,
                                               tolerance,
                                               Int32(poleRange.lowerBound), Int32(poleRange.upperBound))
    }
}

extension Curve3D {
    /// Get the first parameter of the curve.
    public var firstParameter: Double {
        OCCTCurve3DFirstParameter(handle)
    }

    /// Get the last parameter of the curve.
    public var lastParameter: Double {
        OCCTCurve3DLastParameter(handle)
    }
}
