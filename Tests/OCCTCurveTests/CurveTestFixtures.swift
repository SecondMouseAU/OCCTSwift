// CurveTestFixtures.swift
// Shared fixtures for OCCTCurveTests.
// No test suites or test functions here: only shared helpers.

import Foundation
import Testing
import simd

@testable import OCCTSwift

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

// MARK: - Point-to-curve fixtures (#1261)

/// Domain `[3, 8]` along +X: the point at parameter `t` is `(t, 0, 0)`. The basis is an unbounded
/// `Geom_Line`. Shared by `Issue500Curve3DNearestParameterTests`, `Issue539NearestPointOnCurveTests`
/// and `Issue615NearestParameterRangeTests`, which each built this same trimmed-segment fixture
/// independently before the #1261 review pointed out the duplication.
func trimmedSegment() -> Curve3D? {
    Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))?.trimmed(from: 3, to: 8)
}

/// Half of a circle of radius 5 in the XY plane, domain `[0, pi]`: parameter `t` is the point
/// `(5 cos t, 5 sin t, 0)`. Shared by `Issue539NearestPointOnCurveTests` (which called it
/// `halfArc()`) and `Issue615NearestParameterRangeTests` (which called it `halfCircle()`), the same
/// fixture under two different names before the #1261 review pointed out the duplication;
/// `halfCircle` is the name kept.
func halfCircle() -> Curve3D? {
    Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)?.trimmed(from: 0, to: .pi)
}

// MARK: - Continuity fixtures (#1262)

/// A cubic BSpline whose interior knot carries `multiplicity`, which is what drives its measured
/// continuity: mult 1 -> C2, mult 2 -> C1, mult 3 (== degree) -> C0. Shared by
/// `Issue485Curve3DContinuityTests` and `Issue619ContinuityEncodingTests`, which each built this
/// same fixture independently before the #1262 review pointed out the duplication.
func bspline(interiorMultiplicity multiplicity: Int32) -> Curve3D? {
    let poleCount = 4 + Int(multiplicity)
    let poles = (1...poleCount).map { i in
        SIMD3<Double>(Double(i), Double(i % 2) * 2.0, 0)
    }
    return Curve3D.bspline(
        poles: poles,
        knots: [0.0, 0.5, 1.0],
        multiplicities: [4, multiplicity, 4],
        degree: 3)
}

// MARK: - Arc-length reference oracle (#1259)

/// Summed chord length of `segments` evenly spaced parameter samples between `u1` and `u2`. This
/// "measure a curve's true chord length" primitive was reimplemented four separate times under two
/// names (`polylineLength` in `Issue477ArcLengthAccuracyTests`, `Issue603SingleSpanQuadratureTests`
/// and `Issue506ArcLengthBridgeContractTests`; `tracedLength` in `Issue600OutOfDomainRangeTests`)
/// before the #1259 review pointed out the duplication; `polylineLength` is the name kept.
func polylineLength(_ c: Curve3D, from u1: Double, to u2: Double, segments: Int = 20_000) -> Double {
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
/// extrapolate to a reference far tighter than either: `L ≈ L₂ₙ + (L₂ₙ − Lₙ) / 3`. Shared by
/// `Issue477ArcLengthAccuracyTests` and `Issue603SingleSpanQuadratureTests`, which built this same
/// pair independently before the #1259 review pointed out the duplication.
func referenceLength(
    _ c: Curve3D, from u1: Double, to u2: Double,
    segments n: Int = 20_000
) -> Double {
    let coarse = polylineLength(c, from: u1, to: u2, segments: n)
    let fine = polylineLength(c, from: u1, to: u2, segments: 2 * n)
    return fine + (fine - coarse) / 3
}

// MARK: - Multi-span curve fixture (#1260)

/// 5-point interpolated BSpline with sharply varying speed across a ~300-unit range,
/// `NbIntervals(GeomAbs_CN) == 4`. Shared by `Issue548NonFiniteLengthBoundTests` and
/// `Issue600OutOfDomainRangeTests`, which each built this same fixture independently, byte for
/// byte, before the #1260 review pointed out the duplication. `Issue490ContinuityDecoderTests` and
/// `Issue506ArcLengthBridgeContractTests` each build their own `multiSpanCurve()` over a distinct
/// point set suited to their own defect (continuity/split behavior and arc-length range handling,
/// respectively) and are deliberately left alone; only this byte-identical pair was duplication.
func wideRangeMultiSpanCurve() -> Curve3D? {
    Curve3D.interpolate(points: [
        SIMD3(0, 0, 0),
        SIMD3(100, 50, 0),
        SIMD3(150, -60, 40),
        SIMD3(250, 30, -20),
        SIMD3(300, 0, 60),
    ])
}

// MARK: - Sharp-corner/smooth-junction continuity fixtures (#1263)

/// Two BSpline arcs meeting at `(5,0,0)` at a sharp angle: only C0 holds. Shared by
/// `Issue490ContinuityDecoderTests`, `Issue495AnalysisOrderTests` and
/// `LocalAnalysisCurveContinuityTests`, which each built this same fixture geometry independently
/// (five sites across the three files) before the #1263 review pointed out the duplication.
/// Named `sharpCornerCurves` rather than `sharpCorner` because `LocalAnalysisCurveContinuityTests`
/// already has an `@Test func sharpCorner()` of its own.
func sharpCornerCurves() -> (Curve3D, Curve3D)? {
    guard let c1 = Curve3D.fit(points: [SIMD3(0, 0, 0), SIMD3(2.5, 0.5, 0), SIMD3(5, 0, 0)]),
        let c2 = Curve3D.fit(points: [SIMD3(5, 0, 0), SIMD3(5.5, 2.5, 0), SIMD3(5, 5, 0)])
    else { return nil }
    return (c1, c2)
}

/// Two BSpline arcs meeting smoothly at `(5,0,0)`. Shared by `Issue495AnalysisOrderTests` and
/// `LocalAnalysisCurveContinuityTests`, same history as `sharpCornerCurves()` above, and named
/// `smoothJunctionCurves` for the same reason (`LocalAnalysisCurveContinuityTests` has its own
/// `@Test func smoothJunction()`).
func smoothJunctionCurves() -> (Curve3D, Curve3D)? {
    guard let c1 = Curve3D.fit(points: [SIMD3(0, 0, 0), SIMD3(2.5, 1, 0), SIMD3(5, 0, 0)]),
        let c2 = Curve3D.fit(points: [SIMD3(5, 0, 0), SIMD3(7.5, -1, 0), SIMD3(10, 0, 0)])
    else { return nil }
    return (c1, c2)
}
