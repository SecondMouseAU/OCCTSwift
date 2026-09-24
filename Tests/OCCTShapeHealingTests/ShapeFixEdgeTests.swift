import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapefix/probe.mm (transcript.txt beside it).
// Before #766 both asserted `>= 0`, true of every count. Kernel: no box edge needs either fix.
@Suite("ShapeFix Edge Tests")
struct ShapeFixEdgeTests {
    @Test("Fix same parameter on box edges")
    func fixSameParameter() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.fixEdgeSameParameter() == 0)
    }

    @Test("Fix vertex tolerance on box edges")
    func fixVertexTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.fixEdgeVertexTolerance() == 0)
    }
}
