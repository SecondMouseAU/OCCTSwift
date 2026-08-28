import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.164 RepOps non-guard setters & cache entry inspection")
struct EditorViewV164Tests {
    @Test("Cached face mesh inspection on a fresh graph")
    func cachedFaceMeshInspectionOnFreshGraph() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph, graph.faceCount > 0 {
                #expect(graph.cachedFaceMeshIsPresent(0) == false)
                #expect(graph.cachedFaceMeshTriRepCount(0) == 0)
                #expect(graph.cachedFaceMeshActiveIndex(0) == -1)
                #expect(graph.cachedFaceMeshTriRepId(0, repIndex: 0) == nil)
            }
        }
    }

    @Test("Cached face mesh state after appendCachedTriangulation")
    func cachedFaceMeshAfterAppend() {
        let nodes: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)]
        guard let tri = Triangulation.create(nodes: nodes, triangles: [0, 1, 2]) else {
            Issue.record("Triangulation.create nil")
            return
        }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph, graph.faceCount > 0,
                let triRepId = graph.createTriangulationRep(tri)
            {
                graph.appendCachedTriangulation(faceIndex: 0, triRepId: triRepId)
                graph.setCachedActiveIndex(faceIndex: 0, activeIndex: 0)
                #expect(graph.cachedFaceMeshIsPresent(0) == true)
                #expect(graph.cachedFaceMeshTriRepCount(0) == 1)
                #expect(graph.cachedFaceMeshActiveIndex(0) == 0)
                #expect(graph.cachedFaceMeshTriRepId(0, repIndex: 0) == triRepId)
            }
        }
    }

    @Test("Cached edge / coedge mesh accessors return absent on fresh graph")
    func cachedEdgeCoEdgeAbsent() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.cachedEdgeMeshIsPresent(0) == false)
                #expect(graph.cachedEdgeMeshPolygon3DRepId(0) == nil)
                #expect(graph.cachedCoEdgeMeshIsPresent(0) == false)
                #expect(graph.cachedCoEdgeMeshPolygon2DRepId(0) == nil)
                #expect(graph.cachedCoEdgeMeshPolygonOnTriRepCount(0) == 0)
            }
        }
    }
}
