import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-construct-custom-extend/probe.mm (transcript.txt beside it).
@Suite("ShapeCustom DirectModification")
struct ShapeCustomDirectModificationTests {
    @Test("Direct modification orients normals")
    func directModification() throws {
        // #766: was a silent `return` on a failed fixture and `isValid` inside `if let`. Kernel:
        // a valid 6-face solid of volume 1000 (a box already has direct normals).
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.directModification())
        #expect(result.isValid)
        #expect(result.faces().count == 6)
        #expect(abs((result.volume ?? 0) - 1000) < 1e-9)
    }
}
