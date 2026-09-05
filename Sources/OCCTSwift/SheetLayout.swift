import Foundation
import simd

// MARK: - Sheet auto-composition (#84, v0.149)
//
// `Sheet.standardLayout(of:scale:)` produces a 4-view layout (front / top /
// side / optional isometric) arranged in a 2x2 grid inside the sheet's inner
// frame. Arrangement respects ISO 5456-2 projection-angle convention:
//
//   First-angle (ISO / Europe):              Third-angle (ANSI / USA):
//     ┌────────┬────────┐                      ┌────────┬────────┐
//     │ FRONT  │  SIDE  │                      │  TOP   │  ISO   │
//     ├────────┼────────┤                      ├────────┼────────┤
//     │  TOP   │  ISO   │                      │ FRONT  │  SIDE  │
//     └────────┴────────┘                      └────────┴────────┘
//
// The primary ISO convention (top's placement relative to front) is preserved;
// the ISO corner is placed in the opposite lower/upper to keep the four views
// tidy in a 2x2 grid.

extension Sheet {
    /// Auto-compose front / top / side / iso views of `shape` onto this sheet
    /// at the supplied scale.
    ///
    /// Views are sized to fit the sheet's inner frame
    /// (less `margin` on each outer edge and `margin/2` between cells).
    ///
    /// If `scale` is smaller than the fit-to-cell scale computed from the
    /// widest view, the caller's value wins (some views may not fill their
    /// cell). Returns nil if any of the front / top / side projections fail.
    public func standardLayout(
        of shape: Shape,
        scale: DrawingScale = .one,
        margin: Double = 20,
        includeIso: Bool = true
    ) -> StandardLayout? {
        guard let front = Drawing.frontView(of: shape),
            let top = Drawing.topView(of: shape),
            let side = Drawing.sideView(of: shape)
        else {
            return nil
        }
        let iso = includeIso ? Drawing.isometricView(of: shape) : nil

        let views: [(Drawing, (min: SIMD2<Double>, max: SIMD2<Double>)?)] =
            [front, top, side, iso].compactMap { drawing in
                guard let d = drawing else { return nil }
                return (d, d.bounds(includeAnnotations: false))
            }

        // --- Cell sizing ---
        let frame = innerFrame
        let innerW = frame.max.x - frame.min.x - 2 * margin
        let innerH = frame.max.y - frame.min.y - 2 * margin
        let cellW = (innerW - margin / 2) / 2
        let cellH = (innerH - margin / 2) / 2
        guard cellW > 0, cellH > 0 else { return nil }

        // --- Uniform scale: fit the widest/tallest projected view into one cell ---
        var maxViewW = 0.0
        var maxViewH = 0.0
        for (_, bounds) in views {
            guard let b = bounds else { continue }
            maxViewW = max(maxViewW, b.max.x - b.min.x)
            maxViewH = max(maxViewH, b.max.y - b.min.y)
        }
        let fitScale: Double
        if maxViewW > 1e-9 && maxViewH > 1e-9 {
            fitScale = min(cellW / maxViewW, cellH / maxViewH)
        } else {
            fitScale = 1.0
        }
        let appliedScale = min(scale.factor, fitScale)

        // --- Cell centres ---
        // Rows indexed 0 = upper, 1 = lower. Cols indexed 0 = left, 1 = right.
        func cellCentre(col: Int, row: Int) -> SIMD2<Double> {
            let x = frame.min.x + margin + Double(col) * (cellW + margin / 2) + cellW / 2
            // Row 0 (upper) = higher Y; row 1 (lower) = lower Y.
            let topY = frame.max.y - margin - cellH / 2
            let bottomY = frame.min.y + margin + cellH / 2
            return SIMD2(x, row == 0 ? topY : bottomY)
        }

        // --- Slot assignment per ISO projection-angle convention ---
        // Each slot: (col, row) in the 2x2 grid.
        let frontSlot: (Int, Int)
        let topSlot: (Int, Int)
        let sideSlot: (Int, Int)
        let isoSlot: (Int, Int)
        switch projection {
        case .first:
            frontSlot = (0, 0)
            sideSlot = (1, 0)
            topSlot = (0, 1)
            isoSlot = (1, 1)
        case .third:
            topSlot = (0, 0)
            isoSlot = (1, 0)
            frontSlot = (0, 1)
            sideSlot = (1, 1)
        }

        func place(_ drawing: Drawing, at slot: (Int, Int)) -> StandardLayout.PlacedView {
            let centre = cellCentre(col: slot.0, row: slot.1)
            let viewBounds = drawing.bounds(includeAnnotations: false)
            let viewCentre: SIMD2<Double>
            if let b = viewBounds {
                viewCentre = (b.min + b.max) / 2
            } else {
                viewCentre = .zero
            }
            // TransformedDrawing.apply(p) = scale * p + translate; we want
            // apply(viewCentre) = cellCentre.
            let translate = centre - appliedScale * viewCentre
            return StandardLayout.PlacedView(
                drawing: drawing,
                offset: translate,
                scale: appliedScale)
        }

        return StandardLayout(
            front: place(front, at: frontSlot),
            top: place(top, at: topSlot),
            side: place(side, at: sideSlot),
            iso: iso.map { place($0, at: isoSlot) })
    }
}

/// Result of `Sheet.standardLayout(of:scale:)`.
///
/// Each `PlacedView` holds the original unannotated `Drawing` (so callers can attach additional dimensions
/// or centrelines to a specific view) plus the offset and scale that
/// `render(into:)` will apply when emitting.
public struct StandardLayout: Sendable {
    public let front: PlacedView
    public let top: PlacedView
    public let side: PlacedView
    public let iso: PlacedView?

    public struct PlacedView: Sendable {
        public let drawing: Drawing
        public let offset: SIMD2<Double>
        public let scale: Double
    }

    /// Every placed view, in draw order (front, top, side, iso).
    public var placed: [PlacedView] {
        var all = [front, top, side]
        if let iso = iso { all.append(iso) }
        return all
    }

    /// Emit every view onto a writer via its `TransformedDrawing`.
    public func render(into writer: DXFWriter) {
        for p in placed {
            writer.collectFromDrawing(p.drawing, translate: p.offset, scale: p.scale)
        }
    }

    /// Emit every view onto a writer via its `TransformedDrawing`.
    public func render(into writer: PDFWriter) {
        for p in placed {
            writer.collectFromDrawing(p.drawing, translate: p.offset, scale: p.scale)
        }
    }

    /// Emit every view onto a writer via its `TransformedDrawing`.
    public func render(into writer: SVGWriter) {
        for p in placed {
            writer.collectFromDrawing(p.drawing, translate: p.offset, scale: p.scale)
        }
    }
}
