import Foundation
import simd

// MARK: - SVG export (#86, v0.150)
//
// Pure-Swift SVG 1.1 writer. SVG is the target for the web: browser-viewable,
// Inkscape-editable, vector-clean. One `<g>` group per layer, per-layer stroke
// width and dash pattern per ISO 128-20.
//
// Coordinate handling: drawings use mathematical Y (up), SVG uses screen Y
// (down). The writer wraps all content in a group with `transform="scale(1,-1)
// translate(0, -viewBoxMaxY)"` to keep the staged mm coordinates sensible.
// Text is handled specially — the y-flip would mirror glyphs, so each `<text>`
// gets its own counter-transform.

public enum SVGError: Error, LocalizedError {
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .writeFailed(let msg): return "SVG write failed: \(msg)"
        }
    }
}

extension Exporter {
    public static func writeSVG(
        drawing: Drawing, to url: URL,
        deflection: Double = 0.1
    ) throws {
        let writer = SVGWriter(deflection: deflection)
        writer.collectFromDrawing(drawing)
        try writer.write(to: url)
    }

    public static func writeSVG(
        sheet: Sheet, body: (SVGWriter) -> Void,
        to url: URL,
        deflection: Double = 0.1
    ) throws {
        let dim = sheet.dimensions
        let writer = SVGWriter(
            viewBox: (min: .zero, size: dim),
            deflection: deflection)
        body(writer)
        try writer.write(to: url)
    }
}

public final class SVGWriter: @unchecked Sendable, DrawingPrimitiveSink {
    /// Explicit viewBox override.
    ///
    /// When nil, the writer computes the viewBox from the staged content's bounding box at `write(to:)` time.
    public var viewBox: (min: SIMD2<Double>, size: SIMD2<Double>)?
    public let deflection: Double

    /// DrawingPrimitiveSink's shared entity storage -- see DrawingDispatch.swift.
    ///
    /// #1227.
    internal var entityBuffer = DrawingEntityBuffer()
    /// DrawingPrimitiveSink.primitiveOps()'s cache -- see DrawingDispatch.swift.
    ///
    internal var cachedPrimitiveOps: DrawingPrimitiveOps?

    public init(
        viewBox: (min: SIMD2<Double>, size: SIMD2<Double>)? = nil,
        deflection: Double = 0.1
    ) {
        self.viewBox = viewBox
        self.deflection = deflection
    }

    // MARK: - Entity staging
    //
    // Each method forwards to `DrawingEntityBuffer`'s own staging logic (shared with
    // DXFWriter/PDFWriter, #1227); kept as an explicit per-writer `public func` rather than a
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

    // MARK: - SVG serialization

    public func write(to url: URL) throws {
        let vb = viewBox ?? computedViewBox()
        var s = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        s += "<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\" "
        s +=
            "viewBox=\"\(formatMM(vb.min.x)) \(formatMM(vb.min.y)) \(formatMM(vb.size.x)) \(formatMM(vb.size.y))\" "
        s += "width=\"\(formatMM(vb.size.x))mm\" height=\"\(formatMM(vb.size.y))mm\">\n"
        // Flip Y so drawing-space mathematical Y (up) maps to SVG screen Y (down).
        s += "<g transform=\"translate(0,\(formatMM(vb.min.y + vb.size.y))) scale(1,-1)\">\n"

        let layerOrder = [
            "VISIBLE", "OUTLINE", "BORDER", "TITLE",
            "HIDDEN", "CENTER", "DIMENSION", "HATCH", "TEXT",
        ]
        for layer in layerOrder {
            let chunks =
                emitLayerGeometry(layer: layer)
                + emitLayerText(layer: layer)
            if !chunks.isEmpty {
                let strokeWidth = strokeWidthMM(for: layer)
                let dash = SVGWriter.dashPattern(for: layer)
                var groupAttrs =
                    "stroke=\"black\" stroke-width=\"\(formatMM(strokeWidth))\" fill=\"none\""
                if !dash.isEmpty { groupAttrs += " stroke-dasharray=\"\(dash)\"" }
                s += "<g id=\"\(layer)\" \(groupAttrs)>\n\(chunks)</g>\n"
            }
        }
        s += "</g>\n</svg>\n"
        do {
            try s.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw SVGError.writeFailed(error.localizedDescription)
        }
    }

