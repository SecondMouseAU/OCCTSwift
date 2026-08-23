import Foundation
import simd

// MARK: - ISO 1302 surface finish + ISO 1101 GD&T + detail views + break lines (v0.146)

// MARK: - Surface finish (ISO 1302)

/// ISO 1302 surface-texture symbol type.
public enum SurfaceFinishSymbol: String, Sendable, Hashable, Codable {
    /// Any method permitted (basic check-mark V).
    case any
    /// Machining required (V with bar across the top).
    case machiningRequired
    /// Machining prohibited (V with a circle in the apex).
    case machiningProhibited
}

extension DrawingAnnotation {
    /// ISO 1302 surface finish annotation: a check-mark style symbol with Ra
    /// value, a leader line pointing at the feature, and an optional.
    /// production-method text block.
    public static func surfaceFinish(
        at position: SIMD2<Double>,
        leaderTo target: SIMD2<Double>,
        ra: Double,
        symbol: SurfaceFinishSymbol = .machiningRequired,
        method: String? = nil
    ) -> [DrawingAnnotation] {
        // Encode as pre-computed primitive annotations:
        //   - three lines forming the check-mark
        //   - optional bar across the top for machiningRequired
        //   - optional circle in apex for machiningProhibited
        //   - text label with the Ra value above the horizontal bar
        //   - leader line to target
        //   - optional method text
        //
        // Geometry: the symbol is 8×10 mm, apex at `position`, check opens upward.
        let apex = position
        let size = 8.0
        let height = 10.0
        let leftTop = SIMD2(apex.x - size / 2, apex.y + height)
        let rightTop = SIMD2(apex.x + size / 2, apex.y + height)

        var result: [DrawingAnnotation] = [
            // Long arm of the check
            .centreline(
                .init(
                    from: apex, to: rightTop, style: .solid,
                    id: "surface-finish-right")),
            // Short arm
            .centreline(
                .init(
                    from: apex, to: leftTop, style: .solid,
                    id: "surface-finish-left")),
        ]

        switch symbol {
        case .any: break
        case .machiningRequired:
            // Horizontal bar connecting the tops
            result.append(.centreline(.init(from: leftTop, to: rightTop, style: .solid)))
        case .machiningProhibited:
            // Circle in apex
            let r = 2.0
            // Render as a polyline approximation
            let segments = 24
            var pts: [SIMD2<Double>] = []
            for i in 0...segments {
                let t = Double(i) * 2 * .pi / Double(segments)
                pts.append(SIMD2(apex.x + r * cos(t), apex.y + r + r * sin(t)))
            }
            // Emit as text label for simplicity (consumers can swap for a real arc)
            result.append(
                .textLabel(
                    .init(
                        position: SIMD2(apex.x, apex.y + r),
                        text: "O", height: 3)))
        }

        // Ra value above the bar
        let raLabel = String(format: "Ra %.2f", ra)
        result.append(
            .textLabel(
                .init(
                    position: SIMD2(rightTop.x + 2, rightTop.y - 1),
                    text: raLabel, height: 3)))

        // Production method below the bar
        if let method = method {
            result.append(
                .textLabel(
                    .init(
                        position: SIMD2(rightTop.x + 2, rightTop.y - 5),
                        text: method, height: 2.5)))
        }

        // Leader line from apex to target
        result.append(
            .centreline(
                .init(
                    from: apex, to: target, style: .solid,
                    id: "surface-finish-leader")))
        return result
    }
}

// MARK: - GD&T symbols (ISO 1101)

/// ISO 1101 geometric characteristic symbol.
///
/// Matches `Document.GeomToleranceType`.
/// raw values for easy round-trip from XDE into drawings.
public enum GDTSymbol: String, Sendable, Hashable, Codable {
    case straightness, flatness, circularity, cylindricity
    case profileOfLine, profileOfSurface
    case perpendicularity, parallelism, angularity
    case position, concentricity, symmetry, coaxiality
    case circularRunout, totalRunout

