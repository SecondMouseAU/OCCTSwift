import Foundation
import Testing

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
    func edgeDistance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        try #require(edges.count == 12)

        // Edge order is not part of the contract, so pin every edge. Each edge of a centred
        // 10-cube is sqrt(5^2 + 5^2) from the centre.
        for (i, e) in edges.enumerated() {
            let d = try #require(e.distance(to: SIMD3(0, 0, 0)), "edge \(i) has a 3D curve")
            #expect(abs(d - 50.0.squareRoot()) < 1e-9, "edge \(i): got \(d)")
        }

        // From (20, 20, 20) the nearest edge is the one through the +x+y corner column,
        // sqrt(15^2 * 3); the farthest is the opposite column, sqrt(25^2 + 25^2 + 15^2). The
        // clamp to the edge's own ends is what the 15 in each carries, so an infinite-line
        // distance reads lower.
        let far = SIMD3<Double>(20, 20, 20)
        let ds = try edges.map { try #require($0.distance(to: far)) }.sorted()
        #expect(abs(ds[0] - 675.0.squareRoot()) < 1e-9, "nearest: \(ds[0])")
        #expect(abs(ds[11] - 1475.0.squareRoot()) < 1e-9, "farthest: \(ds[11])")
    }
}
