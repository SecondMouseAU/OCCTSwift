import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFPrs_Style Tests")
struct XCAFPrsStyleTests {
    @Test func emptyStyle() {
        let style = PresentationStyle()
        #expect(style.isEmpty)
        // The documented defaults of an empty style, and the controls that make `isEmpty` a
        // reading: a style with a surface colour, or with only a curve colour, is not empty.
        #expect(style.surfaceColor == nil)
        #expect(style.curveColor == nil)
        #expect(style.isVisible)
        #expect(style.surfaceAlpha == 1.0)
        #expect(!PresentationStyle(surfaceRed: 0, surfaceGreen: 0, surfaceBlue: 0).isEmpty)
        var curveOnly = PresentationStyle()
        curveOnly.curveColor = (0, 0, 0)
        #expect(!curveOnly.isEmpty)
        // Two empty styles are equal, and an empty one differs from a coloured one.
        #expect(style.isEqual(to: PresentationStyle()))
        #expect(
            !style.isEqual(to: PresentationStyle(surfaceRed: 0, surfaceGreen: 0, surfaceBlue: 0)))
    }

    @Test func surfaceColor() throws {
        let style = PresentationStyle(surfaceRed: 0.0, surfaceGreen: 0.0, surfaceBlue: 1.0)
        #expect(!style.isEmpty)
        let colour = try #require(style.surfaceColor)
        #expect(colour.red == 0.0)
        #expect(colour.green == 0.0)
        #expect(colour.blue == 1.0)
        #expect(style.surfaceAlpha == 1.0)
        #expect(style.curveColor == nil)
        #expect(style.isVisible)

        // The colour is what OCCT compares: the same one is equal, and each of red, green and
        // blue on its own makes a different style. Blue against red is also the pair a swapped
        // channel order would make equal.
        #expect(
            style.isEqual(to: PresentationStyle(surfaceRed: 0, surfaceGreen: 0, surfaceBlue: 1)))
        let red = PresentationStyle(surfaceRed: 1, surfaceGreen: 0, surfaceBlue: 0)
        let green = PresentationStyle(surfaceRed: 0, surfaceGreen: 1, surfaceBlue: 0)
        #expect(!style.isEqual(to: red))
        #expect(!style.isEqual(to: green))
        #expect(!red.isEqual(to: green))
        #expect(!style.isEqual(to: PresentationStyle()))
    }

    @Test func visibility() {
        var style = PresentationStyle()
        style.isVisible = false
        style.surfaceColor = (1, 0, 0)
        #expect(!style.isVisible)

        // Visibility is part of the style OCCT compares: the same colour, visible, is a
        // different style.
        var visible = PresentationStyle()
        visible.surfaceColor = (1, 0, 0)
        #expect(visible.isVisible)
        #expect(!style.isEqual(to: visible))
        #expect(!visible.isEqual(to: style))
        // And two hidden styles are equal to each other whatever colour they carry, which is
        // what XCAFPrs_Style::IsEqual says (a hidden style overrides everything beneath it).
        var hiddenBlue = PresentationStyle()
        hiddenBlue.isVisible = false
        hiddenBlue.surfaceColor = (0, 0, 1)
        #expect(style.isEqual(to: hiddenBlue))
    }

    /// A hidden style is not empty.
    ///
    /// `XCAFPrs_Style::IsEmpty()` includes visibility, and so does this type's doc comment
    /// ("no colors set, visible"). #3116 made `isEmpty` compute from the stored properties, so
    /// the expectation that was carried as a known issue is now a plain one.
    @Test func hiddenStyleIsNotEmpty() {
        var hidden = PresentationStyle()
        hidden.isVisible = false
        // The control that makes this about visibility and nothing else: the same style,
        // visible, is empty, and a hidden coloured one is not.
        #expect(PresentationStyle().isEmpty)
        var hiddenBlue = PresentationStyle(surfaceRed: 0, surfaceGreen: 0, surfaceBlue: 1)
        hiddenBlue.isVisible = false
        #expect(!hiddenBlue.isEmpty)
        #expect(!hidden.isEmpty)
    }

    @Test func equality() {
        let s1 = PresentationStyle(
            surfaceRed: 1.0, surfaceGreen: 0.0, surfaceBlue: 0.0, surfaceAlpha: 0.5)
        let s2 = PresentationStyle(
            surfaceRed: 1.0, surfaceGreen: 0.0, surfaceBlue: 0.0, surfaceAlpha: 0.5)
        #expect(s1.isEqual(to: s2))
        #expect(s2.isEqual(to: s1))
        #expect(s1.isEqual(to: s1))

        // One property at a time. Each is a style that differs from `s1` in that property only,
        // so an equality that ignores a property reads one of these as equal.
        let otherAlpha = PresentationStyle(
            surfaceRed: 1.0, surfaceGreen: 0.0, surfaceBlue: 0.0, surfaceAlpha: 0.25)
        let otherRed = PresentationStyle(
            surfaceRed: 0.5, surfaceGreen: 0.0, surfaceBlue: 0.0, surfaceAlpha: 0.5)
        let otherGreen = PresentationStyle(
            surfaceRed: 1.0, surfaceGreen: 0.5, surfaceBlue: 0.0, surfaceAlpha: 0.5)
        let otherBlue = PresentationStyle(
            surfaceRed: 1.0, surfaceGreen: 0.0, surfaceBlue: 0.5, surfaceAlpha: 0.5)
        var withCurve = s1
        withCurve.curveColor = (0, 1, 0)
        var otherCurve = s1
        otherCurve.curveColor = (0, 0, 1)
        var hidden = s1
        hidden.isVisible = false
        for (name, other) in [
            ("alpha", otherAlpha), ("red", otherRed), ("green", otherGreen),
            ("blue", otherBlue), ("curve colour present", withCurve), ("hidden", hidden),
        ] {
            #expect(!s1.isEqual(to: other), "differs in \(name) only")
            #expect(!other.isEqual(to: s1), "differs in \(name) only, reversed")
        }
        // The curve colour is compared by value, not only by presence.
        #expect(!withCurve.isEqual(to: otherCurve))
        var sameCurve = s1
        sameCurve.curveColor = (0, 1, 0)
        #expect(withCurve.isEqual(to: sameCurve))

        // A style carrying both colours is compared on both: the same curve with another surface
        // colour differs, and so does the same surface with a curve that differs in red alone.
        var bothOtherSurface = otherRed
        bothOtherSurface.curveColor = (0, 1, 0)
        #expect(!withCurve.isEqual(to: bothOtherSurface))
        var redCurveA = s1
        redCurveA.curveColor = (1.0, 0, 0)
        var redCurveB = s1
        redCurveB.curveColor = (0.5, 0, 0)
        #expect(!redCurveA.isEqual(to: redCurveB))
        // And visibility counts for a style with both colours as it does for a surface-only one.
        var hiddenBoth = withCurve
        hiddenBoth.isVisible = false
        #expect(!withCurve.isEqual(to: hiddenBoth))
        // A colour is a surface colour or a curve colour: the same value in the other slot is a
        // different style.
        var surfaceGreen = PresentationStyle()
        surfaceGreen.surfaceColor = (0, 1, 0)
        var curveGreen = PresentationStyle()
        curveGreen.curveColor = (0, 1, 0)
        #expect(!surfaceGreen.isEqual(to: curveGreen))
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
