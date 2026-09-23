import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Wire Extended")
struct BRepGraphWireExtendedTests {
    @Test func wireIsClosed() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.wireCount == 6)
        for i in 0..<graph.wireCount {
            #expect(graph.isWireClosed(i))
        }
    }

    @Test func wireCoEdgeCount() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let count = graph.wireCoEdgeCount(0)
        #expect(count == 4)  // box face has 4 edges
    }

    @Test func wireFaces() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let faceCount = graph.wireFaceCount(0)
        #expect(faceCount == 1)
        let faces = graph.wireFaces(0)
        #expect(faces == [0])
    }
}
