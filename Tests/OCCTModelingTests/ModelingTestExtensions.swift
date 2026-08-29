// ModelingTestExtensions.swift
// Shared extensions for OCCTModelingTests.
// No @Suite or @Test: only shared helpers.

import simd

extension SIMD3 where Scalar == Double {
    /// Returns a unit vector in the same direction, or `self` if the length is zero.
    ///
    /// Uses a small epsilon threshold (1e-10) rather than exact zero to avoid
    /// normalizing near-zero vectors that would produce NaN or extreme values.
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 1e-10 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}
