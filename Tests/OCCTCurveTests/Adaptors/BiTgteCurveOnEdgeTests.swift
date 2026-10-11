import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to BiTgte_CurveOnEdge on the same two edges of a 10 box
// (Scripts/repro/766-curve-bitgte-pcurve-approx/transcript.txt). Shape.box centres the box, so
// edges[0] runs (-5,-5,-5) -> (-5,-5,5) and edges[1] (-5,-5,5) -> (-5,5,5). The earlier versions
// nested every expectation in `if let` and checked only that values were finite, so any domain
// and any point passed, and a nil curve passed with nothing checked (#766).
@Suite("BiTgte CurveOnEdge v0.112")
struct BiTgteCurveOnEdgeTests {

    private static func boxEdges() -> [Shape] {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box not built")
            return []
        }
        let edges = box.subShapes(ofType: .edge)
        if edges.count != 12 { Issue.record("box has \(edges.count) edges, not 12") }
        return edges
    }

    private static func adjacentCurve() -> BiTgteCurveOnEdge? {
        let edges = boxEdges()
        guard edges.count >= 2 else { return nil }
        let c = BiTgteCurveOnEdge(edgeOnFace: edges[0], edge: edges[1])
        if c == nil { Issue.record("BiTgteCurveOnEdge(edges[0], edges[1]) returned nil") }
        return c
    }

    @Test func createFromEdges() {
        guard let c = Self.adjacentCurve() else { return }
        // The domain is edges[0]'s own range.
        #expect(c.domain == 0...10)
    }

    @Test func evaluatePoint() {
        guard let curve = Self.adjacentCurve() else { return }
        // The kernel answers the shared vertex, (-5, -5, 5), at every parameter of this pair.
        let mid = (curve.domain.lowerBound + curve.domain.upperBound) / 2
        #expect(simd_distance(curve.point(at: mid), SIMD3(-5, -5, 5)) < 1e-9)
    }

    @Test func domainIsValid() {
        guard let curve = Self.adjacentCurve() else { return }
        #expect(curve.domain.upperBound > curve.domain.lowerBound)
        #expect(abs(curve.domain.upperBound - curve.domain.lowerBound - 10) < 1e-12)
    }

    @Test func sameEdgeCreation() {
        let edges = Self.boxEdges()
        guard let first = edges.first else { return }
        guard let c = BiTgteCurveOnEdge(edgeOnFace: first, edge: first) else {
            Issue.record("BiTgteCurveOnEdge(edges[0], edges[0]) returned nil")
            return
        }
        #expect(c.domain == 0...10)
        // On itself, the curve is the edge: its midpoint is (-5, -5, 0).
        #expect(simd_distance(c.point(at: 5), SIMD3(-5, -5, 0)) < 1e-9)
    }
}
