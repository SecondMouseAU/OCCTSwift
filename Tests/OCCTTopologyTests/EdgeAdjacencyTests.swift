import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - Unwrapped Function Audit: Edge Adjacency & Dihedral Angle

@Suite("Edge Adjacency Tests")
struct EdgeAdjacencyTests {

    @Test("Box edge has two adjacent faces")
    func boxEdgeAdjacentFaces() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let edges = box.edges()
        #expect(edges.count == 12)

        // Each edge on a box should have exactly 2 adjacent faces
        let edge = edges[0]
        let adj = edge.adjacentFaces(in: box)
        #expect(adj != nil)
        if let adj {
            #expect(adj.count == 2)  // Both faces should exist for interior edges
        }
    }

    @Test("Box edge dihedral angle is 90 degrees")
    func boxDihedralAngle() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()

        // Find an edge with two adjacent faces
        for edge in edges {
            if let adj = edge.adjacentFaces(in: box), adj.count >= 2 {
                let f1 = adj[0]
                let f2 = adj[1]
                let angle = edge.dihedralAngle(between: f1, and: f2)
                #expect(angle != nil)
                if let angle {
                    // Box edges have 90-degree dihedral angles (PI/2)
                    #expect(abs(angle - .pi / 2) < 0.1 || abs(angle - 3 * .pi / 2) < 0.1)
                }
                return
            }
        }
        // Should have found at least one edge with two faces
        #expect(Bool(false))
    }

    @Test("Cylinder edge adjacent faces")
    func cylinderEdgeAdjacent() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edges = cyl.edges()
        #expect(edges.count >= 2)

        var foundPair = false
        for edge in edges {
            if let adj = edge.adjacentFaces(in: cyl), adj.count >= 2 {
                foundPair = true
                break
            }
        }
        #expect(foundPair)
    }
}
