import Testing
import Foundation
import simd
@testable import OCCTSwift

/// Cover for #600: a finite parameter range reaching outside the curve's domain.
///
/// The documented contract — "parameters outside the curve's domain are clamped to it, so a range
/// wholly outside measures `0`" — came out of #477, which measured it on an interpolated BSpline.
/// It held only for curves with more than one `GeomAbs_CN` interval, because that is the only
/// GCPnts branch which intersects the requested range with the curve's own knots. Everything else
/// measured the range as given: a 10-long segment reported 20 over `[0, 20]`, and a Bezier 122.14
/// long reported 1002.29 one domain width past its end — the polynomial extrapolation #477 removed
/// from the other spelling.
///
/// The rule is now applied in the bridge rather than left to whichever branch a curve's type takes:
/// **a ranged arc length measures the part of the range that lies on the curve**, and a curve whose
/// domain covers a whole period exists at every parameter, so its range is measured in full and
/// winds. Measured over `[f, l + span]` (`Scripts/repro/600-out-of-domain-length/`):
///
/// | curve | was | now |
/// |---|---|---|
/// | segment, 10 long | 20 | 10 |
/// | Bezier, 122.14 long | 1002.29 | 122.14 |
/// | arc, half a circle | 31.42 | 15.71 |
/// | multi-span BSpline | 528.75 | 528.75 |
/// | circle | 62.83 | 62.83 |
/// | periodic BSpline, one period long | 548.51 | 1097.02 |
///
/// The last row is why "confine unless periodic" was not enough on its own: a periodic *composite*
/// curve is both, so GCPnts confined it to one period and silently returned half of what was asked
/// for. Winding is computed in the bridge now, not delegated.
@Suite("An out-of-domain range measures the curve, not its extrapolation (#600)")
struct Issue600OutOfDomainRangeTests {

