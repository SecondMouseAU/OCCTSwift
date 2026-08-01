import Testing
import Foundation
import simd
@testable import OCCTSwift

/// Regression cover for #603: every arc length in the bridge was one fixed-order Gauss quadrature
/// per `GeomAbs_CN` interval. #477 made that "per interval" instead of "per curve", which fixed
/// multi-span BSplines; a conic has exactly one interval, so the single quadrature survived there
/// and a whole ellipse measured up to 1.7% long, a parabola over a wide range 3.1% short.
///
/// Two independent references are used, never the implementation's own answer:
///
///  * a Richardson-extrapolated chord sum (`L ≈ L₂ₙ + (L₂ₙ − Lₙ)/3`, the #477 technique), which
///    works on any curve and only needs `point(at:)`, and
///  * for an ellipse, a Simpson quadrature of `∫√(a²sin²t + b²cos²t) dt` computed here in Swift,
///    which never touches the curve at all.
///
/// They agree to ~1e-11 on every ellipse below. Two of them matter: when this was measured against
/// a single reference on a 5-point interpolated BSpline, only the second one settled whether the
/// kernel or the reference was the wrong number.
@Suite("Arc length stops being one quadrature per span (#603)")
struct Issue603SingleSpanQuadratureTests {

    // MARK: - Independent references

    private func polylineLength(_ c: Curve3D, from u1: Double, to u2: Double, segments: Int) -> Double {
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

    /// Chord sums converge from below as O(h²), so two densities extrapolate far tighter than
    /// either: on a smooth curve this lands within ~1e-13 relative.
    private func referenceLength(_ c: Curve3D, from u1: Double, to u2: Double,
                                 segments n: Int = 20_000) -> Double {
        let coarse = polylineLength(c, from: u1, to: u2, segments: n)
        let fine = polylineLength(c, from: u1, to: u2, segments: 2 * n)
        return fine + (fine - coarse) / 3
    }

    /// `∫√(a²sin²t + b²cos²t) dt` by composite Simpson — the ellipse's arc length from first
    /// principles, with no curve object involved.
    private func ellipseArc(a: Double, b: Double, from t0: Double, to t1: Double,
                            panels n: Int = 200_000) -> Double {
        func f(_ t: Double) -> Double { hypot(a * sin(t), b * cos(t)) }
        let h = (t1 - t0) / Double(n)
        var s = f(t0) + f(t1)
        for i in 1..<n { s += (i % 2 == 1 ? 4.0 : 2.0) * f(t0 + Double(i) * h) }
        return s * h / 3
    }

    private func ellipse(_ a: Double, _ b: Double) -> Curve3D? {
        Curve3D.ellipse(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), majorRadius: a, minorRadius: b)
    }

    // MARK: - The defect itself

