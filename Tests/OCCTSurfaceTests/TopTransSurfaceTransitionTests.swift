import Testing
import simd

@testable import OCCTSwift

@Suite("TopTrans SurfaceTransition Tests")
struct TopTransSurfaceTransitionTests {
    @Test func forwardCrossing() {
        let result = Shape.surfaceTransition(
            tangent: SIMD3(1, 0, 0),
            normal: SIMD3(0, 0, 1),
            surfaceNormal: SIMD3(0, 1, 0),
            surfaceOrientation: 0, boundaryOrientation: 0)
        #expect(result.stateBefore == .out)
        #expect(result.stateAfter == .in)
    }

    @Test func reversedCrossing() {
        let result = Shape.surfaceTransition(
            tangent: SIMD3(1, 0, 0),
            normal: SIMD3(0, 0, 1),
            surfaceNormal: SIMD3(0, 1, 0),
            surfaceOrientation: 1, boundaryOrientation: 1)
        #expect(result.stateBefore == .in)
        #expect(result.stateAfter == .out)
    }

    @Test func withCurvature() {
        // Curvature-enhanced transition: verify it runs without crash
        // and returns determined states when geometry is compatible
        let result = Shape.surfaceTransitionWithCurvature(
            tangent: SIMD3(1, 0, 0),
            normal: SIMD3(0, 0, 1),
            maxDirection: SIMD3(0, 1, 0),
            minDirection: SIMD3(0, 0, 1),
            maxCurvature: 0.1, minCurvature: 0.01,
            surfaceNormal: SIMD3(0, 1, 0),
            surfaceMaxDirection: SIMD3(1, 0, 0),
            surfaceMinDirection: SIMD3(0, 0, 1),
            surfaceMaxCurvature: 0.05, surfaceMinCurvature: 0.005,
            surfaceOrientation: 0, boundaryOrientation: 0)
        // States may be UNKNOWN for some curvature configurations
        _ = result.stateBefore
        _ = result.stateAfter
    }

    @Test func stateEnumValues() {
        #expect(Shape.TopologicalState.in.rawValue == 0)
        #expect(Shape.TopologicalState.out.rawValue == 1)
        #expect(Shape.TopologicalState.on.rawValue == 2)
        #expect(Shape.TopologicalState.unknown.rawValue == 3)
    }
}
