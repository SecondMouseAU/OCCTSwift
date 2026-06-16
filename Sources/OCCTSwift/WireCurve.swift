import Foundation
import OCCTBridge

/// A multi-edge `Wire` treated as a single, continuously-parameterized curve
/// (`BRepAdaptor_CompCurve`) — so you can measure its total length and sample
/// **evenly along it by arc length**, walking across edge boundaries seamlessly.
///
/// Useful for placing loft cross-sections along a measured section wire, walking a
/// prismatic outline at a fixed step, etc. (#211)
///
/// ```swift
/// guard let wc = WireCurve(sectionWire) else { return }
/// let n = 20
/// let pts = (0...n).compactMap { i in
///     wc.point(atAbscissa: wc.length * Double(i) / Double(n))
/// }   // n+1 points spaced equally along the wire
/// ```
public final class WireCurve: @unchecked Sendable {
    internal let ref: OCCTCompCurveRef

    /// Build an arc-length adaptor over `wire`. Returns `nil` if the wire is empty/invalid.
    public init?(_ wire: Wire) {
        guard let r = OCCTCompCurveCreate(wire.handle) else { return nil }
        ref = r
    }

    deinit { OCCTCompCurveRelease(ref) }

    /// Total arc length of the wire.
    public var length: Double { OCCTCompCurveLength(ref) }

    /// The native parameter range `[first, last]` (not arc length — use the
    /// `atAbscissa:` methods for arc-length sampling).
    public var parameterRange: (first: Double, last: Double) {
        var first = 0.0, last = 0.0
        OCCTCompCurveParamRange(ref, &first, &last)
        return (first, last)
    }

    /// Point at a native curve parameter `u` (within ``parameterRange``).
    public func point(atParameter u: Double) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTCompCurvePointAtParam(ref, u, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Unit tangent (first derivative, normalized) at a native parameter `u`.
    /// `nil` at a degenerate point (e.g. a cusp where the derivative vanishes).
    public func tangent(atParameter u: Double) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTCompCurveTangentAtParam(ref, u, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// The native parameter at arc length `s` measured from the start of the wire.
    public func parameter(atAbscissa s: Double) -> Double? {
        var u = 0.0
        guard OCCTCompCurveParamAtAbscissa(ref, s, &u) else { return nil }
        return u
    }

    /// Point at arc length `s` from the start of the wire (0...``length``).
    public func point(atAbscissa s: Double) -> SIMD3<Double>? {
        guard let u = parameter(atAbscissa: s) else { return nil }
        return point(atParameter: u)
    }

    /// Unit tangent at arc length `s` from the start of the wire.
    public func tangent(atAbscissa s: Double) -> SIMD3<Double>? {
        guard let u = parameter(atAbscissa: s) else { return nil }
        return tangent(atParameter: u)
    }

    /// `count` points spaced **equally by arc length** along the wire (`count >= 2`),
    /// including both endpoints — `GCPnts_UniformAbscissa`. One pass, cheaper than calling
    /// ``point(atAbscissa:)`` in a loop.
    public func points(count: Int) -> [SIMD3<Double>] {
        guard count >= 2 else { return [] }
        var buf = [Double](repeating: 0, count: count * 3)
        let n = Int(OCCTCompCurveSampleUniform(ref, Int32(count), &buf))
        return (0..<n).map { SIMD3(buf[$0 * 3], buf[$0 * 3 + 1], buf[$0 * 3 + 2]) }
    }

    /// Points spaced approximately `spacing` apart along the wire (by arc length). The exact
    /// step is adjusted so the samples divide the wire evenly end-to-end.
    public func points(spacing: Double) -> [SIMD3<Double>] {
        let len = length
        guard spacing > 0, len > 0 else { return [] }
        let count = max(2, Int((len / spacing).rounded()) + 1)
        return points(count: count)
    }
}
