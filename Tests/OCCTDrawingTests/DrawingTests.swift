import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Drawing Tests")
struct DrawingTests {

    @Test("Create 2D projection of box")
    func project2DBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1))
        #expect(drawing != nil)
    }

    @Test("Get visible edges from projection")
    func visibleEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1)) else {
            Issue.record("Failed to create projection")
            return
        }
        let visible = drawing.visibleEdges
        #expect(visible != nil)
    }

    @Test("Get hidden edges from isometric view")
    func hiddenEdgesIsometric() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.isometricView(of: box) else {
            Issue.record("Failed to create isometric view")
            return
        }
        let hidden = drawing.hiddenEdges
        // Isometric view of box should have hidden edges
        #expect(hidden != nil)
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
    func standardViews() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!

        let top = Drawing.topView(of: box)
        #expect(top != nil)

        let front = Drawing.frontView(of: box)
        #expect(front != nil)

        let side = Drawing.sideView(of: box)
        #expect(side != nil)
    }
}
