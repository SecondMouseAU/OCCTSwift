// MathTestFixtures.swift
// Shared fixtures for OCCTMathTests.
// No suites or test declarations here: only a shared, non-suite-specific helper.

import Foundation
import simd

/// See Test Layout in CLAUDE.md: "the only shared helper is `SIMD3.normalized`
/// (redefine it in the target if needed)". Not owned by any single suite in this
/// split, and not currently used by any of them (each suite that needs a normalized
/// vector reaches it through `GeomVector3D.normalized()` or a bridge call instead),
/// so it lives here rather than moving with one particular suite.
extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}
