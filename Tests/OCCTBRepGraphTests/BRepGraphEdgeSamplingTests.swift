import Foundation
import Testing
import simd

@testable import OCCTSwift

// Endpoints pinned to the kernel probe (Scripts/repro/766-brepgraph-edge-query-sampling):
// `dist(first, last) > 0.001` and `|r - 5| < 0.1` accepted a sampler that stopped short of the
// end of the range (#1986).
@Suite("BRepGraph Edge Sampling")
struct BRepGraphEdgeSamplingTests {
    @Test func sampleBoxEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeHasCurve(0))
        let points = graph.sampleEdgeCurve(edgeIndex: 0, count: 10)
        try #require(points.count == 10)
        // Edge 0 runs from (-5, -5, -5) to (-5, -5, 5) over its range.
        #expect(points[0] == SIMD3(-5, -5, -5))
        #expect(points[9] == SIMD3(-5, -5, 5))
        // Evenly spaced: consecutive samples 10/9 apart.
        #expect(abs(simd_distance(points[0], points[1]) - 10.0 / 9.0) < 1e-12)
    }

    @Test func sampleSinglePoint() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.edgeHasCurve(0))
        let points = graph.sampleEdgeCurve(edgeIndex: 0, count: 1)
        #expect(points == [SIMD3(-5, -5, -5)])
    }

    @Test func sampleEdgeWithoutCurve() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Test with invalid index
        let points = graph.sampleEdgeCurve(edgeIndex: 999, count: 10)
        #expect(points.isEmpty)
    }

    @Test func sampleZeroCount() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let points = graph.sampleEdgeCurve(edgeIndex: 0, count: 0)
        #expect(points.isEmpty)
    }

    @Test func sampleSphereEdge() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let graph = try #require(BRepGraph(shape: sphere))
        // Only the seam (edge 1) has a curve; the degenerate pole edges sample to nothing.
        #expect(graph.sampleEdgeCurve(edgeIndex: 0, count: 20).isEmpty)
        #expect(graph.sampleEdgeCurve(edgeIndex: 2, count: 20).isEmpty)
        let points = graph.sampleEdgeCurve(edgeIndex: 1, count: 20)
        try #require(points.count == 20)
        // All points should be on the sphere surface (distance from origin ~= 5)
        for p in points {
            #expect(abs(simd_length(p) - 5.0) < 1e-9)
        }
        // The seam runs pole to pole.
        #expect(abs(points[0].z + 5) < 1e-12)
        #expect(abs(points[19].z - 5) < 1e-12)
    }
}
