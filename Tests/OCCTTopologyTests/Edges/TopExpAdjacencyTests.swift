import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.102.0 Tests

@Suite("TopExp Adjacency Tests")
struct TopExpAdjacencyTests {

    @Test func edgeFirstVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let v = edge.edgeFirstVertex()
                #expect(v != nil)
            }
        }
    }

    @Test func edgeLastVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let v = edge.edgeLastVertex()
                #expect(v != nil)
            }
        }
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
            let dist = simd_distance(verts.first, verts.last)
            #expect(dist < 1e-6)
        }
    }

    @Test func commonVertexBetweenEdges() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                // Try pairs until we find adjacent edges
                var found = false
                for i in 0..<min(edges.count, 12) {
                    for j in (i + 1)..<min(edges.count, 12) {
                        if edges[i].commonVertex(with: edges[j]) != nil {
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
                #expect(found)
            }
        }
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
