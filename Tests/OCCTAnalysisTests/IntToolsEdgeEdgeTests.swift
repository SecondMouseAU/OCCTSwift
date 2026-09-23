import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: fixtures are required rather than `if let`-wrapped (a nil edge used to skip every
// assertion and pass), and the counts and ranges are pinned to what `IntTools_EdgeEdge` returns
// for these inputs (Scripts/repro/766-inttoolsedgeedge).
@Suite("IntTools_EdgeEdge Tests")
struct IntToolsEdgeEdgeTests {
    @Test("Intersecting edges produce vertex common part")
    func edgeEdgeVertex() throws {
        // Two edges crossing at origin: X-axis and Y-axis
        let edge1 = try #require(Shape.edgeFromPoints(SIMD3(-1, 0, 0), SIMD3(1, 0, 0)))
        let edge2 = try #require(Shape.edgeFromPoints(SIMD3(0, -1, 0), SIMD3(0, 1, 0)))
        let p = try #require(edge1.edgeEdgeIntersection(with: edge2))
        #expect(p.count == 1)
        if let first = p.first {
            #expect(first.type == .vertex)
            #expect(abs(first.point.x) < 0.1)
            #expect(abs(first.point.y) < 0.1)
            // Each edge is parameterised by length from its start, so both cross at 1.
            #expect(abs(first.param1Range.first - 1) < 1e-9)
            #expect(abs(first.param2Range.first - 1) < 1e-9)
        }
    }

    // The overlap is x in [1, 2], which is parameter [1, 2] on the first edge. `point` is not
    // asserted: for an edge-type part `IntTools_CommonPrt::BoundingPoints` is never set, so the
    // bridge's midpoint reads (0, 0, 0), outside the overlap (#2251).
    @Test("Overlapping collinear edges produce edge common part")
    func edgeEdgeOverlap() throws {
        let edge1 = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(2, 0, 0)))
        let edge2 = try #require(Shape.edgeFromPoints(SIMD3(1, 0, 0), SIMD3(3, 0, 0)))
        let p = try #require(edge1.edgeEdgeIntersection(with: edge2))
        #expect(p.count == 1)
        if let first = p.first {
            #expect(first.type == .edge)
            #expect(abs(first.param1Range.first - 1) < 1e-9)
            #expect(abs(first.param1Range.last - 2) < 1e-9)
        }
    }

    @Test("Non-intersecting edges return empty array")
    func edgeEdgeNoIntersection() throws {
        let edge1 = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(1, 0, 0)))
        let edge2 = try #require(Shape.edgeFromPoints(SIMD3(0, 5, 0), SIMD3(1, 5, 0)))
        let parts = edge1.edgeEdgeIntersection(with: edge2)
        #expect(parts != nil)
        if let p = parts {
            #expect(p.isEmpty)
        }
    }
}
