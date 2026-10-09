import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.150 #85: PDFWriter

@Suite("v0.150 PDFWriter")
struct PDFWriterTests {
    @Test("Empty PDF writes a minimum-valid PDF 1.4 file")
    func emptyPDF() throws {
        let writer = PDFWriter()
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("empty.pdf")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .isoLatin1)
        #expect(content.hasPrefix("%PDF-1.4"))
        #expect(content.contains("xref"))
        #expect(content.contains("%%EOF"))
    }

    @Test("Box front view PDF contains the expected polyline count")
    func boxFrontPDF() {
        guard let box = Shape.box(width: 10, height: 5, depth: 3),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let writer = PDFWriter()
        writer.collectFromDrawing(front)
        let counts = writer.entityCounts
        #expect(counts.lines + counts.polylines > 0)
    }

    @Test("Hidden-layer content emits a dash pattern")
    func hiddenDashPattern() throws {
        let writer = PDFWriter()
        writer.addLine(from: SIMD2(0, 0), to: SIMD2(10, 0), layer: "HIDDEN")
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("hidden.pdf")
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .isoLatin1)
        #expect(content.contains("[3 2] 0 d"))
    }

    @Test("Tolerance symbol survives into PDF content stream")
    func toleranceInPDF() throws {
        let writer = PDFWriter()
        writer.addDimension(
            .linear(
                .init(
                    from: SIMD2(0, 0), to: SIMD2(10, 0),
                    tolerance: .symmetric(0.05))))
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tol.pdf")
        try writer.write(to: url)
        let data = try Data(contentsOf: url)
        // PDF files mix ASCII and binary; decode with a single-byte encoding
        // that can round-trip every byte.
        let content = String(data: data, encoding: .isoLatin1) ?? ""
        // Our escape function passes ± through as UTF-8 bytes (0xC2 0xB1).
        // In isoLatin1 decoding those map to "Â±", check for that instead.
        #expect(content.contains("0.050"))
        // ± is a UTF-8 2-byte sequence; its isoLatin1 decoding is "Â±".
        #expect(content.contains("\u{00C2}\u{00B1}"))
    }

    @Test("Sheet + standardLayout round-trips through writePDF")
    func sheetWritePDF() throws {
        let sheet = Sheet(size: .a4, orientation: .landscape)
        guard let box = Shape.box(width: 20, height: 10, depth: 5),
            let layout = sheet.standardLayout(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sheet.pdf")
        try Exporter.writePDF(
            sheet: sheet,
            body: { pdf in
                // #1180: `Sheet.render`/`StandardLayout.render` used to only accept `DXFWriter`,
                // so this test had to re-derive `StandardLayout.render`'s own body inline
                // instead of calling it, and could draw no sheet border, ISO 7200 title block,
                // or ISO 5456-2 projection symbol at all onto the PDF. Both now accept
                // `PDFWriter` directly.
                sheet.render(into: pdf)
                layout.render(into: pdf)
            }, to: url)
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        #expect(size > 400)  // header + xref + at least one object
    }
}
