import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("#795 exporter drawing-collection consolidation -- golden output")
struct ExporterDrawingCollectionGoldenTests {
    @Test("SVGWriter.collectFromDrawing output is byte-identical to the pre-consolidation capture")
    func svgGolden() throws {
        let writer = SVGWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("795_golden_\(UUID()).svg")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content == golden795SVG)
    }

    @Test("DXFWriter.collectFromDrawing output is byte-identical to the pre-consolidation capture")
    func dxfGolden() throws {
        let writer = DXFWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("795_golden_\(UUID()).dxf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content == golden795DXF)
    }

    @Test("PDFWriter.collectFromDrawing output is byte-identical to the pre-consolidation capture")
    func pdfGolden() throws {
        let writer = PDFWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("795_golden_\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let actual = try Data(contentsOf: url)
        guard
            let expected = Data(
                base64Encoded: golden795PDFBase64,
                options: .ignoreUnknownCharacters)
        else {
            Issue.record("failed to decode golden PDF base64 fixture")
            return
        }
        #expect(actual == expected)
    }

    /// Direct-API path (not via `Drawing`): `addDimension`/`addLine`/etc. staged by hand,
    /// exercising `primitiveOps()` without `collectFromDrawing` in the loop. Not a golden-byte
    /// comparison -- a lightweight structural check that every writer's direct entity-staging
    /// API still produces the same entity counts after the consolidation.
    @Test(
        "Direct addDimension/addLine staging produces matching entity counts across all three writers"
    )
    func directStagingEntityCountsMatch() {
        let dim = DrawingDimension.linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(10, 0),
                tolerance: .bilateral(plus: 0.1, minus: 0.05)))
        let pdf = PDFWriter()
        pdf.addLine(from: .zero, to: SIMD2(1, 1))
        pdf.addDimension(dim)
        let svg = SVGWriter()
        svg.addLine(from: .zero, to: SIMD2(1, 1))
        svg.addDimension(dim)
        let dxf = DXFWriter()
        dxf.addLine(from: .zero, to: SIMD2(1, 1))
        dxf.addDimension(dim)
        #expect(pdf.entityCounts.lines == svg.entityCounts.lines)
        #expect(pdf.entityCounts.lines == dxf.entityCounts.lines)
        #expect(pdf.entityCounts.texts == svg.entityCounts.texts)
        #expect(pdf.entityCounts.texts == dxf.entityCounts.texts)
        #expect(pdf.entityCounts.texts == 3)  // main + upper + lower
    }
}
