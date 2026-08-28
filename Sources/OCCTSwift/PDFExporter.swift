import Foundation
import simd

// MARK: - PDF 1.4 export (#85, v0.150)
//
// Pure-Swift PDF writer — no UIKit / AppKit / Core Graphics dependency. Produces
// a flat, single-page PDF 1.4 file with exploded LINE + cubic-Bézier curve
// geometry plus Helvetica text. Suitable for humans (print, review) where DXF
// serves engineering-tool exchange.
//
// Coordinate model:
//   - Caller staging coordinates are drawing units (mm, matching the DXF side).
//   - `pageSize` is in PDF points (1 pt = 1/72 inch; 1 mm ≈ 2.8346 pt).
//   - The content stream installs a CTM that maps mm → pts, so line widths,
//     text heights, and geometry are all specified in mm throughout.
//
// Per-layer stroke weights follow ISO 128-20:
//   VISIBLE / OUTLINE / BORDER / TITLE     → 0.5 mm
//   HIDDEN / CENTER / DIMENSION / TEXT     → 0.25 mm
//   HATCH                                  → 0.18 mm
//
// Dashed-line patterns (layers without a native linestyle fall through to solid):
//   HIDDEN  → 3 mm dash / 2 mm gap
//   CENTER  → 8 mm dash / 2 mm gap / 2 mm dash / 2 mm gap (chain)

public enum PDFError: Error, LocalizedError {
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .writeFailed(let msg): return "PDF write failed: \(msg)"
        }
    }
}

extension Exporter {
    /// A4 landscape in points (297 × 210 mm).
    public static let pdfA4Landscape = SIMD2<Double>(841, 595)
    /// A3 landscape in points (420 × 297 mm).
    public static let pdfA3Landscape = SIMD2<Double>(1191, 842)

    public static func writePDF(
        drawing: Drawing, to url: URL,
        pageSize: SIMD2<Double> = SIMD2(841, 595),
        deflection: Double = 0.1
    ) throws {
        let writer = PDFWriter(pageSize: pageSize, deflection: deflection)
        writer.collectFromDrawing(drawing)
        try writer.write(to: url)
    }

    public static func writePDF(
        sheet: Sheet, body: (PDFWriter) -> Void,
        to url: URL,
        deflection: Double = 0.1
    ) throws {
        // Page size = sheet dimensions in mm → pts at 72 dpi.
        let dim = sheet.dimensions
        let mmToPt = 72.0 / 25.4
        let writer = PDFWriter(
            pageSize: SIMD2(dim.x * mmToPt, dim.y * mmToPt),
            deflection: deflection)
        body(writer)
        try writer.write(to: url)
    }
}

public final class PDFWriter: @unchecked Sendable, DrawingPrimitiveSink {
    public let pageSize: SIMD2<Double>
    public let deflection: Double

    /// DrawingPrimitiveSink's shared entity storage -- see DrawingDispatch.swift.
    ///
    /// #1227.
    internal var entityBuffer = DrawingEntityBuffer()
    /// DrawingPrimitiveSink.primitiveOps()'s cache -- see DrawingDispatch.swift.
    ///
    internal var cachedPrimitiveOps: DrawingPrimitiveOps?

    public init(pageSize: SIMD2<Double> = SIMD2(841, 595), deflection: Double = 0.1) {
        self.pageSize = pageSize
        self.deflection = deflection
    }

    // MARK: - Entity staging
    //
    // Each method forwards to `DrawingEntityBuffer`'s own staging logic (shared with
    // DXFWriter/SVGWriter, #1227); kept as an explicit per-writer `public func` rather than a
    // `DrawingPrimitiveSink` protocol-extension default for the same reason
    // `collectFromDrawing` below is -- see `DrawingEntityBuffer`'s own doc comment.

    public func addLine(from a: SIMD2<Double>, to b: SIMD2<Double>, layer: String = "VISIBLE") {
        entityBuffer.addLine(from: a, to: b, layer: layer)
    }

