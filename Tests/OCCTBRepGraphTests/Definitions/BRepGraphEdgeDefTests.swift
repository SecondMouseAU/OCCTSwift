import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Edge Def Details")
struct BRepGraphEdgeDefTests {
    @Test func edgeStartEndVertex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    let start = graph.edgeStartVertex(i)
                    let end = graph.edgeEndVertex(i)
                    #expect(start != nil)
                    #expect(end != nil)
                    if let start {
                        #expect(start >= 0 && start < graph.vertexCount)
                    }
                    if let end {
                        #expect(end >= 0 && end < graph.vertexCount)
                    }
                }
            }
        }
    }

    @Test func edgeIsClosedOnBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box edges are NOT closed (they are line segments)
                for i in 0..<graph.edgeCount {
                    #expect(!graph.isEdgeClosed(i))
                }
            }
        }
    }

    @Test func edgeClosedConsistency() {
        let sphere = Shape.sphere(radius: 5)
        if let sphere {
            let graph = BRepGraph(shape: sphere)
            if let graph {
                // For any closed edge, start == end vertex
                for i in 0..<graph.edgeCount {
                    if graph.isEdgeClosed(i) {
                        let start = graph.edgeStartVertex(i)
                        let end = graph.edgeEndVertex(i)
                        if let start, let end {
                            #expect(start == end)
                        }
                    }
                }
                // Verify we can query all edges without error
                #expect(graph.edgeCount > 0)
            }
        }
    }
}
