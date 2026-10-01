import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder ClearMesh")
struct BRepGraphBuilderClearMeshTests {
    // These tests asserted nothing ("should not crash"), so a clear that did nothing passed
    // (#1986). The clear only touches the cache tier: the in-place mesh from `box.mesh` lands
    // in the persistent tier and must survive it. So the cache is seeded first, then the
    // clear must empty it while the persistent mesh stays. All states pinned to the kernel
    // probe (Scripts/repro/766-brepgraph-builder-mutation).
    @Test func clearFaceMesh() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = box.mesh(linearDeflection: 0.1)
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.faceHasTriangulation(0))
        #expect(!graph.cachedFaceMeshIsPresent(0))

        let nodes: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(1, 1, 0),
        ]
        let tri = try #require(Triangulation.create(nodes: nodes, triangles: [0, 1, 2, 1, 3, 2]))
        let repId = try #require(graph.createTriangulationRep(tri))
        graph.appendCachedTriangulation(faceIndex: 0, triRepId: repId)
        #expect(graph.cachedFaceMeshIsPresent(0))

        graph.clearFaceMesh(faceIndex: 0)
        #expect(!graph.cachedFaceMeshIsPresent(0))
        #expect(graph.faceHasTriangulation(0))
    }

    @Test func clearEdgePolygon3D() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = box.mesh(linearDeflection: 0.1)
        let graph = try #require(BRepGraph(shape: box))
        // A planar box's edges carry polygons on triangulation, not 3D polygons.
        #expect(!graph.edgeHasPolygon3D(0))

        let pts: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(2, 0, 0)]
        let poly = try #require(Polygon3D.create(points: pts))
        let repId = try #require(graph.createPolygon3DRep(poly))
        graph.setCachedPolygon3D(edgeIndex: 0, polyRepId: repId)
        #expect(graph.cachedEdgeMeshIsPresent(0))
        #expect(graph.edgeHasPolygon3D(0))

        graph.clearEdgePolygon3D(edgeIndex: 0)
        #expect(!graph.cachedEdgeMeshIsPresent(0))
        #expect(!graph.edgeHasPolygon3D(0))
    }
}
