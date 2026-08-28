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
