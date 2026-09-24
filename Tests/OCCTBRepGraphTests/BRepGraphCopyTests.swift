import Foundation
import Testing
import simd

@testable import OCCTSwift

// Counts pinned to BRepGraph_Copy::Perform / CopyNode in the kernel probe
// (Scripts/repro/766-brepgraph-compact-copy-count).
@Suite("BRepGraph Copy")
struct BRepGraphCopyTests {
    @Test func deepCopy() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let copy = try #require(graph.copy())
        #expect(copy.faceCount == 6)
        #expect(copy.edgeCount == 12)
        #expect(copy.vertexCount == 8)
        #expect(copy.surfaceCount == 6)
    }

    @Test func lightCopy() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let copy = try #require(graph.copy(copyGeometry: false))
        #expect(copy.faceCount == 6)
        #expect(copy.edgeCount == 12)
        #expect(copy.vertexCount == 8)
    }

    @Test func copyFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let faceCopy = try #require(graph.copyFace(0))
        // One square face: its wire, four edges and four vertices come with it.
        #expect(faceCopy.faceCount == 1)
        #expect(faceCopy.wireCount == 1)
        #expect(faceCopy.edgeCount == 4)
        #expect(faceCopy.vertexCount == 4)
    }
}
