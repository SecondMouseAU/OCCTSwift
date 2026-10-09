import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: every test here used to nest its body in `if let box` / `if let graph`, so a nil graph
// skipped all of it and passed, and two of the three had no assertion at all. The values pinned
// below are what the same BRepGraph editor calls return on the pinned kernel, measured in
// Scripts/repro/766-drawing-editorview/transcript.txt.
@Suite("v0.161 EditorView Add/Remove + Ref setters")
struct EditorViewAddRemoveTests {
    @Test("Add operations on a fresh box graph do not crash")
    func addOpsSafe() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("box graph unavailable")
            return
        }
        // The two supplement attachments succeed and mint layer-local uids 1 and 2. The rest are
        // refused: a closed box already wires its own structure, childKind 4 (Edge) is not a
        // shell's or a solid's child kind, and the graph has no compound or compsolid 0. The
        // bridge must not crash on any of them.
        #expect(graph.edgeAddInternalVertex(0, vertexIndex: 0) == 1)
        #expect(graph.faceAddVertex(0, vertexIndex: 0) == 2)
        #expect(graph.shellAddChild(0, childKind: 4, childIndex: 0) == nil)
        #expect(graph.solidAddChild(0, childKind: 4, childIndex: 0) == nil)
        #expect(graph.compoundAddChild(0, childKind: 0, childIndex: 0) == nil)
        #expect(graph.compSolidAddSolid(0, solidIndex: 0) == nil)
    }

    @Test("Remove operations on invalid ref ids return false without crashing")
    func removeOpsSafe() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("box graph unavailable")
            return
        }
        #expect(graph.edgeRemoveVertex(0, vertexRefIndex: 99999) == false)
        #expect(
            graph.edgeReplaceVertex(0, oldVertexRefIndex: 99999, newVertexIndex: 0) == nil)
        #expect(graph.wireRemoveCoEdge(0, coedgeRefIndex: 99999) == false)
        #expect(graph.faceRemoveVertex(0, attachmentUID: 99999) == false)
        #expect(graph.faceRemoveWire(0, wireRefIndex: 99999) == false)
        #expect(graph.shellRemoveFace(0, faceRefIndex: 99999) == false)
        #expect(graph.shellRemoveChild(0, childRefIndex: 99999) == false)
        #expect(graph.solidRemoveShell(0, shellRefIndex: 99999) == false)
        #expect(graph.solidRemoveChild(0, childRefIndex: 99999) == false)
        #expect(graph.compoundRemoveChild(0, childRefIndex: 99999) == false)
        #expect(graph.compSolidRemoveSolid(0, solidRefIndex: 99999) == false)
        graph.removeRep(repKind: 0, repIndex: 99999)  // void; no crash
    }

    @Test("Edge / face / coedge ref setters operate on existing entities")
    func refSettersOnExistingIds() {
        // Box has 12 edges, 8 vertices, 6 faces, 6 wires, 1 shell, 1 solid; ids 0..N-1 are valid.
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box), graph.edgeCount > 0, graph.faceCount > 0,
            graph.shellCount > 0, graph.solidCount > 0, graph.coedgeCount > 0
        else {
            Issue.record("box graph unavailable")
            return
        }
        graph.setEdgeCurve3DRepId(0, curve3DRepId: 0)
        graph.setEdgePolygon3DRepId(0, polygon3DRepId: 0)
        // Coedge 0 starts on edge 0 and face 0, so re-pointing it at edge 5 and face 3 is what
        // makes a setter that did nothing visible; the read-back goes through the Topo view.
        graph.setCoEdgeEdgeDefId(0, edgeIndex: 5)
        graph.setCoEdgeFaceDefId(0, faceIndex: 3)
        #expect(graph.coedgeEdge(0) == 5)
        #expect(graph.coedgeFace(0) == 3)
        graph.setCoEdgeCurve2DRepId(0, curve2DRepId: 0)
        graph.setCoEdgePolygon2DRepId(0, polygon2DRepId: 0)
        graph.setCoEdgePolygonOnTriRepId(0, polygonOnTriRepId: 0)
        graph.clearCoEdgePCurveBinding(0)
        graph.setFaceSurfaceRepId(0, surfaceRepId: 0)
    }
}
