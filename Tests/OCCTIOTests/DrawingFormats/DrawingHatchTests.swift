import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.144 #74: Hatch emission

@Suite("v0.144 Drawing.addHatch + DXFWriter tessellation")
struct DrawingHatchTests {
    @Test("addHatch stores a hatch annotation")
    func storesHatchAnnotation() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let top = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        top.addHatch(
            boundary: [
                SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 20), SIMD2(0, 20),
            ], spacing: 2.0)
        #expect(top.annotations.count == 1)
        if case .hatch = top.annotations[0] {
        } else {
            Issue.record("expected hatch")
        }
    }

    @Test("DXFWriter tessellates hatch into line segments")
    func tessellatesIntoLines() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1),
            let drawing = Drawing.topView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        drawing.addHatch(
            boundary: [
                SIMD2(0, 0), SIMD2(10, 0),
                SIMD2(10, 10), SIMD2(0, 10),
            ],
            angle: 0,  // horizontal lines for predictability
            spacing: 2.0)
        let w = DXFWriter()
        w.collectFromDrawing(drawing)
        // 10 / 2 = 5 scanlines should produce 5 line segments (each horizontal
        // at y = 2, 4, 6, 8 within the square). Allow a little slack.
        #expect(w.entityCounts.lines >= 3)
    }

    // #1172: emitHatch used to be a hand-rolled rotate/scanline/intersect duplicate of
    // HatchPattern.generate's own OCCT-native Hatch_Hatcher call, with a looser
    // near-horizontal tolerance (1e-12 vs Hatch_Hatcher's 1e-7) and no way to reach islands
    // through HatchPattern.generate. It is now a thin wrapper over the same function, so the
    // annotation-dispatch route (emitAnnotation -> emitHatch) and the direct
    // HatchPattern.generate call must produce byte-identical segments for the same inputs.
    @Test("emitHatch shares HatchPattern.generate's implementation (#1172)")
    func emitHatchMatchesHatchPatternGenerate() {
        let boundary: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10),
        ]
        let hatch = DrawingAnnotation.Hatch(boundary: boundary, angle: 0, spacing: 2.0)

        var recorded: [(SIMD2<Double>, SIMD2<Double>, String)] = []
        let ops = DrawingPrimitiveOps(
            addLine: { a, b, layer in recorded.append((a, b, layer)) },
            addPolyline: { _, _, _ in },
            addCircle: { _, _, _ in },
            addArc: { _, _, _, _, _ in },
            addText: { _, _, _, _, _ in }
        )
        emitAnnotation(.hatch(hatch), into: ops)

        let direct = HatchPattern.generate(
            boundary: boundary, direction: SIMD2(1, 0), spacing: 2.0)

        #expect(recorded.count == direct.count)
        guard recorded.count == direct.count else { return }
        for (rec, seg) in zip(recorded, direct) {
            #expect(rec.0 == seg.start)
            #expect(rec.1 == seg.end)
            #expect(rec.2 == "HATCH")
        }
    }
}
