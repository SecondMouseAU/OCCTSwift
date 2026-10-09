import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.143 Point-to-edge distance")
struct PointToEdgeDistanceTests {
    @Test("Curve3D.distance one-liner")
    func curve3DDistance() {
        guard let c = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("segment nil")
            return
        }
        // Distance from (5, 3, 0) to the X axis segment = 3.
        let d = c.distance(to: SIMD3(5, 3, 0))
        #expect(abs(d - 3.0) < 1e-6)
    }

    @Test("Edge.distance one-liner")
    func edgeDistance() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let edges = box.edges()
        guard let first = edges.first else {
            Issue.record("no edges")
            return
        }
        let d = first.distance(to: SIMD3(0, 0, 0))
        #expect(d != nil)
    }
}
