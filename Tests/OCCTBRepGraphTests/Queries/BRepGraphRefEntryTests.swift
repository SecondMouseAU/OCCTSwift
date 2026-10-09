import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values pinned to the kernel probe (Scripts/repro/766-brepgraph-products-refs). Each test was wrapped in
// `if graph.faceRefCount > 0`, and the orientation check accepted any of the four values (#1986).
@Suite("BRepGraph Ref Entry Queries")
struct BRepGraphRefEntryTests {
    @Test func refChildNode() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.refChildNodeKind(.face, refIndex: 0) == .face)
        #expect(graph.refChildNodeIndex(.face, refIndex: 0) == 0)
    }

    @Test func refNotRemoved() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(!graph.isRefRemoved(.face, refIndex: 0))
        #expect(!graph.isRefRemoved(.shell, refIndex: 0))
        // ...and a removed ref does report removed, so a constant `false` fails.
        #expect(graph.removeRef(refKind: .face, refIndex: 0))
        #expect(graph.isRefRemoved(.face, refIndex: 0))
    }

    @Test func refOrientation() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // TopAbs_FORWARD=0, REVERSED=1: the box's face refs alternate, starting REVERSED.
        #expect(graph.faceRefCount == 6)
        #expect((0..<6).map { graph.refOrientation(.face, refIndex: $0) } == [1, 0, 1, 0, 1, 0])
    }
}
