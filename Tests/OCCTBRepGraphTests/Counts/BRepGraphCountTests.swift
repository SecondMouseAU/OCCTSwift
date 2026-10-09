import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Counts")
struct BRepGraphCountTests {
    @Test func activeCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.activeFaceCount == 6)
                #expect(graph.activeEdgeCount == 12)
                #expect(graph.activeVertexCount == 8)
            }
        }
    }

    @Test func geometryCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.surfaceCount == 6)
                #expect(graph.curve3DCount == 12)
                #expect(graph.curve2DCount > 0)
            }
        }
    }

    @Test func coedgeCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.coedgeCount == 24)
            }
        }
    }
}
