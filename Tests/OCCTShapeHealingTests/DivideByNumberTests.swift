import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Divide by Number")
struct DivideByNumberTests {
    /// Was `if let r = result { #expect(...) }`, which passes trivially whether or not `result`
    /// is ever non-nil -- and until #1491 it never was: `OCCTShapeDivideByNumber` was missing
    /// `MaxArea() = -1`, the sentinel `ShapeUpgrade_FaceDivideArea::Perform()` requires to derive
    /// its max-area-per-part from `NbParts()` at all; without it `Perform()`'s very next line
    /// (`(anArea - myMaxArea) < Precision::Confusion()`, comparing against the untouched default
    /// `Precision::Infinite()`) is unconditionally true, so `Perform()` -- and this whole
    /// function -- failed for every input, every time, confirmed directly with a ground-truth
    /// probe against a plain box through this exact call sequence before the fix. Each of a
    /// box's 6 square faces splits into `parts` (4) sub-faces, all landing on one parametric axis
    /// since `dividedByNumber` always passes `nbV: 1` -- 6 * 4 = 24.
    @Test("Divide box into parts")
    func divideBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.faces().count == 6, "premise: a box has 6 faces")
        let result = box.dividedByNumber(4)
        #expect(
            result?.faces().count == 24,
            "expected 6 faces * 4 parts each = 24; OCCTShapeDivideByNumber returning nil here is the pre-#1491 defect (missing MaxArea() = -1), not \"geometry-dependent\""
        )
    }

    @Test("Divide with 1 part returns nil")
    func divideOnePart() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.dividedByNumber(1)
        #expect(result == nil)
    }

    /// A cylinder's two planar end caps decline to split by area (no area-splittable geometry
    /// change) and are kept as-is; the one lateral (curved) face splits into `parts` (4). Net:
    /// 3 original faces -> 2 unchanged + 4 split = 6, confirmed with a ground-truth probe.
    @Test("Divide cylinder into parts")
    func divideCylinder() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        #expect(cyl.faces().count == 3, "premise: a cylinder has 3 faces (2 caps + 1 lateral)")
        let result = cyl.dividedByNumber(4)
        #expect(
            result?.faces().count == 6,
            "expected 2 unsplit caps + 4 lateral-face parts = 6; got \(String(describing: result?.faces().count))"
        )
    }
}
