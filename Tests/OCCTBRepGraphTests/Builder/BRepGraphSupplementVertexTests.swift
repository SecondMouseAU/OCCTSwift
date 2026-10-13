import Foundation
import Testing

@testable import OCCTSwift

// MARK: - Supplement vertex attachments (un-stubbed against OCCT 8.0.0p1 TopoSupplement layer)
//
// Face-direct and edge-internal vertices are a supplemental, RUNTIME concept in 8.0.0p1
// (BRepGraph_LayerTopoSupplement): a freshly built (clean) box graph has none until one is
// attached via faceAddVertex / edgeAddInternalVertex. The returned value is a layer-local
// attachment uid (not a core ref index); removal is by that uid.
@Suite("BRepGraph Supplement Vertices")
struct BRepGraphSupplementVertexTests {
    @Test func faceDirectVertexAttachCountRemove() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        guard let box else {
            Issue.record("box build failed")
            return
        }
        let graph = BRepGraph(shape: box)
        guard let graph else {
            Issue.record("graph build failed")
            return
        }

        // Clean box: no face-direct vertices until we add one.
        #expect(graph.faceVertexRefCount(0) == 0)

        let uid = graph.faceAddVertex(0, vertexIndex: 0)
        #expect(uid != nil)
        if let uid {
            #expect(uid >= 0)
            // The attachment now shows up in the FaceDirectVertex count for face 0.
            #expect(graph.faceVertexRefCount(0) == 1)

            // Removing by the returned uid succeeds and drops the count back.
            #expect(graph.faceRemoveVertex(0, attachmentUID: uid) == true)
            #expect(graph.faceVertexRefCount(0) == 0)

            // Removing the same uid again returns false (already gone).
            #expect(graph.faceRemoveVertex(0, attachmentUID: uid) == false)
        }
    }

    @Test func edgeInternalVertexAttach() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        guard let box else {
            Issue.record("box build failed")
            return
        }
        let graph = BRepGraph(shape: box)
        guard let graph else {
            Issue.record("graph build failed")
            return
        }

        // Attaching an edge-internal vertex returns a non-nil layer-local uid.
        let uid = graph.edgeAddInternalVertex(0, vertexIndex: 0)
        #expect(uid != nil)
        if let uid { #expect(uid >= 0) }

        // A second attachment is a different attachment, so the uid names the attachment and is
        // not a constant; and an index that names no edge is refused rather than answered with a
        // uid.
        let second = graph.edgeAddInternalVertex(0, vertexIndex: 1)
        #expect(second != nil)
        if let uid, let second { #expect(second != uid) }
        #expect(graph.edgeAddInternalVertex(9999, vertexIndex: 0) == nil)

        // A vertex index the graph does not have is refused, not read past the vertex table
        // (#3394: it answered a uid on one run and died of SIGSEGV on the next). A box has 8.
        #expect(graph.vertexCount == 8)
        #expect(graph.edgeAddInternalVertex(0, vertexIndex: 9999) == nil)
        #expect(graph.edgeAddInternalVertex(0, vertexIndex: 8) == nil)
        #expect(graph.edgeAddInternalVertex(0, vertexIndex: -1) == nil)
        #expect(graph.edgeAddInternalVertex(0, vertexIndex: 7) != nil)

        // The face entry point shares the helper.
        #expect(graph.faceAddVertex(0, vertexIndex: 9999) == nil)
        #expect(graph.faceAddVertex(0, vertexIndex: -1) == nil)
        #expect(graph.faceAddVertex(0, vertexIndex: 7) != nil)
    }

    // FaceIsNaturalRestriction: honest read of NbWires == 0. p1 normalizes natural-bound faces
    // (it always materializes a bounding wire) so a box face is NOT a natural-restriction face.
    @Test func boxFacesNotNaturalRestriction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        guard let box else {
            Issue.record("box build failed")
            return
        }
        let graph = BRepGraph(shape: box)
        guard let graph else {
            Issue.record("graph build failed")
            return
        }
        for i in 0..<graph.faceCount {
            #expect(graph.isFaceNaturalRestriction(i) == false)
        }
    }
}
