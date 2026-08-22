import Foundation
import simd

// MARK: - Shared annotation + dimension dispatch (#85, v0.150; unified onto DXF, #795)
//
// DXFWriter used to carry its own inline dispatch for every annotation and dimension
// case (v0.148 and earlier), duplicated instead of shared when PDFWriter/SVGWriter were
// added in v0.150 out of caution — DXF's test coverage was load-bearing and a refactor
// risked regressions with no user-visible benefit (the original rationale for keeping it
// separate, recorded below until #795). The dispatch lives here as free functions that
// take a `DrawingPrimitiveOps` closure bundle; any writer implementing the five 2D
// primitives (addLine, addPolyline, addCircle, addArc, addText) gets full annotation +
// dimension rendering for free.
//
// #795 found that DXFWriter's inline copy had drifted into being the SAME logic, not a
// different one: `formatTolerance`/`TolerancedLabel` were byte-for-byte identical to this
// file's own (private) copies, and DXF's `emitLinear`/`emitRadial`/`emitDiameter`/
// `emitAngular`/`emitOrdinate`/`collectAnnotations`/`emitBalloon`/`emitCuttingPlaneLine`/
// `emitHatch` were the identical logic as this file's `emitDimension`/`emitAnnotation`
// family, just calling `self.addLine(from:to:layer:)` etc. directly instead of through an
// `ops` closure bundle — DXFWriter already implements the same five primitives PDF/SVG do,
// so the "different intermediate representation" concern that justified keeping DXF
// separate never actually applied. Golden-output tests
// (`Tests/OCCTIOTests/OCCTIOTests.swift`, `ExporterDrawingCollectionGoldenTests`) proved
// the unification byte-identical before it was made permanent.
//
// `DrawingPrimitiveSink` is the shared conformance: any writer holding the five staging
// methods gets `primitiveOps()` for free. `collectFromDrawing` stays an explicit `public`
// declaration on each writer (so it keeps documenting and dispatching exactly where it
// always did) but its body is one call into this file's shared `collectDrawing(...)`,
// removing the need for each writer to hand-roll its own copy of the collection loop.

internal struct DrawingPrimitiveOps {
    let addLine: (SIMD2<Double>, SIMD2<Double>, String) -> Void
    let addPolyline: ([SIMD2<Double>], Bool, String) -> Void
    let addCircle: (SIMD2<Double>, Double, String) -> Void
    let addArc: (SIMD2<Double>, Double, Double, Double, String) -> Void
    let addText: (String, SIMD2<Double>, Double, Double, String) -> Void
}

/// A writer that can stage the five 2D drawing primitives PDF, SVG and DXF all
/// understand. Conforming gets `primitiveOps()` via the default implementation below —
/// each writer keeps its own explicit `public func collectFromDrawing` (so the public
/// declaration a consumer sees, and `docs/reference/Export-Vector.md` documents, still
/// lives in `PDFExporter.swift`/`SVGExporter.swift`/`DXFExporter.swift` exactly as before),
/// but its BODY is one call into this file's shared `collectDrawing(...)`. #795.
internal protocol DrawingPrimitiveSink: AnyObject {
    var deflection: Double { get }
    /// Backing storage for `primitiveOps()`'s cache. `nil` until first use; each writer
    /// declares this as a plain stored `var` starting `nil`. #800 review: without this, every
    /// call to `addDimension`/`collectFromDrawing` allocated a fresh 5-closure
    /// `DrawingPrimitiveOps`, which matters for `addDimension`'s documented loop-of-many-calls
    /// use case (composing a DXF from dimension values without going through a `Drawing`).
    var cachedPrimitiveOps: DrawingPrimitiveOps? { get set }
    func addLine(from a: SIMD2<Double>, to b: SIMD2<Double>, layer: String)
    func addPolyline(_ points: [SIMD2<Double>], closed: Bool, layer: String)
    func addCircle(centre: SIMD2<Double>, radius: Double, layer: String)
    func addArc(
        centre: SIMD2<Double>, radius: Double,
        startAngleDeg: Double, endAngleDeg: Double, layer: String)
    func addText(
        _ text: String, at position: SIMD2<Double>,
        height: Double, rotationDeg: Double, layer: String)
}

