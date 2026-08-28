import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Explorers")
struct BRepGraphExplorerTests {
    @Test func childExplorer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // OCCT 8.0 reshaped root iteration to Products only, wrap the
                // box's solid root in a Product to expose it as a graph root.
                _ = graph.linkProductToTopology(shapeRootKind: 0 /* Solid */, shapeRootIndex: 0)
                let roots = graph.rootNodes
                #expect(roots.count > 0)
                if let root = roots.first {
                    let faceCount = graph.childCount(
                        rootKind: root.kind, rootIndex: root.index, targetKind: .face)
                    #expect(faceCount == 6)
                }
            }
        }
    }

    @Test func parentExplorer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let parents = graph.parentCount(nodeKind: .face, nodeIndex: 0)
                #expect(parents > 0)
            }
        }
    }
}
