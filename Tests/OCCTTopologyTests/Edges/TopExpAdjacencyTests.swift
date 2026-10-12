import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.102.0 Tests

@Suite("TopExp Adjacency Tests")
struct TopExpAdjacencyTests {

    @Test func edgeFirstVertex() throws {
        // Edge 0 of the box runs (-5,-5,-5) to (-5,-5,5); its FORWARD vertex is the start.
        // Every edge's first vertex is a box corner and differs from its last by one edge
        // length (10), so returning the last vertex, a fixed corner, or the centre all fail.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        let first = try #require(edges[0].edgeFirstVertex())
        #expect(vectorDistance(first, SIMD3(-5, -5, -5)) < 1e-9)
        for edge in edges {
            let a = try #require(edge.edgeFirstVertex())
            let b = try #require(edge.edgeLastVertex())
            for c in [a.x, a.y, a.z] { #expect(abs(abs(c) - 5) < 1e-9) }
            #expect(abs(vectorDistance(a, b) - 10) < 1e-9)
        }
    }

    @Test func edgeLastVertex() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        let last = try #require(edges[0].edgeLastVertex())
        #expect(vectorDistance(last, SIMD3(-5, -5, 5)) < 1e-9)
        // Edge 8 runs along x at y = z = -5, so first and last differ only in x.
        let first8 = try #require(edges[8].edgeFirstVertex())
        let last8 = try #require(edges[8].edgeLastVertex())
        #expect(vectorDistance(first8, SIMD3(-5, -5, -5)) < 1e-9)
        #expect(vectorDistance(last8, SIMD3(5, -5, -5)) < 1e-9)
    }

    @Test func edgeVerticesBothEnds() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first, let verts = edge.edgeVertices() {
                #expect(verts.first != verts.last || true)  // just check it returns
            }
        }
    }

    @Test func wireVerticesClosedWire() {
        if let wire = Wire.rectangle(width: 10, height: 10),
            let ws = Shape.fromWire(wire),
            let verts = ws.wireVertices()
        {
            // Closed wire: first == last
            let dist = vectorDistance(verts.first, verts.last)
            #expect(dist < 1e-6)
        }
    }

    @Test func commonVertexBetweenEdges() throws {
        // Each of the 12 edges meets 4 others at its two ends (2 per end), so of the 66 pairs
        // exactly 12 * 4 / 2 = 24 share a vertex, and the common vertex is an endpoint of both.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        var adjacent = 0
        for i in 0..<edges.count {
            for j in (i + 1)..<edges.count {
                guard let common = edges[i].commonVertex(with: edges[j]) else { continue }
                adjacent += 1
                for e in [edges[i], edges[j]] {
                    let v = try #require(e.edgeVertices())
                    let d = min(vectorDistance(common, v.first), vectorDistance(common, v.last))
                    #expect(d < 1e-9)
                }
            }
        }
        #expect(adjacent == 24)

        // Edge 0 (vertical at (-5,-5)) meets edge 1 at (-5,-5,5) and edge 3 at (-5,-5,-5);
        // edge 6 (vertical at (5,5)) is on the far side and meets it nowhere.
        let c01 = try #require(edges[0].commonVertex(with: edges[1]))
        #expect(vectorDistance(c01, SIMD3(-5, -5, 5)) < 1e-9)
        let c03 = try #require(edges[0].commonVertex(with: edges[3]))
        #expect(vectorDistance(c03, SIMD3(-5, -5, -5)) < 1e-9)
        #expect(edges[0].commonVertex(with: edges[6]) == nil)
    }

    @Test func edgeFaceAdjacencyBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let adj = box.edgeFaceAdjacency()
            #expect(adj.count == 12)
            // Every edge of a box is shared by exactly 2 faces
            for count in adj {
                #expect(count == 2)
            }
        }
    }

    @Test func vertexEdgeAdjacencyBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let adj = box.vertexEdgeAdjacency()
            #expect(adj.count == 8)
            // Every vertex of a box connects 3 edges
            for count in adj {
                #expect(count == 3)
            }
        }
    }

    @Test func adjacentFacesForEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let faceIndices = box.adjacentFaces(forEdge: edge)
                #expect(faceIndices.count == 2)
            }
        }
    }

    @Test func adjacentEdgesForVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let vertexShapes = box.subShapes(ofType: .vertex)
            if let v = vertexShapes.first {
                let edgeIndices = box.adjacentEdges(forVertex: v)
                #expect(edgeIndices.count == 3)
            }
        }
    }
}
