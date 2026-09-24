import Testing
import simd

@testable import OCCTSwift

@Suite("Extended Revolution")
struct ExtendedRevolutionTests {

    // #766: both tests nested `#expect(revolved != nil)` three `if let`s deep, and their profile
    // lay in the XY plane, perpendicular to the Z axis it was revolved about. BRepPrimAPI_MakeRevol
    // then sweeps it within its own plane: the result is a zero-volume solid that BRepCheck
    // rejects, and `!= nil` accepted it. The profile now stands in the XZ plane (x = 9..11,
    // z = -2.5..2.5), so the axis lies in its plane, and each test pins the kernel's volume
    // (2 pi * 10 * 10 when full) and validity, see Scripts/repro/766-convert-check-evolved-revol/.
    private func xzProfileFace() -> Shape? {
        let wire = Wire.path(
            [SIMD3(9, 0, -2.5), SIMD3(11, 0, -2.5), SIMD3(11, 0, 2.5), SIMD3(9, 0, 2.5)], closed: true)
        #expect(wire != nil)
        guard let wire else { return nil }
        let face = Shape.face(from: wire)
        #expect(face != nil)
        return face
    }
    @Test func revolveFaceFull() {
        // Revolve a face around an axis to create a solid of revolution
        if let face = xzProfileFace() {
            let revolved = face.revolved(axisOrigin: SIMD3(0, 0, 0), axisDirection: SIMD3(0, 0, 1))
            #expect(revolved != nil)
            if let revolved {
                #expect(revolved.isValid)
                #expect(abs((revolved.volume ?? 0) - 628.31853071795877) < 1e-6)
            }
        }
    }

    @Test func revolveFacePartial() {
        if let face = xzProfileFace() {
            let half = face.revolved(axisOrigin: SIMD3(0, 0, 0), axisDirection: SIMD3(0, 0, 1), angle: .pi)
            #expect(half != nil)
            if let half {
                #expect(half.isValid)
                #expect(abs((half.volume ?? 0) - 314.15926535897944) < 1e-6)
            }
        }
    }
}
