import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("TopExp_CommonVertex")
struct TopExpCommonVertexTests {
    @Test func commonVertexBetweenEdges() throws {
        // The static spelling must agree with the instance one: 24 of the 66 edge pairs of a
        // box share a vertex, and the shared point is the same corner both ways round.
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = b.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        var adjacent = 0
        for i in 0..<edges.count {
            for j in (i + 1)..<edges.count {
                let forward = Shape.commonVertex(edge1: edges[i], edge2: edges[j])
                let backward = Shape.commonVertex(edge1: edges[j], edge2: edges[i])
                #expect((forward == nil) == (backward == nil))
                if let f = forward, let r = backward {
                    adjacent += 1
                    #expect(vectorDistance(f, r) < 1e-9)
                    for c in [f.x, f.y, f.z] { #expect(abs(abs(c) - 5) < 1e-9) }
                }
            }
        }
        #expect(adjacent == 24)

        let c = try #require(Shape.commonVertex(edge1: edges[0], edge2: edges[3]))
        #expect(vectorDistance(c, SIMD3(-5, -5, -5)) < 1e-9)
    }

    @Test func noCommonVertexForDisjointEdges() {
        // Create two separate boxes and take edges from each
        let box1 = Shape.box(origin: SIMD3(0, 0, 0), width: 1, height: 1, depth: 1)
        let box2 = Shape.box(origin: SIMD3(100, 100, 100), width: 1, height: 1, depth: 1)
        if let b1 = box1, let b2 = box2 {
            let e1 = b1.subShapes(ofType: .edge)
            let e2 = b2.subShapes(ofType: .edge)
            if !e1.isEmpty && !e2.isEmpty {
                let cv = Shape.commonVertex(edge1: e1[0], edge2: e2[0])
                #expect(cv == nil)
            }
        }
    }
}
