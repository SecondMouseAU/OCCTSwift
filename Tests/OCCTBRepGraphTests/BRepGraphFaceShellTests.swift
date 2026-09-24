import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Face Shells")
struct BRepGraphFaceShellTests {
    @Test func faceShells() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Every face sits in the box's one shell, 0 (kernel probe); `count >= 1` and a range
        // check accepted a wrong shell or a second one (#1986).
        #expect(graph.faceCount == 6)
        for i in 0..<graph.faceCount {
            #expect(graph.faceShellCount(i) == 1)
            #expect(graph.faceShells(i) == [0])
        }
    }

    @Test func faceCompoundCount() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Box faces are not in compounds
        #expect(graph.faceCount == 6)
        for i in 0..<graph.faceCount {
            #expect(graph.faceCompoundCount(i) == 0)
        }
    }
}