    public func addPolyline(
        _ points: [SIMD2<Double>], closed: Bool = false, layer: String = "VISIBLE"
    ) {
        entityBuffer.addPolyline(points, closed: closed, layer: layer)
    }

    public func addCircle(centre: SIMD2<Double>, radius: Double, layer: String = "VISIBLE") {
        entityBuffer.addCircle(centre: centre, radius: radius, layer: layer)
    }

    public func addArc(
        centre: SIMD2<Double>, radius: Double,
        startAngleDeg: Double, endAngleDeg: Double,
        layer: String = "VISIBLE"
    ) {
        entityBuffer.addArc(
            centre: centre, radius: radius,
            startAngleDeg: startAngleDeg, endAngleDeg: endAngleDeg, layer: layer)
    }

    public func addText(
        _ text: String, at position: SIMD2<Double>,
        height: Double = 3.5, rotationDeg: Double = 0,
        layer: String = "TEXT"
    ) {
        entityBuffer.addText(
            text, at: position, height: height, rotationDeg: rotationDeg, layer: layer)
    }

    public func addDimension(_ d: DrawingDimension) {
        emitDimension(d, into: primitiveOps())
    }

    public var entityCounts: (lines: Int, polylines: Int, circles: Int, arcs: Int, texts: Int) {
        entityBuffer.entityCounts
    }

    // MARK: - Collection from Drawing

    public func collectFromDrawing(
        _ drawing: Drawing,
        translate: SIMD2<Double> = .zero,
        scale: Double = 1.0
    ) {
        collectDrawing(drawing, translate: translate, scale: scale, into: self)
    }

    public func collectFromDrawing(_ transformed: TransformedDrawing) {
        collectFromDrawing(
            transformed.source,
            translate: transformed.translate,
            scale: transformed.scale)
    }

    // MARK: - PDF 1.4 serialization

