// Curve2DInterpolateParityTestFixtures.swift
// Shared fixture for the Curve2D interpolation parity suites (#1256).
// No @Suite or test functions here: only a shared assertion helper.

import Testing
import simd

@testable import OCCTSwift

/// Asserts two `Curve2D`s built by parity-checked entry points describe the same curve: same
/// closed/periodic flags, same domain bounds, and matching points at 11 evenly-spaced fractional
/// parameters across that domain.
func expectSameCurve(
    _ a: Curve2D?, _ b: Curve2D?,
    _ comment: Comment? = nil
) {
    #expect(a != nil, comment)
    #expect(b != nil, comment)
    guard let a, let b else { return }
    #expect(a.isClosed == b.isClosed, comment)
    #expect(a.isPeriodic == b.isPeriodic, comment)
    #expect(abs(a.domain.lowerBound - b.domain.lowerBound) < 1e-12, comment)
    #expect(abs(a.domain.upperBound - b.domain.upperBound) < 1e-12, comment)
    for t in stride(from: 0.0, through: 1.0, by: 0.1) {
        let ua = a.domain.lowerBound + t * (a.domain.upperBound - a.domain.lowerBound)
        let ub = b.domain.lowerBound + t * (b.domain.upperBound - b.domain.lowerBound)
        let pa = a.point(at: ua)
        let pb = b.point(at: ub)
        #expect(abs(pa.x - pb.x) < 1e-9, comment)
        #expect(abs(pa.y - pb.y) < 1e-9, comment)
    }
}
