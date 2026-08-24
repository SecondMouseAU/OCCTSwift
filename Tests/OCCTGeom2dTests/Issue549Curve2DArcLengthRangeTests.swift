import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Cover for #549, which removed `OCCTCurve2DLength` and routed `Curve2D.arcLength(from:to:)`
/// through `OCCTCurve2DGetLengthBetween`, the same collapse #506 performed on the 3D spelling.
///
/// The removed function measured through a *pre-bounded* `Geom2dAdaptor_Curve(curve, u1, u2)`
/// instead of passing the range to `GCPnts_AbscissaPoint::Length(adaptor, u1, u2)`. The issue was
/// filed as a consistency question (2D rejected a reversed range where 3D measured it), but
/// measuring the pair against the pinned kernel made it a correctness one as well. On a 5-point
/// 2D interpolation (domain `[0, 318.433]`, true length 353.508):
///
/// | range | pre-bounded (removed) | ranged (live) |
/// |---|---|---|
/// | reversed, in domain | raises, reported as `-1.0` | 169.457 |
/// | overshooting both ends by a domain width | 8082.404 | 353.508 |
/// | wholly outside the domain | 1.259 | 0 |
///
/// So the old spelling extrapolated a 353-unit curve to 8082 and reported it as an ordinary
/// success, the same defect #477 removed from the 3D path, still live in 2D because the two
/// dimensions were fixed one at a time. These assertions pin the surviving behaviour on exactly
/// the ranges where the two forms differ, and check the 2D and 3D answers against each other.
@Suite("Curve2D ranged arc-length contract after the #549 bridge removal")
struct Issue549Curve2DArcLengthRangeTests {

    /// Multi-span interpolated BSpline with sharply varying speed: the shape where the two
    /// adaptor forms diverge, and the shape a line or a single arc cannot detect. The 3D twin
    /// carries the same points in the z = 0 plane so the two dimensions are comparable.
    private static let planarPoints: [SIMD2<Double>] = [
        SIMD2(0, 0), SIMD2(10, 40), SIMD2(20, 0), SIMD2(200, 5), SIMD2(210, 60),
    ]

    private func multiSpanCurve() -> Curve2D? {
        Curve2D.interpolate(through: Self.planarPoints)
    }

    private func multiSpanCurve3D() -> Curve3D? {
        Curve3D.interpolate(points: Self.planarPoints.map { SIMD3($0.x, $0.y, 0) })
    }

    /// Chord-sum reference, so the clamping assertions compare against the curve's real length
    /// rather than against whatever the implementation happens to return for the whole domain.
    private func polylineLength(
        _ c: Curve2D, from u1: Double, to u2: Double,
        segments: Int = 20_000
    ) -> Double {
        var total = 0.0
        var prev = c.point(at: u1)
        for i in 1...segments {
            let u = u1 + (u2 - u1) * Double(i) / Double(segments)
            let p = c.point(at: u)
            total += simd_distance(p, prev)
            prev = p
        }
        return total
    }

    @Test("A reversed in-domain range measures the span, not the failure sentinel")
    func reversedRangeMeasuresTheSpan() {
        guard let c = multiSpanCurve() else {
            Issue.record("the interpolation must build")
            return
        }
        let d = c.domain
        let lo = d.lowerBound + 0.1 * (d.upperBound - d.lowerBound)
        let hi = d.lowerBound + 0.6 * (d.upperBound - d.lowerBound)

        // The pre-bounded adaptor raised Standard_ConstructionError on u1 > u2 and the bridge's
        // catch turned that into -1.0, so a reversed range read as a failed measurement.
        let reversed = c.arcLength(from: hi, to: lo)
        let forward = c.arcLength(from: lo, to: hi)
        #expect(reversed != -1.0)
        #expect(reversed == forward)
        #expect(abs(reversed - polylineLength(c, from: lo, to: hi)) < 0.01 * forward)
    }

