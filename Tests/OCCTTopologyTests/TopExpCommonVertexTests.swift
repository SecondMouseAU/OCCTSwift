import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("TopExp_CommonVertex")
struct TopExpCommonVertexTests {
    @Test func commonVertexBetweenEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            if edges.count >= 2 {
                // Try to find a pair with a common vertex
                var found = false
                for i in 0..<min(edges.count, 5) {
                    for j in (i + 1)..<min(edges.count, 6) {
                        let cv = Shape.commonVertex(edge1: edges[i], edge2: edges[j])
                        if cv != nil {
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
                #expect(found)
            }
        }
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
