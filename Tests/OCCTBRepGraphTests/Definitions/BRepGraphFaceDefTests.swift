import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Face Def Details")
struct BRepGraphFaceDefTests {
    @Test func faceWireCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Each face of a box has exactly 1 wire (the outer wire)
                for i in 0..<graph.faceCount {
                    #expect(graph.faceWireCount(i) >= 1)
                }
            }
        }
    }

    @Test func faceVertexRefCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box faces normally have no isolated vertices
                for i in 0..<graph.faceCount {
                    #expect(graph.faceVertexRefCount(i) == 0)
                }
            }
        }
    }
}
