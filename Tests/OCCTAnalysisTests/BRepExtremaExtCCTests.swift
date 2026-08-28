import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema ExtCC Tests")
struct BRepExtremaExtCCTests {
    @Test("Edge-edge distance between box edges")
    func edgeEdgeDistance() throws {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)!
        // Compare first edges of each box
        let result = box1.edgeEdgeExtrema(edgeIndex1: 0, other: box2, edgeIndex2: 0)
        // Result may or may not find solutions depending on which edges are picked
        if let r = result {
            #expect(r.distance >= 0, "Distance should be non-negative")
            #expect(r.solutionCount >= 1)
        }
    }

    @Test("Edge-edge distance between standalone edge shapes")
    func edgeEdgeDistanceStandaloneEdges() throws {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)!
        // Extract first edge from each box as standalone shapes
        let edges1 = box1.edges()
        let edges2 = box2.edges()
        #expect(!edges1.isEmpty)
        #expect(!edges2.isEmpty)
        if let edge1 = edges1.first, let edge2 = edges2.first {
            // Convert Edge to Shape for the edgeEdgeExtrema function. NOT Shape(handle:
            // edge1.handle): OCCTEdgeRef and OCCTShapeRef both erase to OpaquePointer in
            // Swift, so that compiles, but it aliases the SAME underlying OCCTEdge* as if it
            // were an OCCTShape*, double-owning the C++ handle between Edge and Shape, both
            // of which free it on scope exit (the exact #204 double-free shape, for Edge
            // instead of Wire). Shape.fromEdge allocates a genuinely independent OCCTShape.
            guard let edge1Shape = Shape.fromEdge(edge1),
                let edge2Shape = Shape.fromEdge(edge2)
            else {
                Issue.record("Shape.fromEdge failed")
                return
            }
            let result = Shape.edgeEdgeExtrema(edge1: edge1Shape, edge2: edge2Shape)
            if let r = result {
                #expect(r.distance >= 0, "Distance should be non-negative")
                #expect(r.solutionCount >= 1)
            }
        }
    }
}
