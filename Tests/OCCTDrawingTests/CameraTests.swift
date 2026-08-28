import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Metal Visualization Tests

@Suite("Camera Tests")
struct CameraTests {

    @Test("Default state valid")
    func defaultState() {
        let cam = Camera()
        let eye = cam.eye
        let center = cam.center
        let up = cam.up

        // Default camera should have non-zero eye and up
        let eyeLen = sqrt(eye.x * eye.x + eye.y * eye.y + eye.z * eye.z)
        let upLen = sqrt(up.x * up.x + up.y * up.y + up.z * up.z)
        #expect(eyeLen > 0)
        #expect(upLen > 0)
    }

    @Test("Projection matrix non-identity")
    func projectionMatrixNonIdentity() {
        let cam = Camera()
        cam.aspect = 1.5
        let proj = cam.projectionMatrix

        // Check it's not identity, at least one off-diagonal or non-1 diagonal
        let isIdentity =
            proj.columns.0.x == 1 && proj.columns.1.y == 1 && proj.columns.2.z == 1
            && proj.columns.3.w == 1 && proj.columns.0.y == 0 && proj.columns.0.z == 0
        #expect(!isIdentity)

        // Determinant should be non-zero
        let det = simd_determinant(proj)
        #expect(abs(det) > 1e-10)
    }

    @Test("View matrix changes with eye/center")
    func viewMatrixChanges() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 10)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        let view1 = cam.viewMatrix

        cam.eye = SIMD3(10, 0, 0)
        let view2 = cam.viewMatrix

        // The two view matrices should differ
        let diff = view1.columns.0.x - view2.columns.0.x
        let diff2 = view1.columns.2.z - view2.columns.2.z
        #expect(abs(diff) > 1e-6 || abs(diff2) > 1e-6)
    }

    @Test("Project/Unproject roundtrip")
    func projectUnprojectRoundtrip() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let original = SIMD3<Double>(5, 3, 0)
        let projected = cam.project(original)
        let recovered = cam.unproject(projected)

        #expect(abs(recovered.x - original.x) < 0.1)
        #expect(abs(recovered.y - original.y) < 0.1)
        #expect(abs(recovered.z - original.z) < 0.1)
    }

    @Test("Orthographic mode produces different matrices")
    func orthographicVsPerspective() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        cam.projectionType = .perspective
        let perspProj = cam.projectionMatrix

        cam.projectionType = .orthographic
        let orthoProj = cam.projectionMatrix

        // The projection matrices must differ
        let d =
            abs(perspProj.columns.0.x - orthoProj.columns.0.x)
            + abs(perspProj.columns.2.w - orthoProj.columns.2.w)
        #expect(d > 1e-6)
    }

    @Test("Fit bounding box adjusts camera")
    func fitBoundingBox() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0
        cam.zRange = (near: 0.1, far: 10000)

        let bboxMin = SIMD3<Double>(-5, -5, -5)
        let bboxMax = SIMD3<Double>(5, 5, 5)
        cam.fit(boundingBox: (min: bboxMin, max: bboxMax))

        // Project the center of the bounding box, should be near screen origin
        let boxCenter = SIMD3<Double>(0, 0, 0)
        let projected = cam.project(boxCenter)
        #expect(abs(projected.x) < 0.5)
        #expect(abs(projected.y) < 0.5)
    }
}
