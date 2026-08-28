// TopologyTestFixtures.swift
// Shared fixtures for OCCTTopologyTests.
// No @Suite or @Test: only the SIMD3.normalized helper every per-domain test target's
// header carries per CLAUDE.md's Test Layout convention ("the only shared helper is
// SIMD3.normalized"). Unused within this target as of the #1304 split; carried here
// verbatim from OCCTTopologyTests.swift's header rather than dropped, since this split
// is a pure move.

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
