import Foundation
import Testing

@testable import OCCTSwift

/// #1640: three bridge functions in the healing family were declared, defined, compiled into every
/// build and called from nothing. All three turned out to be duplicates of a function that already
/// has a Swift caller, so all three are deleted and no new Swift API replaces them.
///
/// Deleting a duplicate is only safe if the survivor is actually tested, and the survivors were
/// not. `dividedByParts(4)` asserted `> 6` faces and `dividedClosedFaces()` asserted
/// `>= origFaces`, both of which a splitter that split nothing would pass. These are the
/// assertions that would have failed.
@Suite("Issue #1640: the surviving splitters actually split")
struct Issue1640DuplicateSplittersTests {

    // MARK: - Shape.dividedByParts, the survivor of OCCTShapeUpgradeSplitSurfaceArea

    @Test("a cube's six faces become twenty-four quarters")
    func dividedByPartsSplitsIntoQuarters() throws {
        let cube = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(cube.subShapes(ofType: .face).count == 6)

        let split = try #require(cube.dividedByParts(4))
        #expect(split.subShapes(ofType: .face).count == 24, "6 faces * 4 parts")

        let areas = split.faces().map { $0.area() }
        #expect(areas.count == 24)
        for area in areas {
            #expect(abs(area - 25.0) < 1e-6, "each piece is a quarter of a 10 x 10 face")
        }
        #expect(abs(areas.reduce(0, +) - 600.0) < 1e-6, "and the total surface area is preserved")
    }

    @Test("it is not dividedByNumber under another name")
    func dividedByPartsDiffersFromDividedByNumber() throws {
        // ShapeUpgrade_ShapeDivideArea derives a roughly-square U/V grid from the part count;
        // dividedByNumber forces every cut onto U. On a box whose faces are not square the two
        // reach different topologies, which is what makes them different tools rather than two
        // spellings of one.
        let box = try #require(Shape.box(width: 10, height: 20, depth: 10))
        #expect(try #require(box.dividedByParts(2)).subShapes(ofType: .face).count == 18)
        #expect(try #require(box.dividedByNumber(2)).subShapes(ofType: .face).count == 10)
    }

    @Test("the volume is preserved exactly, and a two-axis split comes back invalid")
    func dividedByPartsVolumeAndValidity() throws {
        let cube = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let before = try #require(cube.volume)

        let twoAxis = try #require(cube.dividedByParts(4))
        #expect(abs(try #require(twoAxis.volume) - before) / before < 1e-9, "1000, exactly")
        // Measured: a 2 x 2 split of each face is BRepCheck-invalid, and it is the two-axis split
        // that does it rather than this entry point. OCCTShapeDivideByNumber(shape, 2, 2) is
        // equally invalid; dividedByNumber never meets it because it pins nbV to 1.
        // Scripts/repro/1640/transcript.txt block 5.
        #expect(!twoAxis.isValid)

        let oneAxis = try #require(cube.dividedByParts(2))
        #expect(oneAxis.subShapes(ofType: .face).count == 12)
        #expect(abs(try #require(oneAxis.volume) - before) / before < 1e-9)
        #expect(oneAxis.isValid, "2 parts is a 2 x 1 split, and that one is valid")
        #expect(try #require(cube.dividedByNumber(4)).isValid)
    }

    @Test("a part count that cannot split anything is a refusal, not an unchanged shape")
    func dividedByPartsTrivialCounts() throws {
        let cube = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // Measured: 1 part reaches ShapeUpgrade_ShapeDivideArea, whose Perform() returns false
        // because there is nothing to split, and the bridge turns that into nil. 0 and negative
        // counts are refused by the bridge before OCCT sees them.
        #expect(cube.dividedByParts(1) == nil)
        #expect(cube.dividedByParts(0) == nil)
        #expect(cube.dividedByParts(-3) == nil)
    }

    // MARK: - Shape.dividedClosedFaces, the survivor of OCCTShapeUpgradeClosedFaceDivide

    @Test("each split point adds exactly one face to a cylinder's closed lateral face")
    func dividedClosedFacesSplitsTheSeamFace() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cylinder.subShapes(ofType: .face).count == 3, "two planar caps, one closed wall")

        for (splitPoints, expected) in [(1, 4), (2, 5), (3, 6)] {
            let divided = try #require(cylinder.dividedClosedFaces(splitPoints: splitPoints))
            #expect(
                divided.subShapes(ofType: .face).count == expected,
                "splitPoints \(splitPoints): the wall becomes \(splitPoints + 1) faces, caps untouched")
            #expect(abs(try #require(divided.volume) - #require(cylinder.volume)) < 1e-6)
        }
    }

    @Test("a shape with no closed face is refused, not returned unchanged")
    func dividedClosedFacesRefusesAShapeWithNothingToDo() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // No face of a box wraps onto itself, so ShapeUpgrade_ShapeDivideClosed::Perform() returns
        // false and the bridge turns that into nil. Worth pinning: nil here means "nothing to do",
        // not "the operation failed", and a caller that treats it as an error will be wrong.
        #expect(box.dividedClosedFaces(splitPoints: 2) == nil)
    }
}