extension DrawingPrimitiveSink {
    /// Ops closure bundle wrapping this sink's own staging methods, for the shared
    /// annotation/dimension dispatchers below. Built once per instance and cached rather
    /// than reallocated on every call (#800 review).
    func primitiveOps() -> DrawingPrimitiveOps {
        if let cached = cachedPrimitiveOps { return cached }
        let built = DrawingPrimitiveOps(
            addLine: { [weak self] a, b, layer in self?.addLine(from: a, to: b, layer: layer) },
            addPolyline: { [weak self] pts, closed, layer in
                self?.addPolyline(pts, closed: closed, layer: layer)
            },
            addCircle: { [weak self] c, r, layer in
                self?.addCircle(centre: c, radius: r, layer: layer)
            },
            addArc: { [weak self] c, r, sDeg, eDeg, layer in
                self?.addArc(
                    centre: c, radius: r, startAngleDeg: sDeg, endAngleDeg: eDeg, layer: layer)
            },
            addText: { [weak self] txt, pos, h, rot, layer in
                self?.addText(txt, at: pos, height: h, rotationDeg: rot, layer: layer)
            }
        )
        cachedPrimitiveOps = built
        return built
    }
}

/// Stage every edge/annotation/dimension from `drawing` onto `sink`, optionally translated
/// and uniformly scaled — the shared collection pipeline every 2D exporter (PDF, SVG, DXF)
/// uses. Each writer's own `public func collectFromDrawing` is a one-line call into this;
/// kept as a free function (not a `DrawingPrimitiveSink` default method) precisely so each
/// writer keeps an explicit `public` declaration of its own — an `internal` protocol's
/// extension methods are not reliably part of a conforming `public` type's visible API
/// from outside the module, and `docs/reference/Export-Vector.md` documents this method
/// once per writer, resolved by which `.swift` file declares it. #795.
internal func collectDrawing(
    _ drawing: Drawing,
    translate: SIMD2<Double>,
    scale: Double,
    into sink: DrawingPrimitiveSink
) {
    // Edges are the highest-volume primitive stream (one call per tessellated segment), so
    // they go straight to `sink`'s own methods -- no closure indirection. #800 review.
    collectProjectedEdges(
        drawing.visibleEdges, layer: "VISIBLE",
        translate: translate, scale: scale,
        deflection: sink.deflection, into: sink)
    collectProjectedEdges(
        drawing.hiddenEdges, layer: "HIDDEN",
        translate: translate, scale: scale,
        deflection: sink.deflection, into: sink)
    collectProjectedEdges(
        drawing.outlineEdges, layer: "OUTLINE",
        translate: translate, scale: scale,
        deflection: sink.deflection, into: sink)
    // Annotations/dimensions are comparatively low-volume and their dispatchers need to stay
    // format-agnostic (shared with `addDimension`'s single-value entry point), so they go
    // through the (now-cached) closure bundle.
    let ops = sink.primitiveOps()
    for a in drawing.annotations {
        let t =
            (translate == .zero && scale == 1.0)
            ? a : a.transformed(translate: translate, scale: scale)
        emitAnnotation(t, into: ops)
    }
    for d in drawing.dimensions {
        let t =
            (translate == .zero && scale == 1.0)
            ? d : d.transformed(translate: translate, scale: scale)
        emitDimension(t, into: ops)
    }
}

