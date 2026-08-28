import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Node Status")
struct BRepGraphNodeStatusTests {
    @Test func noRemovedNodes() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.faceCount {
                    #expect(!graph.isRemoved(nodeKind: .face, nodeIndex: i))
                }
            }
        }
    }
}
