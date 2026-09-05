import Foundation
import simd

// MARK: - DXF 2D export (#63)
//
// OCCT ships no DXF reader or writer. This is a pure-Swift implementation of the
// DXF R12 ASCII subset sufficient to round-trip 2D engineering drawings into
// LibreCAD / QCAD / AutoCAD. It covers LINE, CIRCLE, ARC, LWPOLYLINE, TEXT, and
// the DIMENSION entity (as exploded LINE/TEXT geometry — most consumers can
// read full DIMENSION entities but composing them correctly across implementations
// is finicky, and the exploded form is universally readable).
//
// Layers/linetypes follow technical-drawing convention:
//   VISIBLE   — solid
//   HIDDEN    — DASHED
//   OUTLINE   — solid
//   CENTER    — CHAIN (short-long pattern)
//   DIMENSION — solid
//   TEXT      — solid
//
// v1 renders non-line edges as LWPOLYLINEs from `Shape.allEdgePolylines`. Future
// iterations can emit CIRCLE/ARC/ELLIPSE natively once circle-centre/radius is
// wrapped for Edge.

public enum DXFError: Error, LocalizedError {
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .writeFailed(let msg): return "DXF write failed: \(msg)"
        }
    }
}

extension Exporter {
    /// Export a `Drawing` (HLR projection + optional dimensions/annotations) to DXF R12.
    public static func writeDXF(
        drawing: Drawing, to url: URL,
        deflection: Double = 0.1
    ) throws {
        let writer = DXFWriter(deflection: deflection)
        writer.collectFromDrawing(drawing)
        try writer.write(to: url)
    }

    /// Convenience: project the shape along `viewDirection` and export the projection as DXF.
    public static func writeDXF(
        shape: Shape, to url: URL,
        viewDirection: SIMD3<Double> = SIMD3(0, 0, 1),
        deflection: Double = 0.1
    ) throws {
        guard let drawing = Drawing.project(shape, direction: viewDirection) else {
            throw DXFError.writeFailed("projection failed")
        }
        try writeDXF(drawing: drawing, to: url, deflection: deflection)
    }
}

/// Pure-Swift DXF R12 ASCII writer.
///
/// Public so callers can stage entities manually (useful for tests and for scripts that compose DXFs from mixed sources).
public final class DXFWriter: @unchecked Sendable, DrawingPrimitiveSink, DrawingWriter {
    public let deflection: Double
    /// DrawingPrimitiveSink's shared entity storage -- see DrawingDispatch.swift.
    ///
    /// #1227.
    internal var entityBuffer = DrawingEntityBuffer()
    /// DrawingPrimitiveSink.primitiveOps()'s cache -- see DrawingDispatch.swift.
    ///
    internal var cachedPrimitiveOps: DrawingPrimitiveOps?

    public init(deflection: Double = 0.1) {
        self.deflection = deflection
    }

    // MARK: - Entity staging
    //
    // Each method forwards to `DrawingEntityBuffer`'s own staging logic (shared with
    // PDFWriter/SVGWriter, #1227); kept as an explicit per-writer `public func` rather than a
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

    /// Emit a single pre-built dimension as exploded LINE + TEXT entities.
    ///
    /// Useful for tests and for scripts that compose drawings from dimension values without going through a
    /// `Drawing`. Routes through the shared `DrawingDispatch.swift` dispatcher
    /// (`emitDimension`), the same as `PDFWriter`/`SVGWriter` -- see #795: this used to be a
    /// completely separate, independently hand-written pipeline (`emitLinear`/`emitRadial`/
    /// `emitDiameter`/`emitAngular`/`emitOrdinate`, plus its own `formatTolerance`/
    /// `TolerancedLabel`, byte-for-byte identical to `DrawingDispatch.swift`'s own private
    /// copies), kept apart out of caution that DXF's entities might need a different
    /// intermediate representation. They don't: `DXFWriter` already implements the same five
    /// primitives `PDFWriter`/`SVGWriter` route through `DrawingPrimitiveOps`, so it gets the
    /// identical dispatch for free.
    public func addDimension(_ d: DrawingDimension) {
        emitDimension(d, into: primitiveOps())
    }