/// Tessellate `compound`'s edges (via `allEdgePolylines`) and stage each resulting
/// polyline as a line (2-point case) or polyline, translated/scaled, on `layer`, calling
/// `sink`'s own `addLine`/`addPolyline` directly (no `DrawingPrimitiveOps` closure
/// indirection: this runs once per tessellated segment, the highest-volume primitive stream
/// in a drawing, #800 review). Shared by every `collectDrawing` call for the
/// visible/hidden/outline edge passes — previously three (PDF/SVG/DXF) independently
/// hand-written copies of the identical loop. #795.
private func collectProjectedEdges(
    _ compound: Shape?, layer: String,
    translate: SIMD2<Double>, scale: Double,
    deflection: Double, into sink: DrawingPrimitiveSink
) {
    guard let compound else { return }
    let polys = compound.allEdgePolylines(deflection: deflection)
    func t(_ p: SIMD2<Double>) -> SIMD2<Double> { scale * p + translate }
    for poly in polys {
        guard poly.count >= 2 else { continue }
        let points2D = poly.map { t(SIMD2($0.x, $0.y)) }
        if points2D.count == 2 {
            sink.addLine(from: points2D[0], to: points2D[1], layer: layer)
        } else {
            sink.addPolyline(points2D, closed: false, layer: layer)
        }
    }
}

/// Per-layer stroke weight (mm) per ISO 128-20, shared by PDF and SVG — the two formats
/// whose stroke widths are specified in the same physical unit their content streams are
/// scaled to (PDF's CTM maps mm -> pt before any `w` operator; SVG's viewBox is 1:1 with
/// the staged mm coordinates). DXF has no equivalent concept (colour + linetype per layer,
/// no per-entity line weight), so it is not part of this table. #795.
internal func strokeWidthMM(for layer: String) -> Double {
    switch layer {
    case "VISIBLE", "OUTLINE", "BORDER", "TITLE": return 0.5
    case "HIDDEN", "CENTER", "DIMENSION", "TEXT": return 0.25
    case "HATCH": return 0.18
    default: return 0.25
    }
}

/// Shared PDF/SVG coordinate/length formatting (4 decimal places). DXF formats numbers
/// separately (`%.6f`, via its own `pair(_:_:)` helper) so is not part of this. #795.
internal func formatMM(_ v: Double) -> String {
    String(format: "%.4f", v)
}

// MARK: - Annotation dispatch

internal func emitAnnotation(_ a: DrawingAnnotation, into ops: DrawingPrimitiveOps) {
    switch a {
    case .centreline(let c):
        ops.addLine(c.from, c.to, "CENTER")
    case .centermark(let m):
        let h = m.extent / 2
        ops.addLine(
            SIMD2(m.centre.x - h, m.centre.y),
            SIMD2(m.centre.x + h, m.centre.y), "CENTER")
        ops.addLine(
            SIMD2(m.centre.x, m.centre.y - h),
            SIMD2(m.centre.x, m.centre.y + h), "CENTER")
    case .textLabel(let t):
        ops.addText(t.text, t.position, t.height, t.rotation * 180 / .pi, "TEXT")
    case .hatch(let h):
        emitHatch(h, into: ops)
    case .cuttingPlaneLine(let cpl):
        emitCuttingPlaneLine(cpl, into: ops)
    case .balloon(let b):
        emitBalloon(b, into: ops)
    }
}

private func emitBalloon(_ b: DrawingAnnotation.Balloon, into ops: DrawingPrimitiveOps) {
    ops.addCircle(b.centre, b.radius, "DIMENSION")
    ops.addText(String(b.itemNumber), b.centre, b.radius * 0.9, 0, "TEXT")
    if let target = b.leaderTo {
        let dir = target - b.centre
        let len = simd_length(dir)
        if len > 1e-9 {
            let exit = b.centre + (dir / len) * b.radius
            ops.addLine(exit, target, "DIMENSION")
        }
    }
}

