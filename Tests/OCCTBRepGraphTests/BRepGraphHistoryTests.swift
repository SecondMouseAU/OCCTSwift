import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph History")
struct BRepGraphHistoryTests {
    @Test func historyDefaults() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.isHistoryEnabled)
                #expect(graph.historyRecordCount == 0)
            }
        }
    }

    @Test func historyToggle() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                graph.isHistoryEnabled = false
                #expect(!graph.isHistoryEnabled)
                graph.isHistoryEnabled = true
                #expect(graph.isHistoryEnabled)
            }
        }
    }

    @Test func historyClear() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                graph.clearHistory()
                #expect(graph.historyRecordCount == 0)
            }
        }
    }
}
