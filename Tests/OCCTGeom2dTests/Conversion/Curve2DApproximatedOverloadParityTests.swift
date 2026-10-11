import Foundation
import Testing

@testable import OCCTSwift

// MARK: - Curve2D approximated overload parity (#407)

/// Confirms the two approximation overloads are different OCCT algorithms with different contracts.
///
/// `approximated(tolerance:continuity:maxSegments:maxDegree:)` and
/// `approximatedInRange(first:last:toleranceU:toleranceV:maxDegree:maxSegments:)` are not two
/// configurations of one operation. Every fit is pinned to the degree and pole count
/// `Geom2dConvert_ApproxCurve` and `Approx_Curve2d` give for the same curve and tolerance
/// (`Scripts/repro/766-geom2d-approx-arclength-arctypes/transcript.txt`), and to the tolerance it
/// was asked for, which is the contract: a non-nil curve alone passes a fit made at any tolerance.
@Suite("Curve2D Approximated Overload Parity Tests")
struct Curve2DApproximatedOverloadParityTests {

    @Test("Both overloads succeed on the same curve using only their own implicit defaults")
    func bothOverloadsSucceedWithDefaults() throws {
        let circle = try #require(Curve2D.circle(center: .zero, radius: 10))
        let d = circle.domain

        let wholeDomain = try #require(circle.approximated())
        let ranged = try #require(
            circle.approximatedInRange(first: d.lowerBound, last: d.upperBound))

        // Each default gives its own fit: Geom2dConvert_ApproxCurve at 1e-3 is degree 7 with 13
        // poles, Approx_Curve2d at 1e-6 is degree 8 with 27.
        #expect(wholeDomain.degree == 7)
        #expect(wholeDomain.poleCount == 13)
        #expect(ranged.degree == 8)
        #expect(ranged.poleCount == 27)