    public func write(to url: URL) throws {
        // Assemble objects as Data, tracking byte offsets for the xref table.
        var body = Data()
        var offsets: [Int] = [0]  // index 0 = free entry

        func newline() { body.append(0x0A) }
        func appendAscii(_ s: String) { body.append(s.data(using: .ascii) ?? Data()) }

        // Header: PDF-1.4 + binary marker comment.
        appendAscii("%PDF-1.4\n")
        body.append(contentsOf: [0x25, 0xE2, 0xE3, 0xCF, 0xD3])
        newline()

        func addObject(_ objectId: Int, body objectBody: String) {
            offsets.append(body.count)
            appendAscii("\(objectId) 0 obj\n\(objectBody)\nendobj\n")
        }

        addObject(1, body: "<< /Type /Catalog /Pages 2 0 R >>")
        addObject(2, body: "<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
        addObject(
            3,
            body: """
                << /Type /Page /Parent 2 0 R \
                /MediaBox [0 0 \(formatMM(pageSize.x)) \(formatMM(pageSize.y))] \
                /Contents 4 0 R \
                /Resources << /Font << /F1 5 0 R >> >> >>
                """.replacingOccurrences(of: "\n", with: ""))

        // Object 4: content stream.
        let content = buildContentStream()
        let contentData = content.data(using: .utf8) ?? Data()
        offsets.append(body.count)
        appendAscii("4 0 obj\n<< /Length \(contentData.count) >>\nstream\n")
        body.append(contentData)
        appendAscii("\nendstream\nendobj\n")

        addObject(
            5,
            body:
                "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")

        // xref table.
        let xrefOffset = body.count
        appendAscii("xref\n0 \(offsets.count)\n")
        appendAscii("0000000000 65535 f \n")
        for i in 1..<offsets.count {
            appendAscii(String(format: "%010d 00000 n \n", offsets[i]))
        }
        appendAscii(
            "trailer\n<< /Size \(offsets.count) /Root 1 0 R >>\nstartxref\n\(xrefOffset)\n%%EOF\n")

        do {
            try body.write(to: url)
        } catch {
            throw PDFError.writeFailed(error.localizedDescription)
        }
    }

    /// Build the content stream — this is the PDF painting program that
    /// renders all staged entities in layer order.
    private func buildContentStream() -> String {
        var s = ""
        // CTM: map mm → pts so all geometry/line widths/text heights stay in mm.
        let mmToPt = 72.0 / 25.4
        s += "q\n"
        s += "\(formatMM(mmToPt)) 0 0 \(formatMM(mmToPt)) 0 0 cm\n"
        s += "0 0 0 RG\n"

        // Group entities by layer so we can set linewidth + dash once per group.
        let groups: [(String, () -> String)] = [
            ("VISIBLE", { self.emitLayerGeometry(layer: "VISIBLE") }),
            ("OUTLINE", { self.emitLayerGeometry(layer: "OUTLINE") }),
            ("BORDER", { self.emitLayerGeometry(layer: "BORDER") }),
            ("TITLE", { self.emitLayerGeometry(layer: "TITLE") }),
            ("HIDDEN", { self.emitLayerGeometry(layer: "HIDDEN") }),
            ("CENTER", { self.emitLayerGeometry(layer: "CENTER") }),
            ("DIMENSION", { self.emitLayerGeometry(layer: "DIMENSION") }),
            ("HATCH", { self.emitLayerGeometry(layer: "HATCH") }),
            ("TEXT", { self.emitLayerText(layer: "TEXT") }),
        ]
        // Also emit text on any non-"TEXT" layer (e.g., TITLE labels).
        let nonTextLayers = [
            "VISIBLE", "OUTLINE", "BORDER", "TITLE",
            "HIDDEN", "CENTER", "DIMENSION", "HATCH",
        ]

        for (layer, emit) in groups {
            let geom = emit()
            if !geom.isEmpty {
                s += PDFWriter.stylePreamble(for: layer) + geom
            }
        }
        for layer in nonTextLayers {
            let txt = emitLayerText(layer: layer)
            if !txt.isEmpty {
                s += PDFWriter.stylePreamble(for: layer) + txt
            }
        }
        s += "Q\n"
        return s
    }

    private static func stylePreamble(for layer: String) -> String {
        let w = strokeWidthMM(for: layer)
        let dash = dashPattern(for: layer)
        return "\(formatMM(w)) w\n\(dash) d\n"
    }

    private static func dashPattern(for layer: String) -> String {
        guard let lengths = dashLengths(for: layer) else { return "[] 0" }
        return "[\(lengths.map(String.init).joined(separator: " "))] 0"
    }

    /// Emit all non-text geometry on a layer (lines + polylines + circles + arcs).
    private func emitLayerGeometry(layer: String) -> String {
        var s = ""
        for l in entityBuffer.lines where l.layer == layer {
            s +=
                "\(formatMM(l.a.x)) \(formatMM(l.a.y)) m \(formatMM(l.b.x)) \(formatMM(l.b.y)) l S\n"
        }
        for p in entityBuffer.polylines where p.layer == layer {
            guard let first = p.points.first else { continue }
            s += "\(formatMM(first.x)) \(formatMM(first.y)) m\n"
            for pt in p.points.dropFirst() {
                s += "\(formatMM(pt.x)) \(formatMM(pt.y)) l\n"
            }
            if p.closed { s += "h " }
            s += "S\n"
        }
        for c in entityBuffer.circles where c.layer == layer {
            s += PDFWriter.circlePath(centre: c.centre, radius: c.radius)
        }
        for a in entityBuffer.arcs where a.layer == layer {
            s += PDFWriter.arcPath(
                centre: a.centre, radius: a.radius,
                startDeg: a.startAngleDeg, endDeg: a.endAngleDeg)
        }
        return s
    }

    /// Text emission is separate because text uses the BT/ET operators.
    private func emitLayerText(layer: String) -> String {
        var s = ""
        for t in entityBuffer.texts where t.layer == layer {
            let rad = t.rotationDeg * .pi / 180
            let cosR = cos(rad)
            let sinR = sin(rad)
            let pdfString = PDFWriter.escapeString(t.text)
            s += "BT\n/F1 \(formatMM(t.height)) Tf\n"
            s +=
                "\(formatMM(cosR)) \(formatMM(sinR)) \(formatMM(-sinR)) \(formatMM(cosR)) \(formatMM(t.position.x)) \(formatMM(t.position.y)) Tm\n"
            s += "(\(pdfString)) Tj\nET\n"
        }
        return s
    }

    // MARK: - PDF path builders

    /// Four cubic Bézier segments approximating a full circle.
    private static func circlePath(centre: SIMD2<Double>, radius: Double) -> String {
        let k = 0.5522847498 * radius
        let cx = centre.x
        let cy = centre.y
        var s = "\(formatMM(cx + radius)) \(formatMM(cy)) m\n"
        s +=
            "\(formatMM(cx + radius)) \(formatMM(cy + k)) \(formatMM(cx + k)) \(formatMM(cy + radius)) \(formatMM(cx)) \(formatMM(cy + radius)) c\n"
        s +=
            "\(formatMM(cx - k)) \(formatMM(cy + radius)) \(formatMM(cx - radius)) \(formatMM(cy + k)) \(formatMM(cx - radius)) \(formatMM(cy)) c\n"
        s +=
            "\(formatMM(cx - radius)) \(formatMM(cy - k)) \(formatMM(cx - k)) \(formatMM(cy - radius)) \(formatMM(cx)) \(formatMM(cy - radius)) c\n"
        s +=
            "\(formatMM(cx + k)) \(formatMM(cy - radius)) \(formatMM(cx + radius)) \(formatMM(cy - k)) \(formatMM(cx + radius)) \(formatMM(cy)) c\n"
        s += "h S\n"
        return s
    }

    /// Arc from startDeg to endDeg, split into cubic-Bézier chunks of at
    /// most 90° each.
    private static func arcPath(
        centre: SIMD2<Double>, radius: Double,
        startDeg: Double, endDeg: Double
    ) -> String {
        let a0 = startDeg * .pi / 180
        let a1 = endDeg * .pi / 180
        let totalSpan = a1 - a0
        guard abs(totalSpan) > 1e-9 else { return "" }
        let direction: Double = totalSpan > 0 ? 1 : -1
        let chunkCount = max(1, Int(ceil(abs(totalSpan) / (.pi / 2))))
        let chunkAngle = totalSpan / Double(chunkCount)

        var s = ""
        var current = a0
        let startX = centre.x + radius * cos(current)
        let startY = centre.y + radius * sin(current)
        s += "\(formatMM(startX)) \(formatMM(startY)) m\n"
        for _ in 0..<chunkCount {
            let next = current + chunkAngle
            let halfAngle = chunkAngle / 2
            let kappa = 4.0 / 3.0 * tan(halfAngle / 2)
            // Control-point offsets along the tangent at current/next.
            let p0 = SIMD2(centre.x + radius * cos(current), centre.y + radius * sin(current))
            let p3 = SIMD2(centre.x + radius * cos(next), centre.y + radius * sin(next))
            let t0 = SIMD2(-sin(current), cos(current)) * radius * kappa * direction
            let t3 = SIMD2(-sin(next), cos(next)) * radius * kappa * direction
            let p1 = p0 + t0
            let p2 = p3 - t3
            s +=
                "\(formatMM(p1.x)) \(formatMM(p1.y)) \(formatMM(p2.x)) \(formatMM(p2.y)) \(formatMM(p3.x)) \(formatMM(p3.y)) c\n"
            current = next
        }
        s += "S\n"
        return s
    }

    private static func escapeString(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for c in s {
            switch c {
            case "(", ")", "\\":
                out.append("\\")
                out.append(c)
            case "\n": out.append("\\n")
            case "\r": out.append("\\r")
            case "\t": out.append("\\t")
            default: out.append(c)
            }
        }
        return out
    }
}
