import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Face Queries")
struct BRepGraphFaceQueryTests {
    @Test func faceAdjacency() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let adj = graph.adjacentFaces(of: 0)
                #expect(adj.count == 4)
            }
        }
    }

    @Test func sharedEdges() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let adj = graph.adjacentFaces(of: 0)
                if adj.count > 0 {
                    let shared = graph.sharedEdges(between: 0, and: adj[0])
                    #expect(shared.count == 1)
                }
            }
        }
    }

    @Test func outerWire() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let wire = graph.outerWire(of: 0)
                #expect(wire >= 0)
            }
        }
    }
}