private func emitCuttingPlaneLine(
    _ cpl: DrawingAnnotation.CuttingPlaneLine,
    into ops: DrawingPrimitiveOps
) {
    let start = cpl.traceStart
    let end = cpl.traceEnd
    let traceDir = end - start
    let traceLen = simd_length(traceDir)
    guard traceLen > 1e-6 else { return }
    let u = traceDir / traceLen
    let heavyLen = min(10.0, traceLen * 0.2)
    let heavyEndA = start + u * heavyLen
    let heavyEndB = end - u * heavyLen

    ops.addLine(start, heavyEndA, "CENTER")
    ops.addLine(heavyEndB, end, "CENTER")
    ops.addLine(heavyEndA, heavyEndB, "CENTER")

    let a = cpl.arrowDirection
    let arrowLen = 8.0
    let arrowWidth = 3.0
    let perp = SIMD2(-a.y, a.x)
    func arrow(at p: SIMD2<Double>) {
        let tip = p + a * arrowLen
        let base1 = tip - a * arrowLen * 0.4 + perp * arrowWidth / 2
        let base2 = tip - a * arrowLen * 0.4 - perp * arrowWidth / 2
        ops.addLine(p, tip, "TEXT")
        ops.addLine(tip, base1, "TEXT")
        ops.addLine(tip, base2, "TEXT")
    }
    arrow(at: start)
    arrow(at: end)

    let labelOffset = arrowLen + 4.0
    ops.addText(cpl.label, start + a * labelOffset, 5.0, 0, "TEXT")
    ops.addText(cpl.label, end + a * labelOffset, 5.0, 0, "TEXT")
}

private func emitHatch(_ h: DrawingAnnotation.Hatch, into ops: DrawingPrimitiveOps) {
    guard h.boundary.count >= 3, h.spacing > 0 else { return }
    let cosA = cos(-h.angle)
    let sinA = sin(-h.angle)
    func rotateForward(_ p: SIMD2<Double>) -> SIMD2<Double> {
        SIMD2(cosA * p.x - sinA * p.y, sinA * p.x + cosA * p.y)
    }
    let cosB = cos(h.angle)
    let sinB = sin(h.angle)
    func rotateBack(_ p: SIMD2<Double>) -> SIMD2<Double> {
        SIMD2(cosB * p.x - sinB * p.y, sinB * p.x + cosB * p.y)
    }
    var segments: [(SIMD2<Double>, SIMD2<Double>)] = []
    func addPolygonSegments(_ poly: [SIMD2<Double>]) {
        guard poly.count >= 2 else { return }
        let rotated = poly.map(rotateForward)
        for i in 0..<rotated.count {
            let j = (i + 1) % rotated.count
            segments.append((rotated[i], rotated[j]))
        }
    }
    addPolygonSegments(h.boundary)
    for island in h.islands { addPolygonSegments(island) }
    var minY = Double.infinity
    var maxY = -Double.infinity
    for s in segments {
        minY = min(minY, s.0.y, s.1.y)
        maxY = max(maxY, s.0.y, s.1.y)
    }
    guard minY.isFinite else { return }
    var y = ceil(minY / h.spacing) * h.spacing
    while y < maxY {
        var xs: [Double] = []
        for s in segments {
            let (p, q) = s
            if abs(p.y - q.y) < 1e-12 { continue }
            let minSeg = min(p.y, q.y)
            let maxSeg = max(p.y, q.y)
            if y < minSeg || y >= maxSeg { continue }
            let t = (y - p.y) / (q.y - p.y)
            xs.append(p.x + t * (q.x - p.x))
        }
        xs.sort()
        var i = 0
        while i + 1 < xs.count {
            let p0 = rotateBack(SIMD2(xs[i], y))
            let p1 = rotateBack(SIMD2(xs[i + 1], y))
            ops.addLine(p0, p1, h.layer)
            i += 2
        }
        y += h.spacing
    }
}

// MARK: - Dimension dispatch (with tolerance rendering)

internal func emitDimension(_ d: DrawingDimension, into ops: DrawingPrimitiveOps) {
    switch d {
    case .linear(let lin): emitLinear(lin, into: ops)
    case .radial(let rad): emitRadial(rad, into: ops)
    case .diameter(let dia): emitDiameter(dia, into: ops)
    case .angular(let ang): emitAngular(ang, into: ops)
    case .ordinate(let ord): emitOrdinate(ord, into: ops)
    }
}

private struct TolerancedLabel {
    let main: String
    let upper: String?
    let lower: String?
}

