import Foundation
import Testing

@testable import OCCTSwift

/// #2769: the two `ShapeUpgrade_ShapeDivideArea` entry points, from opposite directions.
///
/// `Shape.dividedByParts(_:)` gated on `Perform()` alone, so `parts: 1` (nothing to split) came back
/// as `nil`, which `docs/reference/Shape-Measurement.md` documented as "a failure, not a no-op".
/// `Shape.dividedByArea(maxArea:)` read no failure signal at all, which is the other half of the
/// same mistake. OCCT tests both together: `ShapeProcess_OperLibrary.cxx` uses
/// `if (!tool.Perform() && tool.Status(ShapeExtend_FAIL))` at all five of its family call sites.
///
/// `OCCTShapeDivideByParts` also had no `Result().IsNull()` check, unlike every sibling, so the
/// `Perform()` gate was its only failure signal. #2769 adds it.
///
/// Measured in `Scripts/repro/2765-convert-to-bezier-perform/`.
@Suite("Issue #2769: nothing to split is not a failure (area splitting)")
struct Issue2769DivideAreaTests {

    @Test("dividedByParts(1) returns the cube, and 2 still splits it")
    func dividedByPartsReturnsTheInputWhenOnePartIsAsked() throws {
        let cube = try #require(Shape.box(width: 10, height: 10, depth: 10))

        // One part per face is no split at all. Before #2769 this was nil.
        let unchanged = try #require(cube.dividedByParts(1))
        #expect(unchanged.subShapes(ofType: .face).count == 6)
        #expect(unchanged.isSame(as: cube), "Result() is the input shape, not a rebuild of it")
        #expect(abs(try #require(unchanged.volume) - 1000.0) < 1e-6)

        // Control.
        let split = try #require(cube.dividedByParts(2))
        #expect(split.subShapes(ofType: .face).count == 12)
        #expect(!split.isSame(as: cube))

        // A count OCCT never sees: the bridge refuses these before constructing the tool, so they
        // stay nil and the change does not widen what the function accepts.
        #expect(cube.dividedByParts(0) == nil)
        #expect(cube.dividedByParts(-3) == nil)
    }

    @Test("dividedByArea with a threshold no face reaches returns the box, not nil")
    func dividedByAreaReturnsTheInputWhenNoFaceExceedsTheThreshold() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))

        // This entry point already ignored `Perform()`, so this half was correct before #2769 and
        // is pinned here so that restoring a bare `if (!divider.Perform()) return nullptr;` fails.
        let unchanged = try #require(box.dividedByArea(maxArea: 1e6))
        #expect(unchanged.subShapes(ofType: .face).count == 6)
        #expect(unchanged.isSame(as: box))

        // Control: a 10 x 20 face is 200, so a 50 threshold has work to do.
        let split = try #require(box.dividedByArea(maxArea: 50))
        #expect(split.subShapes(ofType: .face).count > 6)
        #expect(!split.isSame(as: box))
        #expect(abs(try #require(split.volume) - 6000.0) < 1e-6)
    }
}
