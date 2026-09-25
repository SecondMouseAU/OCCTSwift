import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe LinearForm Tests")
struct LocOpeLinearFormTests {
    @Test("Linear form creates swept shape")
    func linearForm() throws {
        let face = try #require(Shape.box(width: 5, height: 5, depth: 0.1))
        // #766: this asserted only `result != nil`, so any shape passed. Pinned to the kernel
        // (Scripts/repro/766-modeling-locope-linear-form): LocOpe_LinearForm on this box gives a
        // valid compound of 12 faces and volume 5, the bridge and the kernel agreeing to 2e-14.
        let result = try #require(
            face.localLinearForm(
                direction: SIMD3(0, 0, 10),
                from: SIMD3(0, 0, 0),
                to: SIMD3(0, 0, 10)
            ))
        #expect(result.isValid)
        #expect(result.faceCount == 12)
        let volume = try #require(result.volume)
        #expect(abs(volume - 5.0) < 1e-6)
    }
}
