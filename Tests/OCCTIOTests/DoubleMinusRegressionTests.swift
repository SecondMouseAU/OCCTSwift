import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #800 review: no writer emits a malformed double-sign numeric token
//
// A golden test pins BYTES, not correctness -- a golden regenerated from a still-broken
// implementation is indistinguishable from one refreshed to hide a regression until the
// bytes are read by eye. `emitLayerText` (SVGExporter.swift) used to build its
// counter-rotation transform by string-concatenating a literal "-" in front of an
// already-formatted coordinate instead of negating the number first, so a negative x or y
// produced an invalid double-minus SVG number token (e.g. `translate(0.0000,--10.0000)`
// for y = -10). That bug predated this PR but the golden fixture above captured it as
// "correct" until now. These tests assert the property directly, so a future
// regeneration that reintroduces the bug fails here regardless of what the golden bytes say.

fileprivate func xmlAttributeValues(in content: String) -> [String] {
    // Manual scan rather than a text-content regex: attribute values are always inside a
    // `="..."` pair, which structurally excludes a `<text>`/`<title>` element's own inner
    // text content (arbitrary user-supplied labels, which legitimately might contain "--").
    var values: [String] = []
    var searchStart = content.startIndex
    while let eq = content.range(of: "=\"", range: searchStart..<content.endIndex) {
        let valueStart = eq.upperBound
        guard let closeQuote = content.range(of: "\"", range: valueStart..<content.endIndex) else {
            break
        }
        values.append(String(content[valueStart..<closeQuote.lowerBound]))
        searchStart = closeQuote.upperBound
    }
    return values
}

fileprivate func pdfContentStreamNonTextTokens(_ content: String) -> String {
    // Strip every `(...)` string literal (the payload of a `Tj` text-show operator, the
    // only place arbitrary label text appears) before scanning; everything left is PDF
    // operators and the numbers this writer formats itself.
    var stripped = ""
    var depth = 0
    for ch in content {
        if ch == "(" {
            depth += 1
            continue
        }
        if ch == ")" {
            depth -= 1
            continue
        }
        if depth == 0 { stripped.append(ch) }
    }
    return stripped
}

fileprivate func dxfNonTextValues(_ content: String) -> [String] {
    // DXF alternates group-code/value line pairs; group code 1 is the TEXT entity's own
    // string payload (arbitrary label text), every other code's value is this writer's own
    // formatted number or a fixed enum-ish string (layer/linetype/style names).
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var values: [String] = []
    var i = 0
    while i + 1 < lines.count {
        if lines[i] != "1" { values.append(lines[i + 1]) }
        i += 2
    }
    return values
}

@Suite("#800 review: no writer emits a malformed double-sign numeric token")
struct DoubleMinusRegressionTests {
    @Test(
        "SVGWriter's counter-rotation transform never doubles a minus sign for a negative text position"
    )
    func svgTextTransformNegativePosition() throws {
        let writer = SVGWriter()
        writer.addText("label", at: SIMD2(-8, -10), height: 3.5, rotationDeg: 0, layer: "TEXT")
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("800_negative_text_\(UUID()).svg")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("<text"), "expected a <text> element to have been written")
        for value in xmlAttributeValues(in: content) {
            #expect(
                !value.contains("--"),
                "malformed double-sign numeric attribute value: \"\(value)\" in \(content)")
        }
    }

    @Test(
        "No XML attribute value in SVGWriter's golden-drawing output contains a double minus sign")
    func svgGoldenHasNoDoubleMinus() throws {
        let writer = SVGWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("800_svg_golden_scan_\(UUID()).svg")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        let offenders = xmlAttributeValues(in: content).filter { $0.contains("--") }
        #expect(offenders.isEmpty, "malformed double-sign attribute value(s): \(offenders)")
    }

    @Test("No numeric operand in PDFWriter's content stream contains a double minus sign")
    func pdfGoldenHasNoDoubleMinus() throws {
        let writer = PDFWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("800_pdf_golden_scan_\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .isoLatin1) ?? ""
        let nonText = pdfContentStreamNonTextTokens(content)
        #expect(
            !nonText.contains("--"),
            "malformed double-sign numeric token found outside text payloads")
    }

    @Test("No numeric value in DXFWriter's golden-drawing output contains a double minus sign")
    func dxfGoldenHasNoDoubleMinus() throws {
        let writer = DXFWriter()
        writer.collectFromDrawing(makeGolden795Drawing())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("800_dxf_golden_scan_\(UUID()).dxf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        let offenders = dxfNonTextValues(content).filter { $0.contains("--") }
        #expect(offenders.isEmpty, "malformed double-sign value(s): \(offenders)")
    }
}
