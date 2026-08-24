import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #837: `Shape.fixed(tolerance:fixSolid:fixShell:fixFace:fixWire:)`'s `fixShell`/`fixFace`/
/// `fixWire` parameters were accepted but never passed to the underlying `ShapeFix_Shape` --
/// only `fixSolid` had any effect (`OCCTShapeFixDetailed`, `OCCTBridge_Healing.mm`). A caller
/// passing `fixFace: false` silently got `ShapeFix_Shape`'s own always-on default
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

    /// A face with a hole wire wound the *same* rotational sense as the outer wire -- a genuine
    /// `BRepCheck_Face` wire-orientation defect a correct hole must avoid. Built via the raw
    /// `Shape.builderMakeWire()`/`.builderAdd(_:)`/`.setOrientation(_:)` primitives (same as
    /// `Issue655FreeBoundsInternalOrientationTests`) so no automatic orientation correction runs
    /// during construction -- `Shape.face(from:outer:innerWires:)` would fix the hole's
    /// orientation itself via `ShapeFix_Face`, which would defeat this fixture's purpose.
    static func badHoleOrientationFace() -> Shape? {
        guard
            let outerWire = Wire.polygon3D(
                [SIMD3(-5, -5, 0), SIMD3(5, -5, 0), SIMD3(5, 5, 0), SIMD3(-5, 5, 0)], closed: true
            ), let face = Shape.face(from: outerWire)
        else { return nil }

        // Same winding (CCW, viewed from +Z) as the outer wire -- should be the opposite for a
        // valid hole.
        let holePoints: [SIMD3<Double>] = [
            SIMD3(-1, -1, 0), SIMD3(1, -1, 0), SIMD3(1, 1, 0), SIMD3(-1, 1, 0),
        ]
        guard let holeWireShape = Shape.builderMakeWire() else { return nil }
        for i in 0..<holePoints.count {
            guard
                let edgeWire = Wire.line(
                    from: holePoints[i], to: holePoints[(i + 1) % holePoints.count]),
                let edge = edgeWire.edges().first,
                let edgeShape = Shape.fromEdge(edge)
            else { return nil }
            edgeShape.setOrientation(.forward)
            guard holeWireShape.builderAdd(edgeShape) else { return nil }
        }
        holeWireShape.setOrientation(.forward)
        guard face.builderAdd(holeWireShape) else { return nil }
        return face
    }

    @Test("Fixture actually has the wire-orientation defect it claims to")
    func fixtureHasBadOrientation() {
        guard let face = Self.badHoleOrientationFace() else {
            Issue.record("fixture build failed")
            return
        }
        #expect(face.checkFaceWireOrientation() == .badOrientationOfSubshape)
    }

    @Test("fixFace: false leaves a free face's wire-orientation defect uncorrected")
    func fixFaceFalseLeavesDefectInPlace() {
        guard let badFace = Self.badHoleOrientationFace(),
            let compound = Shape.compound([badFace])
        else {
            Issue.record("fixture build failed")
            return
        }
        guard
            let result = compound.fixed(
                tolerance: 1e-6, fixSolid: true, fixShell: true,
                fixFace: false, fixWire: true),
            let resultFace = result.subShapes(ofType: .face).first
        else {
            Issue.record("fixed(fixFace: false) produced no face")
            return
        }
        #expect(resultFace.checkFaceWireOrientation() == .badOrientationOfSubshape)
    }

    @Test("fixFace: true corrects a free face's wire-orientation defect")
    func fixFaceTrueCorrectsDefect() {
        guard let badFace = Self.badHoleOrientationFace(),
            let compound = Shape.compound([badFace])
        else {
            Issue.record("fixture build failed")
            return
        }
        guard
            let result = compound.fixed(
                tolerance: 1e-6, fixSolid: true, fixShell: true,
                fixFace: true, fixWire: true),
            let resultFace = result.subShapes(ofType: .face).first
        else {
            Issue.record("fixed(fixFace: true) produced no face")
            return
        }
        #expect(resultFace.checkFaceWireOrientation() == .noError)
    }
}
