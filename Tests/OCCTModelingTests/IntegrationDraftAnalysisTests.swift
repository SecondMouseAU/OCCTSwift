import Testing
import simd

@testable import OCCTSwift

// MARK: - Integration Tests: Esoteric/Advanced

@Suite("Integration: Draft Analysis")
struct IntegrationDraftAnalysisTests {

    @Test func boxFaceNormalClassification() {
        guard let box = Shape.box(width: 20, height: 30, depth: 40) else {
            #expect(false, "Failed to create box")
            return
        }

        let allFaces = box.faces()
        #expect(allFaces.count == 6, "Box should have 6 faces")

        let pullDirection = SIMD3<Double>(0, 0, 1)  // Z-up pull direction

        var topBottom = 0
        var side = 0

        for face in allFaces {
            if let n = face.normal {
                let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                if len < 1e-10 { continue }
                let normalized = n / len
                // dot product with pull direction
                let dot =
                    normalized.x * pullDirection.x + normalized.y * pullDirection.y + normalized.z
                    * pullDirection.z
                let angleDeg = acos(min(max(dot, -1.0), 1.0)) * 180.0 / .pi

                if angleDeg < 5.0 || angleDeg > 175.0 {
                    topBottom += 1  // top or bottom face
                } else if abs(angleDeg - 90.0) < 5.0 {
                    side += 1  // side face
                }
            }
        }

        #expect(topBottom == 2, "Box should have 2 top/bottom faces")
        #expect(side == 4, "Box should have 4 side faces")
    }
}
