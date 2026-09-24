import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Poly_Polygon2D")
struct Polygon2DTests {
    @Test("create and query")
    func createAndQuery() throws {
        let points: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)]
        let poly = try #require(Polygon2D.create(points: points))  // #1979: was `if let`
        #expect(poly.nodeCount == 4)
        let node = try #require(poly.node(at: 1))  // #1979: was `if let`
        #expect(abs(node.x - 10.0) < 1e-10)
        #expect(abs(node.y - 0.0) < 1e-10)
    }

    @Test("deflection")
    func deflection() throws {
        let points: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        let poly = try #require(Polygon2D.create(points: points))  // #1979: was `if let`
        poly.deflection = 0.5
        #expect(abs(poly.deflection - 0.5) < 1e-10)
    }

    @Test("all nodes")
    func allNodes() throws {
        let points: [SIMD2<Double>] = [SIMD2(1, 2), SIMD2(3, 4), SIMD2(5, 6)]
        let poly = try #require(Polygon2D.create(points: points))  // #1979: was `if let`
        let nodes = poly.nodes()
        // #1979: was `#expect`, so a short result went on to index `nodes[2]` and crashed the run.
        try #require(nodes.count == 3)
        #expect(abs(nodes[2].x - 5.0) < 1e-10)
    }
}
