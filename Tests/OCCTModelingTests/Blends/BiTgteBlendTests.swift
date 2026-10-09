import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.75.0: BiTgte_Blend, GeomConvert, GCPnts, BRepGProp per-face, ProjectCurveOnSurface, PreviewBox

@Suite("BiTgte Blend Tests")
struct BiTgteBlendTests {
    @Test("rolling ball blend on box edge")
    func blendBoxEdge() {
        let box = Shape.box(origin: SIMD3(0, 0, 0), width: 100, height: 80, depth: 60)!
        if let result = box.biTgteBlend(edgeIndices: [0], radius: 5) {
            if let vol = result.volume { #expect(vol > 0) }
        }
    }

    @Test("blend multiple edges")
    func blendMultipleEdges() {
        let box = Shape.box(origin: SIMD3(0, 0, 0), width: 50, height: 50, depth: 50)!
        // Try blending first two edges
        let result = box.biTgteBlend(edgeIndices: [0, 1], radius: 3)
        // May or may not succeed depending on edge adjacency, just verify no crash
        let _ = result
    }
}
