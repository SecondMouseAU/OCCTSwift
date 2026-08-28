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

                // No-readback setters: just confirm they don't crash.
                graph.setEdgeIsClosed(0, isClosed: false)
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

                // No-readback setter.
                graph.setFaceNaturalRestriction(0, naturalRestriction: true)
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
                if graph.wireCount > 0 {
                    graph.setWireIsClosed(0, isClosed: true)
                }
                if graph.shellCount > 0 {
                    graph.setShellIsClosed(0, isClosed: true)
                }
            }
        }
    }
}
