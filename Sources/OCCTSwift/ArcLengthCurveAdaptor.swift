import Foundation

/// Shared arc-length-adaptor interface implemented by ``EdgeCurve`` and ``WireCurve`` (#211/#212/#422).
///
/// Both types wrap a distinct OCCT curve adaptor behind a distinct bridge handle type
/// (`BRepAdaptor_Curve` for a single edge, `BRepAdaptor_CompCurve` for a multi-edge wire), so they
/// stay separate public classes, but once each type supplies its own native-parameter primitives
/// (`length`, `point(atParameter:)`, `tangent(atParameter:)`, `parameter(atAbscissa:)`,
/// `points(count:)`), the arc-length *composition* built on top of them (looking up a point/tangent
/// by abscissa, converting a spacing into an evenly-divided sample count) is identical for both:
/// this protocol's extension supplies that composition exactly once instead of per-type.
///
/// ```swift
/// func firstQuarterPoint(of curve: some ArcLengthCurveAdaptor) -> SIMD3<Double>? {
///     curve.point(atAbscissa: curve.length / 4)
/// }
/// ```
public protocol ArcLengthCurveAdaptor: AnyObject {
    /// Total arc length of the underlying curve.
    var length: Double { get }

    /// The native parameter range `[first, last]` (not arc length, use the `atAbscissa:`
    /// methods for arc-length sampling).
    var parameterRange: (first: Double, last: Double) { get }

    /// Point at a native curve parameter `u` (within ``parameterRange``).
    func point(atParameter u: Double) -> SIMD3<Double>?

    /// Unit tangent (first derivative, normalized) at a native parameter `u`.
    /// `nil` at a degenerate point (e.g. a cusp where the derivative vanishes).
    func tangent(atParameter u: Double) -> SIMD3<Double>?

    /// The native parameter at arc length `s` measured from the start of the curve.
    func parameter(atAbscissa s: Double) -> Double?

    /// `count` points spaced equally by arc length along the curve, including both endpoints.
    /// One pass, cheaper than calling ``point(atAbscissa:)`` in a loop.
    ///
    /// `count` must be at least 2 and at most ``maximumSampleCount``; anything outside that range
    /// returns an empty array (#479).
    func points(count: Int) -> [SIMD3<Double>]
}

extension ArcLengthCurveAdaptor {
    /// Point at arc length `s` from the start of the curve (0...``length``).
    public func point(atAbscissa s: Double) -> SIMD3<Double>? {
        guard let u = parameter(atAbscissa: s) else { return nil }
        return point(atParameter: u)
    }

    /// Unit tangent at arc length `s` from the start of the curve.
    public func tangent(atAbscissa s: Double) -> SIMD3<Double>? {
        guard let u = parameter(atAbscissa: s) else { return nil }
        return tangent(atParameter: u)
    }

    /// The largest sample count either adaptor will produce: ``Sampling/maximumSampleCount``.
    ///
    /// Both ``points(count:)`` and ``points(spacing:)`` return an empty array rather than
    /// attempting a larger request. Declared here by #479 for these two types and now shared with
    /// the other 26 sampling entry points that had the same defect (#558); this stays as the
    /// spelling the adaptors' own documentation uses.
    ///
    /// ```swift
    /// let wc = WireCurve(wire)!
    /// wc.points(spacing: 1e-9).isEmpty      // true: implies 1e11 points, past the ceiling
    /// wc.points(count: WireCurve.maximumSampleCount + 1).isEmpty   // true
    /// ```
    public static var maximumSampleCount: Int { Sampling.maximumSampleCount }

    /// Points spaced approximately `spacing` apart along the curve (by arc length).
    ///
    /// The exact step is adjusted so the samples divide the curve evenly end-to-end.
    ///
    /// - Parameter spacing: Arc-length step, greater than 0. A spacing so small that it implies
    ///   more than ``maximumSampleCount`` points returns an empty array, as do a spacing of 0 or
    ///   less, a NaN spacing, and a curve of zero length (#479). There is no clamping: a request
    ///   the ceiling cannot honour fails visibly rather than coming back silently coarser than
    ///   what was asked for.
    ///
    /// - Returns: An array of points, or an empty array if the request cannot be honoured.
    ///
    /// ```swift
    /// let wc = WireCurve(wire)!          // a 200mm-long wire
    /// let pts = wc.points(spacing: 10)   // 21 points, 10mm apart
    /// wc.points(spacing: 1e-9).isEmpty   // true: 2e11 points is past the ceiling
    /// ```
    public func points(spacing: Double) -> [SIMD3<Double>] {
        guard let count = Sampling.impliedCount(length: length, spacing: spacing) else { return [] }
        return points(count: count)
    }

    /// The shared body of both types' ``points(count:)``: applies the count contract once,
    /// allocates the packed `(x,y,z)` buffer the bridge writes into, and unpacks exactly as many
    /// points as the bridge reports writing.
    ///
    /// - Parameters:
    ///   - count: The requested sample count, honoured only within `2...`
    ///     ``maximumSampleCount``. The lower bound is OCCT's own (`GCPnts_UniformAbscissa`
    ///     documents `nbPoints >= 2` but the Release kernel compiles that precondition out, #501);
    ///     the upper bound is this layer's, since `count` sizes a Swift allocation and is cast to
    ///     the bridge's `int32_t` (#479).
    ///   - sample: The conforming type's own bridge call, taking the count and the buffer and
    ///     returning how many points it wrote.
    ///
    /// - Returns: An array of points, or an empty array if the count is out of bounds.
    internal func sampledPoints(
        count: Int,
        _ sample: (Int32, UnsafeMutablePointer<Double>) -> Int32
    ) -> [SIMD3<Double>] {
        guard let count = Sampling.requested(count) else { return [] }
        var buffer = [Double](repeating: 0, count: count * 3)
        let written = Int(sample(Int32(count), &buffer))
        return unpackSIMD3(buffer, count: written)
    }
}
