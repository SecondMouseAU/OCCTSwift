import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Occurrences")
struct BRepGraphOccurrenceTests {
    @Test func occurrenceCountForPrimitive() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.occurrenceCount == 0)
            }
        }
    }
}
