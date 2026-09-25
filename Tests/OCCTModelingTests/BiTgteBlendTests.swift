import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.75.0: BiTgte_Blend, GeomConvert, GCPnts, BRepGProp per-face, ProjectCurveOnSurface, PreviewBox

@Suite("BiTgte Blend Tests")
struct BiTgteBlendTests {
    // #766: blendBoxEdge and blendMultipleEdges do NOT test a blend. Every edge of a plain box is
    // convex, and on a convex edge BiTgte_Blend reports IsDone and returns a SHELL with the box's own
    // faces and volume: measured on these fixtures and on 27 of the 28 edges of the L-shaped solid
    // blendConcaveEdge builds (Scripts/repro/766-modeling-bitgte-blend), where only the one concave
    // edge changes anything. The two tests pin that kernel behaviour, and they fail if the bridge
    // stops handing back the kernel's shell (nil, or the input solid); blendConcaveEdge is the test
    // that exercises the blend.

    @Test("convex box edge: BiTgte_Blend leaves the box unrounded, as a shell (not a blend test)")
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

    @Test("convex box edges: BiTgte_Blend leaves the box unrounded, as a shell (not a blend test)")
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

    @Test("concave edge: the rolling ball fills the inner corner of an L-shaped solid")
    func blendConcaveEdge() throws {
        // An L-shaped solid: a 40 x 40 x 10 slab with a 40 x 10 x 30 wall standing on its y = 0 edge,
        // fused into one solid (14 faces, 24000 mm3). Its one concave edge is the inner corner where
        // the wall meets the slab: the straight edge along X at y = 10, z = 10. That is the only edge
        // of the 28 on which BiTgte_Blend does anything (measured, edge by edge).
        let slab = try #require(Shape.box(origin: .zero, width: 40, height: 40, depth: 10))
        let wall = try #require(Shape.box(origin: .zero, width: 40, height: 10, depth: 30))
        let lShape = try #require(slab.union(wall))
        #expect(lShape.subShapes(ofType: .face).count == 14)
        let inputVolume = try #require(lShape.volume)
        #expect(abs(inputVolume - 24000) < 1e-6)

        // Found by where it is, not by ordinal: it is index 22 in the current enumeration.
        let corner = lShape.edges(inBounds: SIMD3(-1, 9.5, 9.5), SIMD3(41, 10.5, 10.5))
        try #require(corner.count == 1)

        // A ball of radius 3 rolling in that corner adds three blend surfaces (17 faces) and fills
        // the corner, so the shell encloses a little more than the solid it was made from: the
        // kernel's 24076.815 against 24000. A radius of 1.5 gives 24019.261 (measured), so the
        // volume also says the radius reached the kernel. The result is a SHELL, the input a SOLID.
        let blend = try #require(lShape.biTgteBlend(edgeIndices: [corner[0].index], radius: 3))
        #expect(blend.shapeType == .shell)
        #expect(blend.isValid)
        #expect(blend.subShapes(ofType: .face).count == 17)
        let volume = try #require(blend.volume)
        #expect(abs(volume - 24076.815240690972) < 1e-4)
    }
}
