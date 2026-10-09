import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dConvert_ApproxArcsSegments")
struct ApproxArcsSegmentsTests {
    @Test("approximate circle as arcs")
    func approxCircle() {
        if let circ = Curve2D.circle(center: SIMD2(0, 0), radius: 5),
            let trimmed = circ.trimmed(from: 0, to: .pi)
        {
            let segments = trimmed.approxArcsAndSegments(tolerance: 0.1, angleTolerance: 0.1)
            #expect(segments.count >= 1)
        }
    }

    @Test("approximate line")
    func approxLine() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)),
            let trimmed = line.trimmed(from: 0, to: 10)
        {
            let segments = trimmed.approxArcsAndSegments(tolerance: 0.1, angleTolerance: 0.1)
            #expect(segments.count >= 1)
        }
    }
}
