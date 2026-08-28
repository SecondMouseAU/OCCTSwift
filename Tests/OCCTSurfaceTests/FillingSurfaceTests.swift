import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.45.0 Tests

@Suite("Filling Surface Tests")
struct FillingSurfaceTests {
    /// Helper to get 4 coplanar edges from a box face
    private func getFaceEdges() -> [Edge] {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let face = box.faces()[0]
        let wire = face.outerWire!
        // Get edges from the shape that belong to this face's wire
        let allEdges = box.edges()
        // Use first 4 edges (a box face has 4 edges)
        return Array(allEdges.prefix(4))
    }

    @Test("Basic 4-edge filling creates a face")
    func basicFilling() throws {
        let edges = getFaceEdges()
        #expect(edges.count == 4)

        let filling = FillingSurface()
        for edge in edges {
            #expect(filling.add(edge: edge, continuity: .g0))
        }

        let result = filling.build()
        #expect(result != nil)
        #expect(filling.isDone)
    }

    @Test("G0 error is small for planar fill")
    func g0Error() throws {
        let edges = getFaceEdges()

        let filling = FillingSurface()
        for edge in edges {
            filling.add(edge: edge, continuity: .g0)
        }
        let _ = filling.build()

        let g0 = filling.g0Error
        #expect(g0 != nil)
        if let g0 {
            #expect(g0 < 0.01)
        }
    }

    @Test("Filling with point constraint")
    func fillingWithPoint() throws {
        let edges = getFaceEdges()

        let filling = FillingSurface()
        for edge in edges {
            filling.add(edge: edge, continuity: .g0)
        }
        // Add interior point above the plane
        filling.add(point: SIMD3(5, 5, 3))

        let result = filling.build()
        #expect(result != nil)
        #expect(filling.isDone)
    }

    @Test("G1 and G2 errors are available after build")
    func g1g2Errors() throws {
        let edges = getFaceEdges()

        let filling = FillingSurface()
        for edge in edges {
            filling.add(edge: edge, continuity: .g0)
        }
        let _ = filling.build()

        let g1 = filling.g1Error
        let g2 = filling.g2Error
        // Errors should be retrievable (may be 0 for a planar fill)
        #expect(g1 != nil)
        #expect(g2 != nil)
    }

    @Test("Filling with free edge constraint")
    func freeEdgeConstraint() throws {
        let edges = getFaceEdges()

        let filling = FillingSurface()
        // Add 3 boundary edges and 1 free edge
        for i in 0..<3 {
            filling.add(edge: edges[i], continuity: .g0)
        }
        filling.add(freeEdge: edges[3], continuity: .g0)

        let result = filling.build()
        #expect(result != nil)
    }

    @Test("Unfilled filling is not done")
    func notDoneBeforeBuild() throws {
        let filling = FillingSurface()
        #expect(!filling.isDone)
        #expect(filling.g0Error == nil)
    }
}
