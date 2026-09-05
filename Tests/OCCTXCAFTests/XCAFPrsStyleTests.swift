import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFPrs_Style Tests")
struct XCAFPrsStyleTests {
    @Test func emptyStyle() {
        let style = PresentationStyle()
        #expect(style.isEmpty)
    }

    @Test func surfaceColor() {
        var style = PresentationStyle(surfaceRed: 0.0, surfaceGreen: 0.0, surfaceBlue: 1.0)
        #expect(!style.isEmpty)
        #expect(style.surfaceColor != nil)
    }

    @Test func visibility() {
        var style = PresentationStyle()
        style.isVisible = false
        style.surfaceColor = (1, 0, 0)
        #expect(!style.isVisible)
    }

    @Test func equality() {
        let s1 = PresentationStyle(
            surfaceRed: 1.0, surfaceGreen: 0.0, surfaceBlue: 0.0, surfaceAlpha: 0.5)
        let s2 = PresentationStyle(
            surfaceRed: 1.0, surfaceGreen: 0.0, surfaceBlue: 0.0, surfaceAlpha: 0.5)
        #expect(s1.isEqual(to: s2))
    }

    // Regression test for #1569: a style with ONLY curveColor set (surfaceColor left nil,
    // a state the struct's memberwise mutability explicitly allows) used to fall into
    // toOCCT()'s empty-style branch, silently dropping the curve color.
    @Test func curveColorOnly() {
        var style = PresentationStyle()
        style.curveColor = (0.0, 1.0, 0.0)
        #expect(style.surfaceColor == nil)

        // isEmpty must not be true just because surfaceColor is nil.
        #expect(!style.isEmpty)

        var same = PresentationStyle()
        same.curveColor = (0.0, 1.0, 0.0)
        #expect(style.isEqual(to: same))

        var differentCurve = PresentationStyle()
        differentCurve.curveColor = (1.0, 0.0, 0.0)
        #expect(!style.isEqual(to: differentCurve))
    }
}
