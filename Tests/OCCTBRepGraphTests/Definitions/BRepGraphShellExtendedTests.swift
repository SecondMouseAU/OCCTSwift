import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Shell Extended")
struct BRepGraphShellExtendedTests {
    @Test func shellCompoundCount() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.shellCount == 1)
        for i in 0..<graph.shellCount {
            #expect(graph.shellCompoundCount(i) == 0)
        }
    }

    @Test func shellIsClosed() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Box shell should be closed
        try #require(graph.shellCount == 1)
        #expect(graph.isShellClosed(0))
    }
}
