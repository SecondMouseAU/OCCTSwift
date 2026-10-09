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
        fixer.perform()
        // Result/face are retrievable and valid; a clean face needs no failure-level fix.
        if let r = fixer.result { #expect(r.isValid) }
        if let f = fixer.face { #expect(f.isValid) }
        #expect(!fixer.status(.fail))
    }

    @Test("FaceFixer individual fix passes run without crashing")
    func faceFixerIndividualPasses() {
        guard let face = planarFace(), let fixer = FaceFixer(face: face) else {
            Issue.record("setup")
            return
        }
        // These must execute and return a Bool (no crash) on a clean face.
        _ = fixer.fixIntersectingWires()
        _ = fixer.fixWiresTwoCoincEdges()
        _ = fixer.fixLoopWire()
        _ = fixer.fixPeriodicDegenerated()
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
