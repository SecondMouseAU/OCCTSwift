import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.68.0 Tests

@Suite("TopTrans CurveTransition Tests")
struct TopTransCurveTransitionTests {
    @Test func basicCurveTransition() {
        let result = Shape.curveTransition(
            tangent: SIMD3(1, 0, 0),
            boundaryTangent: SIMD3(0, 1, 0),
            boundaryNormal: SIMD3(0, 0, 1))
        _ = result.stateBefore
        _ = result.stateAfter
    }

    @Test func curveTransitionWithCurvature() {
        let result = Shape.curveTransitionWithCurvature(
            tangent: SIMD3(1, 0, 0),
            curveNormal: SIMD3(0, 0, 1), curveCurvature: 0.1,
            boundaryTangent: SIMD3(0, 1, 0),
            boundaryNormal: SIMD3(0, 0, 1),
            surfaceCurvature: 0.05)
        _ = result.stateBefore
        _ = result.stateAfter
    }
}
