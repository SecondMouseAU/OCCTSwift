import Foundation
import Testing

@testable import OCCTSwift

/// #837: Shape.fixed(tolerance:fixSolid:fixShell:fixFace:fixWire:)'s `fixShell`/`fixFace`/
/// `fixWire` parameters were accepted but never passed to the underlying `ShapeFix_Shape` --
/// only `fixSolid` had any effect (`OCCTShapeFixDetailed`, `OCCTBridge_Healing.mm`).
///
/// A caller
/// passing `fixFace: false` silently got ShapeFix_Shape's own always-on default
/// (`FixFreeFaceMode()`) instead, with no error and nothing in the return value to reveal it.
///
/// This suite proves the fix with a fixture `ShapeFix_Face::FixOrientation` (run as part of
/// fixing a *free* face -- one not attached to a shell) reliably corrects: a face whose hole
/// wire is wound the same rotational sense as its outer wire, instead of the opposite sense a
/// valid hole needs. `BRepCheck_Face`'s own orientation check
/// (`Shape.checkFaceWireOrientation()`) reports `.badOrientationOfSubshape` on the raw fixture
/// and `.noError` once `ShapeFix_Face` has corrected it.
///
/// Ground-truth verified directly against the pinned kernel with a standalone C++ reproducer
/// (`clang++` against `OCCT.xcframework`, per CLAUDE.md's "Compile a Ground Truth C++ Test")
/// before writing this fixture: it built the identical shape and confirmed
/// `FixFreeFaceMode() = 1` changes `BRepCheck_Face::OrientationOfWires()` from
/// `BRepCheck_BadOrientationOfSubshape` (32) to `BRepCheck_NoError` (0), while `= 0` leaves it at
/// `BadOrientationOfSubshape` -- the exact two branches `fixFace: true`/`fixFace: false` are
/// meant to reach.
///
/// **Prove-the-test-fails record (okf/policies/prove-the-test-fails.md):** run against the
/// pre-fix bridge (only `FixSolidMode()` wired up, `fixFace` accepted and discarded),
/// `fixFaceFalseLeavesDefectInPlace` failed -- `ShapeFix_Shape`'s own `FixFreeFaceMode` default
/// (always on) fixed the orientation even though `fixFace: false` asked it not to, so the result
/// read `.noError` instead of the expected `.badOrientationOfSubshape`. Restoring the three
/// `FixFree*Mode()` assignments in `OCCTShapeFixDetailed` made it pass, and
/// `fixFaceTrueCorrectsDefect` passed throughout (both branches ran the fix before the change,
/// since the dead parameter meant it always ran).
@Suite("#837: fixed() mode-flag wiring")
struct Issue837FixDetailedModeFlagsTests {

    @Test("Fixture actually has the wire-orientation defect it claims to")
    func fixtureHasBadOrientation() throws {
        let face = try #require(badHoleOrientationFace(), "fixture build failed")
        #expect(face.checkFaceWireOrientation() == .badOrientationOfSubshape)
        // The wrong winding makes the 2x2 hole ADD to the face's area: 10x10 plus 2x2 is 104, where
        // a correctly wound hole gives 96. Both tests below pin their result against these two.
        #expect(abs((face.surfaceArea ?? 0) - 104) < 1e-9)
    }

    @Test("fixFace: false leaves a free face's wire-orientation defect uncorrected")
    func fixFaceFalseLeavesDefectInPlace() throws {
        let badFace = try #require(badHoleOrientationFace(), "fixture build failed")
        let compound = try #require(Shape.compound([badFace]), "fixture build failed")
        let result = try #require(
            compound.fixed(
                tolerance: 1e-6, fixSolid: true, fixShell: true,
                fixFace: false, fixWire: true),
            "fixed(fixFace: false) returned nil")
        let faces = result.subShapes(ofType: .face)
        try #require(faces.count == 1, "fixed(fixFace: false) gave \(faces.count) faces, not 1")
        let resultFace = try #require(faces.first)
        #expect(resultFace.checkFaceWireOrientation() == .badOrientationOfSubshape)
        // Measured on the pinned kernel: the hole still adds, 104, and keeps both wires.
        #expect(abs((resultFace.surfaceArea ?? 0) - 104) < 1e-9)
        #expect(resultFace.subShapeCount(ofType: .wire) == 2)
    }

    @Test("fixFace: true corrects a free face's wire-orientation defect")
    func fixFaceTrueCorrectsDefect() throws {
        let badFace = try #require(badHoleOrientationFace(), "fixture build failed")
        let compound = try #require(Shape.compound([badFace]), "fixture build failed")
        let result = try #require(
            compound.fixed(
                tolerance: 1e-6, fixSolid: true, fixShell: true,
                fixFace: true, fixWire: true),
            "fixed(fixFace: true) returned nil")
        let faces = result.subShapes(ofType: .face)
        try #require(faces.count == 1, "fixed(fixFace: true) gave \(faces.count) faces, not 1")
        let resultFace = try #require(faces.first)
        #expect(resultFace.checkFaceWireOrientation() == .noError)
        // Measured on the pinned kernel: the hole is now subtracted, 96, and both wires survive.
        #expect(abs((resultFace.surfaceArea ?? 0) - 96) < 1e-9)
        #expect(resultFace.subShapeCount(ofType: .wire) == 2)
    }
}
