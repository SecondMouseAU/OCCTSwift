import Testing
import simd

@testable import OCCTSwift

@Suite("Glue Tests")
struct GlueTests {

    @Test("Glue two boxes")
    func glueTwoBoxes() {
        // Create two boxes that share a face
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(10, 0, 0))!

        let glued = Shape.glue(box1, box2, tolerance: 1e-6)

        #expect(glued != nil)
        #expect(glued!.isValid)

        // Volume should be sum of both
        let gluedVolume = glued!.volume ?? 0
        let expectedVolume = 10.0 * 10.0 * 10.0 * 2
        #expect(abs(gluedVolume - expectedVolume) < 1.0)
    }
}
