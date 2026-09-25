import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
@Suite("ShapeFix EdgeProjAux Tests")
struct ShapeFixEdgeProjAuxTests {
    @Test func projectEdge() throws {
        // #766: was `last > first || last == first` inside `if let`. Kernel: [0, 10].
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.edgeProjAux(faceIndex: 0, edgeIndex: 0))
        #expect(result.first == 0)
        #expect(result.last == 10)
    }
}