    private func computedViewBox() -> (min: SIMD2<Double>, size: SIMD2<Double>) {
        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity
        func extend(_ p: SIMD2<Double>) {
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }
        for l in entityBuffer.lines {
            extend(l.a)
            extend(l.b)
        }
        for p in entityBuffer.polylines { for pt in p.points { extend(pt) } }
        for c in entityBuffer.circles {
            extend(SIMD2(c.centre.x - c.radius, c.centre.y - c.radius))
            extend(SIMD2(c.centre.x + c.radius, c.centre.y + c.radius))
        }
        for a in entityBuffer.arcs {
            extend(SIMD2(a.centre.x - a.radius, a.centre.y - a.radius))
            extend(SIMD2(a.centre.x + a.radius, a.centre.y + a.radius))
        }
        for t in entityBuffer.texts { extend(t.position) }
        guard minX.isFinite else { return (min: .zero, size: SIMD2(100, 100)) }
        let pad = 5.0
        return (
            min: SIMD2(minX - pad, minY - pad),
            size: SIMD2((maxX - minX) + 2 * pad, (maxY - minY) + 2 * pad)
        )
    }

    private func emitLayerGeometry(layer: String) -> String {
        var s = ""
        for l in entityBuffer.lines where l.layer == layer {
            s +=
                "<line x1=\"\(formatMM(l.a.x))\" y1=\"\(formatMM(l.a.y))\" x2=\"\(formatMM(l.b.x))\" y2=\"\(formatMM(l.b.y))\"/>\n"
        }
        for p in entityBuffer.polylines where p.layer == layer {
            let pts = p.points.map { "\(formatMM($0.x)),\(formatMM($0.y))" }.joined(separator: " ")
            if p.closed {
                s += "<polygon points=\"\(pts)\"/>\n"
            } else {
                s += "<polyline points=\"\(pts)\"/>\n"
            }
        }
        for c in entityBuffer.circles where c.layer == layer {
            s +=
                "<circle cx=\"\(formatMM(c.centre.x))\" cy=\"\(formatMM(c.centre.y))\" r=\"\(formatMM(c.radius))\"/>\n"
        }
        for a in entityBuffer.arcs where a.layer == layer {
            s += svgArcPath(
                centre: a.centre, radius: a.radius,
                startDeg: a.startAngleDeg, endDeg: a.endAngleDeg)
        }
        return s
    }

    private func emitLayerText(layer: String) -> String {
        var s = ""
        for t in entityBuffer.texts where t.layer == layer {
            // Counter-flip the group's Y-flip so text reads right-side up.
            let rot = formatMM(-t.rotationDeg)
            let x = formatMM(t.position.x)
            let y = formatMM(t.position.y)
            // Negate the NUMBER, then format -- not the other way around. Prefixing a literal
            // "-" onto an already-formatted string doubles up for a negative coordinate
            // (e.g. y = -10 would print "--10.0000", which is not a valid SVG number: #800 review).
            let negX = formatMM(-t.position.x)
            let negY = formatMM(-t.position.y)
            let escaped = SVGWriter.escapeXML(t.text)
            s += "<text x=\"\(x)\" y=\"\(y)\" font-family=\"Helvetica\" "
            s += "font-size=\"\(formatMM(t.height))\" "
            s +=
                "transform=\"matrix(1,0,0,-1,0,0) translate(\(x),\(negY)) rotate(\(rot)) translate(\(negX),\(y))\" "
            s += "fill=\"black\" stroke=\"none\">\(escaped)</text>\n"
        }
        return s
    }

    private func svgArcPath(
        centre: SIMD2<Double>, radius: Double,
        startDeg: Double, endDeg: Double
    ) -> String {
        let a0 = startDeg * .pi / 180
        let a1 = endDeg * .pi / 180
        let start = SIMD2(centre.x + radius * cos(a0), centre.y + radius * sin(a0))
        let end = SIMD2(centre.x + radius * cos(a1), centre.y + radius * sin(a1))
        let span = a1 - a0
        let largeArc = abs(span) > .pi ? 1 : 0
        // sweep-flag: 1 = positive-angle (CCW) in user coordinate, but the
        // containing group has scale(1,-1), so CCW in math-Y maps to CW in
        // screen-Y. SVG's "positive angle" is CW in screen-Y; setting sweep
        // to `span > 0 ? 1 : 0` gives the expected visual result.
        let sweep = span > 0 ? 1 : 0
        return
            "<path d=\"M \(formatMM(start.x)) \(formatMM(start.y)) A \(formatMM(radius)) \(formatMM(radius)) 0 \(largeArc) \(sweep) \(formatMM(end.x)) \(formatMM(end.y))\"/>\n"
    }

    private static func dashPattern(for layer: String) -> String {
        switch layer {
        case "HIDDEN": return "3,2"
        case "CENTER": return "8,2,2,2"
        default: return ""
        }
    }

    private static func escapeXML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