    private func multiSpanCurve() -> Curve3D? {
        Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(100, 50, 0), SIMD3(150, -60, 40),
            SIMD3(250, 30, -20), SIMD3(300, 0, 60)
        ])
    }

    private func periodicCurve() -> Curve3D? {
        Curve3D.interpolatePeriodic(points: [
            SIMD3(0, 0, 0), SIMD3(100, 40, 0), SIMD3(160, -30, 20),
            SIMD3(60, -90, -10), SIMD3(-40, -30, 30)
        ])
    }

    /// Chord sum over the range *as the curve evaluates it* — so it winds on a periodic curve and
    /// extrapolates on a polynomial one. Used only where the two should agree.
    private func tracedLength(_ c: Curve3D, from u1: Double, to u2: Double,
                              segments: Int = 20_000) -> Double {
        var total = 0.0
        var prev = c.point(at: u1)
        for i in 1...segments {
            let p = c.point(at: u1 + (u2 - u1) * Double(i) / Double(segments))
            let d = p - prev
            total += (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
            prev = p
        }
        return total
    }

    // MARK: - Curves that stop where their domain stops

    @Test("A segment measures its own length past the end, not the line's extension")
    func segmentDoesNotExtendPastItsTrim() {
        guard let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)),
              let whole = seg.length else { return }
        let d = seg.domain
        let span = d.upperBound - d.lowerBound

        #expect(abs(whole - 10) < 1e-9)
        // Was 20: |u2 - u1| * 1.0, with nothing confining it to the trim.
        #expect(seg.length(from: d.lowerBound, to: d.upperBound + span) == whole)
        #expect(seg.length(from: d.lowerBound - span, to: d.upperBound + span) == whole)
        // Was 10 — the whole length, for a range the curve does not occupy at all.
        #expect(seg.length(from: d.upperBound + span, to: d.upperBound + 2 * span) == 0)
        #expect(seg.length(from: d.lowerBound - 2 * span, to: d.lowerBound - span) == 0)
        // The sentinel spellings follow.
        #expect(seg.arcLength(from: d.upperBound + span, to: d.upperBound + 2 * span) == 0)
        #expect(seg.arcLengthBetween(d.lowerBound, d.upperBound + span) == whole)
    }

    @Test("A Bezier is not evaluated past its poles")
    func bezierDoesNotExtrapolate() {
        guard let bez = Curve3D.bezier(poles: [
            SIMD3(0, 0, 0), SIMD3(30, 60, 0), SIMD3(70, -40, 20), SIMD3(100, 0, 0)
        ]), let whole = bez.length else { return }
        let d = bez.domain
        let span = d.upperBound - d.lowerBound

        // Was 1002.29 for a curve 122.14 long, and 3582.87 for a range wholly outside it.
        #expect(bez.length(from: d.lowerBound, to: d.upperBound + span) == whole)
        #expect(bez.length(from: d.upperBound + span, to: d.upperBound + 2 * span) == 0)
        #expect(whole > 100 && whole < 200)
    }

    @Test("An arc stops at its trim, even though its basis circle is periodic")
    func trimmedArcDoesNotFinishTheCircle() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5),
              let arc = circle.trimmed(from: 0, to: .pi),
              let whole = arc.length else { return }

        // The adaptor reports IsPeriodic() == true here — a Geom_TrimmedCurve inherits its basis
        // curve's periodicity — so periodicity alone cannot be the test. Its domain covers half a
        // period, and the half the caller trimmed away is not part of this curve.
        #expect(abs(whole - 5 * Double.pi) < 1e-6)
        #expect(arc.length(from: 0, to: 2 * .pi) == whole)          // was 31.42, the full circle
        #expect(arc.length(from: 2 * .pi, to: 3 * .pi) == 0)        // was 15.71
    }

    @Test("A multi-span BSpline keeps the behaviour #477 and #506 pinned")
    func multiSpanBSplineIsUnchanged() {
        guard let c = multiSpanCurve(), let whole = c.length else { return }
        let d = c.domain
        let span = d.upperBound - d.lowerBound

        #expect(c.length(from: d.lowerBound - span, to: d.upperBound + span) == whole)
        #expect(c.length(from: d.upperBound + 1, to: d.upperBound + 2) == 0)
        #expect(c.length(from: d.lowerBound, to: d.upperBound) == whole)
    }

    // MARK: - Curves whose domain covers a period, which really do travel the whole range

    @Test("A circle still winds: two periods measure two circumferences")
    func circleStillWinds() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5),
              let whole = circle.length else { return }

        // Confining would have been a regression here: the curve is periodic, and the range says
        // "go round twice".
        #expect(abs(whole - 10 * Double.pi) < 1e-6)
        if let two = circle.length(from: 0, to: 4 * .pi) {
            #expect(abs(two - 2 * whole) < 1e-6)
        }
        if let three = circle.length(from: -2 * .pi, to: 4 * .pi) {
            #expect(abs(three - 3 * whole) < 1e-6)
        }
        // A range wholly outside the domain is still on the curve, one turn further round.
        if let shifted = circle.length(from: 4 * .pi, to: 6 * .pi) {
            #expect(abs(shifted - whole) < 1e-6)
        }
        // Half a turn, wherever it starts.
        if let half = circle.length(from: 6 * .pi, to: 7 * .pi) {
            #expect(abs(half - whole / 2) < 1e-6)
        }
    }

    @Test("An ellipse winds too, in whole multiples of its own measured length")
    func ellipseWinds() {
        guard let ellipse = Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1),
                                            majorRadius: 8, minorRadius: 3),
              let whole = ellipse.length else { return }

        // Compared against the curve's own whole-domain measurement rather than an independent
        // reference: GCPnts integrates a single-span conic with one quadrature over the whole
        // domain and lands 0.34% high on this ellipse (36.4894 against a true 36.36686), which is
        // an accuracy question of its own and not what this test is about.
        if let two = ellipse.length(from: 0, to: 4 * .pi) {
            #expect(abs(two - 2 * whole) < 1e-6 * whole)
        }
        if let one = ellipse.length(from: 2 * .pi, to: 4 * .pi) {
            #expect(abs(one - whole) < 1e-6 * whole)
        }
    }

    @Test("A periodic BSpline no longer stops silently at one period")
    func periodicBSplineWindsInsteadOfStopping() {
        guard let c = periodicCurve(), let whole = c.length else { return }
        let d = c.domain
        let period = d.upperBound - d.lowerBound

        // Was `whole`: the curve is periodic *and* composite, so GCPnts confined the range to the
        // knots and returned one period for a request of two — less than was asked for, with no
        // failure reported.
        guard let two = c.length(from: d.lowerBound, to: d.lowerBound + 2 * period) else {
            Issue.record("a periodic curve must measure a two-period range")
            return
        }
        #expect(abs(two - 2 * whole) < 1e-6 * whole)
        #expect(two > 1.5 * whole)

        // Against an independent reference, since this row is a behaviour change rather than a
        // preserved one: the chord sum evaluates the curve itself, winding included.
        let traced = tracedLength(c, from: d.lowerBound, to: d.lowerBound + 2 * period)
        #expect(abs(two - traced) < 0.01 * traced)

        // A range wholly past the end is one more turn, not nothing.
        if let past = c.length(from: d.upperBound, to: d.upperBound + period) {
            #expect(abs(past - whole) < 1e-6 * whole)
        }
        // And a partial range crossing the seam measures once, not twice.
        if let seam = c.length(from: d.upperBound - period / 4, to: d.upperBound + period / 4) {
            #expect(abs(seam - whole / 2) < 0.05 * whole)
        }
    }

    // MARK: - The same rule in 2D and on an edge

    @Test("Curve2D answers an out-of-domain range the way Curve3D does")
    func curve2DMatchesCurve3D() {
        guard let seg2 = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)),
              let circle2 = Curve2D.circle(center: .zero, radius: 5),
              let spline2 = Curve2D.interpolate(through: [
                  SIMD2(0, 0), SIMD2(100, 50), SIMD2(150, -60), SIMD2(250, 30), SIMD2(300, 0)
              ]) else {
            Issue.record("2D fixtures must build")
            return
        }

        if let whole = seg2.length {
            #expect(seg2.length(from: 0, to: 20) == whole)        // was 20
            #expect(seg2.length(from: 20, to: 30) == 0)           // was 10
            #expect(seg2.arcLength(from: 0, to: 20) == whole)     // was 20, via the other spelling
            #expect(seg2.arcLength(from: 20, to: 30) == 0)
        }
        if let whole = circle2.length, let two = circle2.length(from: 0, to: 4 * .pi) {
            #expect(abs(two - 2 * whole) < 1e-6)                  // still winds
            #expect(abs(circle2.arcLength(from: 0, to: 4 * .pi) - 2 * whole) < 1e-6)
        }
        if let whole = spline2.length {
            let d = spline2.domain
            let span = d.upperBound - d.lowerBound
            #expect(spline2.length(from: d.lowerBound, to: d.upperBound + span) == whole)
            // The pre-bounded spelling used to extrapolate here: 4771.88 for a curve 457.26 long.
            #expect(abs(spline2.arcLength(from: d.lowerBound, to: d.upperBound + span) - whole)
                    < 1e-6 * whole)
        }
    }

    @Test("An edge answers the same as the curve it was built from")
    func edgeMatchesItsCurve() {
        guard let straight = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0)),
              let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5),
              let circleEdge = Shape.edgeFromCurve(circle),
              let periodic = periodicCurve(),
              let periodicEdge = Shape.edgeFromCurve(periodic) else {
            Issue.record("edge fixtures must build")
            return
        }

        let sd = straight.edgeAdaptorDomain
        let sspan = sd.upperBound - sd.lowerBound
        #expect(abs(straight.edgeArcLength(from: sd.lowerBound, to: sd.upperBound + sspan)
                    - straight.edgeArcLength) < 1e-9)                       // was 20
        #expect(straight.edgeArcLength(from: sd.upperBound + sspan,
                                       to: sd.upperBound + 2 * sspan) == 0) // was 10

        let cwhole = circleEdge.edgeArcLength
        #expect(abs(circleEdge.edgeArcLength(from: 0, to: 4 * .pi) - 2 * cwhole) < 1e-6)

        let pd = periodicEdge.edgeAdaptorDomain
        let period = pd.upperBound - pd.lowerBound
        let pwhole = periodicEdge.edgeArcLength
        // Was one period, the same silent stop as the curve spelling.
        #expect(abs(periodicEdge.edgeArcLength(from: pd.lowerBound,
                                               to: pd.lowerBound + 2 * period) - 2 * pwhole)
                < 1e-6 * pwhole)
    }

    // MARK: - Nothing in-domain moved

    @Test("In-domain measurements are untouched")
    func inDomainRangesAreUnchanged() {
        guard let c = multiSpanCurve(), let whole = c.length,
              let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5),
              let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else { return }
        let d = c.domain
        let span = d.upperBound - d.lowerBound

        #expect(c.length(from: d.lowerBound, to: d.upperBound) == whole)
        if let half = c.length(from: d.lowerBound, to: d.lowerBound + span / 2) {
            let traced = tracedLength(c, from: d.lowerBound, to: d.lowerBound + span / 2)
            #expect(abs(half - traced) < 0.01 * traced)
        }
        // Order tolerance and the zero-width interval, both from #506/#408.
        let lo = d.lowerBound + 0.1 * span, hi = d.lowerBound + 0.6 * span
        #expect(c.length(from: hi, to: lo) == c.length(from: lo, to: hi))
        #expect(c.length(from: hi, to: hi) == 0)
        #expect(seg.length(from: 2, to: 7) == 5)
        if let quarter = circle.length(from: 0, to: .pi / 2), let whole = circle.length {
            #expect(abs(quarter - whole / 4) < 1e-6)
        }
        // And the #548 guard is still in front of all of it.
        #expect(c.length(from: d.lowerBound, to: .nan) == nil)
    }
}
