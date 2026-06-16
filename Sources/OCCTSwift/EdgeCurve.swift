import Foundation
import OCCTBridge

/// A single `Edge` as an **arc-length-parameterized** curve (`BRepAdaptor_Curve`).
///
/// `Edge` already offers `point(at parameter:)` / `tangent(at parameter:)` in the edge's
/// *native* parameter space; `EdgeCurve` adds the arc-length side — `length`,
/// `point(atAbscissa:)`, evenly-spaced sampling — matching ``WireCurve`` for a single edge. (#211/#212)
///
/// ```swift
/// guard let ec = EdgeCurve(edge) else { return }
/// let mids = ec.points(count: 11)        // 11 points equally spaced along the edge
/// let half = ec.point(atAbscissa: ec.length / 2)
/// ```
public final class EdgeCurve: @unchecked Sendable {
    internal let ref: OCCTEdgeCurveRef

    /// Build an arc-length adaptor over `edge`. Returns `nil` if the edge is invalid (e.g.
    /// has no 3D curve).
    public init?(_ edge: Edge) {
        guard let r = OCCTEdgeCurveCreate(edge.handle) else { return nil }
        ref = r
    }

    deinit { OCCTEdgeCurveRelease(ref) }

    /// Arc length of the edge.
    public var length: Double { OCCTEdgeCurveLength(ref) }

    /// The native parameter range `[first, last]` (not arc length).
    public var parameterRange: (first: Double, last: Double) {
        var first = 0.0, last = 0.0
        OCCTEdgeCurveParamRange(ref, &first, &last)
        return (first, last)
    }

    /// Point at a native curve parameter `u`.
    public func point(atParameter u: Double) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTEdgeCurvePointAtParam(ref, u, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Unit tangent at a native parameter `u` (`nil` at a degenerate point).
    public func tangent(atParameter u: Double) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTEdgeCurveTangentAtParam(ref, u, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Native parameter at arc length `s` from the start of the edge.
    public func parameter(atAbscissa s: Double) -> Double? {
        var u = 0.0
        guard OCCTEdgeCurveParamAtAbscissa(ref, s, &u) else { return nil }
        return u
    }

    /// Point at arc length `s` from the start of the edge (0...``length``).
    public func point(atAbscissa s: Double) -> SIMD3<Double>? {
        guard let u = parameter(atAbscissa: s) else { return nil }
        return point(atParameter: u)
    }

    /// Unit tangent at arc length `s` from the start of the edge.
    public func tangent(atAbscissa s: Double) -> SIMD3<Double>? {
        guard let u = parameter(atAbscissa: s) else { return nil }
        return tangent(atParameter: u)
    }

    /// `count` points spaced equally by arc length along the edge (`count >= 2`), endpoints included.
    public func points(count: Int) -> [SIMD3<Double>] {
        guard count >= 2 else { return [] }
        var buf = [Double](repeating: 0, count: count * 3)
        let n = Int(OCCTEdgeCurveSampleUniform(ref, Int32(count), &buf))
        return (0..<n).map { SIMD3(buf[$0 * 3], buf[$0 * 3 + 1], buf[$0 * 3 + 2]) }
    }

    /// Points spaced approximately `spacing` apart along the edge (by arc length).
    public func points(spacing: Double) -> [SIMD3<Double>] {
        let len = length
        guard spacing > 0, len > 0 else { return [] }
        let count = max(2, Int((len / spacing).rounded()) + 1)
        return points(count: count)
    }
}
