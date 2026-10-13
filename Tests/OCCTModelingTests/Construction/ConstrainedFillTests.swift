import Testing

@testable import OCCTSwift

@Suite("Constrained Fill Tests")
struct ConstrainedFillTests {
    // Helper: get 4 edges from a box's top face (Z+)
    private func boxTopEdges() -> [Edge] {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        return box.edges().filter { edge in
            let (start, end) = edge.endpoints
            // Box centered at origin: top face at Z = 5 (depth/2)
            return abs(start.z - 5) < 1e-7 && abs(end.z - 5) < 1e-7
        }
    }

    @Test("Fill with box edges")
    func fillWithBoxEdges() throws {
        let edges = boxTopEdges()
        try #require(edges.count == 4)
        // The four top edges of the cube bound the plane z = 5, so the filling surface is that
        // 10 x 10 patch: one face, four edges, area 100, flat at z = 5 (measured on kernel.6).
        let filled = try #require(
            Shape.constrainedFill(
                edge1: edges[0], edge2: edges[1],
                edge3: edges[2], edge4: edges[3]))
        #expect(filled.shapeType == .face)
        #expect(filled.edges().count == 4)
        #expect(abs((filled.surfaceArea ?? -1) - 100.0) < 1e-6)
        let bounds = try #require(filled.boundingBox)
        #expect(abs(bounds.min.z - 5) < 1e-5 && abs(bounds.max.z - 5) < 1e-5)
        #expect(abs(bounds.min.x + 5) < 1e-5 && abs(bounds.max.x - 5) < 1e-5)
        #expect(abs(bounds.min.y + 5) < 1e-5 && abs(bounds.max.y - 5) < 1e-5)
    }

    @Test("Fill info on box face")
    func fillInfoOnBox() throws {
        // Use a box directly - its faces already are valid
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // The constrainedFillInfo looks for BSpline surfaces
        // A box has planar faces, not BSpline
        let info = box.constrainedFillInfo
        // Expected: nil since box faces are planar, not BSpline
        #expect(info == nil)
    }
}
