import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe RevolutionForm Tests")
struct LocOpeRevolutionFormTests {
    @Test("Revolution form creates swept shape")
    func revolutionForm() throws {
        // #766: this revolved `Shape.box(width: 3, height: 3, depth: 0.1)`, a centred solid
        // straddling the axis, and LocOpe_RevolutionForm returned an EMPTY compound for it, which
        // `result != nil` accepted. The profile is now a 2 x 5 face in the XZ plane at x = 9..11,
        // and a quarter turn gives the kernel's solid of volume (pi/2) * 10 * 10 = 157.08
        // (LocOpe_RevolutionForm, Scripts/repro/766-join-local-loft/).
        let wire = Wire.path(
            [SIMD3(9, 0, -2.5), SIMD3(11, 0, -2.5), SIMD3(11, 0, 2.5), SIMD3(9, 0, 2.5)], closed: true)
        let face = wire.flatMap { Shape.face(from: $0) }
        #expect(face != nil)
        guard let face else { return }
        let result = face.localRevolutionForm(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angle: .pi / 2
        )
        #expect(result != nil, "Revolution form should produce a shape")
        if let result {
            #expect(result.isValid)
            #expect(result.faceCount == 6)
            #expect(abs((result.volume ?? 0) - 157.07963267948972) < 1e-6)
        }
    }
}
