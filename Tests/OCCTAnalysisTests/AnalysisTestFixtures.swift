// AnalysisTestFixtures.swift
// Shared fixture for OCCTAnalysisTests.
// No test suite or test cases here, only the SIMD3.normalized helper.

import Foundation
import simd

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}
