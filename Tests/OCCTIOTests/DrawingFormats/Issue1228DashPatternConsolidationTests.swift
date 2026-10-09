import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #1228: PDF/SVG dash-pattern consolidation

@Suite("#1228 PDF/SVG dash-pattern consolidation")
struct Issue1228DashPatternConsolidationTests {
    /// `dashLengths(for:)` (`DrawingDispatch.swift`) is now the one shared per-layer table;
    /// pins the actual documented values directly, the same level of coverage
    /// `strokeWidthMM(for:)` doesn't have either (its own coverage is indirect, through
    /// rendered output only).
    @Test("dashLengths(for:) returns the documented per-layer values")
    func dashLengthsTable() {
        #expect(dashLengths(for: "HIDDEN") == [3, 2])
        #expect(dashLengths(for: "CENTER") == [8, 2, 2, 2])
        #expect(dashLengths(for: "VISIBLE") == nil)
        #expect(dashLengths(for: "TEXT") == nil)
    }

    /// The duplication #1228 fixed: `PDFWriter.dashPattern(for:)` and
    /// `SVGWriter.dashPattern(for:)` each independently switched over the identical dash
    /// lengths, formatted into each format's own syntax.
    ///
    /// Per the issue body, nothing before this test would catch the two drifting apart from
    /// each other -- existing coverage (`PDFWriterTests.hiddenDashPattern`,
    /// `SVGWriterTests.hiddenDashArray`) pins each format's literal output independently, and
    /// a whole-document golden byte-diff wouldn't localize a mismatch to this function either.
    ///
    /// This test instead derives the *expected* string for every dashed and non-dashed layer
    /// from the one shared `dashLengths(for:)` table, then checks both writers' actual
    /// rendered output against it, so a hand-edit to either writer's own dash formatting that
    /// disagrees with the shared table (the exact shape of the original defect, and the only
    /// way one could recur now that both read the same function) fails here.
    ///
    /// Layers limited to `VISIBLE`/`OUTLINE`/`HIDDEN`/`CENTER`/`DIMENSION` (not `TEXT`):
    /// `PDFWriter`'s content-stream builder routes the `TEXT` layer through
    /// `emitLayerText(layer:)` only (never `emitLayerGeometry`), so a line staged on that
    /// layer specifically never renders there at all -- an orthogonal PDF text-vs-geometry
    /// dispatch quirk, not part of the dash-pattern duplication this test is proving.
    @Test(
        "PDF and SVG dash output agrees with the shared dashLengths(for:) table",
        arguments: ["HIDDEN", "CENTER", "VISIBLE", "OUTLINE", "DIMENSION"])
    func dashOutputMatchesSharedTable(layer: String) throws {
        let expected = dashLengths(for: layer)

        let pdfWriter = PDFWriter()
        pdfWriter.addLine(from: SIMD2(0, 0), to: SIMD2(10, 0), layer: layer)
        let pdfURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("1228_dash_\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: pdfURL) }
        try pdfWriter.write(to: pdfURL)
        let pdfContent = String(data: try Data(contentsOf: pdfURL), encoding: .isoLatin1) ?? ""
        let expectedPDFDash =
            "[\((expected ?? []).map(String.init).joined(separator: " "))] 0"
        #expect(pdfContent.contains("\(expectedPDFDash) d"))

        let svgWriter = SVGWriter()
        svgWriter.addLine(from: SIMD2(0, 0), to: SIMD2(10, 0), layer: layer)
        let svgURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("1228_dash_\(UUID()).svg")
        defer { try? FileManager.default.removeItem(at: svgURL) }
        try svgWriter.write(to: svgURL)
        let svgContent = try String(contentsOf: svgURL, encoding: .utf8)
        if let lengths = expected {
            let expectedSVGDash = lengths.map(String.init).joined(separator: ",")
            #expect(svgContent.contains("stroke-dasharray=\"\(expectedSVGDash)\""))
        } else {
            #expect(!svgContent.contains("stroke-dasharray"))
        }
    }
}
