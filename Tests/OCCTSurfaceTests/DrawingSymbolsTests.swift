import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.146: Surface finish, GD&T, detail, break lines

@Suite("v0.146 Surface finish + GD&T symbols")
struct DrawingSymbolsTests {
    @Test("Surface finish symbol produces check-mark + bar + Ra text + leader")
    func surfaceFinishMachiningRequired() {
        let anns = DrawingAnnotation.surfaceFinish(
            at: SIMD2(10, 10),
            leaderTo: SIMD2(20, 5),
            ra: 1.6,
            symbol: .machiningRequired)
        // 2 arms + 1 bar + Ra text + leader = 5 annotations.
        #expect(anns.count == 5)
    }

    @Test("Surface finish .any has no horizontal bar")
    func surfaceFinishAny() {
        let required = DrawingAnnotation.surfaceFinish(
            at: .zero, leaderTo: SIMD2(10, 0), ra: 1.0, symbol: .machiningRequired)
        let any = DrawingAnnotation.surfaceFinish(
            at: .zero, leaderTo: SIMD2(10, 0), ra: 1.0, symbol: .any)
        #expect(required.count > any.count)
    }

    @Test("Surface finish .machiningProhibited emits circle as centreline segments")
    func surfaceFinishMachiningProhibited() {
        let anns = DrawingAnnotation.surfaceFinish(
            at: SIMD2(10, 10),
            leaderTo: SIMD2(20, 5),
            ra: 1.6,
            symbol: .machiningProhibited)
        // 2 arms + 24 circle segments + Ra text + leader = 28 annotations.
        #expect(anns.count == 28)
        let lineCount = anns.filter {
            if case .centreline = $0 { return true } else { return false }
        }.count
        // 2 arms + 24 circle segments + 1 leader = 27 lines
        #expect(lineCount == 27)
        let textCount = anns.filter {
            if case .textLabel = $0 { return true } else { return false }
        }.count
        // 1 Ra text label
        #expect(textCount == 1)
    }

    @Test("Feature control frame produces rectangle + dividers + symbol + tolerance")
    func featureControlFrame() {
        let anns = DrawingAnnotation.featureControlFrame(
            at: SIMD2(0, 0),
            symbol: .position,
            tolerance: "0.1",
            datums: ["A", "B", "C"])
        // 4 box edges + 2 dividers + 2 datum dividers + glyph + tolerance + 3 datum letters = 12
        let lineCount = anns.filter {
            if case .centreline = $0 { return true } else { return false }
        }.count
        #expect(lineCount >= 6)  // box + internal dividers
        let textCount = anns.filter {
            if case .textLabel = $0 { return true } else { return false }
        }.count
        #expect(textCount == 5)  // symbol + tolerance + 3 datums
    }

    @Test("Datum feature symbol has box + triangle pointer")
    func datumFeature() {
        let anns = DrawingAnnotation.datumFeature(
            label: "A",
            at: SIMD2(10, 10),
            pointingTo: SIMD2(30, 10))
        // 4 box edges + letter + 3 triangle edges + leader = 9
        let lineCount = anns.filter {
            if case .centreline = $0 { return true } else { return false }
        }.count
        #expect(lineCount == 8)
    }

    // MARK: - #1188: rectangleCentrelines geometry (corner order and winding,
    // not just annotation counts, since neither box below had a coordinate
    // assertion before this helper existed).

    @Test("rectangleCentrelines traces the four box edges in CCW winding")
    func rectangleCentrelinesWinding() {
        let box = DrawingAnnotation.rectangleCentrelines(
            min: SIMD2(2, 3), max: SIMD2(12, 9))
        let lines: [DrawingAnnotation.Centreline] = box.compactMap {
            if case .centreline(let c) = $0 { return c } else { return nil }
        }
        #expect(lines.count == 4)
        // bottom (L->R), right (bottom->top), top (R->L), left (top->bottom).
        #expect(lines[0].from == SIMD2(2, 3) && lines[0].to == SIMD2(12, 3))
        #expect(lines[1].from == SIMD2(12, 3) && lines[1].to == SIMD2(12, 9))
        #expect(lines[2].from == SIMD2(12, 9) && lines[2].to == SIMD2(2, 9))
        #expect(lines[3].from == SIMD2(2, 9) && lines[3].to == SIMD2(2, 3))
        for line in lines {
            #expect(line.style == .solid)
        }
    }

    @Test("Feature control frame outer box matches the min/max corners exactly")
    func featureControlFrameOuterBoxGeometry() {
        let anns = DrawingAnnotation.featureControlFrame(
            at: SIMD2(0, 0),
            symbol: .position,
            tolerance: "0.1",
            datums: ["A", "B", "C"])
        let lines: [DrawingAnnotation.Centreline] = anns.compactMap {
            if case .centreline(let c) = $0 { return c } else { return nil }
        }
        // The outer box is emitted first, as the first 4 centrelines, ahead of
        // the vertical dividers.
        let cellH = 8.0
        let totalW = 10.0 + 20.0 + 8.0 * 3  // symbolW + toleranceW + datumW * datums.count
        let bottomLeft = SIMD2<Double>(0, 0)
        let topRight = SIMD2(totalW, cellH)
        #expect(lines.count >= 4)
        #expect(lines[0].from == bottomLeft && lines[0].to == SIMD2(topRight.x, bottomLeft.y))
        #expect(lines[1].from == SIMD2(topRight.x, bottomLeft.y) && lines[1].to == topRight)
        #expect(lines[2].from == topRight && lines[2].to == SIMD2(bottomLeft.x, topRight.y))
        #expect(lines[3].from == SIMD2(bottomLeft.x, topRight.y) && lines[3].to == bottomLeft)
    }

    @Test("Datum feature box matches the min/max corners exactly")
    func datumFeatureBoxGeometry() {
        let anns = DrawingAnnotation.datumFeature(
            label: "A",
            at: SIMD2(10, 10),
            pointingTo: SIMD2(30, 10))
        let lines: [DrawingAnnotation.Centreline] = anns.compactMap {
            if case .centreline(let c) = $0 { return c } else { return nil }
        }
        // The label box is emitted first, as the first 4 centrelines, ahead of
        // the letter and the triangle pointer.
        let boxSize = 8.0
        let bl = SIMD2<Double>(10, 10)
        let tr = SIMD2(bl.x + boxSize, bl.y + boxSize)
        #expect(lines.count >= 4)
        #expect(lines[0].from == bl && lines[0].to == SIMD2(tr.x, bl.y))
        #expect(lines[1].from == SIMD2(tr.x, bl.y) && lines[1].to == tr)
        #expect(lines[2].from == tr && lines[2].to == SIMD2(bl.x, tr.y))
        #expect(lines[3].from == SIMD2(bl.x, tr.y) && lines[3].to == bl)
    }

    @Test("GDT symbol glyphs are non-empty")
    func gdtGlyphs() {
        for s in [GDTSymbol.flatness, .position, .perpendicularity, .concentricity] {
            #expect(!s.glyph.isEmpty)
        }
    }

    @Test("Break line is a zigzag of 5 segments")
    func breakLine() {
        let anns = DrawingAnnotation.breakLine(
            from: SIMD2(0, 0), to: SIMD2(100, 0), amplitude: 2)
        #expect(anns.count == 5)
    }

    @Test("Detail view returns a TransformedDrawing with expected scale")
    func detailView() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let drawing = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let detail = drawing.detailView(at: SIMD2(200, 100), scale: 2.0)
        #expect(detail.scale == 2.0)
        #expect(detail.translate == SIMD2(200, 100))
    }
}
