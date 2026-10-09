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
        if let result = face.draftPrism(height1: 5, height2: 3, angle: 0.1) {
            #expect(result.faceCount > 0)
        }
    }
}
