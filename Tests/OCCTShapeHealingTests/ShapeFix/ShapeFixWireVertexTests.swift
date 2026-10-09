import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
@Suite("ShapeFix WireVertex Tests")
struct ShapeFixWireVertexTests {
    @Test("Fix wire vertices on box")
    func fixWireVertices() throws {
        // #766: was `>= 0`. Kernel: nothing to fix on any box wire at 1e-4.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.fixWireVertices(precision: 1e-4) == 0)
    }
}