    /// The issue's own table, re-measured through `Curve3D.length`. Every one of these was between
    /// 0.34% and 1.74% long before; the tolerance here is 1e-9 relative, six orders inside the
    /// smallest of those errors, so the suite cannot pass on the single quadrature.
    @Test("A whole ellipse measures its own circumference, not 0.3-1.7% more")
    func wholeEllipseLength() {
        let cases: [(Double, Double, Double)] = [
            (8, 3, 0.00337), (8, 7, 0.0000096), (10, 1, 0.01485), (100, 30, 0.00550), (1, 0.05, 0.01737),
        ]
        for (a, b, oldRelativeError) in cases {
            guard let c = ellipse(a, b), let measured = c.length else {
                Issue.record("ellipse \(a) x \(b) failed to build or measure")
                continue
            }
            let truth = ellipseArc(a: a, b: b, from: 0, to: 2 * .pi)
            let chord = referenceLength(c, from: c.domain.lowerBound, to: c.domain.upperBound)
            // The two references agree, so neither is the thing being tested.
            #expect(abs(chord - truth) / truth < 1e-9,
                    "references disagree for \(a) x \(b): \(chord) vs \(truth)")
            #expect(abs(measured - truth) / truth < 1e-9,
                    "ellipse \(a) x \(b): measured \(measured), truth \(truth), relative \(abs(measured - truth) / truth) (was \(oldRelativeError))")
        }
    }

    /// The worst case measured anywhere in this family, and the one the issue guessed at but did
    /// not probe: a parabola gets an order-5 Gauss rule (`CPnts_AbscissaPoint`'s `order()` special
    /// -cases it), so over a wide range it was 3.09% SHORT — the only fixture whose error had the
    /// opposite sign.
    @Test("A parabola over a wide range measures its arc, not 3% less")
    func wideParabolaLength() {
        guard let c = Curve3D.parabola(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
                                       focal: 3),
              let measured = c.length(from: -100, to: 100) else {
            Issue.record("parabola failed to build or measure"); return
        }
        let truth = referenceLength(c, from: -100, to: 100)
        #expect(abs(measured - truth) / truth < 1e-9,
                "parabola: measured \(measured), truth \(truth), relative \(abs(measured - truth) / truth) (was 0.0309 short)")
    }

    @Test("A hyperbola over a wide range measures its arc")
    func wideHyperbolaLength() {
        guard let c = Curve3D.hyperbola(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
                                        majorRadius: 5, minorRadius: 2),
              let measured = c.length(from: -4, to: 4) else {
            Issue.record("hyperbola failed to build or measure"); return
        }
        let truth = referenceLength(c, from: -4, to: 4)
        #expect(abs(measured - truth) / truth < 1e-9,
                "hyperbola: measured \(measured), truth \(truth) (was 0.067% long)")
    }

    /// A degree-3 Bezier gets an order-6 rule (`2 * Degree`), which is not enough when the poles
    /// make the speed whip: this is not a conic defect, and a curve type with no analytic form at
    /// all shows it too.
    @Test("A whipping cubic Bezier measures its arc")
    func whippingBezierLength() {
        guard let c = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(0.2, 40, 0),
                                             SIMD3(9.8, -40, 0), SIMD3(10, 0, 0)]),
              let measured = c.length else {
            Issue.record("Bezier failed to build or measure"); return
        }
        let truth = referenceLength(c, from: c.domain.lowerBound, to: c.domain.upperBound)
        #expect(abs(measured - truth) / truth < 1e-9,
                "Bezier: measured \(measured), truth \(truth) (was 0.189% short)")
    }

    /// #477 is not superseded, it is completed: splitting at the `GeomAbs_CN` boundaries left each
    /// span on one quadrature, and a 5-point interpolation's spans are wide enough for that to
    /// matter (6.0e-5 relative, 100x worse than the 40-point curve #477 was tested on).
    ///
    /// This fixture is also the one that forces the subdivision to happen INSIDE each interval.
    /// Halving the whole range puts the split on a knot GCPnts already splits at, so a level-1 and
    /// a level-2 measurement come back bit-identical and a naive convergence test ratifies the
    /// wrong answer.
    @Test("A short multi-span interpolation gets the accuracy per-span splitting left behind")
    func multiSpanInterpolationLength() {
        var pts: [SIMD3<Double>] = []
        for i in 1...5 {
            pts.append(SIMD3(Double(i) * 3.0,
                             i.isMultiple(of: 2) ? -12.0 : 12.0,
                             i.isMultiple(of: 3) ? -4.0 : 4.0))
        }
        guard let c = Curve3D.interpolate(points: pts), let measured = c.length else {
            Issue.record("interpolation failed"); return
        }
        let truth = referenceLength(c, from: c.domain.lowerBound, to: c.domain.upperBound)
        #expect(abs(measured - truth) / truth < 1e-9,
                "5-point interpolation: measured \(measured), truth \(truth) (was 6.0e-5 out)")
    }

    // MARK: - What must NOT change

    /// A line and a circle are `GCPnts_LengthParametrized`: their length is a closed form, not a
    /// quadrature, and there is nothing to converge. Subdividing must return the same closed form,
    /// not a numerically integrated approximation of it.
    @Test("The closed forms stay closed forms")
    func lengthParametrizedCurvesUnchanged() {
        guard let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
              let circumference = circle.length,
              let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 12)),
              let straight = line.length else {
            Issue.record("closed-form fixtures failed"); return
        }
        #expect(abs(circumference - 2 * .pi * 5) < 1e-12, "circle: \(circumference)")
        #expect(abs(straight - 13.0) < 1e-12, "segment: \(straight)")
    }

    /// Sub-ranges were already accurate (the error is set by how far one integration interval
    /// spans, not by the curve's type), so they must stay where they were.
    @Test("Accurate sub-ranges stay accurate, and the parts still sum to the whole")
    func subRangesUnchanged() {
        guard let c = ellipse(8, 3), let whole = c.length else {
            Issue.record("ellipse failed"); return
        }
        let quarter = c.length(from: 0, to: .pi / 2)
        let half = c.length(from: 0, to: .pi)
        #expect(quarter != nil && half != nil)
        if let q = quarter {
            #expect(abs(q - ellipseArc(a: 8, b: 3, from: 0, to: .pi / 2)) < 1e-9, "quarter \(q)")
        }
        if let h = half {
            #expect(abs(h - ellipseArc(a: 8, b: 3, from: 0, to: .pi)) < 1e-9, "half \(h)")
            // The whole used to be 0.337% more than twice its own halves.
            #expect(abs(whole - 2 * h) / whole < 1e-9, "whole \(whole) vs two halves \(2 * h)")
        }
    }

    /// #600's winding contract, on a curve whose one period is now measured accurately: two turns
    /// must be exactly twice one, and one must be the circumference.
    @Test("A wound range winds an accurate period (#600 preserved)")
    func periodicWindingStillHolds() {
        guard let c = ellipse(10, 1), let one = c.length else {
            Issue.record("ellipse failed"); return
        }
        let two = c.length(from: 0, to: 4 * .pi)
        #expect(two != nil)
        if let two {
            #expect(abs(two - 2 * one) / two < 1e-9, "two turns \(two) vs 2 x \(one)")
            #expect(abs(one - ellipseArc(a: 10, b: 1, from: 0, to: 2 * .pi)) / one < 1e-9)
        }
    }

    // MARK: - The inverse

    /// The pairing this fix had to keep. OCCT's root finder inverts the very quadrature the length
    /// no longer uses (`CPnts_MyRootFunction::Value` is one Gauss rule over `[u0, X]`), so before
    /// this both sides were wrong by the same 0.337% and `parameterAtLength(length)` still landed
    /// on the last parameter. Making only the length accurate would have moved that answer to
    /// 6.2438 on an 8 x 3 ellipse whose domain ends at 6.2832 — 0.33% short in arc.
    @Test("parameterAtLength(length) still lands on the end of the curve")
    func inverseAgreesWithTheLengthItInverts() {
        for (a, b) in [(8.0, 3.0), (10.0, 1.0), (1.0, 0.05)] {
            guard let c = ellipse(a, b), let total = c.length else {
                Issue.record("ellipse \(a) x \(b) failed"); continue
            }
            let end = c.parameterAtLength(total, from: c.domain.lowerBound)
            #expect(abs(end - c.domain.upperBound) < 1e-7,
                    "ellipse \(a) x \(b): parameterAtLength(\(total)) = \(end), domain ends at \(c.domain.upperBound)")
        }
    }

    /// And every fraction of the way, not just the end: the parameter returned for half the length
    /// must actually be half the length along.
    @Test("A fraction of the length is that fraction of the arc")
    func inverseIsAccurateMidCurve() {
        guard let c = ellipse(1, 0.05), let total = c.length else {
            Issue.record("ellipse failed"); return
        }
        for fraction in [0.25, 0.5, 0.75] {
            let u = c.parameterAtLength(total * fraction, from: c.domain.lowerBound)
            let arc = referenceLength(c, from: c.domain.lowerBound, to: u)
            #expect(abs(arc - total * fraction) / total < 1e-8,
                    "fraction \(fraction): u = \(u), arc there \(arc), wanted \(total * fraction)")
        }
    }

    /// Travelling backwards from the end must be the mirror of travelling forwards from the start.
    @Test("A negative abscissa walks backwards accurately")
    func inverseWalksBackwards() {
        guard let c = ellipse(10, 1), let total = c.length else {
            Issue.record("ellipse failed"); return
        }
        let u = c.parameterAtLength(-total / 4, from: c.domain.upperBound)
        let arc = referenceLength(c, from: u, to: c.domain.upperBound)
        #expect(abs(arc - total / 4) / total < 1e-8,
                "backwards quarter: u = \(u), arc from there to the end \(arc), wanted \(total / 4)")
    }

    // MARK: - The same geometry through every other entry point

    @Test("A 2D ellipse measures the same as the 3D one, both spellings")
    func curve2DAgrees() {
        guard let c = Curve2D.ellipse(center: SIMD2(0, 0), majorRadius: 8, minorRadius: 3),
              let whole = c.length else {
            Issue.record("2D ellipse failed"); return
        }
        let truth = ellipseArc(a: 8, b: 3, from: 0, to: 2 * .pi)
        #expect(abs(whole - truth) / truth < 1e-9, "Curve2D.length: \(whole) vs \(truth)")
        // arcLength(from:to:) is the other 2D spelling, on a pre-bounded adaptor (#549).
        let ranged = c.arcLength(from: 0, to: 2 * .pi)
        #expect(abs(ranged - truth) / truth < 1e-9, "Curve2D.arcLength: \(ranged) vs \(truth)")
        // ...and its inverse.
        if let end = c.parameterAtLength(whole, from: c.domain.lowerBound) {
            #expect(abs(end - c.domain.upperBound) < 1e-7, "2D parameterAtLength(length) = \(end)")
        } else {
            Issue.record("2D parameterAtLength returned nil")
        }
    }

    @Test("An elliptical edge measures the same as the curve it was built from")
    func edgeAgrees() {
        guard let c = ellipse(10, 1), let curveLength = c.length,
              let edge = Shape.edgeFromCurve(c) else {
            Issue.record("edge fixture failed"); return
        }
        let truth = ellipseArc(a: 10, b: 1, from: 0, to: 2 * .pi)
        #expect(abs(edge.edgeArcLength - truth) / truth < 1e-9,
                "edgeArcLength \(edge.edgeArcLength) vs \(truth)")
        #expect(abs(edge.edgeArcLength - curveLength) / truth < 1e-9,
                "edge \(edge.edgeArcLength) vs curve \(curveLength)")

        let domain = edge.edgeAdaptorDomain
        let ranged = edge.edgeArcLength(from: domain.lowerBound, to: domain.upperBound)
        #expect(abs(ranged - truth) / truth < 1e-9, "edgeArcLength(from:to:) \(ranged)")

        // The fraction entry point takes a fraction of the total and then walks it: both halves
        // were biased before, and they cancelled. They must still meet at the end.
        let end = edge.edgeParameterAtFraction(1.0)
        #expect(abs(end - domain.upperBound) < 1e-7,
                "edgeParameterAtFraction(1.0) = \(end), domain ends at \(domain.upperBound)")
        let mid = edge.edgeParameterAtFraction(0.5)
        let firstHalf = edge.edgeArcLength(from: domain.lowerBound, to: mid)
        #expect(abs(firstHalf - truth / 2) / truth < 1e-8,
                "edgeParameterAtFraction(0.5) split \(firstHalf) of \(truth)")
    }

    @Test("A wire containing an elliptical edge measures accurately, and so does its adaptor")
    func wireAgrees() {
        guard let c = ellipse(10, 1), let edge = Shape.edgeFromCurve(c),
              let e = edge.edges().first, let wire = Wire.wireFromEdges([e]) else {
            Issue.record("wire fixture failed"); return
        }
        let truth = ellipseArc(a: 10, b: 1, from: 0, to: 2 * .pi)
        if let wireLength = wire.length {
            #expect(abs(wireLength - truth) / truth < 1e-9, "Wire.length \(wireLength) vs \(truth)")
        } else {
            Issue.record("Wire.length returned nil")
        }

        guard let wc = WireCurve(wire) else { Issue.record("WireCurve failed"); return }
        #expect(abs(wc.length - truth) / truth < 1e-9, "WireCurve.length \(wc.length)")
        if let end = wc.parameter(atAbscissa: wc.length) {
            #expect(abs(end - wc.parameterRange.last) < 1e-7,
                    "WireCurve.parameter(atAbscissa: length) = \(end)")
        } else {
            Issue.record("WireCurve.parameter(atAbscissa:) returned nil at the full length")
        }
    }

    @Test("An EdgeCurve measures accurately and inverts consistently")
    func edgeCurveAgrees() {
        guard let c = ellipse(10, 1), let shape = Shape.edgeFromCurve(c),
              let edge = shape.edges().first, let ec = EdgeCurve(edge) else {
            Issue.record("EdgeCurve fixture failed"); return
        }
        let truth = ellipseArc(a: 10, b: 1, from: 0, to: 2 * .pi)
        #expect(abs(ec.length - truth) / truth < 1e-9, "EdgeCurve.length \(ec.length)")
        if let end = ec.parameter(atAbscissa: ec.length) {
            #expect(abs(end - ec.parameterRange.last) < 1e-7,
                    "EdgeCurve.parameter(atAbscissa: length) = \(end)")
        } else {
            Issue.record("EdgeCurve.parameter(atAbscissa:) returned nil at the full length")
        }
    }
}
