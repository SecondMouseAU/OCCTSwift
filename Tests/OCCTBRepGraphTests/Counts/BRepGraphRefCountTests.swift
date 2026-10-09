import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Ref Counts")
struct BRepGraphRefCountTests {
    @Test func refCountsForBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box has shells, faces, wires, coedges, vertices refs
                #expect(graph.shellRefCount >= 1)
                #expect(graph.faceRefCount >= 6)
                #expect(graph.wireRefCount >= 6)
                #expect(graph.coedgeRefCount >= 24)
                #expect(graph.vertexRefCount >= 16)  // edges have start/end vertex refs
                #expect(graph.solidRefCount >= 0)
                #expect(graph.childRefCount >= 0)
                #expect(graph.occurrenceRefCount == 0)  // no assembly
            }
        }
    }

    @Test func refCountsConsistency() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Face ref count should be >= face definition count
                #expect(graph.faceRefCount >= graph.faceCount)
                // Wire ref count should be >= wire definition count
                #expect(graph.wireRefCount >= graph.wireCount)
            }
        }
    }
}
