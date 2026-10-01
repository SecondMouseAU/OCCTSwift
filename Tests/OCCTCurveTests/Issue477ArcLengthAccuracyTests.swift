import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Regression cover for #477, arc-length accuracy on multi-span curves.
///
/// `Curve3D.length` / `length(from:to:)` integrated arc length with a single
/// `CPnts_AbscissaPoint::Length` Gauss quadrature across the whole parameter domain, which on a
/// multi-span BSpline was wrong by up to several percent with no error signalled. #477 made the
/// measurement composite.
///
/// Every assertion here is against an **independently computed** reference (a densely sampled
/// polyline, Richardson-extrapolated), never against whatever the implementation happens to
/// return. That is what the assertions are worth; it is no longer what separates the integrators.
///
/// **The contrast this suite was written around is gone from the kernel we ship** (#2916).
/// Carried patch `0021` subdivides inside `CPnts` too, so on the pinned asset the whole-domain
/// quadrature #477 replaced agrees with the reference to 3.3e-10 on the zigzag below and 1.0e-10
/// on the helix, and passes every accuracy bound here. Re-measured 2026-10-01 against
/// `v4.0.0-kernel.3`, the asset `Package.swift` pins:
/// `Scripts/repro/766-curve-arclength-accuracy/`. Every figure quoted below cites that transcript
/// and none of them claims the old quadrature would now fail.
///
/// **The composite measurement is the bridge's, not `GCPnts`'.** `occtAdaptorArcLength`
/// (`OCCTBridge_Internal.h`) splits at the `GeomAbs_CN` interval boundaries and integrates each
/// span with `CPnts`; only a curve with one interval reaches `GCPnts_AbscissaPoint::Length`, so
/// on the two fixtures below the bridge never calls it. The two agree bit for bit, because
/// `GCPnts` splits on the same array and delegates the same way, which is the point rather than
/// a reason to let the prose stand: the accuracy these tests measure is the per-span `CPnts`
/// sum's, and `0021` is what made that sum right. The out-of-domain clamp is a third place again,
/// `occtConfineToDomain` inside `occtAdaptorLengthBetween`.
///
/// What the suite still guards, each proven red under its own injection during the #766 Curve
/// lift: the bridge's wiring to the composite measurement, the out-of-domain clamp, the
/// zero-width short-circuit, and agreement across all five arc-length spellings.
@Suite("Curve3D arc-length accuracy on multi-span curves (#477)")
struct Issue477ArcLengthAccuracyTests {

    // MARK: - Fixtures
    //
    // The independent reference (`polylineLength` + `referenceLength`) moved to
    // `CurveTestFixtures.swift` (#1259): this file's copy was byte-identical to
    // `Issue603SingleSpanQuadratureTests`'s.

    /// A pathological multi-span fixture: 40 interpolated points, 39 `GeomAbs_CN` spans.
    ///
    /// Sharply varying speed (cubic acceleration in x) and a zigzag in y, the ordinary shape of
    /// an interpolated toolpath or an imported spline. Domain `[0, 344.4]`, length 356.25.
    ///
    /// The old integrator was several percent low on it before carried patch `0021`; on the
    /// pinned asset it is 3.3e-10 low (`Scripts/repro/766-curve-arclength-accuracy/`, "zigzag 40
    /// points"). This is still the suite's pathological fixture, by construction rather than by
    /// measured divergence.
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

    /// A benign multi-span fixture: 60 interpolated points along three turns of a helix.
    ///
    /// 59 spans, smooth and constant-speed. Included so the suite covers a benign multi-span
    /// curve as well as a pathological one. On the pinned asset both integrators land within
    /// 1.0e-10 of the reference here (`Scripts/repro/766-curve-arclength-accuracy/`, "helix 60
    /// points").
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
            // Measured 3.1e-14 against the reference on the pinned asset
            // (`Scripts/repro/766-curve-arclength-accuracy/`, zigzag "reference whole"). 1e-5 is
            // not a line drawn between two integrators any more, because patch `0021` brought
            // the old one to 3.3e-10 here. What it bounds now is the reference's own residual:
            // the worst agreement anywhere in that transcript between `GCPnts` and the
            // Richardson-extrapolated chord sum is 2.3e-12, on the zigzag's `[1/3, 2/3]`
            // sub-range, which leaves 1e-5 seven orders of headroom. Deliberately loose, so a
            // toolchain difference in `sin`/`cos` cannot flake it.
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
            // The ranged overload had the identical defect. Measured 2.3e-12 against the
            // reference on the pinned asset, where the old integrator is 1.3e-11
            // (`Scripts/repro/766-curve-arclength-accuracy/`, zigzag "reference [1/3, 2/3]").
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

        // #766: a nil from either optional spelling used to skip its check.
        if let length = curve.length {
            #expect(abs(length - wholeReference) / wholeReference < 1e-5)
        } else {
            Issue.record("length returned nil")
        }
        if let ranged = curve.length(from: u1, to: u2) {
            #expect(abs(ranged - rangedReference) / rangedReference < 1e-5)
        } else {
            Issue.record("length(from:to:) returned nil")
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
            // Measured 3.0e-16 against the reference on the pinned asset
            // (`Scripts/repro/766-curve-arclength-accuracy/`, helix "reference whole"). 1e-8 is
            // the tightest bound the suite draws anywhere: a smooth constant-speed curve is where
            // the chord-sum reference converges best, so it is the fixture that can carry one.
            // It no longer separates the integrators; the old one is 1.0e-10 here.
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
        // #766: a failed factory, or a nil half-circle length, used to skip its check.
        if let segment = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0)) {
            if let l = segment.length {
                #expect(abs(l - 5.0) < 1e-9)
            } else {
                Issue.record("length returned nil on a line segment")
            }
        } else {
            Issue.record("could not build the segment")
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
            } else {
                Issue.record("length(from:to:) returned nil on a half circle")
            }
        } else {
            Issue.record("could not build the circle")
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
        // its knots and returned a length many times the curve's own. Still does, and patch
        // `0021` did not change it: over `[f - s, l + s]` on this fixture
        // `CPnts_AbscissaPoint::Length` returns 442165.86 against the curve's own 356.25, 1241x
        // (`Scripts/repro/766-curve-arclength-accuracy/`, zigzag "unclamped CPnts"). This is the
        // one comparison in the suite the pinned kernel still bears out.
        //
        // What clamps is `occtConfineToDomain` in `occtAdaptorLengthBetween`, before any
        // integrator is called, which is the safer reading of a caller that overshot. The same
        // transcript's "bridge (occtAdaptorLengthBetween, non-periodic arm)" line is this test's
        // two assertions exactly: the overshot range confines to the domain length, and the range
        // wholly past the end confines to nothing and measures 0.
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
