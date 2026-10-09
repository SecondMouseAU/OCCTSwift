import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Face Def Details")
struct BRepGraphFaceDefTests {
    @Test func faceWireCount() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Each face of a box has exactly 1 wire (the outer wire); `>= 1` accepted 2 (#1986).
        #expect(graph.faceCount == 6)
        for i in 0..<graph.faceCount {
            #expect(graph.faceWireCount(i) == 1)
        }
    }

    // `== 0` alone passes a counter that always answers 0 (#1986), so a direct vertex is also
    // attached to face 0 and must be counted there and nowhere else (kernel probe:
    // Editor().Supplement().AttachToFace, then one FaceDirectVertex on face 0).
    @Test func faceVertexRefCount() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Box faces normally have no isolated vertices
        #expect(graph.faceCount == 6)
        for i in 0..<graph.faceCount {
            #expect(graph.faceVertexRefCount(i) == 0)
        }
        _ = try #require(graph.faceAddVertex(0, vertexIndex: 0))
        #expect(graph.faceVertexRefCount(0) == 1)
        #expect(graph.faceVertexRefCount(1) == 0)
    }
}
