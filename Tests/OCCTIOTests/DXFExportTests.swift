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
}
