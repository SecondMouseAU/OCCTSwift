import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to Approx_Curve3d on the same curves (Scripts/repro/766-curve-gcpnts-approx/transcript.txt).
// The earlier versions sat inside `if let`, gated the error check on `isDone`, and approxLine
// checked only `isDone` (#766).
@Suite("GeomConvert ApproxCurve Tests")
struct GeomConvertApproxCurveTests {
    @Test("approximate circle as BSpline")
    func approxCircle() {
        guard let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10)
        else {
            Issue.record("circle not built")
            return
        }
        let result = circle.approxWithDetails(tolerance: 1e-3)
        #expect(result.hasResult)
        #expect(result.curve != nil)
        #expect(result.isDone)
        #expect(abs(result.maxError - 0.00067601082781564242) < 1e-12)
    }

    @Test("approximate line as BSpline")
    func approxLine() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 1, 0)),
            let t = line.trimmed(from: 0, to: 10)
        else {
            Issue.record("trimmed line not built")
            return
        }
        let result = t.approxWithDetails(tolerance: 1e-6, continuity: .c1)
        #expect(result.isDone)
        #expect(result.maxError < 1e-12)
        guard let c = result.curve else {
            Issue.record("no approximated curve")
            return
        }
        #expect(simd_distance(c.endPoint, SIMD3(10, 10, 0) / 2.0.squareRoot()) < 1e-9)
    }
}
