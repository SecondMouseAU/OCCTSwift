import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe Draft Prism Tests")
struct LocOpeDPrismTests {
    @Test("Draft prism with two heights")
    func draftPrismTwoHeights() throws {
        // Get a face from a box
        let box = try #require(Shape.box(width: 10, height: 10, depth: 1))
        let face = try #require(box.face(at: 0))
        // #766: this asserted only `result != nil`, so any shape passed, the wrong prism
        // included. Pinned to the kernel (Scripts/repro/766-modeling-locope-dprism,
        // transcript-evidence-fix.txt): LocOpe_DPrism(face, 5, 3, 0.1) on face 0 of this box is a
        // valid solid of 10 faces and volume 64.050646231928056.
        let result = try #require(face.draftPrism(height1: 5, height2: 3, angle: 0.1))
        #expect(result.isValid)
        #expect(result.faceCount == 10)
        let volume = try #require(result.volume)
        #expect(abs(volume - 64.050646231928056) < 1e-6)
    }

    @Test("Draft prism single height")
    func draftPrismSingleHeight() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 1))
        let face = try #require(box.face(at: 0))
        // #766: this asserted only `result != nil`. Pinned to the kernel
        // (Scripts/repro/766-modeling-locope-dprism, transcript-evidence-fix.txt):
        // LocOpe_DPrism(face, 5, 0.1) on the same face is a valid solid of 6 faces and volume
        // 24.085995119264528, which also tells it apart from the two-height form above.
        let result = try #require(face.draftPrism(height: 5, angle: 0.1))
        #expect(result.isValid)
        #expect(result.faceCount == 6)
        let volume = try #require(result.volume)
        #expect(abs(volume - 24.085995119264528) < 1e-6)
    }

    @Test("Draft prism produces faces")
    func draftPrismHasFaces() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 1))
        let face = try #require(box.face(at: 0))
        // #766: this was `if let result = ... { #expect(result.faceCount > 0) }`, which passed
        // when the prism failed (nil skipped the only assertion) and accepted any face count.
        // Pinned to the kernel (Scripts/repro/766-modeling-locope-dprism): LocOpe_DPrism with
        // two heights on face 0 of this box is a valid solid of 10 faces; the single-height
        // form of the same face has 6, so the count also tells the two constructors apart.
        let result = try #require(face.draftPrism(height1: 5, height2: 3, angle: 0.1))
        #expect(result.faceCount == 10)
        #expect(result.isValid)
    }
}
