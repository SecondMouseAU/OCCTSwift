import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Deduplicate")
struct BRepGraphDeduplicateTests {
    @Test func deduplicateBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let result = graph.deduplicate()
                #expect(result.canonicalSurfaces == 6)
                #expect(result.canonicalCurves == 12)
            }
        }
    }
}
