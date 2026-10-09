import Foundation
import Testing

@testable import OCCTSwift

// #3116: XCAFPrs_Style::IsEmpty() is `!hasSurfColor && !hasCurvColor && material.IsNull() &&
// isVisible` (XCAFPrs_Style.hxx), so a hidden style is never empty. PresentationStyle.isEmpty
// used to return a field the bridge computed from a default (visible) style.
@Suite("PresentationStyle isEmpty vs XCAFPrs_Style::IsEmpty")
struct Issue3116PresentationStyleIsEmptyTests {
    @Test func hiddenStyleWithNoColourIsNotEmpty() {
        var style = PresentationStyle()
        style.isVisible = false
        #expect(!style.isEmpty)
        // The same style must not be both empty and different from the empty style.
        #expect(!style.isEqual(to: PresentationStyle()))
    }

    @Test func emptyMatrix() {
        // (hasSurface, hasCurve, visible) -> OCCT IsEmpty = !surf && !curv && visible
        for hasSurface in [false, true] {
            for hasCurve in [false, true] {
                for visible in [false, true] {
                    var style = PresentationStyle()
                    if hasSurface { style.surfaceColor = (1, 0, 0) }
                    if hasCurve { style.curveColor = (0, 1, 0) }
                    style.isVisible = visible
                    let expected = !hasSurface && !hasCurve && visible
                    #expect(
                        style.isEmpty == expected,
                        "surface \(hasSurface) curve \(hasCurve) visible \(visible)")
                }
            }
        }
    }
}
