import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.146 #77: Cosmetic threads

@Suite("v0.146 Cosmetic thread annotations")
struct CosmeticThreadTests {
    @Test("Side view produces two parallel centrelines")
    func sideViewProducesTwoLines() {
        let anns = DrawingAnnotation.cosmeticThreadSideView(
            axisStart: SIMD2(0, 0),
            axisEnd: SIMD2(30, 0),
            majorDiameter: 10,
            pitch: 1.5)
        #expect(anns.count == 2)
        for a in anns {
            if case .centreline = a {} else { Issue.record("expected centreline") }
        }
    }

    @Test("End view returns three .arc DrawingAnnotation cases (ISO 6410 3/4 broken arc)")
    func endViewThreeArcs() {
        let anns = DrawingAnnotation.cosmeticThreadEndView(
            centre: SIMD2(0, 0),
            majorDiameter: 10,
            pitch: 1.5)
        #expect(anns.count == 3)
        // #1179: cosmeticThreadEndView used to return a bespoke, non-`DrawingAnnotation`
        // `ArcSegment` type; every element here must now be a proper `.arc` case on the
        // CENTER layer, matching the sibling `cosmeticThreadSideView`'s `.centreline` cases.
        var totalSweep = 0.0
        for ann in anns {
            guard case .arc(let a) = ann else {
                Issue.record("expected .arc case, got \(ann)")
                continue
            }
            #expect(a.layer == "CENTER")
            totalSweep += a.endAngle - a.startAngle
        }
        // Total sweep should be ~270° (0→90, 90→180, 180→315).
        #expect(abs(totalSweep - 7 * .pi / 4) < 1e-9)
    }

    @Test("Drawing.addCosmeticThreadEndView adds 3 arc annotations directly to the drawing")
    func addEndViewToDrawing() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let anns = drawing.addCosmeticThreadEndView(
            centre: SIMD2(5, 5),
            majorDiameter: 10,
            pitch: 1.5)
        #expect(anns.count == 3)
        // #1179: the whole point is that these land on the drawing's own annotationStore
        // (not just a value the caller happens to be handed back), same as
        // `addCosmeticThreadSide` already does for the side view.
        #expect(drawing.annotations.count == 3)
        for ann in drawing.annotations {
            if case .arc = ann {} else { Issue.record("expected .arc case, got \(ann)") }
        }
    }

    @Test("#1179: a Drawing's cosmetic thread end view reaches DXF, PDF and SVG alike")
    func endViewReachesAllThreeWriters() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        drawing.addCosmeticThreadEndView(
            centre: SIMD2(5, 5),
            majorDiameter: 10,
            pitch: 1.5)

        let dxf = DXFWriter()
        dxf.collectFromDrawing(drawing)
        let pdf = PDFWriter()
        pdf.collectFromDrawing(drawing)
        let svg = SVGWriter()
        svg.collectFromDrawing(drawing)

        // Before the fix, the end-view arcs could never reach a `Drawing` at all -- the only
        // consumer was DXFWriter's own bespoke `addCosmeticThreadEndView` extension staging
        // straight onto its private `arcs` array, bypassing `collectFromDrawing`/`emitAnnotation`
        // entirely. PDFWriter and SVGWriter had no equivalent method and would see 0 arcs here.
        #expect(dxf.entityCounts.arcs == 3)
        #expect(pdf.entityCounts.arcs == 3)
        #expect(svg.entityCounts.arcs == 3)
    }

    @Test("#1179: cosmetic thread end view arcs extend Drawing.bounds()")
    func endViewExtendsBounds() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.frontView(of: box),
            let boundsBefore = drawing.bounds(includeAnnotations: true)
        else {
            Issue.record("setup nil")
            return
        }
        // Centre the end view far outside the box's silhouette so it visibly extends bounds.
        let farCentre = SIMD2(boundsBefore.max.x + 1000, boundsBefore.max.y + 1000)
        drawing.addCosmeticThreadEndView(
            centre: farCentre,
            majorDiameter: 10,
            pitch: 1.5)
        guard let boundsAfter = drawing.bounds(includeAnnotations: true) else {
            Issue.record("expected non-nil bounds")
            return
        }
        // Before the fix there was no `.arc` case at all, so `DrawingAnnotation.keyPoints`
        // (which `bounds()` reads) had no way to see this geometry.
        #expect(boundsAfter.max.x > boundsBefore.max.x + 500)
        #expect(boundsAfter.max.y > boundsBefore.max.y + 500)
    }

    @Test("Drawing.addCosmeticThreadSide with callout adds 3 annotations")
    func addSideWithCallout() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let anns = drawing.addCosmeticThreadSide(
            axisStart: SIMD2(0, 0),
            axisEnd: SIMD2(20, 0),
            majorDiameter: 10,
            pitch: 1.5,
            callout: "M10×1.5")
        // 2 centrelines + 1 callout label
        #expect(anns.count == 3)
    }

    @Test("DXFWriter.addCosmeticThreadEndView emits three arcs")
    func dxfWriterEndView() {
        let writer = DXFWriter()
        writer.addCosmeticThreadEndView(
            centre: SIMD2(0, 0),
            majorDiameter: 10,
            pitch: 1.5)
        #expect(writer.entityCounts.arcs == 3)
    }
}
