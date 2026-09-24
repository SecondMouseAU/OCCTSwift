import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Deduplicate")
struct BRepGraphDeduplicateTests {
    // A box has nothing to merge: every surface and curve is already canonical and nothing is
    // rewritten (BRepGraph_Deduplicate::Perform in the kernel probe).
    @Test func deduplicateBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let result = graph.deduplicate()
        #expect(result.canonicalSurfaces == 6)
        #expect(result.canonicalCurves == 12)
        #expect(result.surfaceRewrites == 0)
        #expect(result.curveRewrites == 0)
    }
}
