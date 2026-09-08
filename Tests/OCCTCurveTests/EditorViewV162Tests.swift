import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.162 EditorView geometric, location, PCurve setters")
struct EditorViewV162Tests {
    @Test("Per-(edge, face1, face2) regularity setter reports failure on the pinned kernel")
    func edgeRegularitySetterReportsFailure() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph, graph.coedgeCount > 0, graph.edgeCount > 0, graph.faceCount > 1 {
                // OCCT 8.0.0 GA replaced per-coedge SetContinuity / SetSeamContinuity /
                // SetSeamPairId with EdgeOps:SetRegularity, continuity now lives on
                // (edge, face1, face2). face1 == face2 expresses seam continuity.
                //
                // That write path does not exist in 8.0.1: BRepGraph_LayerRegularity does not
                // compile and is absent from libOCCT, so the bridge function is a stub that
                // reports failure and never reads the continuity argument. Assert that, rather
                // than discarding the result, this test had shipped since the GA upgrade with
                // `_ =` on both calls and no expectation, so nothing noticed. #490/#513.
                #expect(graph.setEdgeRegularity(0, face1: 0, face2: 1, continuity: 1) == false)
                #expect(graph.setEdgeRegularity(0, face1: 0, face2: 0, continuity: 0) == false)
            }
        }
    }

    // #1652 removed `setCoEdgeUVBox(_:u1:v1:u2:v2:)`: OCCT 8.0.1 stores no per-coedge UV box, and
    // `BRepGraph_Tool::CoEdge::UVPoints` derives the endpoints from the PCurve. The two tests
    // below cover the write path that replaced it. Both fail if `coEdgeSetPCurve` or
    // `coEdgeAddPCurve` becomes a no-op, which is what the removed setter had silently been.
    @Test("coEdgeSetPCurve binds and clears the PCurve that the UV endpoints derive from")
    func coEdgeSetPCurveBindsAndClears() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box), graph.coedgeCount > 0
        else {
            Issue.record("box graph with coedges unavailable")
            return
        }
        guard
            let line = Curve2D.line(
                through: SIMD2<Double>(2, 3), direction: SIMD2<Double>(1, 0))
        else {
            Issue.record("Curve2D.line nil")
            return
        }
        // Clear first, then bind. A freshly ingested box already reports `coedgeHasPCurve` true
        // (measured in Scripts/repro/1652-brepgraph-noop-setters/), so asserting it after a bind
        // would pass on a no-op bridge. Ordered this way both assertions are real transitions.
        graph.coEdgeSetPCurve(0, curve2D: nil)
        #expect(graph.coedgeHasPCurve(0) == false)
        graph.coEdgeSetPCurve(0, curve2D: line)
        #expect(graph.coedgeHasPCurve(0))
    }

    @Test("coEdgeAddPCurve appends a coedge carrying the requested parameter range")
    func coEdgeAddPCurveCarriesRange() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box), graph.edgeCount > 0, graph.faceCount > 0
        else {
            Issue.record("box graph unavailable")
            return
        }
        guard
            let line = Curve2D.line(
                through: SIMD2<Double>(2, 3), direction: SIMD2<Double>(1, 0))
        else {
            Issue.record("Curve2D.line nil")
            return
        }
        let before = graph.coedgeCount
        graph.coEdgeAddPCurve(
            edgeIndex: 0, faceIndex: 0, curve2D: line, first: 0.0, last: 4.0)
        #expect(graph.coedgeCount == before + 1)
        if graph.coedgeCount == before + 1 {
            let added = before
            #expect(graph.coedgeHasPCurve(added))
            let range = graph.coedgeRange(added)
            #expect(abs(range.first - 0.0) < 1e-9)
            #expect(abs(range.last - 4.0) < 1e-9)
        }
    }

    // #1652 also removed `repSetPolygonOnTriTriangulationId(_:triRepId:)`: a polygon-on-tri
    // resolves its triangulation through the owning face, so `setFaceTriangulationRep` is the
    // call that changes it. Asserting the face has no triangulation before the bind is what makes
    // this fail if that setter becomes a no-op; the old version only checked the post-state.
    @Test("Face triangulation rep binding")
    func faceTriangulationRepBinding() {
        let nodes: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)]
        let triangles = [0, 1, 2]
        guard let tri = Triangulation.create(nodes: nodes, triangles: triangles) else {
            Issue.record("Triangulation.create nil")
            return
        }
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box), graph.faceCount > 0
        else {
            Issue.record("box graph unavailable")
            return
        }
        #expect(graph.meshFaceActiveTriangulationRepId(0) == nil)
        guard let triRepId = graph.createTriangulationRep(tri) else {
            Issue.record("createTriangulationRep nil")
            return
        }
        graph.setFaceTriangulationRep(0, triRepId: triRepId)
        // After binding, MeshView should report the rep as the active triangulation.
        #expect(graph.meshFaceActiveTriangulationRepId(0) != nil)
    }
}
