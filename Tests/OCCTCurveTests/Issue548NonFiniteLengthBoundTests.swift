import Testing
import Foundation
import simd
@testable import OCCTSwift

/// Cover for #548: a non-finite parameter bound used to be answered differently by every ranged
/// arc-length entry point, depending on the curve's type.
///
/// `GCPnts_AbscissaPoint::Length(adaptor, u1, u2)` does not validate its bounds. Curves with more
/// than one `GeomAbs_CN` interval take its `GCPnts_AbsComposite` branch, which reduces the range
/// with `std::min`/`std::max` — and those return their *first* argument when the comparison is
/// false. Measured against the pinned kernel on a 5-point interpolated BSpline
/// (`Scripts/repro/548-nonfinite-length-bounds/`):
///
/// | bounds | line / segment / circle | Bezier | multi-span BSpline |
/// |---|---|---|---|
/// | `(f, .nan)` | `nan` → `nil` | `nan` → `nil` | `0` — a genuine zero-width interval |
/// | `(.nan, l)` | `nan` → `nil` | `nan` → `nil` | the curve's whole length |
/// | `(f, .infinity)` | `+inf` — passes `l >= 0` | `nan` → `nil` | the whole length |
///
/// So the "`nil` means the computation failed" guarantee `Curve3D.length(from:to:)` documents (and
/// on which #408 built the `-1.0` sentinel of `arcLength(from:to:)` / `arcLengthBetween(_:_:)`)
/// held on exactly the curve types the existing parity suite happened to use. The multi-span
/// BSpline fixture below is the shape those tests could not detect: a segment cannot fail this way.
///
/// `Shape.edgeArcLength(from:to:)` was worse still — it has no optional and no sentinel, so a NaN
/// bound on a straight edge returned NaN straight through into caller arithmetic.
///
/// The bounds are now checked in the bridge (`occtValidParameterRange`), before any adaptor is
/// built, so the contract no longer depends on the integrator's own handling of NaN.
@Suite("Non-finite arc-length bounds report failure on every curve type (#548)")
struct Issue548NonFiniteLengthBoundTests {

    /// Multi-span interpolated BSpline: `NbIntervals(GeomAbs_CN) == 4`, so it takes the composite
    /// branch where a NaN bound produced a plausible number instead of NaN.
    private func multiSpanCurve() -> Curve3D? {
        Curve3D.interpolate(points: [
            SIMD3(0, 0, 0),
            SIMD3(100, 50, 0),
            SIMD3(150, -60, 40),
            SIMD3(250, 30, -20),
            SIMD3(300, 0, 60)
        ])
    }

    private func multiSpanCurve2D() -> Curve2D? {
        Curve2D.interpolate(through: [
            SIMD2(0, 0),
            SIMD2(100, 50),
            SIMD2(150, -60),
            SIMD2(250, 30),
            SIMD2(300, 0)
        ])
    }

    private let nonFinite: [(String, Double)] = [
        ("nan", Double.nan),
        ("+infinity", Double.infinity),
        ("-infinity", -Double.infinity)
    ]

    // MARK: - Curve3D

    @Test("A NaN upper bound is nil, not the 0 that means a zero-width interval")
    func nanUpperBoundIsNotZero() {
        guard let c = multiSpanCurve() else { return }
        let d = c.domain

        // Was 0.0: std::min(u1, nan) == std::max(u1, nan) == u1 collapsed the interval to [u1, u1].
        #expect(c.length(from: d.lowerBound, to: .nan) == nil)
        #expect(c.arcLength(from: d.lowerBound, to: .nan) == -1.0)
        #expect(c.arcLengthBetween(d.lowerBound, .nan) == -1.0)

        // The value that failure must stay distinguishable from, on this same fixture.
        let mid = (d.lowerBound + d.upperBound) / 2
        #expect(c.length(from: mid, to: mid) == 0.0)
        #expect(c.arcLength(from: mid, to: mid) == 0.0)
    }

