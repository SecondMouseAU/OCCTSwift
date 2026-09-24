import Foundation
import Testing
import simd

@testable import OCCTSwift

// Both tests used to compare the FIRST edge of each box and read the result under `if let`.
// Measured by Scripts/repro/766-brepextrema-extcc/probe.mm (transcript.txt beside it), those two
// edges are both parallel to Z, BRepExtrema_ExtCC reports IsParallel, the bridge returns
// solutionCount 0 and the wrapper returns nil, so neither test ever reached an assertion and
// both passed whatever the extrema returned (#1920, #1921).
//
// Box 1 is centred on the origin ([-5, 5]^3); box 2 spans [20, 30] x [0, 10] x [0, 10]. Edge 1
// of box 1 runs (-5, -5, 5) -> (-5, 5, 5) along Y; edge 0 of box 2 runs (20, 0, 0) -> (20, 0, 10)
// along Z. Their common perpendicular joins (-5, 0, 5) to (20, 0, 5): one extremum, distance 25.
@Suite("BRepExtrema ExtCC Tests")
struct BRepExtremaExtCCTests {
    @Test("Edge-edge distance between box edges")
    func edgeEdgeDistance() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10))

        // The original pair is parallel and has no isolated extremum: stated, not skipped.
        #expect(box1.edgeEdgeExtrema(edgeIndex1: 0, other: box2, edgeIndex2: 0) == nil)

        let r = try #require(box1.edgeEdgeExtrema(edgeIndex1: 1, other: box2, edgeIndex2: 0))
        #expect(r.solutionCount == 1)
        #expect(!r.isParallel)
        #expect(abs(r.distance - 25) < 1e-9)
        #expect(simd_distance(r.pointOnEdge1, SIMD3(-5, 0, 5)) < 1e-9)
        #expect(simd_distance(r.pointOnEdge2, SIMD3(20, 0, 5)) < 1e-9)
    }

    @Test("Edge-edge distance between standalone edge shapes")
    func edgeEdgeDistanceStandaloneEdges() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10))
        // Extract standalone edge shapes: edge 1 of box 1, edge 0 of box 2 (see above).
        let edges1 = box1.edges()
        let edges2 = box2.edges()
        #expect(edges1.count == 12)
        #expect(edges2.count == 12)
        try #require(edges1.count > 1 && !edges2.isEmpty)
        // Convert Edge to Shape for the edgeEdgeExtrema function. NOT Shape(handle:
        // edge1.handle): OCCTEdgeRef and OCCTShapeRef both erase to OpaquePointer in
        // Swift, so that compiles, but it aliases the SAME underlying OCCTEdge* as if it
        // were an OCCTShape*, double-owning the C++ handle between Edge and Shape, both
        // of which free it on scope exit (the exact #204 double-free shape, for Edge
        // instead of Wire). Shape.fromEdge allocates a genuinely independent OCCTShape.
        guard let edge1Shape = Shape.fromEdge(edges1[1]),
            let edge2Shape = Shape.fromEdge(edges2[0])
        else {
            Issue.record("Shape.fromEdge failed")
            return
        }
        let r = try #require(Shape.edgeEdgeExtrema(edge1: edge1Shape, edge2: edge2Shape))
        #expect(r.solutionCount == 1)
        #expect(!r.isParallel)
        #expect(abs(r.distance - 25) < 1e-9)
        #expect(simd_distance(r.pointOnEdge1, SIMD3(-5, 0, 5)) < 1e-9)
        #expect(simd_distance(r.pointOnEdge2, SIMD3(20, 0, 5)) < 1e-9)
    }
}
