import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.138: DXF export (#63)

@Suite("v0.138 DXF export")
struct DXFExportTests {
    // #1229: DXFError used to declare a `.drawingEmpty` case that nothing ever threw --
    // DXFWriter.write(to:) has never checked whether any entities were staged, matching
    // PDFWriter's own (already-tested, see `PDFWriterTests.emptyPDF`) and SVGWriter's own
    // (already-tested, see `SVGWriterTests.emptySVG`) silent-success behavior on empty
    // content. This pins that same behavior for DXF, the one of the three writers that had
    // no "empty" test at all before this issue.
    @Test("Empty DXF writes a minimum-valid DXF R12 file (#1229)")
    func emptyDXF() throws {
        let writer = DXFWriter()
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("empty_1229_\(UUID()).dxf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SECTION"))
        #expect(content.contains("HEADER"))
        #expect(content.contains("ENTITIES"))
        #expect(content.contains("EOF"))
    }

    @Test("Box front view produces DXF with LINE entities")
    func boxFrontViewDXF() throws {
        guard let box = Shape.box(width: 100, height: 50, depth: 30),
            let drawing = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
            "test_box.dxf")
        defer { try? FileManager.default.removeItem(at: url) }
        try Exporter.writeDXF(drawing: drawing, to: url)
        let data = try String(contentsOf: url, encoding: .utf8)
        #expect(data.contains("SECTION"))
        #expect(data.contains("HEADER"))
        #expect(data.contains("ENTITIES"))
        #expect(data.contains("LINE") || data.contains("LWPOLYLINE"))
        #expect(data.contains("EOF"))
        // Layer table present
        #expect(data.contains("VISIBLE"))
    }

    @Test("DXFWriter emits LINE entity for a single line")
    func singleLine() {
        let w = DXFWriter()
        w.addLine(from: SIMD2(0, 0), to: SIMD2(10, 10))
        #expect(w.entityCounts.lines == 1)
    }

    @Test("Linear dimension emits extension lines + dim line + text")
    func linearDimensionEntityCount() throws {
        guard let box = Shape.box(width: 20, height: 20, depth: 5),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        drawing.clearAnnotations()
        drawing.addLinearDimension(from: SIMD2(0, 0), to: SIMD2(20, 0), offset: 10, label: "20.00")
        let w = DXFWriter()
        w.collectFromDrawing(drawing)
        // 2 extension lines + 1 dim line + body edges
        #expect(w.entityCounts.lines >= 3)
        #expect(w.entityCounts.texts >= 1)
    }

    @Test("Diameter dimension emits CIRCLE element (via radial)")
    func radialEmitsCircle() {
        let w = DXFWriter()
        let drawing = Drawing.topView(of: Shape.box(width: 10, height: 10, depth: 10)!)!
        drawing.addRadialDimension(centre: SIMD2(0, 0), radius: 5)
        w.collectFromDrawing(drawing)
        #expect(w.entityCounts.circles >= 1)
    }

    // #1589: DXFWriter.tables()'s LTYPE table header declared a group-70 max-entry count of 4
    // while only 3 linetypes (CONTINUOUS, DASHED, CHAIN) were ever written before ENDTAB, a
    // stale/copy-paste value present since the file's very first commit (a6977a7b, v0.138.0).
    // Every other table in the same function (LAYER, STYLE) has a count matching its actual
    // entries exactly. This walks the written DXF text itself -- not `tables()`, which is
    // private -- so it fails against the pre-fix `pair(70, 4)` and passes once the declared
    // count matches the real one.
    @Test("LTYPE table's declared group-70 count matches its actual entry count (#1589)")
    func ltypeTableDeclaredCountMatchesEntries() throws {
        let writer = DXFWriter()
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ltype_count_1589_\(UUID()).dxf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writer.write(to: url)
        let content = try String(contentsOf: url, encoding: .utf8)

        // The LTYPE table header is `pair(0,"TABLE") + pair(2,"LTYPE") + pair(70, N)`, i.e.
        // the literal text "0\nTABLE\n2\nLTYPE\n70\n" immediately followed by N.
        guard let headerRange = content.range(of: "0\nTABLE\n2\nLTYPE\n70\n") else {
            Issue.record("LTYPE table header not found in DXF output")
            return
        }
        let afterCode = content[headerRange.upperBound...]
        guard let countEnd = afterCode.firstIndex(of: "\n") else {
            Issue.record("LTYPE declared count line not terminated")
            return
        }
        guard let declaredCount = Int(afterCode[afterCode.startIndex..<countEnd]) else {
            Issue.record("LTYPE declared count is not an integer")
            return
        }

        guard let endTabRange = content.range(of: "0\nENDTAB\n", range: countEnd..<content.endIndex)
        else {
            Issue.record("LTYPE table's ENDTAB not found")
            return
        }
        // Each linetype entry starts with `pair(0,"LTYPE") + pair(2,<name>)`, i.e. "0\nLTYPE\n";
        // the table header itself starts with "0\nTABLE\n" so it never matches this pattern.
        let tableBody = content[countEnd..<endTabRange.lowerBound]
        let actualCount = tableBody.components(separatedBy: "0\nLTYPE\n").count - 1

        #expect(declaredCount == actualCount)
    }
}
