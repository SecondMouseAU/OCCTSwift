import Foundation
import OCCTBridge

/// A single `Edge` as an **arc-length-parameterized** curve (`BRepAdaptor_Curve`).
///
/// `Edge` already offers `point(at parameter:)` / `tangent(at parameter:)` in the edge's
/// *native* parameter space; `EdgeCurve` adds the arc-length side (`length`,
/// `point(atAbscissa:)`, evenly-spaced sampling), matching ``WireCurve`` for a single edge. (#211/#212)
///
/// The arc-length composition (`point`/`tangent(atAbscissa:)`, `points(spacing:)`) is shared with
/// ``WireCurve`` via ``ArcLengthCurveAdaptor``; see that protocol for the underlying primitives.
///
/// ```swift
/// guard let ec = EdgeCurve(edge) else { return }
/// let mids = ec.points(count: 11)        // 11 points equally spaced along the edge
/// let half = ec.point(atAbscissa: ec.length / 2)
/// ```
public final class EdgeCurve: ArcLengthCurveAdaptor, @unchecked Sendable {
    internal let ref: OCCTEdgeCurveRef

    /// Build an arc-length adaptor over `edge`. Returns `nil` if the edge is invalid (e.g.
    /// has no 3D curve).
    public init?(_ edge: Edge) {
        guard let r = OCCTEdgeCurveCreate(edge.handle) else { return nil }
        ref = r
    }

    deinit { OCCTEdgeCurveRelease(ref) }

    /// Arc length of the edge.
    ///
    /// Measured per `GeomAbs_CN` interval and subdivided to convergence, the same measurement
    /// ``Shape/edgeArcLength`` makes, so the two cannot disagree (#603).
    public var length: Double { OCCTEdgeCurveLength(ref) }

    /// The native parameter range `[first, last]` (not arc length).
    public var parameterRange: (first: Double, last: Double) {
        var first = 0.0
        var last = 0.0
        OCCTEdgeCurveParamRange(ref, &first, &last)
        return (first, last)
    }

    /// Point at a native curve parameter `u`.
    public func point(atParameter u: Double) -> SIMD3<Double>? {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        guard OCCTEdgeCurvePointAtParam(ref, u, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Unit tangent at a native parameter `u` (`nil` at a degenerate point).
    public func tangent(atParameter u: Double) -> SIMD3<Double>? {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        guard OCCTEdgeCurveTangentAtParam(ref, u, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Native parameter at arc length `s` from the start of the edge.
    ///
    /// Walks the same subdivided pieces ``length`` is summed from, so
    /// `parameter(atAbscissa: length)` lands on `parameterRange.last` (#603).
    public func parameter(atAbscissa s: Double) -> Double? {
        var u = 0.0
        guard OCCTEdgeCurveParamAtAbscissa(ref, s, &u) else { return nil }
        return u
    }

    /// `count` points spaced equally by arc length along the edge, endpoints included.
    ///
    /// - Parameter count: Sample count, honoured within `2...`
    ///   ``ArcLengthCurveAdaptor/maximumSampleCount``; outside that range the result is empty
    ///   (#479). Buffer allocation and the count contract are shared with ``WireCurve``.
    ///
    /// ```swift
    /// let ec = EdgeCurve(edge)!
    /// let pts = ec.points(count: 11)                     // 11 points, endpoints included
    /// ec.points(count: EdgeCurve.maximumSampleCount + 1).isEmpty   // true
    /// ```
    public func points(count: Int) -> [SIMD3<Double>] {
        sampledPoints(count: count) { n, buf in OCCTEdgeCurveSampleUniform(ref, n, buf) }
    }

    // point(atAbscissa:), tangent(atAbscissa:), points(spacing:) are supplied by the
    // ArcLengthCurveAdaptor extension: see that protocol.
}
