import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Edge Wires CoEdges")
struct BRepGraphEdgeWiresCoEdgesTests {
    @Test func edgeWires() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    let wires = graph.edgeWires(i)
                    // Each edge of a box belongs to at least 1 wire
                    #expect(!wires.isEmpty)
                    for w in wires {
                        #expect(w >= 0 && w < graph.wireCount)
                    }
                }
            }
        }
    }

    @Test func edgeCoEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    let coedges = graph.edgeCoEdges(i)
                    // Each edge has at least 1 coedge
                    #expect(!coedges.isEmpty)
                    for c in coedges {
                        #expect(c >= 0 && c < graph.coedgeCount)
                    }
                }
            }
        }
    }

    @Test func edgeFindCoEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // For each edge, find a coedge on one of its faces
                for i in 0..<graph.edgeCount {
                    let edgeFaces = graph.faces(of: i)
                    if let firstFace = edgeFaces.first {
                        let coedge = graph.edgeFindCoEdge(edgeIndex: i, faceIndex: firstFace)
                        #expect(coedge != nil)
                        if let coedge {
                            #expect(coedge >= 0 && coedge < graph.coedgeCount)
                        }
                    }
                }
            }
        }
    }
}
