import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values pinned to the kernel probe (Scripts/repro/766-brepgraph-edge-wires-explorer-face).
// The range checks these replaced (`!isEmpty` plus `w >= 0 && w < wireCount`) passed a query
// that returned the same wire or coedge for every edge (#1986).
@Suite("BRepGraph Edge Wires CoEdges")
struct BRepGraphEdgeWiresCoEdgesTests {
    // Each box edge sits in the wires of its two faces.
    static let wires: [[Int]] = [
        [0, 2], [0, 4], [0, 3], [0, 5], [1, 2], [1, 4], [1, 3], [1, 5], [2, 4], [2, 5], [3, 4], [3, 5],
    ]
    // ...and has one coedge in each.
    static let coedges: [[Int]] = [
        [0, 9], [1, 16], [2, 13], [3, 20], [4, 11], [5, 18], [6, 15], [7, 22], [8, 17], [10, 21],
        [12, 19], [14, 23],
    ]

    @Test func edgeWires() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeCount == 12)
        #expect((0..<graph.edgeCount).map { graph.edgeWires($0) } == Self.wires)
    }

    @Test func edgeCoEdges() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeCount == 12)
        #expect((0..<graph.edgeCount).map { graph.edgeCoEdges($0) } == Self.coedges)
    }

    @Test func edgeFindCoEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeCount == 12)
        // For each edge, the coedge on its first face is the first of its two coedges.
        let firstFaces = [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3]
        for i in 0..<graph.edgeCount {
            #expect(graph.edgeFindCoEdge(edgeIndex: i, faceIndex: firstFaces[i]) == Self.coedges[i][0])
        }
    }
}
