import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.161 EditorView Add/Remove + Ref setters")
struct EditorViewAddRemoveTests {
    @Test("Add operations on a fresh box graph do not crash")
    func addOpsSafe() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // These return nil on invalid topology (a closed box already wires its own
                // structure), but the bridge must not crash.
                _ = graph.edgeAddInternalVertex(0, vertexIndex: 0)
                _ = graph.faceAddVertex(0, vertexIndex: 0)
                _ = graph.shellAddChild(0, childKind: 4, childIndex: 0)
                _ = graph.solidAddChild(0, childKind: 4, childIndex: 0)
                _ = graph.compoundAddChild(0, childKind: 0, childIndex: 0)
                _ = graph.compSolidAddSolid(0, solidIndex: 0)
            }
        }
    }

    @Test("Remove operations on invalid ref ids return false without crashing")
    func removeOpsSafe() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
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
        }
    }

    @Test("Edge / face / coedge ref setters operate on existing entities")
    func refSettersOnExistingIds() {
        // Box has 12 edges, 8 vertices, 6 faces, 6 wires, 1 shell, 1 solid; ids 0..N-1 are valid.
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph, graph.edgeCount > 0, graph.faceCount > 0, graph.shellCount > 0,
                graph.solidCount > 0
            {
                graph.setEdgeCurve3DRepId(0, curve3DRepId: 0)
                graph.setEdgePolygon3DRepId(0, polygon3DRepId: 0)
                if graph.coedgeCount > 0 {
                    graph.setCoEdgeEdgeDefId(0, edgeIndex: 0)
                    graph.setCoEdgeFaceDefId(0, faceIndex: 0)
                    graph.setCoEdgeCurve2DRepId(0, curve2DRepId: 0)
                    graph.setCoEdgePolygon2DRepId(0, polygon2DRepId: 0)
                    graph.setCoEdgePolygonOnTriRepId(0, polygonOnTriRepId: 0)
                    graph.clearCoEdgePCurveBinding(0)
                }
                graph.setFaceSurfaceRepId(0, surfaceRepId: 0)
            }
        }
    }
}
