import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe RevolutionForm Tests")
struct LocOpeRevolutionFormTests {
    @Test("Revolution form creates swept shape")
    func revolutionForm() throws {
        let face = Shape.box(width: 3, height: 3, depth: 0.1)!
        let result = face.localRevolutionForm(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angle: .pi / 2
        )
        #expect(result != nil, "Revolution form should produce a shape")
    }
}
