import Foundation
import Testing
import simd

@testable import OCCTSwift

// Counts pinned to the kernel probe (Scripts/repro/766-brepgraph-products-refs): every expectation was a lower bound, and the
// vertex bound (`>= 16`) sat eight below the real 24 (#1986).
@Suite("BRepGraph Ref Counts")
struct BRepGraphRefCountTests {
    @Test func refCountsForBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.shellRefCount == 1)
        #expect(graph.faceRefCount == 6)
        #expect(graph.wireRefCount == 6)
        #expect(graph.coedgeRefCount == 24)
        #expect(graph.vertexRefCount == 24)  // each edge's start and end
        #expect(graph.solidRefCount == 0)
        #expect(graph.childRefCount == 0)
        #expect(graph.occurrenceRefCount == 0)  // no assembly
    }

    @Test func refCountsConsistency() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // A box uses each face and each wire exactly once.
        #expect(graph.faceRefCount == graph.faceCount)
        #expect(graph.wireRefCount == graph.wireCount)
    }
}
