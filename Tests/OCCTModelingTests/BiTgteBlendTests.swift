import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.75.0: BiTgte_Blend, GeomConvert, GCPnts, BRepGProp per-face, ProjectCurveOnSurface, PreviewBox

@Suite("BiTgte Blend Tests")
struct BiTgteBlendTests {
    @Test("rolling ball blend on box edge")
    func blendBoxEdge() throws {
        // #766: this used to assert only inside `if let result`, so a blend that returned nil
        // passed, and a `guard let result else { return }` then let a nil skip the assertions
        // silently; the result goes through try #require now. Pinned to the kernel instead
        // (Scripts/repro/766-modeling-bitgte-blend): BiTgte_Blend on one edge of this box reports
        // IsDone and returns a 6-face shell that encloses the box's own volume, 100 * 80 * 60. It
        // does not round the edge; if a kernel change ever makes it do so, the face count and
        // volume here are what will say so. The result is a SHELL, where the box it was made from
        // is a SOLID with the same faces and volume, so the type is what tells this result from
        // the input handed back unchanged.
        let box = try #require(
            Shape.box(origin: SIMD3(0, 0, 0), width: 100, height: 80, depth: 60))
        let result = try #require(box.biTgteBlend(edgeIndices: [0], radius: 5))
        #expect(result.shapeType == .shell)
        #expect(result.faces().count == 6)
        #expect(abs((result.volume ?? -1) - 480_000) < 1e-3)
    }

    @Test("blend multiple edges")
    func blendMultipleEdges() throws {
        let box = try #require(
            Shape.box(origin: SIMD3(0, 0, 0), width: 50, height: 50, depth: 50))
        // #766: this used to end in `let _ = result`, with no assertion at all, and then
        // guarded the result with `guard let result else { return }`. Pinned to the
        // kernel (Scripts/repro/766-modeling-bitgte-blend): edges 0 and 1 blend to IsDone with a
        // 6-face shell enclosing the box's 125000, the same no-op the single-edge case shows.
        let result = try #require(box.biTgteBlend(edgeIndices: [0, 1], radius: 3))
        #expect(result.shapeType == .shell)
        #expect(result.faces().count == 6)
        #expect(abs((result.volume ?? -1) - 125_000) < 1e-3)
    }
}
