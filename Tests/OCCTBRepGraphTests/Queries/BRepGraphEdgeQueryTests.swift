import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Edge Queries")
struct BRepGraphEdgeQueryTests {
    @Test func edgeFaceCount() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let nbFaces = graph.faceCount(of: 0)
                #expect(nbFaces == 2)
            }
        }
    }

    @Test func edgeFaces() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let faces = graph.faces(of: 0)
                #expect(faces.count == 2)
            }
        }
    }

    @Test func noBoundaryEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(!graph.isBoundaryEdge(i))
                }
            }
        }
    }

    @Test func allManifoldEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(graph.isManifoldEdge(i))
                }
            }
        }
    }

    @Test func edgeAdjacency() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let adj = graph.adjacentEdges(of: 0)
                #expect(adj.count > 0)
            }
        }
    }
}
