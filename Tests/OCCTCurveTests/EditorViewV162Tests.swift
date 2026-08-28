import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.162 EditorView geometric, location, PCurve setters")
struct EditorViewV162Tests {
    @Test(
        "CoEdge UV box setter and per-(edge, face1, face2) regularity setter operate on existing entities"
    )
    func coedgeGeometricSetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph, graph.coedgeCount > 0, graph.edgeCount > 0, graph.faceCount > 1 {
                graph.setCoEdgeUVBox(0, u1: 0, v1: 0, u2: 1, v2: 1)
                // OCCT 8.0.0 GA replaced per-coedge SetContinuity / SetSeamContinuity /
                // SetSeamPairId with EdgeOps:SetRegularity, continuity now lives on
                // (edge, face1, face2). face1 == face2 expresses seam continuity.
                //
                // That write path does not exist in 8.0.0p1: BRepGraph_LayerRegularity does not
                // compile and is absent from libOCCT, so the bridge function is a stub that
                // reports failure and never reads the continuity argument. Assert that, rather
                // than discarding the result, this test had shipped since the GA upgrade with
                // `_ =` on both calls and no expectation, so nothing noticed. #490/#513.
                #expect(graph.setEdgeRegularity(0, face1: 0, face2: 1, continuity: 1) == false)
                #expect(graph.setEdgeRegularity(0, face1: 0, face2: 0, continuity: 0) == false)
            }
        }
    }

    @Test("Identity matrix location setters do not crash on existing refs")
    func identityLocationSetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let m = BRepGraph.identityLocationMatrix
                #expect(m.count == 12)
                if graph.faceRefCount > 0 { graph.setFaceRefLocalLocation(0, matrix: m) }
                if graph.shellRefCount > 0 { graph.setShellRefLocalLocation(0, matrix: m) }
                if graph.solidRefCount > 0 { graph.setSolidRefLocalLocation(0, matrix: m) }
                if graph.wireRefCount > 0 { graph.setWireRefLocalLocation(0, matrix: m) }
                if graph.coedgeRefCount > 0 { graph.setCoEdgeRefLocalLocation(0, matrix: m) }
                if graph.vertexRefCount > 0 { graph.setVertexRefLocalLocation(0, matrix: m) }
            }
        }
    }

    @Test("Face triangulation rep binding")
    func faceTriangulationRepBinding() {
        let nodes: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)]
        let triangles = [0, 1, 2]
        guard let tri = Triangulation.create(nodes: nodes, triangles: triangles) else {
            Issue.record("Triangulation.create nil")
            return
        }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph, graph.faceCount > 0 {
                guard let triRepId = graph.createTriangulationRep(tri) else {
                    Issue.record("createTriangulationRep nil")
                    return
                }
                graph.setFaceTriangulationRep(0, triRepId: triRepId)
                // After binding, MeshView should report the rep as the active triangulation.
                let active = graph.meshFaceActiveTriangulationRepId(0)
                #expect(active != nil)
            }
        }
    }
}