private func formatTolerance(base: String, tolerance: DrawingTolerance) -> TolerancedLabel {
    switch tolerance {
    case .none:
        return TolerancedLabel(main: base, upper: nil, lower: nil)
    case .symmetric(let v):
        return TolerancedLabel(
            main: base + " ±" + String(format: "%.3f", v),
            upper: nil, lower: nil)
    case .fitClass(let s):
        return TolerancedLabel(main: base + " " + s, upper: nil, lower: nil)
    case .bilateral(let plus, let minus):
        return TolerancedLabel(
            main: base,
            upper: "+" + String(format: "%.3f", plus),
            lower: "-" + String(format: "%.3f", minus))
    case .unilateral(let v):
        if v >= 0 {
            return TolerancedLabel(
                main: base,
                upper: "+" + String(format: "%.3f", v),
                lower: "0")
        } else {
            return TolerancedLabel(
                main: base,
                upper: "0",
                lower: String(format: "%.3f", v))
        }
    case .limits(let lower, let upper):
        return TolerancedLabel(
            main: base,
            upper: String(format: "%.3f", upper),
            lower: String(format: "%.3f", lower))
    }
}

private func emitTolerancedText(
    _ parts: TolerancedLabel,
    at position: SIMD2<Double>,
    height: Double,
    rotationDeg: Double,
    stackOffset: SIMD2<Double>,
    into ops: DrawingPrimitiveOps
) {
    ops.addText(parts.main, position, height, rotationDeg, "TEXT")
    let small = height * 0.55
    if let u = parts.upper {
        ops.addText(u, position + stackOffset, small, rotationDeg, "TEXT")
    }
    if let l = parts.lower {
        ops.addText(l, position - stackOffset, small, rotationDeg, "TEXT")
    }
}

private func emitLinear(_ d: DrawingDimension.Linear, into ops: DrawingPrimitiveOps) {
    let dir = simd_normalize(d.to - d.from)
    let perp = SIMD2<Double>(-dir.y, dir.x)
    let from2 = d.from + perp * d.offset
    let to2 = d.to + perp * d.offset
    ops.addLine(d.from, from2, "DIMENSION")
    ops.addLine(d.to, to2, "DIMENSION")
    ops.addLine(from2, to2, "DIMENSION")
    let mid = (from2 + to2) / 2
    let base = d.label ?? String(format: "%.2f", d.value)
    let rotDeg = atan2(dir.y, dir.x) * 180 / .pi
    let parts = formatTolerance(base: base, tolerance: d.tolerance)
    emitTolerancedText(
        parts, at: mid + perp * 2, height: 3.5,
        rotationDeg: rotDeg, stackOffset: perp * 2.0, into: ops)
}

private func emitRadial(_ d: DrawingDimension.Radial, into ops: DrawingPrimitiveOps) {
    let endOnCircle = SIMD2(
        d.centre.x + d.radius * cos(d.leaderAngle),
        d.centre.y + d.radius * sin(d.leaderAngle))
    let leaderTip = SIMD2(
        d.centre.x + (d.radius + 10) * cos(d.leaderAngle),
        d.centre.y + (d.radius + 10) * sin(d.leaderAngle))
    ops.addCircle(d.centre, d.radius, "DIMENSION")
    ops.addLine(endOnCircle, leaderTip, "DIMENSION")
    let base = d.label ?? String(format: "R%.2f", d.value)
    let parts = formatTolerance(base: base, tolerance: d.tolerance)
    let perp = SIMD2(-sin(d.leaderAngle), cos(d.leaderAngle))
    emitTolerancedText(
        parts, at: leaderTip, height: 3.5, rotationDeg: 0,
        stackOffset: perp * 2.0, into: ops)
}

