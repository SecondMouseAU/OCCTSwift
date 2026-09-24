import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.45.0 Tests

@Suite("Filling Surface Tests")
struct FillingSurfaceTests {

    // #766: the builds asserted only non-nil / isDone and the errors only `< 0.01` or non-nil, so
    // a fill that dropped its point constraint or treated a free edge as a bound one passed. The
    // first four box edges are the x = -5 face's square (the box is centred), so the plain fill
    // is that 10 x 10 square. Pinned values are BRepOffsetAPI_MakeFilling's own with the same
    // defaults, see Scripts/repro/766-filling-surface/.
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
        if let result {
            #expect(abs((result.surfaceArea ?? 0) - 100) < 1e-9)
        }
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
            // The kernel reports 1.33e-15 for this exactly planar fill.
            #expect(g0 < 1e-12)
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
        // The boundary square sits at x = -5, so (5, 5, 3) is 10 off its plane: the constraint
        // pulls the surface out to an area of 1038.99, against 100 without it. (It does not reach
        // the point: the kernel's face stays 10 from it.)
        if let result {
            #expect(abs((result.surfaceArea ?? 0) - 1038.9910066176521) < 1e-6)
        }
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
        // Errors should be retrievable, and for C0 constraints the kernel reports exactly 0.
        #expect(g1 == 0)
        #expect(g2 == 0)
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
        // A free edge only attracts the surface, it does not bound it: 125.0 against the 100 of
        // the four-bound fill.
        if let result {
            #expect(abs((result.surfaceArea ?? 0) - 124.99804710385433) < 1e-6)
        }
    }

    @Test("Unfilled filling is not done")
    func notDoneBeforeBuild() throws {
        let filling = FillingSurface()
        #expect(!filling.isDone)
        #expect(filling.g0Error == nil)
    }
}