    // MARK: - Collection from Drawing
    //
    // Both overloads forward to `DrawingDispatch.swift`'s shared `collectDrawing(...)` --
    // the same body `PDFWriter`/`SVGWriter` call. Annotation collection (centrelines,
    // centermarks, text labels, hatches, cutting-plane lines, balloons) goes through
    // `DrawingDispatch.swift`'s `emitAnnotation`, reached the same way -- previously DXF's
    // own `collectAnnotations`/`emitBalloon`/`emitCuttingPlaneLine`/`emitHatch`, the
    // identical logic calling `self.addX` directly instead of through the shared `ops`
    // bundle. #795.

    /// Collect a Drawing's edges, annotations and dimensions onto this writer.
    ///
    /// Translated and uniformly scaled -- the shared collection pipeline every 2D exporter (PDF, SVG, DXF) uses.
    public func collectFromDrawing(
        _ drawing: Drawing,
        translate: SIMD2<Double> = .zero,
        scale: Double = 1.0
    ) {
        collectDrawing(drawing, translate: translate, scale: scale, into: self)
    }

    /// Collect a `TransformedDrawing` onto this writer -- convenience for multi-view sheet
    /// composition.
    public func collectFromDrawing(_ transformed: TransformedDrawing) {
        collectFromDrawing(
            transformed.source,
            translate: transformed.translate,
            scale: transformed.scale)
    }

    // MARK: - Serialization

