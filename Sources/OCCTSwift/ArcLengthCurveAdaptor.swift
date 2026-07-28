import Foundation

/// Shared arc-length-adaptor interface implemented by ``EdgeCurve`` and ``WireCurve`` (#211/#212/#422).
///
/// Both types wrap a distinct OCCT curve adaptor behind a distinct bridge handle type
/// (`BRepAdaptor_Curve` for a single edge, `BRepAdaptor_CompCurve` for a multi-edge wire), so they
/// stay separate public classes — but once each type supplies its own native-parameter primitives
/// (`length`, `point(atParameter:)`, `tangent(atParameter:)`, `parameter(atAbscissa:)`,
/// `points(count:)`), the arc-length *composition* built on top of them (looking up a point/tangent
/// by abscissa, converting a spacing into an evenly-divided sample count) is identical for both —
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

    /// The native parameter range `[first, last]` (not arc length — use the `atAbscissa:`
    /// methods for arc-length sampling).
    var parameterRange: (first: Double, last: Double) { get }

    /// Point at a native curve parameter `u` (within ``parameterRange``).
    func point(atParameter u: Double) -> SIMD3<Double>?

    /// Unit tangent (first derivative, normalized) at a native parameter `u`.
    /// `nil` at a degenerate point (e.g. a cusp where the derivative vanishes).
    func tangent(atParameter u: Double) -> SIMD3<Double>?

    /// The native parameter at arc length `s` measured from the start of the curve.
    func parameter(atAbscissa s: Double) -> Double?

    /// `count` points spaced equally by arc length along the curve (`count >= 2`), including both
    /// endpoints. One pass, cheaper than calling ``point(atAbscissa:)`` in a loop.
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

    /// Points spaced approximately `spacing` apart along the curve (by arc length). The exact
    /// step is adjusted so the samples divide the curve evenly end-to-end.
    public func points(spacing: Double) -> [SIMD3<Double>] {
        let len = length
        guard spacing > 0, len > 0 else { return [] }
        let count = max(2, Int((len / spacing).rounded()) + 1)
        return points(count: count)
    }
}
