import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.144 G1: ISO 128-20 / 3098 / 5455 style constants

@Suite("v0.144 ISO drawing style constants")
struct DrawingStyleTests {
    @Test("DrawingLineWidth values match ISO 128-20 tiers")
    func lineWidths() {
        #expect(DrawingLineWidth.thin.rawValue == 0.25)
        #expect(DrawingLineWidth.thick.rawValue == 0.50)
        #expect(DrawingLineWidth.allCases.count == 9)
    }

    @Test("DrawingTextHeight.snap picks nearest ISO 3098 tier")
    func textHeightSnap() {
        #expect(DrawingTextHeight.snap(3.8) == .h35)
        #expect(DrawingTextHeight.snap(4.3) == .h50)
        #expect(DrawingTextHeight.snap(8) == .h70)
    }

    @Test("DrawingTextHeight.recommended varies by paper")
    func textHeightRecommended() {
        #expect(DrawingTextHeight.recommended(forPaper: "A0") == .h50)
        #expect(DrawingTextHeight.recommended(forPaper: "A4") == .h35)
    }

    @Test("DrawingScale factor and label")
    func drawingScales() {
        #expect(DrawingScale.one.factor == 1.0)
        #expect(DrawingScale.reduction(2).factor == 0.5)
        #expect(DrawingScale.enlargement(5).factor == 5.0)
        #expect(DrawingScale.reduction(10).label == "1:10")
        #expect(DrawingScale.enlargement(2).label == "2:1")
    }

    @Test("strokeWidthMM returns ISO 128-20 line widths")
    func strokeWidthMMLayers() {
        #expect(strokeWidthMM(for: "VISIBLE") == 0.5)
        #expect(strokeWidthMM(for: "HIDDEN") == 0.25)
        #expect(strokeWidthMM(for: "CENTER") == 0.25)
        #expect(strokeWidthMM(for: "HATCH") == 0.18)
    }

    @Test("ArrowStyle length scales with line width")
    func arrowStyleLength() {
        let L = DrawingArrowStyle.filledClosed.length(forLineWidth: .w025)
        #expect(abs(L - 1.5) < 1e-9)
    }

    @Test("DrawingScale preferred includes ISO series")
    func preferredScales() {
        let labels = DrawingScale.preferred.map(\.label)
        #expect(labels.contains("1:1"))
        #expect(labels.contains("1:10"))
        #expect(labels.contains("2:1"))
        #expect(labels.contains("1:100"))
    }
}
