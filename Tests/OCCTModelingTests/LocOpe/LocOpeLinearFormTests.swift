import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe LinearForm Tests")
struct LocOpeLinearFormTests {
    @Test("Linear form creates swept shape")
    func linearForm() throws {
        let face = Shape.box(width: 5, height: 5, depth: 0.1)!
        let result = face.localLinearForm(
            direction: SIMD3(0, 0, 10),
            from: SIMD3(0, 0, 0),
            to: SIMD3(0, 0, 10)
        )
        #expect(result != nil, "Linear form should produce a shape")
    }
}
