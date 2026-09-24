import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
@Suite("ShapeFix SplitCommonVertex Tests")
struct ShapeFixSplitCommonVertexTests {
    @Test("Split common vertices on box")
    func splitVertices() throws {
        // #766: was non-nil plus `isValid` inside `if let`. Kernel: a box has nothing to split,
        // 8 vertices and volume 1000 afterwards.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let r = try #require(box.splitCommonVertices())
        #expect(r.isValid)
        #expect(r.subShapes(ofType: .vertex).count == 8)
        #expect(abs((r.volume ?? 0) - 1000) < 1e-9)
    }
}
