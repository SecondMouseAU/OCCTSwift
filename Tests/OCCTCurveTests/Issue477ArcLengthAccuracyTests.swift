import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Regression cover for #477: `Curve3D.length` / `length(from:to:)` integrated arc length with
/// `CPnts_AbscissaPoint::Length`, a single Gauss quadrature across the whole parameter domain.
/// On a multi-span BSpline that is wrong by up to several percent with no error signalled.
/// The bridge now uses `GCPnts_AbscissaPoint::Length`, which splits the curve at its `GeomAbs_CN`
/// interval boundaries and integrates each span.
///
/// Every assertion here is against an **independently computed** reference (a densely sampled
/// polyline, Richardson-extrapolated), never against whatever the implementation happens to
/// return, so the suite fails on the old integrator rather than ratifying it.
@Suite("Curve3D arc-length accuracy on multi-span curves (#477)")
struct Issue477ArcLengthAccuracyTests {

    // MARK: - Independent reference

    /// Summed chord length of `segments` evenly spaced parameter samples.
    private func polylineLength(_ c: Curve3D, from u1: Double, to u2: Double, segments: Int)
        -> Double
    {
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

    /// Chord-sum arc length converges from below as O(h²), so two sample densities Richardson-
    /// extrapolate to a reference far tighter than either: `L ≈ L₂ₙ + (L₂ₙ − Lₙ) / 3`.
    private func referenceLength(
        _ c: Curve3D, from u1: Double, to u2: Double,
        segments n: Int = 20_000
    ) -> Double {
        let coarse = polylineLength(c, from: u1, to: u2, segments: n)
        let fine = polylineLength(c, from: u1, to: u2, segments: 2 * n)
        return fine + (fine - coarse) / 3
    }

    // MARK: - Fixtures

    /// 40 interpolated points with sharply varying speed (cubic acceleration in x) and a zigzag
    /// in y, 39 `GeomAbs_CN` spans: the ordinary shape of an interpolated toolpath or an
    /// imported spline. The old integrator was ~5% low on this curve.
    private func zigzagCurve() -> Curve3D? {
        var pts: [SIMD3<Double>] = []
        for i in 0..<40 {
            let s = Double(i) / 39.0
            pts.append(
                SIMD3(
                    100.0 * s * s * s,
                    i.isMultiple(of: 2) ? 0.0 : 8.0,
                    5.0 * sin(6.0 * .pi * s)))
        }
        return Curve3D.interpolate(points: pts)
    }

    /// 60 interpolated points along three turns of a helix, 59 spans, smooth and constant-speed,
    /// where the old integrator was only 3.9e-6 out relative. Included so the suite covers a
    /// benign multi-span curve as well as a pathological one.
    private func helixCurve() -> Curve3D? {
        var pts: [SIMD3<Double>] = []
        for i in 0..<60 {
            let t = 2.0 * .pi * 3.0 * Double(i) / 59.0
            pts.append(SIMD3(10.0 * cos(t), 10.0 * sin(t), 2.0 * t))
        }
        return Curve3D.interpolate(points: pts)
    }

    // MARK: - Tests

    @Test("length of a multi-span interpolated BSpline matches an independent reference")
    func multiSpanLengthMatchesReference() {
        guard let curve = zigzagCurve() else {
            Issue.record("interpolation of the 40-point zigzag failed")
            return
        }
        let d = curve.domain
        let reference = referenceLength(curve, from: d.lowerBound, to: d.upperBound)

        if let measured = curve.length {
            let relative = abs(measured - reference) / reference
            // Measured: 2.9e-7 with the composite integrator, 5.1e-2 with the whole-domain
            // quadrature it replaced. 1e-5 keeps 35x headroom over the former (and over the
            // reference's own residual error) while still failing the latter by 5000x.
            #expect(
                relative < 1e-5,
                "length \(measured) is \(relative * 100)% away from reference \(reference)")
        } else {
            Issue.record("length returned nil on a valid interpolated BSpline")
        }
    }

