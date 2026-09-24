import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Drawing Tests")
struct DrawingTests {

    /// #766: the projection tests below used to assert only that a drawing or an edge category
    /// was non-nil, so a projection along the wrong direction, or of the wrong shape, passed. They
    /// now pin the unique edge count and the 2D extent HLRBRep_Algo produces for the same shape
    /// and view (`Shape.box` is centred on the origin), measured in
    /// Scripts/repro/766-drawing-core-transform/transcript.txt.
    ///
    /// Throws through `#require` when the category or its bounding box is nil, so the calling test
    /// stops at the first missing shape instead of recording it and carrying on to the next view.
    private func expectEdges(
        _ shape: Shape?, count: Int, min: SIMD2<Double>, max: SIMD2<Double>,
        _ what: String
    ) throws {
        let found = try #require(shape, "\(what): no edges")
        let bb = try #require(found.boundingBox, "\(what): edges have no bounding box")
        #expect(found.edges().count == count, "\(what): \(found.edges().count) edges")
        #expect(
            simd_length(SIMD2(bb.min.x, bb.min.y) - min) < 1e-6
                && simd_length(SIMD2(bb.max.x, bb.max.y) - max) < 1e-6,
            "\(what): extent \(bb.min) .. \(bb.max)")
    }

    @Test("Create 2D projection of box")
    func project2DBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1)) else {
            Issue.record("Failed to create projection")
            return
        }
        try expectEdges(
            drawing.visibleEdges, count: 4,
            min: SIMD2(-5.0000001, -5.0000001), max: SIMD2(5.0000001, 5.0000001), "top visible")
    }

    @Test("Get visible edges from projection")
    func visibleEdges() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.isometricView(of: box) else {
            Issue.record("Failed to create projection")
            return
        }
        // Isometric: the three near faces show nine visible edges, the hexagonal silhouette.
        try expectEdges(
            drawing.visibleEdges, count: 9,
            min: SIMD2(-7.07106791, -8.16496591), max: SIMD2(7.07106791, 8.16496591),
            "iso visible")
    }

    @Test("Get hidden edges from isometric view")
    func hiddenEdgesIsometric() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.isometricView(of: box) else {
            Issue.record("Failed to create isometric view")
            return
        }
        // Isometric view of box: the three edges meeting at the far corner are hidden.
        try expectEdges(
            drawing.hiddenEdges, count: 3,
            min: SIMD2(-7.07106791, -4.082483), max: SIMD2(7.07106791, 8.16496591),
            "iso hidden")
    }

    // #1421: OCCTDrawingGetEdges' empty-result guard checked `compound.IsNull()`, but
    // BRep_Builder::MakeCompound always leaves that false (it unconditionally allocates a fresh
    // TopoDS_TCompound before anything is added), so the guard could never fire. A category with
    // zero contributing edges came back as a valid, non-nil, empty ``Shape`` instead of the `nil`
    // ``Drawing/edges(ofType:)`` documents. A sphere alone in the scene is convex, so nothing
    // occludes anything and `.hidden` is genuinely empty regardless of view direction -- confirmed
    // directly against the unfixed bridge before this test was written: `edges(ofType: .hidden)`
    // returned a non-nil `Shape` with `edgeCount == 0`, for both directions below.
    @Test("Hidden edges are nil for a convex shape with no self-occlusion (#1421)")
    func hiddenEdgesNilForConvexShapeWithNoSelfOcclusion() {
        let sphere = Shape.sphere(radius: 10)!

        guard let drawing = Drawing.project(sphere, direction: SIMD3(0, 0, 1)) else {
            Issue.record("Failed to create projection")
            return
        }
        #expect(drawing.hiddenEdges == nil)
        // Confirms the nil above means "this category is genuinely empty", not "the projection
        // itself failed" -- a lone sphere still has visible edges (its outline).
        #expect(drawing.visibleEdges != nil)

        // Same claim from a second, unrelated view direction, so the result isn't an artifact of
        // one particular projection.
        guard let isoDrawing = Drawing.isometricView(of: sphere) else {
            Issue.record("Failed to create isometric projection")
            return
        }
        #expect(isoDrawing.hiddenEdges == nil)
    }

    // #1421: same defect, the other edge category. A box has only flat faces and sharp edges, so
    // OCCT's HLR "outline" category (the generated silhouette of a smooth/curved surface) has
    // nothing to contribute -- the box's visible boundary comes entirely from sharp edges
    // (visibleEdges), never from outline. Confirmed against the unfixed bridge the same way as
    // above: `edges(ofType: .outline)` returned a non-nil `Shape` with `edgeCount == 0`.
    @Test("Outline edges are nil for a shape with no curved surfaces (#1421)")
    func outlineEdgesNilForShapeWithNoSilhouette() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1)) else {
            Issue.record("Failed to create projection")
            return
        }
        #expect(drawing.outlineEdges == nil)
        #expect(drawing.visibleEdges != nil)
    }

    @Test("Standard views")
    func standardViews() throws {
        let box = Shape.box(width: 10, height: 20, depth: 30)!

        // Each view is the box's rectangle in that view's gp_Ax2 frame: 10 x 20 from the top,
        // 30 x 10 from the front, 30 x 20 from the side.
        try expectEdges(
            Drawing.topView(of: box)?.visibleEdges, count: 4,
            min: SIMD2(-5.0000001, -10.0000001), max: SIMD2(5.0000001, 10.0000001), "top")
        try expectEdges(
            Drawing.frontView(of: box)?.visibleEdges, count: 4,
            min: SIMD2(-15.0000001, -5.0000001), max: SIMD2(15.0000001, 5.0000001), "front")
        try expectEdges(
            Drawing.sideView(of: box)?.visibleEdges, count: 4,
            min: SIMD2(-15.0000001, -10.0000001), max: SIMD2(15.0000001, 10.0000001), "side")
    }
}
