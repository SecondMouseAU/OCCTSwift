import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to Geom_BezierCurve after the same edit
// (Scripts/repro/766-curve-bezier-bspline/transcript.txt). The earlier versions nested their
// checks in `if let`, and setPoleWithWeight checked only the Bool the bridge returns, which is
// `true` whether or not the edit happened (#766).
@Suite("v0.126.0, Curve3D Bezier completions")
struct Curve3DBezierCompletionsTests {
    @Test("InsertPoleBefore increases pole count")
    func insertPoleBefore() {
        guard let c = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(1, 1, 1)]) else {
            Issue.record("Bezier not built")
            return
        }
        #expect(c.poleCount == 2)
        #expect(c.bezierInsertPoleBefore(1, point: SIMD3(0.5, 0.5, 0.5)))
        #expect(c.poleCount == 3)
        #expect(c.bezierStartPoint == SIMD3(0.5, 0.5, 0.5))
    }

    @Test("Reverse swaps start and end")
    func reverse() {
        guard let c = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(10, 20, 30)]) else {
            Issue.record("Bezier not built")
            return
        }
        #expect(c.bezierReverse())
        #expect(c.bezierStartPoint == SIMD3(10, 20, 30))
        #expect(c.bezierEndPoint == SIMD3(0, 0, 0))
    }

    @Test("SetPoleWithWeight on rational Bezier")
    func setPoleWithWeight() {
        guard
            let c = Curve3D.bezier(
                poles: [SIMD3(0, 0, 0), SIMD3(5, 5, 0), SIMD3(10, 0, 0)],
                weights: [1, 1, 1])
        else {
            Issue.record("Bezier not built")
            return
        }
        #expect(c.bezierSetPoleWithWeight(index: 2, point: SIMD3(5, 10, 0), weight: 2.0))
        #expect(c.bezierWeights == [1, 2, 1])
        // C(0.5) = (0.25 * 0 + 2 * 0.5 * 2 * (5, 10) + 0.25 * (10, 0)) / (0.25 + 1 + 0.25)
        #expect(simd_distance(c.point(at: 0.5), SIMD3(5, 6.666666666666667, 0)) < 1e-12)
    }
}
