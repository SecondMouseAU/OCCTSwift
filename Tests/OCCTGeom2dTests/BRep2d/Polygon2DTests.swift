import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Poly_Polygon2D")
struct Polygon2DTests {
    @Test("create and query")
    func createAndQuery() {
        let points: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)]
        if let poly = Polygon2D.create(points: points) {
            #expect(poly.nodeCount == 4)
            if let node = poly.node(at: 1) {
                #expect(abs(node.x - 10.0) < 1e-10)
                #expect(abs(node.y - 0.0) < 1e-10)
            }
        }
    }

    @Test("deflection")
    func deflection() {
        let points: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        if let poly = Polygon2D.create(points: points) {
            poly.deflection = 0.5
            #expect(abs(poly.deflection - 0.5) < 1e-10)
        }
    }

    @Test("all nodes")
    func allNodes() {
        let points: [SIMD2<Double>] = [SIMD2(1, 2), SIMD2(3, 4), SIMD2(5, 6)]
        if let poly = Polygon2D.create(points: points) {
            let nodes = poly.nodes()
            #expect(nodes.count == 3)
            #expect(abs(nodes[2].x - 5.0) < 1e-10)
        }
    }
}
