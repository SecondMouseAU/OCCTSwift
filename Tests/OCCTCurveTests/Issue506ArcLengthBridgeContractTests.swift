import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Cover for #506, which deleted three orphaned arc-length bridge functions
/// (`OCCTCurve3DArcLength`, `OCCTCurve3DArcLengthBetween`, `OCCTCurve3DLength`) left unreachable
/// when #408 routed every Swift spelling through `OCCTCurve3DGetLength` /
/// `OCCTCurve3DGetLengthBetween`.
///
/// The deleted ranged function was not a redundant copy. It measured through a *pre-bounded*
/// `GeomAdaptor_Curve(curve, u1, u2)` rather than passing the range to
/// `GCPnts_AbscissaPoint::Length(adaptor, u1, u2)`, and the two forms disagree wherever the range
/// is not an ordinary in-domain interval. Measured against the pinned kernel on the fixture below:
///
/// | range | pre-bounded (deleted) | ranged (live) |
/// |---|---|---|
/// | reversed, in domain | raises, reported as `0` | 173.76 |
/// | overshooting both ends by a domain width | 8489.78 | 360.99 (the curve's own length) |
/// | wholly outside the domain | 1.34 | 0 |
///
/// Nothing exercised any of that: the three functions had no Swift call site and no test, so a
/// future caller rewiring onto one (or copying one as a template) would have reinherited both the
/// `0`-means-failure collapse #408 fixed and the extrapolation #477 fixed, silently. These
/// assertions pin the surviving behaviour on exactly the ranges where the two forms differ.
@Suite("Curve3D ranged arc-length contract after the #506 bridge removal")
struct Issue506ArcLengthBridgeContractTests {

    /// Multi-span interpolated BSpline with sharply varying speed: the shape where the two
    /// adaptor forms diverge most, and the shape a straight line or a single arc cannot detect.
    private func multiSpanCurve() -> Curve3D? {
        Curve3D.interpolate(points: [
            SIMD3(0, 0, 0),
            SIMD3(10, 40, 0),
            SIMD3(20, 0, 0),
            SIMD3(200, 5, 0),
            SIMD3(210, 60, 30),
        ])
    }

    /// Chord-sum reference, so the clamping assertions compare against the curve's real length
    /// rather than against whatever the implementation returns for the whole domain.
    private func polylineLength(
        _ c: Curve3D, from u1: Double, to u2: Double,
        segments: Int = 20_000
    ) -> Double {
        var total = 0.0
        var prev = c.point(at: u1)
        for i in 1...segments {
            let u = u1 + (u2 - u1) * Double(i) / Double(segments)
            let p = c.point(at: u)
            let d = p - prev
            total += (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
            prev = p
        }
        return total
    }

    @Test("A reversed in-domain range measures the span, not zero")
    func reversedRangeMeasuresTheSpan() {
        guard let c = multiSpanCurve() else { return }
        let d = c.domain
        let lo = d.lowerBound + 0.1 * (d.upperBound - d.lowerBound)
        let hi = d.lowerBound + 0.6 * (d.upperBound - d.lowerBound)

        guard let forward = c.length(from: lo, to: hi),
            let reversed = c.length(from: hi, to: lo)
        else {
            Issue.record("both orderings must measure on a valid curve")
            return
        }

        // The pre-bounded adaptor raised Standard_ConstructionError on u1 > u2 and the deleted
        // function's catch turned that into 0, so a reversed range read as a zero-length interval.
        #expect(reversed == forward)
        #expect(reversed > 0)
        #expect(abs(reversed - polylineLength(c, from: lo, to: hi)) < 0.01 * forward)
    }

    @Test("Parameters past both ends clamp to the domain instead of extrapolating")
    func overshootingBothEndsClampsToTheDomain() {
        guard let c = multiSpanCurve(), let whole = c.length else { return }
        let d = c.domain
        let span = d.upperBound - d.lowerBound

        guard let overshot = c.length(from: d.lowerBound - span, to: d.upperBound + span) else {
            Issue.record("an out-of-domain range must still measure")
            return
        }

        // The pre-bounded adaptor evaluated the BSpline's polynomial past its knots: 8489.78
        // against a curve 360.99 long, reported as an ordinary success.
        #expect(overshot == whole)
        #expect(
            abs(overshot - polylineLength(c, from: d.lowerBound, to: d.upperBound)) < 0.01 * whole)
    }

    @Test("A range wholly outside the domain measures zero")
    func rangeOutsideTheDomainMeasuresZero() {
        guard let c = multiSpanCurve() else { return }
        let d = c.domain

        // Clamping both bounds to upperBound leaves an empty interval. The pre-bounded adaptor
        // extrapolated it instead, reporting 1.34 for a range the curve does not occupy.
        #expect(c.length(from: d.upperBound + 1, to: d.upperBound + 2) == 0)
    }

    @Test("All three Swift spellings agree on the ranges that used to diverge")
    func everySpellingAgreesOnDivergentRanges() {
        guard let c = multiSpanCurve() else { return }
        let d = c.domain
        let span = d.upperBound - d.lowerBound
        let cases: [(String, Double, Double)] = [
            ("reversed", d.lowerBound + 0.6 * span, d.lowerBound + 0.1 * span),
            ("overshoot both ends", d.lowerBound - span, d.upperBound + span),
            ("wholly outside", d.upperBound + 1, d.upperBound + 2),
            ("equal parameters", d.lowerBound + 0.3 * span, d.lowerBound + 0.3 * span),
        ]

        // #408 made these three spellings one computation. They shared no code before it: two
        // reached the deleted functions and one reached the surviving pair.
        for (label, u1, u2) in cases {
            guard let canonical = c.length(from: u1, to: u2) else {
                Issue.record("\(label): canonical spelling must measure")
                continue
            }
            #expect(c.arcLength(from: u1, to: u2) == canonical, "\(label)")
            #expect(c.arcLengthBetween(u1, u2) == canonical, "\(label)")
        }
    }
}
