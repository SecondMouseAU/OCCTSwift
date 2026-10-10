import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: these used to nest their assertions in `if let box` / `if let graph, ...`, so a nil
// graph skipped every one of them and passed; they now record it. The capture-before/
// assert-unchanged closure checks also passed for a getter that always answered the same wrong
// value, so the before value is now pinned to the kernel's (edge 0 open, wire 0 and shell 0
// closed; Scripts/repro/766-drawing-editorview/transcript.txt).
@Suite("v0.159 EditorView field setters")
struct EditorViewSettersTests {
    @Test("Vertex point and tolerance set then read back")
    func vertexFieldSetters() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box), graph.vertexCount > 0
        else {
            Issue.record("box graph unavailable")
            return
        }
        graph.setVertexPoint(0, x: 1.5, y: 2.5, z: 3.5)
        let p = graph.vertexPoint(0)
        #expect(abs(p.x - 1.5) < 1e-9)
        #expect(abs(p.y - 2.5) < 1e-9)
        #expect(abs(p.z - 3.5) < 1e-9)

        graph.setVertexTolerance(0, tolerance: 0.0001)
        #expect(abs(graph.vertexTolerance(0) - 0.0001) < 1e-12)
    }

    @Test("Edge tolerance, range, and flags set then read back")
    func edgeFieldSetters() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box), graph.edgeCount > 0
        else {
            Issue.record("box graph unavailable")
            return
        }
        graph.setEdgeTolerance(0, tolerance: 0.001)
        #expect(abs(graph.edgeTolerance(0) - 0.001) < 1e-12)

        graph.setEdgeParamRange(0, first: 0.25, last: 7.5)
        let r = graph.edgeRange(0)
        #expect(abs(r.first - 0.25) < 1e-9)
        #expect(abs(r.last - 7.5) < 1e-9)

        // OCCT 8.0.0p1: SameParameter / SameRange / Degenerated are now derived per-CoEdge
        // properties (computed from pcurve vs 3D curve), not settable edge flags, the setters
        // are no-ops and the getters report the derived value. (The setEdgeParamRange above made
        // edge 0's range mismatch its 3D curve, so SameParameter/SameRange are legitimately
        // false here.) Confirm the now-derived getters don't crash; a real box edge is never
        // degenerate regardless of the no-op setter.
        graph.setEdgeSameParameter(0, sameParameter: false)
        _ = graph.isEdgeSameParameter(0)
        graph.setEdgeSameRange(0, sameRange: false)
        _ = graph.isEdgeSameRange(0)
        graph.setEdgeDegenerate(0, degenerate: true)
        #expect(!graph.isEdgeDegenerated(0))

        // Same shape as SameParameter/SameRange/Degenerate above: closure is derived, the
        // setter is a no-op (#1001). A box edge is a straight segment, so it reads open.
        let closedBefore = graph.isEdgeClosed(0)
        #expect(closedBefore == false)
        graph.setEdgeIsClosed(0, isClosed: !closedBefore)
        #expect(graph.isEdgeClosed(0) == closedBefore)
    }

    @Test("Face tolerance set then read back")
    func faceFieldSetters() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box), graph.faceCount > 0
        else {
            Issue.record("box graph unavailable")
            return
        }
        graph.setFaceTolerance(0, tolerance: 0.005)
        #expect(abs(graph.faceTolerance(0) - 0.005) < 1e-12)

        // No-op setter (#1001): the natural-restriction flag is no longer stored/settable
        // in OCCT 8.0.0p1. Capture-before/assert-unchanged, not a hardcoded expectation.
        let restrictionBefore = graph.isFaceNaturalRestriction(0)
        graph.setFaceNaturalRestriction(0, naturalRestriction: !restrictionBefore)
        #expect(graph.isFaceNaturalRestriction(0) == restrictionBefore)
    }

    @Test("CoEdge/Wire/Shell setters do not crash on valid ids")
    func auxiliarySetters() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box), graph.wireCount > 0, graph.shellCount > 0
        else {
            Issue.record("box graph unavailable")
            return
        }
        // A box's face wires and its shell start closed. Pinned before the coedge setters below,
        // which move coedge 0's range to [0, 1] and so change what wire 0's derived closure reads.
        #expect(graph.isWireClosed(0) == true)
        #expect(graph.isShellClosed(0) == true)
        // The box has wires/shells; coedges are derived per-face. Setters are no-ops on
        // invalid ids (try/catch in bridge) so the calls below are always safe.
        graph.setCoEdgeParamRange(0, first: 0.0, last: 1.0)
        graph.setCoEdgeOrientation(0, orientation: 0)
        // setWireIsClosed/setShellIsClosed are no-ops (#1001): closure is derived from the
        // coedge chain / face-boundary incidence in OCCT 8.0.0p1. Capture-before/
        // assert-unchanged: the no-op setter must not move the derived value.
        let wireClosedBefore = graph.isWireClosed(0)
        graph.setWireIsClosed(0, isClosed: !wireClosedBefore)
        #expect(graph.isWireClosed(0) == wireClosedBefore)
        let shellClosedBefore = graph.isShellClosed(0)
        graph.setShellIsClosed(0, isClosed: !shellClosedBefore)
        #expect(graph.isShellClosed(0) == shellClosedBefore)
    }
}
