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

        // #766: this used a box centred on the point the camera already looked at, and asserted
        // the projected centre within 0.5 of the origin, so a fit that did nothing passed (the
        // centre was already at (0, 0)). An off-centre box makes the fit do the work:
        // Graphic3d_Camera::FitMinMax moves the centre to (25, 25, 0) and scales so the box's
        // widest corner lands on the NDC edge, measured in
        // Scripts/repro/766-drawing-autodim-balloon-camera/transcript.txt. Unfitted, the box
        // centre projects to (0.05, 0.05).
        let bboxMin = SIMD3<Double>(20, 20, -5)
        let bboxMax = SIMD3<Double>(30, 30, 5)
        cam.fit(boundingBox: (min: bboxMin, max: bboxMax))

        let c = cam.center
        #expect(abs(c.x - 25) < 1e-9 && abs(c.y - 25) < 1e-9 && abs(c.z) < 1e-9, "centre \(c)")
        let projected = cam.project(SIMD3(25, 25, 0))
        #expect(abs(projected.x) < 1e-9)
        #expect(abs(projected.y) < 1e-9)
        var widest = 0.0
        for i in 0..<8 {
            let corner = SIMD3(
                i & 1 == 0 ? bboxMin.x : bboxMax.x,
                i & 2 == 0 ? bboxMin.y : bboxMax.y,
                i & 4 == 0 ? bboxMin.z : bboxMax.z)
            let s = cam.project(corner)
            widest = max(widest, abs(s.x), abs(s.y))
        }
        #expect(abs(widest - 1) < 1e-6, "widest corner should sit on the NDC edge, got \(widest)")
    }
}
