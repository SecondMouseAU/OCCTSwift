import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe SplitShape Tests")
struct LocOpeSplitShapeTests {
    @Test("Split edge at parameter")
    func splitEdge() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Try splitting the first edge at midpoint
        // #766: this was `if let r = result { #expect(!r.vertices().isEmpty || true) }`, a
        // tautology inside an `if let`: nothing it could observe would fail it. Pinned to the
        // kernel (Scripts/repro/766-modeling-locope-split-shape): edge 0 of the centred box runs
        // (-5,-5,-5)-(-5,-5,5) over the range [0, 10], so parameter 0.5 splits it at (-5,-5,0)
        // into two edges sharing that new vertex, three vertices in all.
        guard let r = box.splitEdge(at: 0, parameter: 0.5) else {
            Issue.record("splitEdge(at: 0, parameter: 0.5) returned nil")
            return
        }
        #expect(r.subShapes(ofType: .edge).count == 2)
        let vertices = r.vertices()
        #expect(vertices.count == 3)
        #expect(vertices.contains { simd_distance($0, SIMD3(-5, -5, 0)) < 1e-9 })
    }
}
