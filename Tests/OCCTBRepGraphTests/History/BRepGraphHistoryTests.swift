import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph History")
struct BRepGraphHistoryTests {
    @Test func historyDefaults() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.isHistoryEnabled)
        #expect(graph.historyRecordCount == 0)
    }

    @Test func historyToggle() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        graph.isHistoryEnabled = false
        #expect(!graph.isHistoryEnabled)
        graph.isHistoryEnabled = true
        #expect(graph.isHistoryEnabled)
    }

    // Clearing a fresh graph's empty history proved nothing: a clear that did nothing passed
    // (#1986). A record is made first, so the clear has something to remove.
    @Test func historyClear() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        graph.recordHistory(
            operationName: "Op", original: BRepGraph.NodeRef(kind: .face, index: 0),
            replacements: [BRepGraph.NodeRef(kind: .face, index: 42)])
        #expect(graph.historyRecordCount == 1)
        graph.clearHistory()
        #expect(graph.historyRecordCount == 0)
    }
}
