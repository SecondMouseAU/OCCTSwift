import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.68.0 Tests

// States pinned to TopTrans_CurveTransition on the pinned kernel
// (Scripts/repro/766-curve-final-sampling/transcript.txt): a curve along +x crossing a boundary
// whose normal is +z is OUT before and IN after, with and without the curvature terms.
@Suite("TopTrans CurveTransition Tests")
struct TopTransCurveTransitionTests {
    @Test func basicCurveTransition() {
        let result = Shape.curveTransition(
            tangent: SIMD3(1, 0, 0),
            boundaryTangent: SIMD3(0, 1, 0),
            boundaryNormal: SIMD3(0, 0, 1))
        #expect(result.stateBefore == .out)
        #expect(result.stateAfter == .in)
    }

    @Test func curveTransitionWithCurvature() {
        let result = Shape.curveTransitionWithCurvature(
            tangent: SIMD3(1, 0, 0),
            curveNormal: SIMD3(0, 0, 1), curveCurvature: 0.1,
            boundaryTangent: SIMD3(0, 1, 0),
            boundaryNormal: SIMD3(0, 0, 1),
            surfaceCurvature: 0.05)
        #expect(result.stateBefore == .out)
        #expect(result.stateAfter == .in)
    }
}
