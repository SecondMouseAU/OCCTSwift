import Foundation
import Testing

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

    /// A 10x10 face on z=0 with a hole that crosses the outer wire.
    ///
    /// The hole runs from x=8 to x=12, so it crosses the outer wire at x=10. It is also wound
    /// the same way as the outer wire, which `ShapeFix_Face` would repair too, but the defect
    /// these tests use it for is the crossing.
    ///
    /// Built from raw `builderAdd` primitives so no fixing runs during construction.
    private func faceWithCrossingHole() throws -> Shape {
        let outer = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true))
        let face = try #require(Shape.face(from: outer))
        let hole = try #require(Shape.builderMakeWire())
        let corners: [SIMD3<Double>] = [
            SIMD3(8, 4, 0), SIMD3(12, 4, 0), SIMD3(12, 6, 0), SIMD3(8, 6, 0),
        ]
        for i in 0..<corners.count {
            let line = try #require(Wire.line(from: corners[i], to: corners[(i + 1) % 4]))
            let edge = try #require(line.edges().first)
            let edgeShape = try #require(Shape.fromEdge(edge))
            edgeShape.setOrientation(.reversed)
            try #require(hole.builderAdd(edgeShape), "could not add hole edge \(i)")
        }
        hole.setOrientation(.reversed)
        try #require(face.builderAdd(hole), "could not add the hole wire to the face")
        // The fixture means its name only if BRepCheck itself sees the crossing.
        try #require(
            face.checkFaceIntersectingWires() == .intersectingWires,
            "the hole does not cross the outer wire")
        return face
    }

    @Test("FaceFixer per-pass control: set modes, perform, read result/status")
    func faceFixerControl() throws {
        let face = try #require(planarFace(), "setup")
        let fixer = try #require(FaceFixer(face: face), "setup")
        // Toggle individual passes (the natural-bound pass is the one that ballooned a face earlier).
        fixer.setMode(.addNaturalBound, .off)
        fixer.setMode(.orientation, .on)
        fixer.setMode(.intersectingWires, .auto)
        // #766: pinned to ShapeFix_Face on the same face with the same modes
        // (Scripts/repro/766-healing-1638-266-318-438): Perform() reports nothing to do, status
        // OK set, DONE and FAIL clear.
        #expect(fixer.perform() == false)
        #expect(fixer.status(.ok))
        #expect(!fixer.status(.done))
        #expect(!fixer.status(.fail))
        let r = try #require(fixer.result, "FaceFixer returned no result")
        let f = try #require(fixer.face, "FaceFixer returned no face")
        #expect(r.isValid)
        #expect(f.isValid)
        #expect(abs((f.surfaceArea ?? 0) - 100) < 1e-9)
    }

    /// The contrast the test above lacks: a face that does need fixing, with the same pass on.
    ///
    /// Measured on the pinned kernel: `perform()` returns true with status DONE set and OK and
    /// FAIL clear, and the result passes the orientation check the input fails. Without it, a
    /// `perform`/`status` wired to constants reads the same on the clean face.
    @Test("FaceFixer reports a repair when the face needs one, with the orientation pass on")
    func faceFixerReportsARepair() throws {
        let bad = try #require(badHoleOrientationFace())
        try #require(bad.checkFaceWireOrientation() == .badOrientationOfSubshape)
        let fixer = try #require(FaceFixer(face: bad), "setup")
        fixer.setMode(.orientation, .on)
        #expect(fixer.perform() == true)
        #expect(!fixer.status(.ok))
        #expect(fixer.status(.done))
        #expect(!fixer.status(.fail))
        let result = try #require(fixer.result, "FaceFixer returned no result")
        #expect(result.checkFaceWireOrientation() == .noError)
        #expect(result.isValid)
        // The hole is subtracted once the winding is right: 100 - 4 = 96, not 100 + 4.
        #expect(abs((result.surfaceArea ?? 0) - 96) < 1e-9)
    }

    @Test("FaceFixer individual fix passes run without crashing")
    func faceFixerIndividualPasses() throws {
        let face = try #require(planarFace(), "setup")
        let fixer = try #require(FaceFixer(face: face), "setup")
        // #766: these were `_ =`, discarding the answer. On a clean face the kernel reports
        // that none of the four passes had anything to fix.
        #expect(fixer.fixIntersectingWires() == false)
        #expect(fixer.fixWiresTwoCoincEdges() == false)
        #expect(fixer.fixLoopWire() == false)
        #expect(fixer.fixPeriodicDegenerated() == false)
        let kept = try #require(fixer.face, "the fixer lost its face")
        #expect(abs((kept.surfaceArea ?? 0) - 100) < 1e-9)
    }

    /// The control for the four negative answers above, for the one pass with a cheap defect.
    ///
    /// The defect is a hole crossing the outer wire. Measured: `fixIntersectingWires()` returns
    /// true on it and the other three stay false, since the crossing is not a loop or a
    /// coincident-edge pair.
    @Test("fixIntersectingWires reports a repair on a hole that crosses the outer wire")
    func fixIntersectingWiresReportsARepair() throws {
        let crossing = try faceWithCrossingHole()
        let fixer = try #require(FaceFixer(face: crossing), "setup")
        #expect(fixer.fixIntersectingWires() == true)
        let other = try #require(FaceFixer(face: crossing), "setup")
        #expect(other.fixWiresTwoCoincEdges() == false)
        #expect(other.fixLoopWire() == false)
        #expect(other.fixPeriodicDegenerated() == false)
    }

    @Test("BRepCheck_Face diagnostics: a clean face passes all three")
    func checkCleanFace() throws {
        let face = try #require(planarFace(), "setup")
        #expect(face.checkFaceIntersectingWires() == .noError)
        #expect(face.checkFaceWireImbrication() == .noError)
        #expect(face.checkFaceWireOrientation() == .noError)
        // Controls, so `.noError` is the face's answer and not a constant: a hole that crosses the
        // outer wire trips all three checks, and a hole wound like the outer wire trips only the
        // orientation check. Measured on the pinned kernel.
        let crossing = try faceWithCrossingHole()
        #expect(crossing.checkFaceIntersectingWires() == .intersectingWires)
        #expect(crossing.checkFaceWireImbrication() == .intersectingWires)
        #expect(crossing.checkFaceWireOrientation() == .intersectingWires)
        let wound = try #require(badHoleOrientationFace())
        #expect(wound.checkFaceIntersectingWires() == .noError)
        #expect(wound.checkFaceWireImbrication() == .noError)
        #expect(wound.checkFaceWireOrientation() == .badOrientationOfSubshape)
    }

    @Test("BRepCheck_Face diagnostics: a non-face yields checkFail")
    func checkNonFace() throws {
        let box = try #require(Shape.box(width: 1, height: 1, depth: 1), "setup")
        #expect(box.checkFaceIntersectingWires() == .checkFail)
        #expect(box.checkFaceWireOrientation() == .checkFail)
        #expect(box.checkFaceWireImbrication() == .checkFail)
    }
}
