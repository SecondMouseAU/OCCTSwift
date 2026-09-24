import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #266 follow-up: ShapeFix_Face control + BRepCheck_Face diagnostics

@Suite("Issue #266 follow-up, face healing control & checks")
struct Issue266FaceHealingControlTests {

    /// A 10×10 planar face on the z=0 plane.
    private func planarFace() -> Shape? {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
            let outer = Wire.polygon3D(
                [
                    SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0),
                ], closed: true)
        else { return nil }
        return Shape.face(from: plane, outer: outer, innerWires: [])
    }

    @Test("FaceFixer per-pass control: set modes, perform, read result/status")
    func faceFixerControl() {
        guard let face = planarFace(), let fixer = FaceFixer(face: face) else {
            Issue.record("setup")
            return
        }
        // Toggle individual passes (the natural-bound pass is the one that ballooned a face earlier).
        fixer.setMode(.addNaturalBound, .off)
        fixer.setMode(.orientation, .on)
        fixer.setMode(.intersectingWires, .auto)
        // #766: pinned to ShapeFix_Face on the same face with the same modes
        // (Scripts/repro/766-healing-1638-266-318-438): Perform() reports nothing to do, status
        // OK set, DONE and FAIL clear. Before #766 the result/face checks sat inside `if let`,
        // and `!status(.fail)` was the only unconditional assertion.
        #expect(fixer.perform() == false)
        #expect(fixer.status(.ok))
        #expect(!fixer.status(.done))
        #expect(!fixer.status(.fail))
        guard let r = fixer.result, let f = fixer.face else {
            Issue.record("FaceFixer returned no result or face")
            return
        }
        #expect(r.isValid)
        #expect(f.isValid)
        #expect(abs((f.surfaceArea ?? 0) - 100) < 1e-9)
    }

    @Test("FaceFixer individual fix passes run without crashing")
    func faceFixerIndividualPasses() {
        guard let face = planarFace(), let fixer = FaceFixer(face: face) else {
            Issue.record("setup")
            return
        }
        // #766: these were `_ =`, discarding the answer. On a clean face the kernel reports
        // that none of the four passes had anything to fix.
        #expect(fixer.fixIntersectingWires() == false)
        #expect(fixer.fixWiresTwoCoincEdges() == false)
        #expect(fixer.fixLoopWire() == false)
        #expect(fixer.fixPeriodicDegenerated() == false)
        #expect(fixer.face != nil)
    }

    @Test("BRepCheck_Face diagnostics: a clean face passes all three")
    func checkCleanFace() {
        guard let face = planarFace() else {
            Issue.record("setup")
            return
        }
        #expect(face.checkFaceIntersectingWires() == .noError)
        #expect(face.checkFaceWireImbrication() == .noError)
        #expect(face.checkFaceWireOrientation() == .noError)
    }

    @Test("BRepCheck_Face diagnostics: a non-face yields checkFail")
    func checkNonFace() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1) else {
            Issue.record("setup")
            return
        }
        #expect(box.checkFaceIntersectingWires() == .checkFail)
        #expect(box.checkFaceWireOrientation() == .checkFail)
    }
}
