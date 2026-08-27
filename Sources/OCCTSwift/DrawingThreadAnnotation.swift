import Foundation
import simd

// MARK: - ISO 6410 cosmetic thread representation (#77, v0.146)
//
// 3D threads (v0.139) are expensive: real helical geometry inflates STEP by
// 10-100× and can produce HLR artefacts. ISO 6410 specifies a *cosmetic*
// thread representation for drawings — a simple pattern of lines and arcs
// indicating "there's a thread here" without modelling the helical form.
//
// Rules encoded:
//   - Side view:
//       * Two parallel thin lines at the minor diameter, inside the major-
//         diameter silhouette, spanning the thread length.
//       * The major-diameter silhouette is the usual visible edge (not added
//         by this API — it comes from the model's HLR projection).
//   - End view (circular):
//       * 3/4 broken arc at the minor diameter — three arcs covering 0-90°,
//         90°-180°, and 180°-315°, with a visible gap in the last quadrant.
//   - Optional callout text with a leader line (e.g. "M10×1.5")

extension DrawingAnnotation {
    /// Minor diameter per ISO 68 metric V thread: D - 1.0825*P, floored at 0.8*D.
    /// Returns Double; shared by side-view and end-view builders.
    static func minorDiameter(majorDiameter: Double, pitch: Double) -> Double {
        max(majorDiameter - 1.0825 * pitch, majorDiameter * 0.8)
    }

    /// ISO 6410 cosmetic thread — side view pattern.
    ///
    /// Produces two parallel lines on the CENTER layer spanning the thread
    /// length inside the shank's side-view silhouette, plus an optional
    /// callout label on the TEXT layer.
    public static func cosmeticThreadSideView(
        axisStart: SIMD2<Double>,  // thread start projected into the 2D view
        axisEnd: SIMD2<Double>,  // thread end projected into the 2D view
        majorDiameter: Double,
        pitch: Double,
        callout: String? = nil
    ) -> [DrawingAnnotation] {
        let axis = axisEnd - axisStart
        let len = simd_length(axis)
        guard len > 1e-6 else { return [] }
        let axisUnit = axis / len
        let perp = leftPerpendicular2D(of: axisUnit)
        // Minor diameter per ISO 68 (metric V thread): D_minor = D - 1.0825·P.
        // We draw at +/- minor/2 perpendicular to the axis.
        let minorDiameter = Self.minorDiameter(majorDiameter: majorDiameter, pitch: pitch)
        let halfMinor = minorDiameter / 2

        let topStart = axisStart + halfMinor * perp
        let topEnd = axisEnd + halfMinor * perp
        let botStart = axisStart - halfMinor * perp
        let botEnd = axisEnd - halfMinor * perp

        var result: [DrawingAnnotation] = [
            .centreline(
                .init(
                    from: topStart, to: topEnd, style: .solid,
                    id: "cosmetic-thread-top")),
            .centreline(
                .init(
                    from: botStart, to: botEnd, style: .solid,
                    id: "cosmetic-thread-bottom")),
        ]
        if let callout = callout {
            // Leader starts at thread midline, goes out and up slightly.
            let mid = (axisStart + axisEnd) / 2
            let leaderTip = mid + (halfMinor + 10) * perp
            result.append(
                .textLabel(
                    .init(
                        position: leaderTip, text: callout,
                        height: 3.5)))
        }
        return result
    }