private func emitDiameter(_ d: DrawingDimension.Diameter, into ops: DrawingPrimitiveOps) {
    let cos_ = cos(d.leaderAngle)
    let sin_ = sin(d.leaderAngle)
    let pA = SIMD2(d.centre.x - d.radius * cos_, d.centre.y - d.radius * sin_)
    let pB = SIMD2(d.centre.x + d.radius * cos_, d.centre.y + d.radius * sin_)
    ops.addLine(pA, pB, "DIMENSION")
    let tip = SIMD2(pB.x + 5 * cos_, pB.y + 5 * sin_)
    let base = d.label ?? String(format: "⌀%.2f", d.value)
    let parts = formatTolerance(base: base, tolerance: d.tolerance)
    let perp = SIMD2(-sin_, cos_)
    emitTolerancedText(
        parts, at: tip, height: 3.5, rotationDeg: 0,
        stackOffset: perp * 2.0, into: ops)
}

private func emitAngular(_ d: DrawingDimension.Angular, into ops: DrawingPrimitiveOps) {
    let v1 = simd_normalize(d.ray1 - d.vertex)
    let v2 = simd_normalize(d.ray2 - d.vertex)
    let a1 = atan2(v1.y, v1.x)
    let a2 = atan2(v2.y, v2.x)
    var start = a1
    var end = a2
    if end < start { swap(&start, &end) }
    ops.addArc(d.vertex, d.arcRadius, start * 180 / .pi, end * 180 / .pi, "DIMENSION")
    let midAngle = (start + end) / 2
    let textPos = SIMD2(
        d.vertex.x + (d.arcRadius + 3) * cos(midAngle),
        d.vertex.y + (d.arcRadius + 3) * sin(midAngle))
    let base = d.label ?? String(format: "%.1f°", d.value * 180 / .pi)
    let parts = formatTolerance(base: base, tolerance: d.tolerance)
    let radial = SIMD2(cos(midAngle), sin(midAngle))
    emitTolerancedText(
        parts, at: textPos, height: 3.5, rotationDeg: 0,
        stackOffset: radial * 2.0, into: ops)
}

private func emitOrdinate(_ d: DrawingDimension.Ordinate, into ops: DrawingPrimitiveOps) {
    let crossExtent = 3.0
    ops.addLine(
        SIMD2(d.origin.x - crossExtent, d.origin.y),
        SIMD2(d.origin.x + crossExtent, d.origin.y), "DIMENSION")
    ops.addLine(
        SIMD2(d.origin.x, d.origin.y - crossExtent),
        SIMD2(d.origin.x, d.origin.y + crossExtent), "DIMENSION")

    let tickLen = 2.0
    for feature in d.features {
        let dx = feature.position.x - d.origin.x
        let dy = feature.position.y - d.origin.y

        if dx != 0 {
            ops.addLine(
                SIMD2(feature.position.x, d.origin.y),
                SIMD2(feature.position.x, feature.position.y), "DIMENSION")
            ops.addLine(
                SIMD2(feature.position.x, d.origin.y - tickLen),
                SIMD2(feature.position.x, d.origin.y + tickLen), "DIMENSION")
            let xBase = feature.label ?? String(format: "%.2f", dx)
            let xParts = formatTolerance(base: xBase, tolerance: d.tolerance)
            emitTolerancedText(
                xParts,
                at: SIMD2(feature.position.x, d.origin.y - 5),
                height: 3.5, rotationDeg: 90,
                stackOffset: SIMD2(2.0, 0), into: ops)
        }
        if dy != 0 {
            ops.addLine(
                SIMD2(d.origin.x, feature.position.y),
                SIMD2(feature.position.x, feature.position.y), "DIMENSION")
            ops.addLine(
                SIMD2(d.origin.x - tickLen, feature.position.y),
                SIMD2(d.origin.x + tickLen, feature.position.y), "DIMENSION")
            let yBase = feature.label ?? String(format: "%.2f", dy)
            let yParts = formatTolerance(base: yBase, tolerance: d.tolerance)
            emitTolerancedText(
                yParts,
                at: SIMD2(d.origin.x - 5, feature.position.y),
                height: 3.5, rotationDeg: 0,
                stackOffset: SIMD2(0, 2.0), into: ops)
        }
    }
}
