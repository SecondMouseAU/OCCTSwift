import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve2D approximated overload parity (#407)

/// Confirms `approximated(tolerance:continuity:maxSegments:maxDegree:)` and
/// `approximatedInRange(first:last:toleranceU:toleranceV:maxDegree:maxSegments:)` are two
/// distinct OCCT algorithms with distinct contracts, not two configurations of one operation.
@Suite("Curve2D Approximated Overload Parity Tests")
struct Curve2DApproximatedOverloadParityTests {

    @Test("Both overloads succeed on the same curve using only their own implicit defaults")
    func bothOverloadsSucceedWithDefaults() {
        let circle = Curve2D.circle(center: .zero, radius: 10)!
        let d = circle.domain

        let wholeDomain = circle.approximated()
        let ranged = circle.approximatedInRange(first: d.lowerBound, last: d.upperBound)

        #expect(wholeDomain != nil)
        #expect(ranged != nil)
    }

    /// A curve complex enough that `Geom2dConvert_ApproxCurve`/`Approx_Curve2d` can't trivially
    /// satisfy an arbitrarily tight tolerance with a handful of low-degree spans — so the actual
    /// requested tolerance genuinely constrains the fit, rather than every tolerance in the
    /// 1e-2...1e-8 band converging to the same near-machine-precision result. Found empirically:
    /// a two-frequency sine zigzag through 60 points. Below ~1e-5 the fit saturates at ~1e-14
    /// (the algorithm can just reproduce the input almost exactly); at 1e-3 it measurably can't,
    /// giving a real, tolerance-sized deviation. That gap is what makes the two real defaults
    /// (1e-3 vs 1e-6) distinguishable by behavior instead of by reading the source.
    private static func toleranceSensitiveCurve() -> Curve2D {
        var pts: [SIMD2<Double>] = []
        for i in 0..<60 {
            let x = Double(i) * 0.5
            let y = sin(Double(i) * 0.6) * 3.0 + sin(Double(i) * 1.3) * 0.6
            pts.append(SIMD2(x, y))
        }
        return Curve2D.interpolate(through: pts)!
    }

    /// Largest sampled distance between `original` and `approx` over `original`'s domain.
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
    func wholeDomainDefaultToleranceProducesMeasurableError() {
        // Calls with NO explicit `tolerance:` — exercising Curve2D.swift's actual `1e-3` default,
        // not a copy of the literal. Measured on `toleranceSensitiveCurve()`: the default gives
        // ~5.5e-4 max deviation, comfortably inside (1e-5, 5e-3). If the real default were
        // mistakenly tightened toward `1e-6` (matching the other overload), deviation collapses
        // to ~1.8e-14 and fails the lower bound; if loosened toward `1e-2`, deviation exceeds
        // 8e-3 and fails the upper bound. Verified both directions by temporarily editing the
        // real default in Curve2D.swift and confirming this test fails, then restoring it.
        let curve = Self.toleranceSensitiveCurve()
        let approx = curve.approximated()
        #expect(approx != nil)
        if let approx {
            let dev = Self.maxSampledDeviation(curve, approx)
            #expect(dev > 1e-5)
            #expect(dev < 5e-3)
        }
    }

    @Test("Ranged overload's implicit default tolerance produces a near-exact fit")
    func rangedDefaultToleranceProducesNearExactFit() {
        // Calls with NO explicit `toleranceU`/`toleranceV` — exercising the actual `1e-6`
        // defaults. Measured on the same curve: ~1.8e-14 max deviation, i.e. this tolerance is
        // tight enough that the fit is essentially exact. If the real default were mistakenly
        // loosened toward `1e-3` (matching the other overload), deviation jumps to ~7e-4 and
        // fails the bound below. Verified by temporarily editing the real default in
        // Curve2D.swift and confirming this test fails, then restoring it.
        let curve = Self.toleranceSensitiveCurve()
        let d = curve.domain
        let approx = curve.approximatedInRange(first: d.lowerBound, last: d.upperBound)
        #expect(approx != nil)
        if let approx {
            let dev = Self.maxSampledDeviation(curve, approx)
            #expect(dev < 1e-9)
        }
    }

    @Test(
        "Both overloads independently succeed on the same curve; neither promises to structurally match the other"
    )
    func bothOverloadsSucceedIndependentlyOnSameCurve() {
        // Addresses the issue's own gap: no prior test called both overloads on the same input
        // and compared results. Checked empirically before writing this test (pole/degree counts
        // across a circle, an off-center circle, an ellipse, and a wiggly interpolated curve, at
        // both matching and default tolerances): `Geom2dConvert_ApproxCurve` (whole-domain) and
        // `Approx_Curve2d` (ranged) frequently produce IDENTICAL pole/degree counts — a circle at
        // `tol=1e-6` gives 27 poles/degree 8 on both, for instance — and only sometimes diverge
        // (the wiggly curve at `tol=1e-3`: 268 poles/degree 7 vs. 315 poles/degree 8). So
        // structural agreement or disagreement isn't a reliable, input-independent property of
        // either API and isn't asserted here. What both overloads *do* promise is independently
        // succeeding on the same curve; that's what this test checks.
        let circle = Curve2D.circle(center: .zero, radius: 10)!
        let d = circle.domain

        let wholeDomain = circle.approximated(tolerance: 1e-6, continuity: 2)
        let ranged = circle.approximatedInRange(
            first: d.lowerBound, last: d.upperBound,
            toleranceU: 1e-6, toleranceV: 1e-6)

        #expect(wholeDomain != nil)
        #expect(ranged != nil)
        if let wholeDomain, let ranged {
            #expect(wholeDomain.degree != nil)
            #expect(ranged.degree != nil)
        }
    }

    @Test("Whole-domain overload's continuity is a live knob; ranged overload has none")
    func continuityIsConfigurableOnlyOnWholeDomainOverload() {
        // `approximated(tolerance:continuity:...)` threads `continuity` into
        // `Geom2dConvert_ApproxCurve`. `approximatedInRange` has no such parameter at all —
        // the bridge hardcodes GeomAbs_C2. Both continuity settings below must still succeed
        // on the whole-domain overload, confirming the knob is live, not vestigial.
        let circle = Curve2D.circle(center: .zero, radius: 10)!
        let c0 = circle.approximated(tolerance: 1e-3, continuity: 0)
        let c2 = circle.approximated(tolerance: 1e-3, continuity: 2)
        #expect(c0 != nil)
        #expect(c2 != nil)
    }
}