    /// ISO 6410 cosmetic thread — end-view (circular) pattern.
    ///
    /// Produces a 3/4 broken arc at the minor diameter: typically three arcs
    /// covering 0-90°, 90°-180°, and 180°-315° with a visible gap near one
    /// quadrant, indicating the thread.
    ///
    /// Returns three `.arc` annotations on the "CENTER" layer, ready to `append(contentsOf:)`
    /// onto a `Drawing` (or pass to `Drawing.addCosmeticThreadEndView`) — a full
    /// `DrawingAnnotation` factory, matching `cosmeticThreadSideView` above, so the arcs render
    /// identically through DXF, PDF and SVG (#1179: this used to return a bespoke `ArcSegment`
    /// type that was never a `DrawingAnnotation` and so could only reach `DXFWriter`, via its own
    /// `addCosmeticThreadEndView` extension below, which is now itself just a thin wrapper over
    /// this factory).
    public static func cosmeticThreadEndView(
        centre: SIMD2<Double>,
        majorDiameter: Double,
        pitch: Double
    ) -> [DrawingAnnotation] {
        let minorDiameter = Self.minorDiameter(majorDiameter: majorDiameter, pitch: pitch)
        let r = minorDiameter / 2
        // Three arcs: 0→90, 90→180, 180→315 (with a 45° gap at 315-360)
        return [
            .arc(
                .init(
                    centre: centre, radius: r, startAngle: 0, endAngle: .pi / 2,
                    layer: "CENTER")),
            .arc(
                .init(
                    centre: centre, radius: r, startAngle: .pi / 2, endAngle: .pi,
                    layer: "CENTER")),
            .arc(
                .init(
                    centre: centre, radius: r, startAngle: .pi, endAngle: 7 * .pi / 4,
                    layer: "CENTER")),
        ]
    }
}

extension Drawing {
    /// Convenience: add an ISO 6410 cosmetic thread side-view pattern plus
    /// optional callout to this drawing.
    ///
    /// Returns the added annotations for further manipulation.
    @discardableResult
    public func addCosmeticThreadSide(
        axisStart: SIMD2<Double>,
        axisEnd: SIMD2<Double>,
        majorDiameter: Double,
        pitch: Double,
        callout: String? = nil
    ) -> [DrawingAnnotation] {
        let anns = DrawingAnnotation.cosmeticThreadSideView(
            axisStart: axisStart, axisEnd: axisEnd,
            majorDiameter: majorDiameter, pitch: pitch, callout: callout)
        for a in anns { annotationStore.appendAnnotation(a) }
        return anns
    }

    /// Convenience: add an ISO 6410 cosmetic thread end-view 3/4 broken-arc pattern to this
    /// drawing.
    ///
    /// Returns the added annotations for further manipulation. Unlike
    /// `DXFWriter.addCosmeticThreadEndView` below, the arcs added here are stored on the
    /// `Drawing` itself, so they render identically whether the drawing is later exported to
    /// DXF, PDF or SVG, and participate in `bounds()`/`detailView()` like every other annotation.
    @discardableResult
    public func addCosmeticThreadEndView(
        centre: SIMD2<Double>,
        majorDiameter: Double,
        pitch: Double
    ) -> [DrawingAnnotation] {
        let anns = DrawingAnnotation.cosmeticThreadEndView(
            centre: centre, majorDiameter: majorDiameter, pitch: pitch)
        for a in anns { annotationStore.appendAnnotation(a) }
        return anns
    }
}

extension DXFWriter {
    /// Write an ISO 6410 cosmetic thread end-view 3/4 arc set directly onto this writer, with no
    /// `Drawing` in the loop.
    ///
    /// Delegates to `DrawingAnnotation.cosmeticThreadEndView` and stages each arc through the
    /// same shared `emitAnnotation` dispatch every other annotation renders through (#1179), so
    /// this stays behaviourally identical to before (three arcs on the "CENTER" layer) while no
    /// longer hand-rolling its own radians→degrees `addArc` calls. For a drawing that should also
    /// be exportable to PDF/SVG, or that should participate in `bounds()`, prefer
    /// `Drawing.addCosmeticThreadEndView` above.
    public func addCosmeticThreadEndView(
        centre: SIMD2<Double>,
        majorDiameter: Double,
        pitch: Double
    ) {
        let ops = primitiveOps()
        for a in DrawingAnnotation.cosmeticThreadEndView(
            centre: centre, majorDiameter: majorDiameter, pitch: pitch)
        {
            emitAnnotation(a, into: ops)
        }
    }
}
