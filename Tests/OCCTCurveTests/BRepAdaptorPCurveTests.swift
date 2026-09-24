import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to BRepAdaptor_Curve2d on the same edge and face
// (Scripts/repro/766-curve-bitgte-pcurve-approx/transcript.txt): edges[0] of the centred 10x20x30
// box, (-5,-10,-15) -> (-5,-10,15), on faces[0], the x = -5 plane. The earlier pcurveValue ended in
// `#expect(Bool(true))`, so it could not fail, and pcurveParams accepted any increasing range (#766).
@Suite("BRepAdaptor PCurve")
struct BRepAdaptorPCurveTests {
    private static func fixture() -> (edge: Edge, face: Face)? {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            Issue.record("Failed to create box")
            return nil
        }
        let faces = box.faces()
        let edges = box.edges()
        guard let face = faces.first, let edge = edges.first else {
            Issue.record("box has no faces or no edges")
            return nil
        }
        return (edge, face)
    }

    @Test("PCurve params on box face")
    func pcurveParams() {
        guard let fx = Self.fixture() else { return }
        let (edge, face) = (fx.edge, fx.face)
        guard let params = edge.pcurveParams(on: face) else {
            Issue.record("no pcurve for edges[0] on faces[0]")
            return
        }
        #expect(params.first == 0)
        #expect(params.last == 30)
    }

    @Test("PCurve value evaluation")
    func pcurveValue() {
        guard let fx = Self.fixture() else { return }
        let (edge, face) = (fx.edge, fx.face)
        guard let uv = edge.pcurveValue(at: 15, on: face) else {
            Issue.record("no pcurve value for edges[0] on faces[0]")
            return
        }
        // The edge midpoint, (-5, -10, 0), sits at (u, v) = (15, 0) on the x = -5 plane.
        #expect(abs(uv.x - 15) < 1e-9)
        #expect(abs(uv.y) < 1e-9)
    }
}
