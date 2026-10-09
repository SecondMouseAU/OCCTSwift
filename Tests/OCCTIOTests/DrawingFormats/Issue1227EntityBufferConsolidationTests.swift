import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("#1227 DXF/PDF/SVG shared entity-buffer staging")
struct Issue1227EntityBufferConsolidationTests {
    /// DXFWriter/PDFWriter/SVGWriter used to each independently declare the five entity
    /// arrays and the five `addLine`/`addPolyline`/`addCircle`/`addArc`/`addText` staging
    /// methods, byte-for-byte identical apart from the arc tuple's field names (#1227).
    ///
    /// Exercises every one of the five primitives -- including a degenerate 1-point
    /// "polyline" that the now-shared `DrawingEntityBuffer.addPolyline` guard must still
    /// silently drop -- across all three writers. Nothing in the pre-existing golden-output
    /// tests stages a sub-2-point polyline, so this is coverage those tests don't already
    /// give.
    @Test(
        "addLine/addPolyline/addCircle/addArc/addText produce identical entityCounts across all three writers"
    )
    func allPrimitivesAgreeAcrossWriters() {
        let dxf = DXFWriter()
        let pdf = PDFWriter()
        let svg = SVGWriter()

        func stage(_ w: DrawingPrimitiveSink) {
            w.addLine(from: SIMD2(0, 0), to: SIMD2(1, 1), layer: "VISIBLE")
            w.addPolyline([SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)], closed: false, layer: "VISIBLE")
            // A < 2-point "polyline" must be silently dropped.
            w.addPolyline([SIMD2(9, 9)], closed: false, layer: "VISIBLE")
            w.addCircle(centre: SIMD2(0, 0), radius: 5, layer: "VISIBLE")
            w.addArc(
                centre: SIMD2(0, 0), radius: 5, startAngleDeg: 0, endAngleDeg: 90, layer: "VISIBLE")
            w.addText("hi", at: SIMD2(0, 0), height: 3.5, rotationDeg: 0, layer: "TEXT")
        }
        stage(dxf)
        stage(pdf)
        stage(svg)

        for counts in [dxf.entityCounts, pdf.entityCounts, svg.entityCounts] {
            #expect(counts.lines == 1)
            #expect(counts.polylines == 1)
            #expect(counts.circles == 1)
            #expect(counts.arcs == 1)
            #expect(counts.texts == 1)
        }
    }

    /// The arc entity's own fields specifically -- #1227 unified PDF/SVG's internal
    /// `startDeg`/`endDeg` tuple field spelling onto DXF's `startAngleDeg`/`endAngleDeg`
    /// (the public `addArc(...)` parameter names) so all three share one
    /// `DrawingEntityBuffer.arcs` array.
    ///
    /// A field swapped in that unification would still produce an arc entity (so
    /// `entityCounts.arcs` alone wouldn't catch it) but with the wrong sweep, so this checks
    /// the actual angle values render correctly through all three writers' own serializers.
    @Test("A staged arc's start/end angles round-trip correctly through all three writers")
    func arcAnglesRoundTripThroughAllWriters() throws {
        let dxf = DXFWriter()
        dxf.addArc(centre: .zero, radius: 5, startAngleDeg: 30, endAngleDeg: 120, layer: "VISIBLE")
        let sweep = try #require(dxf.arcSweeps.first)
        #expect(sweep.startAngleDeg == 30)
        #expect(sweep.endAngleDeg == 120)

        // PDF/SVG expose no direct arcSweeps accessor, so round-trip through the rendered
        // output instead: the golden-output tests already cover full-drawing byte identity,
        // this isolates the arc-only path with a hand-staged entity. The arc's own start
        // point -- (centre.x + radius*cos(30deg), centre.y + radius*sin(30deg)) == (4.3301,
        // 2.5000) -- is what both serializers emit first.
        let pdfWriter = PDFWriter()
        pdfWriter.addArc(
            centre: .zero, radius: 5, startAngleDeg: 30, endAngleDeg: 120, layer: "VISIBLE")
        let pdfURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("1227_arc_\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: pdfURL) }
        try pdfWriter.write(to: pdfURL)
        let pdfContent = String(data: try Data(contentsOf: pdfURL), encoding: .isoLatin1) ?? ""
        #expect(pdfContent.contains("4.3301 2.5000 m"))

        let svgWriter = SVGWriter()
        svgWriter.addArc(
            centre: .zero, radius: 5, startAngleDeg: 30, endAngleDeg: 120, layer: "VISIBLE")
        let svgURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("1227_arc_\(UUID()).svg")
        defer { try? FileManager.default.removeItem(at: svgURL) }
        try svgWriter.write(to: svgURL)
        let svgContent = try String(contentsOf: svgURL, encoding: .utf8)
        #expect(svgContent.contains("M 4.3301 2.5000 A"))
    }
}
