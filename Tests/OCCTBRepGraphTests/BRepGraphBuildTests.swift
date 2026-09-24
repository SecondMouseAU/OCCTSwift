import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - BRepGraph Tests (v0.129.0)

// Counts pinned to the kernel probe (Scripts/repro/766-brepgraph-build-coedge). The sphere
// and fused-shape tests asserted `faceCount > 0`, `edgeCount >= 0` (always true) and
// `faceCount > 6`, which accepted a miscounting graph (#1986).
@Suite("BRepGraph Build")
struct BRepGraphBuildTests {
    @Test func buildFromBox() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.faceCount == 6)
        #expect(graph.edgeCount == 12)
        #expect(graph.vertexCount == 8)
        #expect(graph.shellCount == 1)
        #expect(graph.solidCount == 1)
        #expect(graph.wireCount == 6)
        #expect(graph.compoundCount == 0)
        #expect(graph.coedgeCount == 24)
        #expect(graph.nodeCount == 58)
    }

    @Test func buildParallel() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let graph = try #require(BRepGraph(shape: box, parallel: true))
        #expect(graph.faceCount == 6)
        #expect(graph.edgeCount == 12)
        #expect(graph.nodeCount == 58)
    }

    @Test func buildFromSphere() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let graph = try #require(BRepGraph(shape: sphere))
        // One spherical face bounded by a seam edge and two degenerate pole edges.
        #expect(graph.faceCount == 1)
        #expect(graph.edgeCount == 3)
        #expect(graph.vertexCount == 2)
        #expect(graph.nodeCount == 13)
    }

    @Test func buildFromComplex() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let cyl = try #require(Shape.cylinder(radius: 5, height: 30))
        let union: Shape? = box + cyl
        let fused = try #require(union)
        let graph = try #require(BRepGraph(shape: fused))
        #expect(graph.faceCount == 8)
        #expect(graph.edgeCount == 15)
        #expect(graph.compoundCount == 1)
        #expect(graph.isValid)
    }
}
