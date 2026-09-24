import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Approx SameParameter Tests")
struct ApproxSameParameterTests {
    // The earlier version wrapped its one expectation in `if let`, so a bridge returning nil
    // passed with no expectation run (#766). Approx_SameParameter reports these two lines as
    // same-parameter (Scripts/repro/766-curve-adaptor-approx/transcript.txt).
    @Test("same parameter on line/plane")
    func sameParamLinePlane() {
        guard let line3d = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let line2d = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)),
            let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        else {
            Issue.record("could not build the line, 2D line or plane")
            return
        }
        guard let r = line3d.checkSameParameter(curve2D: line2d, surface: plane) else {
            Issue.record("Approx_SameParameter reported not done")
            return
        }
        #expect(r.isSameParameter)
    }
}
