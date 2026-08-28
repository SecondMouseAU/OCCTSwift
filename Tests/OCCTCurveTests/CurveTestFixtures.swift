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