    /// Unicode glyph or short textual representation (used when emitting to).
    ///
    /// DXF via plain TEXT. (Full Unicode glyphs render in AutoCAD but require.
    /// a TrueType font; the textual form is always safe.).
    public var glyph: String {
        switch self {
        case .straightness: return "STR"
        case .flatness: return "FLT"
        case .circularity: return "O"
        case .cylindricity: return "CYL"
        case .profileOfLine: return "⌒"
        case .profileOfSurface: return "⌓"
        case .perpendicularity: return "⊥"
        case .parallelism: return "∥"
        case .angularity: return "∠"
        case .position: return "⌖"
        case .concentricity: return "⊙"
        case .symmetry: return "="
        case .coaxiality: return "◎"
        case .circularRunout: return "↗"
        case .totalRunout: return "↗↗"
        }
    }
}

extension DrawingAnnotation {
    /// ISO 1101 feature control frame (the classic rectangular box with).
    /// symbol | tolerance | datum references.
    ///
    /// Example: `[⌖] [0.1 Ⓜ] [A] [B] [C]` (positional tolerance 0.1 at).
    /// maximum material condition relative to datums A, B, C.
    public static func featureControlFrame(
        at position: SIMD2<Double>,
        symbol: GDTSymbol,
        tolerance: String,  // e.g. "0.1" or "0.1 M" for MMC
        datums: [String] = [],
        leaderTo target: SIMD2<Double>? = nil
    ) -> [DrawingAnnotation] {
        let cellH = 8.0
        let symbolW = 10.0
        let toleranceW = 20.0
        let datumW = 8.0
        let totalW = symbolW + toleranceW + datumW * Double(datums.count)

        var result: [DrawingAnnotation] = []

        // Outer rectangle
        let bottomLeft = position
        let topRight = SIMD2(position.x + totalW, position.y + cellH)
        // Represent as 4 lines forming the outer box
        result.append(
            .centreline(
                .init(
                    from: bottomLeft,
                    to: SIMD2(topRight.x, bottomLeft.y),
                    style: .solid)))
        result.append(
            .centreline(
                .init(
                    from: SIMD2(topRight.x, bottomLeft.y),
                    to: topRight, style: .solid)))
        result.append(
            .centreline(
                .init(
                    from: topRight,
                    to: SIMD2(bottomLeft.x, topRight.y),
                    style: .solid)))
        result.append(
            .centreline(
                .init(
                    from: SIMD2(bottomLeft.x, topRight.y),
                    to: bottomLeft, style: .solid)))

        // Vertical dividers
        let divX1 = bottomLeft.x + symbolW
        let divX2 = divX1 + toleranceW
        result.append(
            .centreline(
                .init(
                    from: SIMD2(divX1, bottomLeft.y),
                    to: SIMD2(divX1, topRight.y),
                    style: .solid)))
        result.append(
            .centreline(
                .init(
                    from: SIMD2(divX2, bottomLeft.y),
                    to: SIMD2(divX2, topRight.y),
                    style: .solid)))

        // Symbol glyph in first cell
        result.append(
            .textLabel(
                .init(
                    position: SIMD2(
                        bottomLeft.x + symbolW / 3,
                        bottomLeft.y + cellH / 3),
                    text: symbol.glyph, height: 4)))

        // Tolerance in second cell
        result.append(
            .textLabel(
                .init(
                    position: SIMD2(divX1 + 2, bottomLeft.y + cellH / 3),
                    text: tolerance, height: 3.5)))

        // Datum cells
        for (i, datum) in datums.enumerated() {
            let cellX = divX2 + Double(i) * datumW
            if i > 0 {
                result.append(
                    .centreline(
                        .init(
                            from: SIMD2(cellX, bottomLeft.y),
                            to: SIMD2(cellX, topRight.y),
                            style: .solid)))
            }
            result.append(
                .textLabel(
                    .init(
                        position: SIMD2(
                            cellX + datumW / 3,
                            bottomLeft.y + cellH / 3),
                        text: datum, height: 3.5)))
        }

        // Leader line
        if let target = target {
            let leaderStart = SIMD2(bottomLeft.x, bottomLeft.y + cellH / 2)
            result.append(.centreline(.init(from: leaderStart, to: target, style: .solid)))
        }
        return result
    }