    public func write(to url: URL) throws {
        var out = ""
        out.reserveCapacity(8192)
        out += header()
        out += tables()
        out += blocks()
        out += entities()
        out += eof()
        do {
            try out.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw DXFError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - DXF sections

    private func pair(_ code: Int, _ value: String) -> String {
        "\(code)\n\(value)\n"
    }
    private func pair(_ code: Int, _ value: Double) -> String {
        pair(code, String(format: "%.6f", value))
    }
    private func pair(_ code: Int, _ value: Int) -> String {
        pair(code, "\(value)")
    }

    private func header() -> String {
        pair(0, "SECTION") + pair(2, "HEADER")
            + pair(9, "$ACADVER") + pair(1, "AC1009")
            + pair(9, "$INSUNITS") + pair(70, 4)  // mm
            + pair(0, "ENDSEC")
    }

    private func tables() -> String {
        var s = pair(0, "SECTION") + pair(2, "TABLES")

        // LTYPE
        s += pair(0, "TABLE") + pair(2, "LTYPE") + pair(70, 3)
        s +=
            pair(0, "LTYPE") + pair(2, "CONTINUOUS") + pair(70, 0) + pair(3, "Solid line")
            + pair(72, 65) + pair(73, 0) + pair(40, 0.0)
        s +=
            pair(0, "LTYPE") + pair(2, "DASHED") + pair(70, 0) + pair(3, "Dashed ____ ____ ____")
            + pair(72, 65) + pair(73, 2) + pair(40, 7.5)
            + pair(49, 5.0) + pair(49, -2.5)
        s +=
            pair(0, "LTYPE") + pair(2, "CHAIN") + pair(70, 0) + pair(3, "Chain ____ _ ____ _")
            + pair(72, 65) + pair(73, 4) + pair(40, 15.0)
            + pair(49, 10.0) + pair(49, -2.5) + pair(49, 0.0) + pair(49, -2.5)
        s += pair(0, "ENDTAB")

        // LAYER
        s += pair(0, "TABLE") + pair(2, "LAYER") + pair(70, 11)
        s += layer("0", colour: 7, linetype: "CONTINUOUS")
        s += layer("VISIBLE", colour: 7, linetype: "CONTINUOUS")
        s += layer("HIDDEN", colour: 8, linetype: "DASHED")
        s += layer("OUTLINE", colour: 7, linetype: "CONTINUOUS")
        s += layer("CENTER", colour: 1, linetype: "CHAIN")
        s += layer("DIMENSION", colour: 5, linetype: "CONTINUOUS")
        s += layer("TEXT", colour: 3, linetype: "CONTINUOUS")
        s += layer("HATCH", colour: 9, linetype: "CONTINUOUS")
        s += layer("SECTION", colour: 7, linetype: "CONTINUOUS")
        s += layer("BORDER", colour: 7, linetype: "CONTINUOUS")
        s += layer("TITLE", colour: 7, linetype: "CONTINUOUS")
        s += pair(0, "ENDTAB")

        // Required STYLE table (one default style)
        s += pair(0, "TABLE") + pair(2, "STYLE") + pair(70, 1)
        s +=
            pair(0, "STYLE") + pair(2, "STANDARD") + pair(70, 0) + pair(40, 0.0) + pair(41, 1.0)
            + pair(50, 0.0) + pair(71, 0) + pair(42, 2.5) + pair(3, "txt") + pair(4, "")
        s += pair(0, "ENDTAB")

        s += pair(0, "ENDSEC")
        return s
    }

    private func layer(_ name: String, colour: Int, linetype: String) -> String {
        pair(0, "LAYER") + pair(2, name) + pair(70, 0) + pair(62, colour) + pair(6, linetype)
    }

    private func blocks() -> String {
        // Empty BLOCKS section required by R12.
        pair(0, "SECTION") + pair(2, "BLOCKS") + pair(0, "ENDSEC")
    }

    private func entities() -> String {
        var s = pair(0, "SECTION") + pair(2, "ENTITIES")
        for l in entityBuffer.lines {
            s +=
                pair(0, "LINE") + pair(8, l.layer)
                + pair(10, l.a.x) + pair(20, l.a.y) + pair(30, 0.0)
                + pair(11, l.b.x) + pair(21, l.b.y) + pair(31, 0.0)
        }
        for p in entityBuffer.polylines {
            s +=
                pair(0, "LWPOLYLINE") + pair(8, p.layer)
                + pair(90, p.points.count) + pair(70, p.closed ? 1 : 0)
            for pt in p.points {
                s += pair(10, pt.x) + pair(20, pt.y)
            }
        }
        for c in entityBuffer.circles {
            s +=
                pair(0, "CIRCLE") + pair(8, c.layer)
                + pair(10, c.centre.x) + pair(20, c.centre.y) + pair(30, 0.0)
                + pair(40, c.radius)
        }
        for a in entityBuffer.arcs {
            s +=
                pair(0, "ARC") + pair(8, a.layer)
                + pair(10, a.centre.x) + pair(20, a.centre.y) + pair(30, 0.0)
                + pair(40, a.radius)
                + pair(50, a.startAngleDeg) + pair(51, a.endAngleDeg)
        }
        for t in entityBuffer.texts {
            s +=
                pair(0, "TEXT") + pair(8, t.layer)
                + pair(10, t.position.x) + pair(20, t.position.y) + pair(30, 0.0)
                + pair(40, t.height)
                + pair(1, t.text)
                + pair(50, t.rotationDeg)
        }
        s += pair(0, "ENDSEC")
        return s
    }

    private func eof() -> String {
        pair(0, "EOF")
    }

    // MARK: - Introspection (used by tests)

    public var entityCounts: (lines: Int, polylines: Int, circles: Int, arcs: Int, texts: Int) {
        entityBuffer.entityCounts
    }

    /// The staged arcs' start/end angles, in the order added.
    ///
    /// Lets a test check the actual sweep an annotation drew, not just that some arc was drawn.
    public var arcSweeps: [(startAngleDeg: Double, endAngleDeg: Double)] {
        entityBuffer.arcs.map { ($0.startAngleDeg, $0.endAngleDeg) }
    }
}
