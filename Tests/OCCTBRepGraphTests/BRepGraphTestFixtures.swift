// BRepGraphTestFixtures.swift
// Shared fixtures for OCCTBRepGraphTests.
// No suites or test functions here: only the shared SIMD3.normalized helper, carried over
// verbatim from the pre-split OCCTBRepGraphTests.swift (#1303 split). Declared once per
// module, matching CLAUDE.md's Test Layout note that SIMD3.normalized is redefined per
// target as needed; not currently called by any suite in this target, kept here rather than
// dropped since this is a pure move.

import Foundation
import OCCTSwift
import Testing
import simd

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}
