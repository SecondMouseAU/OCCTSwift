import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - Unwrapped Function Audit: Edge Adjacency & Dihedral Angle

@Suite("Edge Adjacency Tests")
struct EdgeAdjacencyTests {

    @Test("Box edge has two adjacent faces")
    func boxEdgeAdjacentFaces() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
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
    func boxDihedralAngle() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()

        // Find an edge with two adjacent faces
        for edge in edges {
            if let adj = edge.adjacentFaces(in: box), adj.count >= 2 {
                let f1 = adj[0]
                let f2 = adj[1]
                let angle = edge.dihedralAngle(between: f1, and: f2)
                #expect(angle != nil)
                if let angle {
                    // Box edges have 90-degree dihedral angles (PI/2), always convex, so the
                    // `3*PI/2` branch this used to also accept could never actually be taken
                    // (#1434). See Issue1434DihedralAngleRangeTests for coverage of the concave
                    // (>PI) half of the documented range, using a fixture that isn't the
                    // self-symmetric 90-degree case a box's edges always are.
                    #expect(abs(angle - .pi / 2) < 0.1)
                }
                return
            }
        }
        // Should have found at least one edge with two faces
        #expect(Bool(false))
    }

    @Test("Cylinder edge adjacent faces")
    func cylinderEdgeAdjacent() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let edges = cyl.edges()
        #expect(edges.count == 3)

        // The two rim circles (length 2 pi r) are shared by the lateral face (2 pi r h = 100 pi)
        // and one cap (pi r^2 = 25 pi), so each has exactly those two faces. The seam (length h)
        // lies on the lateral face alone, so it reports that one face, not a pair. Measured on
        // kernel.6: counts [2, 1, 2], areas as below.
        var circleCount = 0
        var seamCount = 0
        for edge in edges {
            let adj = try #require(edge.adjacentFaces(in: cyl))
            let areas = adj.map { $0.area() }.sorted()
            if abs(edge.length - 2 * .pi * 5) < 1e-9 {
                circleCount += 1
                #expect(areas.count == 2)
                if areas.count == 2 {
                    #expect(abs(areas[0] - 25 * .pi) < 1e-9)
                    #expect(abs(areas[1] - 100 * .pi) < 1e-9)
                }
            } else {
                seamCount += 1
                #expect(abs(edge.length - 10) < 1e-9)
                #expect(areas.count == 1)
                if let lateral = areas.first { #expect(abs(lateral - 100 * .pi) < 1e-9) }
            }
        }
        #expect(circleCount == 2)
        #expect(seamCount == 1)
    }
}
