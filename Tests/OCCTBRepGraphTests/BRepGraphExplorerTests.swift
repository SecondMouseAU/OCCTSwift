import Foundation
import Testing
import simd

@testable import OCCTSwift

// Counts pinned to BRepGraph_ChildExplorer / BRepGraph_ParentExplorer in the kernel probe
// (Scripts/repro/766-brepgraph-edge-wires-explorer-face). `parents > 0` and `roots.count > 0`
// accepted miscounts, and an empty root list skipped the face count entirely (#1986).
@Suite("BRepGraph Explorers")
struct BRepGraphExplorerTests {
    @Test func childExplorer() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // OCCT 8.0 reshaped root iteration to Products only, wrap the
        // box's solid root in a Product to expose it as a graph root.
        _ = graph.linkProductToTopology(shapeRootKind: 0 /* Solid */, shapeRootIndex: 0)
        let roots = graph.rootNodes
        #expect(roots.count == 1)
        let root = try #require(roots.first)
        #expect(graph.childCount(rootKind: root.kind, rootIndex: root.index, targetKind: .face) == 6)
    }

    @Test func parentExplorer() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.parentCount(nodeKind: .face, nodeIndex: 0) == 2)
    }
}
