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

    @Test("Edge isCircle for cylinder edge")
    func edgeIsCircle() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edges = cyl.edges()
        // Cylinder has circular edges at top and bottom
        let hasCircle = edges.contains { $0.isCircle }
        #expect(hasCircle)
    }
}