    @Test("A NaN lower bound is nil, not the curve's whole length")
    func nanLowerBoundIsNotTheWholeLength() {
        guard let c = multiSpanCurve(), let whole = c.length else { return }
        let d = c.domain

        // Was the whole length: both reduced bounds became NaN, every per-span skip test went
        // false, and each span was integrated in full — indistinguishable from a real measurement.
        #expect(c.length(from: .nan, to: d.upperBound) == nil)
        #expect(c.arcLength(from: .nan, to: d.upperBound) == -1.0)
        #expect(c.arcLengthBetween(.nan, d.upperBound) == -1.0)
        #expect(whole > 0)
    }

    @Test("Two NaN bounds are nil, not the whole length")
    func bothBoundsNaNIsNil() {
        guard let c = multiSpanCurve() else { return }
        #expect(c.length(from: .nan, to: .nan) == nil)
        #expect(c.arcLength(from: .nan, to: .nan) == -1.0)
    }

    @Test("Every non-finite bound is nil, on every curve type")
    func nonFiniteBoundsAreNilOnEveryCurveType() {
        let fixtures: [(String, Curve3D?)] = [
            ("segment", Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))),
            ("circle", Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)),
            ("multi-span bspline", multiSpanCurve())
        ]
        for (name, curve) in fixtures {
            guard let c = curve else {
                Issue.record("\(name): fixture must build")
                continue
            }
            let d = c.domain
            for (label, bad) in nonFinite {
                // On a segment and a circle an infinite bound used to return +infinity, which
                // passes the bridge's `l >= 0` guard and reached the caller as a "length".
                #expect(c.length(from: d.lowerBound, to: bad) == nil, "\(name) upper \(label)")
                #expect(c.length(from: bad, to: d.upperBound) == nil, "\(name) lower \(label)")
                #expect(c.arcLength(from: d.lowerBound, to: bad) == -1.0, "\(name) upper \(label)")
                #expect(c.arcLengthBetween(bad, d.upperBound) == -1.0, "\(name) lower \(label)")
            }
        }
    }

    @Test("Finite ranges still measure exactly as before")
    func finiteRangesAreUnaffected() {
        guard let c = multiSpanCurve(), let whole = c.length else { return }
        let d = c.domain
        let span = d.upperBound - d.lowerBound

        #expect(c.length(from: d.lowerBound, to: d.upperBound) == whole)

        // The three ranges #506 pinned, none of which the new precondition may reject: a reversed
        // range, one overshooting both ends (clamped on this curve type), one wholly outside.
        let lo = d.lowerBound + 0.1 * span
        let hi = d.lowerBound + 0.6 * span
        #expect(c.length(from: hi, to: lo) == c.length(from: lo, to: hi))
        #expect(c.length(from: d.lowerBound - span, to: d.upperBound + span) == whole)
        #expect(c.length(from: d.upperBound + 1, to: d.upperBound + 2) == 0)

        if let half = c.length(from: d.lowerBound, to: d.lowerBound + span / 2) {
            #expect(half > 0 && half < whole)
        }
    }

    // MARK: - Curve2D (same GCPnts template, reached through Geom2dAdaptor_Curve)

    @Test("Curve2D.length(from:to:) reports nil for a non-finite bound too")
    func curve2DLengthRejectsNonFiniteBounds() {
        // Measured before the fix on the 2D interpolated BSpline: 0 for a NaN upper bound and
        // 457.26 (its whole length) for a NaN lower one — the 3D figures exactly, since both
        // adaptors instantiate the same GCPnts_AbscissaPoint::length template.
        let fixtures: [(String, Curve2D?)] = [
            ("segment", Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))),
            ("circle", Curve2D.circle(center: .zero, radius: 5)),
            ("multi-span bspline", multiSpanCurve2D())
        ]
        for (name, curve) in fixtures {
            guard let c = curve, let whole = c.length else {
                Issue.record("\(name): fixture must build and measure")
                continue
            }
            let d = c.domain
            for (label, bad) in nonFinite {
                #expect(c.length(from: d.lowerBound, to: bad) == nil, "\(name) upper \(label)")
                #expect(c.length(from: bad, to: d.upperBound) == nil, "\(name) lower \(label)")
            }
            #expect(c.length(from: d.lowerBound, to: d.upperBound) == whole, "\(name)")
        }
    }

    @Test("Curve2D.arcLength(from:to:) reports -1.0 for a non-finite bound")
    func curve2DArcLengthRejectsNonFiniteBounds() {
        // This spelling measures through a *pre-bounded* Geom2dAdaptor_Curve, which never reaches
        // the composite branch and so propagated NaN on its own — but returned +infinity for an
        // infinite bound on the length-parametrized types, and +infinity passes the bridge's
        // `l >= 0` guard. Hence both fixtures: the segment is the one that used to leak a value.
        let fixtures: [(String, Curve2D?)] = [
            ("segment", Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))),
            ("circle", Curve2D.circle(center: .zero, radius: 5)),
            ("multi-span bspline", multiSpanCurve2D())
        ]
        for (name, curve) in fixtures {
            guard let c = curve else {
                Issue.record("\(name): fixture must build")
                continue
            }
            let d = c.domain
            for (label, bad) in nonFinite {
                #expect(c.arcLength(from: d.lowerBound, to: bad) == -1.0, "\(name) upper \(label)")
                #expect(c.arcLength(from: bad, to: d.upperBound) == -1.0, "\(name) lower \(label)")
            }
            #expect(c.arcLength(from: d.lowerBound, to: d.upperBound) > 0, "\(name)")
        }
    }

    // MARK: - Shape.edgeArcLength (BRepAdaptor_Curve)

    @Test("Shape.edgeArcLength(from:to:) never returns NaN for a NaN bound")
    func edgeArcLengthRejectsNonFiniteBounds() {
        guard let spline = multiSpanCurve(),
              let splineEdge = Shape.edgeFromCurve(spline),
              let straightEdge = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0)) else {
            Issue.record("edge fixtures must build")
            return
        }

        for (name, edge) in [("straight", straightEdge), ("multi-span bspline", splineEdge)] {
            let d = edge.edgeAdaptorDomain
            for (label, bad) in nonFinite {
                let upper = edge.edgeArcLength(from: d.lowerBound, to: bad)
                let lower = edge.edgeArcLength(from: bad, to: d.upperBound)
                // The straight edge used to hand NaN itself back to the caller: this entry point
                // has no optional and, before #548, no failure sentinel either.
                #expect(!upper.isNaN, "\(name) upper \(label)")
                #expect(!lower.isNaN, "\(name) lower \(label)")
                #expect(upper == -1.0, "\(name) upper \(label)")
                #expect(lower == -1.0, "\(name) lower \(label)")
            }

            // A valid range is untouched by the precondition, and agrees with the total.
            let total = edge.edgeArcLength
            let measured = edge.edgeArcLength(from: d.lowerBound, to: d.upperBound)
            #expect(total > 0, "\(name)")
            #expect(measured == total, "\(name)")
        }
    }

    @Test("The edge sentinel is distinguishable from a genuine zero-width interval")
    func edgeFailureIsDistinguishableFromZero() {
        guard let edge = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0)) else { return }
        let d = edge.edgeAdaptorDomain
        let mid = (d.lowerBound + d.upperBound) / 2

        // 0 used to mean both "this range is empty" and "this call failed", which is the collapse
        // #408 removed from Curve3D and this entry point kept.
        #expect(edge.edgeArcLength(from: mid, to: mid) == 0.0)
        #expect(edge.edgeArcLength(from: mid, to: .nan) == -1.0)
    }
}
