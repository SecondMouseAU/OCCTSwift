import Foundation
import OCCTBridge

/// A multi-edge Wire treated as a single, continuously-parameterized curve.
/// (BRepAdaptor_CompCurve), so you can measure its total length and sample.
/// **evenly along it by arc length**, walking across edge boundaries seamlessly.
///
/// Useful for placing loft cross-sections along a measured section wire, walking a.
/// prismatic outline at a fixed step, etc (#211).
///
/// The arc-length composition (point/`tangent(atAbscissa:)`, `points(spacing:)`) is shared with
/// `EdgeCurve` via `ArcLengthCurveAdaptor`; see that protocol for the underlying primitives.
///
/// ```swift.
/// guard let wc = WireCurve(sectionWire) else { return }.
/// let n = 20.
/// let pts = (0...n).compactMap { i in.
///     wc.point(atAbscissa: wc.length * Double(i) / Double(n))
/// }   // n+1 points spaced equally along the wire.
/// ```.
public final class WireCurve: ArcLengthCurveAdaptor, @unchecked Sendable {
    internal let ref: OCCTCompCurveRef

    /// Build an arc-length adaptor over wire.
    ///
    /// Returns nil if the wire is empty/invalid.
    public init?(_ wire: Wire) {
        guard let r = OCCTCompCurveCreate(wire.handle) else { return nil }
        ref = r
    }

    deinit { OCCTCompCurveRelease(ref) }

    /// Total arc length of the wire.
    ///
    /// Measured per GeomAbs_CN interval and subdivided to convergence, the same measurement.
    /// ``Wire/length`` makes, so the two cannot disagree (#603).
    public var length: Double { OCCTCompCurveLength(ref) }

    /// The native parameter range `[first, last]` (not arc length, use the.
    /// `atAbscissa:` methods for arc-length sampling).
    public var parameterRange: (first: Double, last: Double) {
        var first = 0.0
        var last = 0.0
        OCCTCompCurveParamRange(ref, &first, &last)
        return (first, last)
    }

    /// Point at a native curve parameter u (within `parameterRange`).
    public func point(atParameter u: Double) -> SIMD3<Double>? {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        guard OCCTCompCurvePointAtParam(ref, u, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Unit tangent (first derivative, normalized) at a native parameter u.
    /// nil at a degenerate point (e.g. a cusp where the derivative vanishes).
    public func tangent(atParameter u: Double) -> SIMD3<Double>? {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        guard OCCTCompCurveTangentAtParam(ref, u, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// The native parameter at arc length s measured from the start of the wire.
    ///
    /// Walks the same subdivided pieces `length` is summed from, so.
    /// `parameter(atAbscissa: length)` lands on `parameterRange.last` (#603).
    public func parameter(atAbscissa s: Double) -> Double? {
        var u = 0.0
        guard OCCTCompCurveParamAtAbscissa(ref, s, &u) else { return nil }
        return u
    }

    /// count points spaced **equally by arc length** along the wire, including both.
    /// endpoints (GCPnts_UniformAbscissa).
    ///
    /// One pass, cheaper than calling.
    /// ``point(atAbscissa:)`` in a loop.
    ///
    /// - Parameter count: Sample count, honoured within `2...`
    ///   ``ArcLengthCurveAdaptor/maximumSampleCount``; outside that range the result is empty.
    ///   (#479).
    ///
    ///   Buffer allocation and the count contract are shared with `EdgeCurve`.
    ///
    /// ```swift.
    /// let wc = WireCurve(wire)!.
    /// let pts = wc.points(count: 21)                     // 21 points, endpoints included
    /// wc.points(count: WireCurve.maximumSampleCount + 1).isEmpty   // true
    /// ```.
    public func points(count: Int) -> [SIMD3<Double>] {
        sampledPoints(count: count) { n, buf in OCCTCompCurveSampleUniform(ref, n, buf) }
    }

    // point(atAbscissa:), tangent(atAbscissa:), points(spacing:) are supplied by the
    // ArcLengthCurveAdaptor extension: see that protocol.
}
