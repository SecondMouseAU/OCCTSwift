import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Edge, Properties")
struct EdgePropertyTests {
    @Test("Edge isLine for box edge")
    func edgeIsLine() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        guard let edge = edges.first else {
            Issue.record("Box should have edges")
            return
        }
        #expect(edge.isLine)
        #expect(!edge.isCircle)
    }

    /// A cylinder has three edges: the top and bottom circles and the straight seam
    /// (`Scripts/repro/766-edge-distance-elc/`). "Some edge is a circle" also passed a predicate
    /// that answered true for the seam line, so each edge's answer is checked.
    @Test("Edge isCircle for cylinder edge")
    func edgeIsCircle() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edges = cyl.edges()
        #expect(edges.count == 3)
        #expect(edges.filter { $0.isCircle }.count == 2)
        #expect(edges.filter { $0.isLine }.count == 1)
        #expect(!edges.contains { $0.isCircle && $0.isLine })
    }
}
