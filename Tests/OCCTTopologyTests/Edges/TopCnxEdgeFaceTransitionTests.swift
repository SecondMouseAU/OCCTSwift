import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("TopCnx EdgeFaceTransition Tests")
struct TopCnxEdgeFaceTransitionTests {
    @Test("linear edge with single face")
    func linearEdgeSingleFace() {
        let face = Shape.FaceInterference(
            tangent: SIMD3(1, 0, 0),
            normal: SIMD3(0, 0, 1),
            curvature: 0,
            orientation: 0,  // FORWARD
            transition: 0,  // FORWARD
            boundaryTransition: 0,  // FORWARD
            tolerance: 1e-6)

        let result = Shape.edgeFaceTransition(
            edgeTangent: SIMD3(1, 0, 0),
            edgeNormal: SIMD3(0, 0, 0),  // linear
            edgeCurvature: 0,
            faces: [face])

        #expect(result.transition >= 0 && result.transition <= 3)
        #expect(result.boundaryTransition >= 0 && result.boundaryTransition <= 3)
    }

    @Test("curved edge with two faces")
    func curvedEdgeTwoFaces() {
        let face1 = Shape.FaceInterference(
            tangent: SIMD3(1, 0, 0),
            normal: SIMD3(0, 0, 1),
            curvature: 0,
            orientation: 0, transition: 0, boundaryTransition: 0,
            tolerance: 1e-6)
        let face2 = Shape.FaceInterference(
            tangent: SIMD3(1, 0, 0),
            normal: SIMD3(0, 0, -1),
            curvature: 0,
            orientation: 1, transition: 1, boundaryTransition: 1,
            tolerance: 1e-6)

        let result = Shape.edgeFaceTransition(
            edgeTangent: SIMD3(1, 0, 0),
            edgeNormal: SIMD3(0, 1, 0),
            edgeCurvature: 0.1,
            faces: [face1, face2])

        #expect(result.transition >= 0 && result.transition <= 3)
    }
}
