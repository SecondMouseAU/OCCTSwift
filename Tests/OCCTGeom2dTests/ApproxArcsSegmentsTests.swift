import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dConvert_ApproxArcsSegments")
struct ApproxArcsSegmentsTests {
    // #1979: both tests nested their only assertion in `if let`, and asserted `count >= 1`, so a
    // result that dropped a piece passed. Pinned to what Geom2dConvert_ApproxArcsSegments returns
    // for these inputs (Scripts/repro/766-geom2d-aht-axisplacement/): two arcs for the half
    // circle, one segment for the line.
    @Test("approximate circle as arcs")
    func approxCircle() throws {
        let circ = try #require(Curve2D.circle(center: SIMD2(0, 0), radius: 5))
        let trimmed = try #require(circ.trimmed(from: 0, to: .pi))
        let segments = trimmed.approxArcsAndSegments(tolerance: 0.1, angleTolerance: 0.1)
        try #require(segments.count == 2)
        let start = segments[0].point(at: segments[0].domain.lowerBound)
        let end = segments[1].point(at: segments[1].domain.upperBound)
        #expect(simd_distance(start, SIMD2(5, 0)) < 1e-9)
        #expect(simd_distance(end, SIMD2(-5, 0)) < 1e-9)
    }

    @Test("approximate line")
    func approxLine() throws {
        let line = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        let trimmed = try #require(line.trimmed(from: 0, to: 10))
        let segments = trimmed.approxArcsAndSegments(tolerance: 0.1, angleTolerance: 0.1)
        try #require(segments.count == 1)
        let seg = segments[0]
        #expect(simd_distance(seg.point(at: seg.domain.lowerBound), SIMD2(0, 0)) < 1e-9)
        #expect(simd_distance(seg.point(at: seg.domain.upperBound), SIMD2(10, 0)) < 1e-9)
    }
}
