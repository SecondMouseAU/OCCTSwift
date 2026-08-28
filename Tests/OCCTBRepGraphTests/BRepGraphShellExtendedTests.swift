import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Shell Extended")
struct BRepGraphShellExtendedTests {
    @Test func shellCompoundCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.shellCount {
                    #expect(graph.shellCompoundCount(i) == 0)
                }
            }
        }
    }

    @Test func shellIsClosed() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box shell should be closed
                #expect(graph.shellCount >= 1)
                if graph.shellCount > 0 {
                    #expect(graph.isShellClosed(0))
                }
            }
        }
    }
}
