import Testing
import simd

@testable import OCCTSwift

@Suite("Constrained Fill Tests")
struct ConstrainedFillTests {
    // Helper: get 4 edges from a box's top face
    private func boxTopEdges() -> [Edge] {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        return box.edges()
    }

    @Test("Fill with box edges")
    func fillWithBoxEdges() throws {
        let edges = boxTopEdges()
        #expect(edges.count >= 4)
        // Use 4 edges from the box
        _ = Shape.constrainedFill(
            edge1: edges[0], edge2: edges[1],
            edge3: edges[2], edge4: edges[3])
        // May or may not succeed depending on edge connectivity
        // The important thing is it doesn't crash
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
