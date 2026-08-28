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
}
