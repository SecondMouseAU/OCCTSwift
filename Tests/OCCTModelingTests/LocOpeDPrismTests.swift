import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe Draft Prism Tests")
struct LocOpeDPrismTests {
    @Test("Draft prism with two heights")
    func draftPrismTwoHeights() throws {
        // Get a face from a box
        let box = Shape.box(width: 10, height: 10, depth: 1)!
        let face = box.face(at: 0)!
        let result = face.draftPrism(height1: 5, height2: 3, angle: 0.1)
        #expect(result != nil)
    }

    @Test("Draft prism single height")
    func draftPrismSingleHeight() throws {
        let box = Shape.box(width: 10, height: 10, depth: 1)!
        let face = box.face(at: 0)!
        let result = face.draftPrism(height: 5, angle: 0.1)
        #expect(result != nil)
    }

    @Test("Draft prism produces faces")
    func draftPrismHasFaces() throws {
        let box = Shape.box(width: 10, height: 10, depth: 1)!
        let face = box.face(at: 0)!
        // #766: this was `if let result = ... { #expect(result.faceCount > 0) }`, which passed
        // when the prism failed (nil skipped the only assertion) and accepted any face count.
        // Pinned to the kernel (Scripts/repro/766-modeling-locope-dprism): LocOpe_DPrism with
        // two heights on face 0 of this box is a valid solid of 10 faces; the single-height
        // form of the same face has 6, so the count also tells the two constructors apart.
        guard let result = face.draftPrism(height1: 5, height2: 3, angle: 0.1) else {
            Issue.record("draftPrism(height1:height2:angle:) returned nil")
            return
        }
        #expect(result.faceCount == 10)
        #expect(result.isValid)
    }
}
