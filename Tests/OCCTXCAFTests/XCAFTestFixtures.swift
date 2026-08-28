// XCAFTestFixtures.swift
// Shared fixtures for OCCTXCAFTests.
// No @Suite or @Test: only shared helpers.

import simd

/// Every per-domain test target carries its own copy of this helper (see CLAUDE.md's Test Layout
/// note: "the only shared helper is SIMD3.normalized"); moved here verbatim from
/// OCCTXCAFTests.swift when that monolith was split by @Suite (#1307), same as the other 16
/// domains' own copy lives in whichever file is that target's canonical home for it.
extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}
