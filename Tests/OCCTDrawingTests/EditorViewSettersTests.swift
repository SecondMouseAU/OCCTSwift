import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.159 EditorView field setters")
struct EditorViewSettersTests {
    @Test("Vertex point and tolerance set then read back")
    func vertexFieldSetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph, graph.vertexCount > 0 {
                graph.setVertexPoint(0, x: 1.5, y: 2.5, z: 3.5)
                let p = graph.vertexPoint(0)
                #expect(abs(p.x - 1.5) < 1e-9)
                #expect(abs(p.y - 2.5) < 1e-9)
                #expect(abs(p.z - 3.5) < 1e-9)

                graph.setVertexTolerance(0, tolerance: 0.0001)
                #expect(abs(graph.vertexTolerance(0) - 0.0001) < 1e-12)
            }
        }
    }

    @Test("Edge tolerance, range, and flags set then read back")
    func edgeFieldSetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph, graph.edgeCount > 0 {
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
                // setter is a no-op (#1001). Capture-before/assert-unchanged rather than assuming
                // a specific boolean, since the point is that the setter can't move the derived
                // value either way, not that a box edge happens to read false.
                let closedBefore = graph.isEdgeClosed(0)
                graph.setEdgeIsClosed(0, isClosed: !closedBefore)
                #expect(graph.isEdgeClosed(0) == closedBefore)
            }
        }
    }

    @Test("Face tolerance set then read back")
    func faceFieldSetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph, graph.faceCount > 0 {
                graph.setFaceTolerance(0, tolerance: 0.005)
                #expect(abs(graph.faceTolerance(0) - 0.005) < 1e-12)

                // No-op setter (#1001): the natural-restriction flag is no longer stored/settable
                // in OCCT 8.0.0p1. Capture-before/assert-unchanged, not a hardcoded expectation.
                let restrictionBefore = graph.isFaceNaturalRestriction(0)
                graph.setFaceNaturalRestriction(0, naturalRestriction: !restrictionBefore)
                #expect(graph.isFaceNaturalRestriction(0) == restrictionBefore)
            }
        }
    }

    @Test("CoEdge/Wire/Shell setters do not crash on valid ids")
    func auxiliarySetters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // The box has wires/shells; coedges are derived per-face. Setters are no-ops on
                // invalid ids (try/catch in bridge) so the calls below are always safe.
                graph.setCoEdgeParamRange(0, first: 0.0, last: 1.0)
                graph.setCoEdgeOrientation(0, orientation: 0)
                // setWireIsClosed/setShellIsClosed are no-ops (#1001): closure is derived from the
                // coedge chain / face-boundary incidence in OCCT 8.0.0p1. Capture-before/
                // assert-unchanged, not a hardcoded expectation.
                if graph.wireCount > 0 {
                    let closedBefore = graph.isWireClosed(0)
                    graph.setWireIsClosed(0, isClosed: !closedBefore)
                    #expect(graph.isWireClosed(0) == closedBefore)
                }
                if graph.shellCount > 0 {
                    let closedBefore = graph.isShellClosed(0)
                    graph.setShellIsClosed(0, isClosed: !closedBefore)
                    #expect(graph.isShellClosed(0) == closedBefore)
                }
            }
        }
    }
}