    @Test("length(from:to:) over a sub-range matches an independent reference")
    func multiSpanRangedLengthMatchesReference() {
        guard let curve = zigzagCurve() else {
            Issue.record("interpolation of the 40-point zigzag failed")
            return
        }
        let d = curve.domain
        let span = d.upperBound - d.lowerBound
        let u1 = d.lowerBound + span / 3
        let u2 = d.lowerBound + 2 * span / 3
        let reference = referenceLength(curve, from: u1, to: u2)

        if let measured = curve.length(from: u1, to: u2) {
            let relative = abs(measured - reference) / reference
            // The ranged overload had the identical defect: measured 4.8e-10 now, 2.2e-2 before.
            #expect(
                relative < 1e-5,
                "length(from:to:) \(measured) is \(relative * 100)% away from reference \(reference)"
            )
        } else {
            Issue.record("length(from:to:) returned nil on a valid interpolated BSpline")
        }
    }

    @Test("all five arc-length spellings agree with the same independent reference")
    func everyArcLengthSpellingMatchesReference() {
        guard let curve = zigzagCurve() else {
            Issue.record("interpolation of the 40-point zigzag failed")
            return
        }
        let d = curve.domain
        let span = d.upperBound - d.lowerBound
        let u1 = d.lowerBound + span / 4
        let u2 = d.lowerBound + 3 * span / 4

        let wholeReference = referenceLength(curve, from: d.lowerBound, to: d.upperBound)
        let rangedReference = referenceLength(curve, from: u1, to: u2)

        // `totalArcLength` / `arcLength(from:to:)` / `arcLengthBetween(_:_:)` reach the composite
        // integrator by their own bridge calls today and via `length` / `length(from:to:)` once
        // #408 lands; asserting each against the reference holds either way.
        #expect(abs(curve.totalArcLength - wholeReference) / wholeReference < 1e-5)
        #expect(abs(curve.arcLength(from: u1, to: u2) - rangedReference) / rangedReference < 1e-5)
        #expect(abs(curve.arcLengthBetween(u1, u2) - rangedReference) / rangedReference < 1e-5)

        if let length = curve.length {
            #expect(abs(length - wholeReference) / wholeReference < 1e-5)
        }
        if let ranged = curve.length(from: u1, to: u2) {
            #expect(abs(ranged - rangedReference) / rangedReference < 1e-5)
        }
    }

    @Test("a smooth 59-span interpolated helix matches an independent reference")
    func interpolatedHelixMatchesReference() {
        guard let curve = helixCurve() else {
            Issue.record("interpolation of the 60-point helix failed")
            return
        }
        let d = curve.domain
        let reference = referenceLength(curve, from: d.lowerBound, to: d.upperBound)

        if let measured = curve.length {
            // Measured 4.3e-15 now, 3.9e-6 before: a smooth curve is where the two integrators
            // come closest, so this is the tightest bound the suite can draw between them.
            #expect(
                abs(measured - reference) / reference < 1e-8,
                "helix length \(measured) vs reference \(reference)")
        } else {
            Issue.record("length returned nil on a valid interpolated helix")
        }
    }

    @Test("analytic curves stay exact")
    func analyticCurvesStayExact() {
        // Both integrators are exact on these; the assertions guard the swap itself.
        if let segment = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0)) {
            if let l = segment.length {
                #expect(abs(l - 5.0) < 1e-9)
            } else {
                Issue.record("length returned nil on a line segment")
            }
        }

        if let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 7) {
            if let l = circle.length {
                #expect(abs(l - 2 * .pi * 7) < 1e-9)
            } else {
                Issue.record("length returned nil on a circle")
            }
            let d = circle.domain
            if let half = circle.length(from: d.lowerBound, to: d.lowerBound + .pi) {
                #expect(abs(half - .pi * 7) < 1e-9)
            }
        }
    }

    @Test("a zero-width parameter interval still reports exactly zero")
    func zeroWidthIntervalIsZero() {
        guard let curve = zigzagCurve() else {
            Issue.record("interpolation of the 40-point zigzag failed")
            return
        }
        let d = curve.domain
        let mid = (d.lowerBound + d.upperBound) / 2
        #expect(curve.length(from: mid, to: mid) == 0.0)
    }

    @Test("a reversed parameter range reports the same length as the forward one")
    func reversedRangeMatchesForward() {
        guard let curve = zigzagCurve() else {
            Issue.record("interpolation of the 40-point zigzag failed")
            return
        }
        let d = curve.domain
        let span = d.upperBound - d.lowerBound
        let u1 = d.lowerBound + span / 4
        let u2 = d.lowerBound + 3 * span / 4
        if let forward = curve.length(from: u1, to: u2),
            let reversed = curve.length(from: u2, to: u1)
        {
            #expect(abs(forward - reversed) < 1e-9)
        } else {
            Issue.record("length(from:to:) returned nil on a valid sub-range")
        }
    }

    @Test("out-of-domain parameters clamp to the curve domain instead of extrapolating")
    func outOfDomainParametersClamp() {
        guard let curve = zigzagCurve() else {
            Issue.record("interpolation of the 40-point zigzag failed")
            return
        }
        let d = curve.domain
        let span = d.upperBound - d.lowerBound

        // The old whole-domain quadrature evaluated the BSpline's polynomial extension outside
        // its knots and returned a length many times the curve's own (2711 for a 56-unit curve).
        // The composite integrator clamps to the domain, which is the safer reading of a caller
        // that overshot.
        guard let whole = curve.length else {
            Issue.record("length returned nil on a valid interpolated BSpline")
            return
        }
        if let overshot = curve.length(from: d.lowerBound - span, to: d.upperBound + span) {
            #expect(
                abs(overshot - whole) < 1e-6,
                "overshooting both ends gave \(overshot), expected the domain length \(whole)")
        } else {
            Issue.record("length(from:to:) returned nil for out-of-domain parameters")
        }
        if let outside = curve.length(from: d.upperBound + span, to: d.upperBound + 2 * span) {
            #expect(
                outside == 0.0,
                "a range wholly outside the domain gave \(outside), expected 0")
        } else {
            Issue.record("length(from:to:) returned nil for a wholly out-of-domain range")
        }
    }
}
