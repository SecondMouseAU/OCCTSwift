import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Wire Extended")
struct BRepGraphWireExtendedTests {
    @Test func wireIsClosed() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.wireCount {
                    #expect(graph.isWireClosed(i))
                }
            }
        }
    }

    @Test func wireCoEdgeCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let count = graph.wireCoEdgeCount(0)
                #expect(count == 4)  // box face has 4 edges
            }
        }
    }

    @Test func wireFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let faceCount = graph.wireFaceCount(0)
                #expect(faceCount == 1)
                let faces = graph.wireFaces(0)
                #expect(faces.count == 1)
            }
        }
    }
}
