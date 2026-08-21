import Testing
import simd
@testable import OCCTSwift

/// Issue #274: `Shape.face(outer:holes:)` (bridge `OCCTShapeCreateFaceWithHoles`) used to reverse
/// EVERY hole wire unconditionally. That is only correct when the caller passes a hole wound the
/// SAME way as the outer; a hole passed already wound OPPOSITE (the geometrically correct sense for
/// a hole) was flipped back to WRONG, producing an invalid face / an un-subtracted hole.
///
/// The fix makes the reversal CONDITIONAL: each hole is reversed only when its winding currently
/// matches the outer's (decided by the sign of its signed area in the face plane). Either input
/// winding must therefore yield the SAME valid face with the hole correctly subtracted.
///
/// Both tests below use the SAME geometry (a 10×10 outer CCW square with a 4×4 centred hole); the
/// only difference is the hole's authored winding, so the winding is the sole discriminator. A
/// regression to unconditional-reverse breaks the "already opposite" case and this suite fails loudly.
@Suite("Issue #274, hole wire orientation is corrected conditionally")
struct Issue274HoleWireOrientationTests {

    // 10×10 outer square, authored COUNTER-CLOCKWISE (right, up, left, down). Area = 100.
    private func outerCCW() -> Wire? {
        Wire.polygon3D([
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)
        ], closed: true)
    }

    // 4×4 centred hole authored CLOCKWISE, i.e. OPPOSITE the CCW outer (the correct hole sense).
    private func holeCW() -> Wire? {
        Wire.polygon3D([
            SIMD3(3, 3, 0), SIMD3(3, 7, 0), SIMD3(7, 7, 0), SIMD3(7, 3, 0)
        ], closed: true)
    }

    // 4×4 centred hole authored COUNTER-CLOCKWISE, i.e. the SAME sense as the outer.
    private func holeCCW() -> Wire? {
        Wire.polygon3D([
            SIMD3(3, 3, 0), SIMD3(7, 3, 0), SIMD3(7, 7, 0), SIMD3(3, 7, 0)
        ], closed: true)
    }

    private let expectedArea = 100.0 - 16.0  // outer 100 − hole 16 = 84

    /// Hole passed ALREADY OPPOSITE the outer (CW vs CCW), the correct winding a caller may already
    /// have. This is the case the old unconditional reverse BROKE. Must produce a valid, subtracted face.
    @Test("hole wound opposite the outer (CW) → valid face, hole subtracted")
    func holeAlreadyOppositeIsKept() {
        guard let outer = outerCCW(), let hole = holeCW() else { Issue.record("setup"); return }
        guard let face = Shape.face(outer: outer, holes: [hole]) else {
            Issue.record("face(outer:holes:) returned nil for opposite-wound hole"); return
        }
        #expect(face.isValid)
        #expect(face.subShapeCount(ofType: .wire) == 2)  // outer + one real hole
        guard let area = face.surfaceArea else { Issue.record("no surfaceArea"); return }
        #expect(abs(area - expectedArea) < 1e-6)
    }

    /// Hole passed the SAME way as the outer (CCW), the function must still correct it. Must produce
    /// the identical valid, subtracted face.
    @Test("hole wound same as the outer (CCW) → still corrected, hole subtracted")
    func holeSameSenseIsReversed() {
        guard let outer = outerCCW(), let hole = holeCCW() else { Issue.record("setup"); return }
        guard let face = Shape.face(outer: outer, holes: [hole]) else {
            Issue.record("face(outer:holes:) returned nil for same-wound hole"); return
        }
        #expect(face.isValid)
        #expect(face.subShapeCount(ofType: .wire) == 2)
        guard let area = face.surfaceArea else { Issue.record("no surfaceArea"); return }
        #expect(abs(area - expectedArea) < 1e-6)
    }

    /// Both windings must agree: same geometry, same result regardless of authored hole winding.
    @Test("both hole windings produce the same valid subtracted face")
    func bothWindingsAgree() {
        guard let outer1 = outerCCW(), let outer2 = outerCCW(),
              let hCW = holeCW(), let hCCW = holeCCW() else { Issue.record("setup"); return }
        guard let faceFromCW = Shape.face(outer: outer1, holes: [hCW]),
              let faceFromCCW = Shape.face(outer: outer2, holes: [hCCW]) else {
            Issue.record("one of the faces was nil"); return
        }
        #expect(faceFromCW.isValid)
        #expect(faceFromCCW.isValid)
        let aCW = faceFromCW.surfaceArea ?? -1
        let aCCW = faceFromCCW.surfaceArea ?? -2
        #expect(abs(aCW - expectedArea) < 1e-6)
        #expect(abs(aCCW - expectedArea) < 1e-6)
        #expect(abs(aCW - aCCW) < 1e-9)
    }
}