    /// ISO 1101 datum feature symbol (letter in a box with triangle pointer).
    public static func datumFeature(
        label: String,  // single letter like "A"
        at position: SIMD2<Double>,
        pointingTo target: SIMD2<Double>
    ) -> [DrawingAnnotation] {
        let boxSize = 8.0
        let triangleSize = 6.0

        // Box
        let bl = position
        let tr = SIMD2(position.x + boxSize, position.y + boxSize)
        var result: [DrawingAnnotation] = [
            .centreline(.init(from: bl, to: SIMD2(tr.x, bl.y), style: .solid)),
            .centreline(.init(from: SIMD2(tr.x, bl.y), to: tr, style: .solid)),
            .centreline(.init(from: tr, to: SIMD2(bl.x, tr.y), style: .solid)),
            .centreline(.init(from: SIMD2(bl.x, tr.y), to: bl, style: .solid)),
            .textLabel(
                .init(
                    position: SIMD2(bl.x + boxSize / 3, bl.y + boxSize / 3),
                    text: label, height: 4)),
        ]

        // Triangle pointing at target
        let dir = target - position
        let len = simd_length(dir)
        if len > 1e-6 {
            let u = dir / len
            let perp = SIMD2(-u.y, u.x)
            let apex = target
            let baseMid = target - u * triangleSize
            let baseL = baseMid + perp * (triangleSize / 2)
            let baseR = baseMid - perp * (triangleSize / 2)
            result.append(.centreline(.init(from: apex, to: baseL, style: .solid)))
            result.append(.centreline(.init(from: apex, to: baseR, style: .solid)))
            result.append(.centreline(.init(from: baseL, to: baseR, style: .solid)))
            // Leader from box to triangle base
            let boxEdge = SIMD2(position.x + boxSize / 2, position.y + boxSize / 2)
            result.append(.centreline(.init(from: boxEdge, to: baseMid, style: .solid)))
        }
        return result
    }
}

// MARK: - Detail view + break lines (G5)

extension Drawing {
    /// Compose a detail view of a region from this drawing, scaled up and.
    /// placed at placement.
    ///
    /// Returns a TransformedDrawing ready to pass to.
    /// `DXFWriter.collectFromDrawing`.
    ///
    /// Caller should pair with a `DrawingAnnotation.textLabel` marker on the.
    /// parent view indicating the detail bubble + a textLabel on the detail.
    /// placement indicating the scale, e.g. "DETAIL A  2:1".
    public func detailView(at placement: SIMD2<Double>, scale: Double) -> TransformedDrawing {
        transformed(translate: placement, scale: scale)
    }
}

extension DrawingAnnotation {
    /// ISO 128-30 break line marking compressed length.
    ///
    /// Renders as a short.
    /// zigzag at the midpoint of the two endpoints.
    public static func breakLine(
        from: SIMD2<Double>, to: SIMD2<Double>,
        amplitude: Double = 2.0
    ) -> [DrawingAnnotation] {
        let mid = (from + to) / 2
        let dir = simd_normalize(to - from)
        let perp = SIMD2(-dir.y, dir.x)
        let step = 2.0
        let p1 = mid - step * dir
        let p2 = mid - 0.5 * step * dir + amplitude * perp
        let p3 = mid + 0.5 * step * dir - amplitude * perp
        let p4 = mid + step * dir
        return [
            .centreline(.init(from: from, to: p1, style: .solid)),
            .centreline(.init(from: p1, to: p2, style: .solid)),
            .centreline(.init(from: p2, to: p3, style: .solid)),
            .centreline(.init(from: p3, to: p4, style: .solid)),
            .centreline(.init(from: p4, to: to, style: .solid)),
        ]
    }
}