    @Test("A reversed range on a single-span curve measures the span too")
    func reversedRangeOnBezierMeasuresTheSpan() {
        guard let bez = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)]) else {
            Issue.record("the Bezier must build")
            return
        }
        // #409's suite pinned this exact range as returning -1.0. It is a measurement now.
        let reversed = bez.arcLength(from: 0.8, to: 0.2)
        #expect(reversed != -1.0)
        #expect(abs(reversed - bez.arcLength(from: 0.2, to: 0.8)) < 1e-9)
        #expect(abs(reversed - polylineLength(bez, from: 0.2, to: 0.8)) < 1e-4)
    }

    @Test("Parameters past both ends clamp to the domain instead of extrapolating")
    func overshootingBothEndsClampsToTheDomain() {
        guard let c = multiSpanCurve(), let whole = c.length else {
            Issue.record("the interpolation must build and measure")
            return
        }
        let d = c.domain
        let span = d.upperBound - d.lowerBound

        // The pre-bounded adaptor evaluated the BSpline's polynomial past its knots: 8082.404
        // against a curve 353.508 long, reported as an ordinary success rather than a failure.
        let overshot = c.arcLength(from: d.lowerBound - span, to: d.upperBound + span)
        #expect(overshot == whole)
        #expect(
            abs(overshot - polylineLength(c, from: d.lowerBound, to: d.upperBound)) < 0.01 * whole)
    }

    @Test("A range wholly outside the domain measures zero, not a fragment of the extrapolation")
    func rangeOutsideTheDomainMeasuresZero() {
        guard let c = multiSpanCurve() else {
            Issue.record("the interpolation must build")
            return
        }
        let d = c.domain
        // Clamping both bounds to upperBound leaves an empty interval. The pre-bounded adaptor
        // extrapolated it instead, reporting 1.259 for a range the curve does not occupy.
        #expect(c.arcLength(from: d.upperBound + 1, to: d.upperBound + 2) == 0)
    }

    @Test("Equal parameters are still a genuine zero, not the failure sentinel")
    func equalParametersMeasureZero() {
        guard let c = multiSpanCurve() else {
            Issue.record("the interpolation must build")
            return
        }
        let d = c.domain
        let mid = d.lowerBound + 0.3 * (d.upperBound - d.lowerBound)
        let len = c.arcLength(from: mid, to: mid)
        #expect(abs(len) < 1e-9)
        #expect(len != -1.0)
    }

    @Test("The -1.0 sentinel still reports a genuine failure")
    func genuineFailureIsStillTheSentinel() {
        guard let bez = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)]) else {
            Issue.record("the Bezier must build")
            return
        }
        // Dropping the range check does not make every input measurable: a NaN bound poisons the
        // quadrature on a single-span curve, which the bridge's `l >= 0` guard reports as failure.
        // (On a multi-span curve NaN lands on a domain bound instead; the 3D half of that is
        // #548, and this path now shares it.)
        #expect(bez.arcLength(from: 0, to: .nan) == -1.0)
        #expect(bez.length(from: 0, to: .nan) == nil)
    }

    @Test("The two spellings are one computation, on the ranges that used to diverge")
    func bothSpellingsAgreeOnDivergentRanges() {
        guard let c = multiSpanCurve() else {
            Issue.record("the interpolation must build")
            return
        }
        let d = c.domain
        let span = d.upperBound - d.lowerBound
        let cases: [(String, Double, Double)] = [
            ("reversed", d.lowerBound + 0.6 * span, d.lowerBound + 0.1 * span),
            ("overshoot both ends", d.lowerBound - span, d.upperBound + span),
            ("wholly outside", d.upperBound + 1, d.upperBound + 2),
            ("equal parameters", d.lowerBound + 0.3 * span, d.lowerBound + 0.3 * span),
        ]

        for (label, u1, u2) in cases {
            guard let canonical = c.length(from: u1, to: u2) else {
                Issue.record("\(label): the canonical spelling must measure")
                continue
            }
            #expect(c.arcLength(from: u1, to: u2) == canonical, "\(label)")
        }
    }

    @Test("2D and 3D answer the same on a reversed and an out-of-domain range")
    func twoDAndThreeDAgree() {
        guard let c2 = multiSpanCurve(), let c3 = multiSpanCurve3D() else {
            Issue.record("both interpolations must build")
            return
        }
        // The two interpolations run through the same points in the same plane, so their domains
        // and lengths match; before #549 only the answers differed, and only on these ranges.
        let d2 = c2.domain
        let d3 = c3.domain
        #expect(abs((d2.upperBound - d2.lowerBound) - (d3.upperBound - d3.lowerBound)) < 1e-6)

        let span = d2.upperBound - d2.lowerBound
        let fractions: [(String, Double, Double)] = [
            ("reversed", 0.6, 0.1),
            ("overshoot both ends", -1.0, 2.0),
            ("wholly outside", 1.1, 1.2),
        ]
        for (label, f1, f2) in fractions {
            let a2 = c2.arcLength(from: d2.lowerBound + f1 * span, to: d2.lowerBound + f2 * span)
            let a3 = c3.arcLength(from: d3.lowerBound + f1 * span, to: d3.lowerBound + f2 * span)
            #expect(a2 != -1.0, "\(label): 2D must measure")
            #expect(a3 != -1.0, "\(label): 3D must measure")
            #expect(abs(a2 - a3) < 1e-6 * max(1.0, abs(a3)), "\(label)")
        }
    }
}
