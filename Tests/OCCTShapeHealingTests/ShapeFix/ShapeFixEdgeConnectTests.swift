import Foundation
import Testing

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
@Suite("ShapeFix EdgeConnect Tests")
struct ShapeFixEdgeConnectTests {
    @Test func fixEdgeConnect() throws {
        // #766: was non-nil inside `if let`. The result keeps the box's 6 faces and volume.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let fixed = try #require(box.fixEdgeConnect())
        #expect(fixed.faces().count == 6)
        #expect(abs((fixed.volume ?? 0) - 1000) < 1e-9)
    }

    // #3252: ShapeFix_EdgeConnect rewrites edge vertices in place and, run over a box, leaves it
    // invalid (Scripts/repro/3252/transcript.txt). The receiver must survive, and so must the result.
    @Test func fixEdgeConnectLeavesCallersShapeValid() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.isValid)
        let fixed = try #require(box.fixEdgeConnect())
        #expect(box.isValid)
        #expect(fixed.isValid)
    }
}