        // And each stays within the tolerance it defaulted to, 1e-3 and 1e-6.
        #expect(Self.maxSampledDeviation(circle, wholeDomain) < 1e-3)
        #expect(Self.maxSampledDeviation(circle, ranged) < 1e-6)
    }

    // A curve a tolerance genuinely constrains: complex enough that Geom2dConvert_ApproxCurve and
    // Approx_Curve2d cannot trivially satisfy an arbitrarily tight tolerance with a handful of
    // low-degree spans, so the requested tolerance shapes the fit instead of every tolerance in
    // the 1e-2...1e-8 band converging on the same near-machine-precision result. Found
    // empirically: a two-frequency sine zigzag through 60 points. Below about 1e-5 the fit
    // saturates at about 1e-14, because the algorithm can reproduce the input almost exactly; at
    // 1e-3 it measurably cannot, and gives a real, tolerance-sized deviation. That gap is what
    // makes the two defaults (1e-3 against 1e-6) distinguishable by behaviour rather than by
    // reading the source.
    private static func toleranceSensitiveCurve() throws -> Curve2D {
        var pts: [SIMD2<Double>] = []
        for i in 0..<60 {
            let x = Double(i) * 0.5
            let y = sin(Double(i) * 0.6) * 3.0 + sin(Double(i) * 1.3) * 0.6
            pts.append(SIMD2(x, y))
        }
        return try #require(Curve2D.interpolate(through: pts))
    }

    // The largest sampled distance between `original` and `approx`, over the domain of `original`.
    private static func maxSampledDeviation(
        _ original: Curve2D, _ approx: Curve2D,
        samples: Int = 300
    ) -> Double {
        let d = original.domain
        var maxDev = 0.0
        for i in 0...samples {
            let t = d.lowerBound + (d.upperBound - d.lowerBound) * Double(i) / Double(samples)
            let p1 = original.point(at: t)
            let p2 = approx.point(at: t)
            let dx = p1.x - p2.x
            let dy = p1.y - p2.y
            maxDev = max(maxDev, (dx * dx + dy * dy).squareRoot())
        }
        return maxDev
    }

    @Test(
        "Whole-domain overload's implicit default tolerance produces a real, non-trivial fit error")
    func wholeDomainDefaultToleranceProducesMeasurableError() throws {
        // Calls with NO explicit `tolerance:`, exercising Curve2D.swift's actual `1e-3` default
        // and not a copy of the literal. Measured on `toleranceSensitiveCurve()`: the default gives
        // about 5.5e-4 max deviation, comfortably inside (1e-5, 5e-3). If the real default were
        // tightened toward `1e-6` (matching the other overload), the deviation collapses to about
        // 1.8e-14 and fails the lower bound; if loosened toward `1e-2`, it exceeds 8e-3 and fails
        // the upper bound. Both directions were checked by editing the default and confirming this
        // test fails.
        let curve = try Self.toleranceSensitiveCurve()
        let approx = try #require(curve.approximated())
        let dev = Self.maxSampledDeviation(curve, approx)
        #expect(dev > 1e-5)
        #expect(dev < 5e-3)
    }

    @Test("Ranged overload's implicit default tolerance produces a near-exact fit")
    func rangedDefaultToleranceProducesNearExactFit() throws {
        // Calls with NO explicit `toleranceU`/`toleranceV`, exercising the actual `1e-6` defaults.
        // Measured on the same curve: about 1.8e-14 max deviation, so this tolerance is tight
        // enough for the fit to be essentially exact. If the real default were loosened toward
        // `1e-3` (matching the other overload), the deviation jumps to about 7e-4 and fails the
        // bound below. Checked by editing the default and confirming this test fails.
        let curve = try Self.toleranceSensitiveCurve()
        let d = curve.domain
        let approx = try #require(
            curve.approximatedInRange(first: d.lowerBound, last: d.upperBound))
        let dev = Self.maxSampledDeviation(curve, approx)
        #expect(dev < 1e-9)
    }

    @Test("Both overloads independently succeed on the same curve without promising to match")
    func bothOverloadsSucceedIndependentlyOnSameCurve() throws {
        // Addresses the issue's own gap: no prior test called both overloads on the same input
        // and compared results. Checked empirically before writing this test (pole and degree
        // counts across a circle, an off-center circle, an ellipse and a wiggly interpolated
        // curve, at both matching and default tolerances): `Geom2dConvert_ApproxCurve`
        // (whole-domain) and `Approx_Curve2d` (ranged) frequently produce IDENTICAL pole and
        // degree counts (a circle at `tol=1e-6` gives 27 poles of degree 8 on both, for
        // instance) and only sometimes diverge (the wiggly curve at `tol=1e-3`: 268 poles of
        // degree 7 against 315 poles of degree 8). So structural agreement or disagreement is not
        // a reliable, input-independent property of either API and is not asserted here. What both
        // overloads do promise is succeeding independently on the same curve, and that is what
        // this test checks.
        let circle = try #require(Curve2D.circle(center: .zero, radius: 10))
        let d = circle.domain

        let wholeDomain = circle.approximated(tolerance: 1e-6, continuity: 2)
        let ranged = circle.approximatedInRange(
            first: d.lowerBound, last: d.upperBound,
            toleranceU: 1e-6, toleranceV: 1e-6)

        // `degree != nil` passes any fit. At 1e-6 both give degree 8 with 27 poles.
        let w = try #require(wholeDomain)
        let r = try #require(ranged)
        #expect(w.degree == 8)
        #expect(w.poleCount == 27)
        #expect(r.degree == 8)
        #expect(r.poleCount == 27)

        // Both stay within the 1e-6 they were asked for.
        #expect(Self.maxSampledDeviation(circle, w) < 1e-6)
        #expect(Self.maxSampledDeviation(circle, r) < 1e-6)
    }

    @Test("Whole-domain overload's continuity is a live knob; ranged overload has none")
    func continuityIsConfigurableOnlyOnWholeDomainOverload() throws {
        // `approximated(tolerance:continuity:...)` threads `continuity` into
        // `Geom2dConvert_ApproxCurve`. `approximatedInRange` has no such parameter at all, and the
        // bridge hardcodes GeomAbs_C2.
        let circle = try #require(Curve2D.circle(center: .zero, radius: 10))
        // Two non-nil results do not show the knob does anything, and a bridge that dropped
        // `continuity` would pass them. The two settings give different fits: 15 poles at C0 and
        // 13 at C2.
        let c0 = try #require(circle.approximated(tolerance: 1e-3, continuity: 0))
        let c2 = try #require(circle.approximated(tolerance: 1e-3, continuity: 2))
        #expect(c0.poleCount == 15)
        #expect(c2.poleCount == 13)

        // Both honour the tolerance they were given.
        #expect(Self.maxSampledDeviation(circle, c0) < 1e-3)
        #expect(Self.maxSampledDeviation(circle, c2) < 1e-3)
    }
}
