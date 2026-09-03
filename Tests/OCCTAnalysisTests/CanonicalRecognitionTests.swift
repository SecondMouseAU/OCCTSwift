import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Canonical Recognition")
struct CanonicalRecognitionTests {
    /// Find the sub-face of `shape` whose analytic surface matches `surfaceType`.
    private func face(of shape: Shape, surfaceType: Face.SurfaceType) -> Shape? {
        shape.subShapes(ofType: .face).first { Face($0)?.surfaceType == surfaceType }
    }

    @Test("Canonical recognition callable on box")
    func recognizeCallableOnBox() {
        // ShapeAnalysis_CanonicalRecognition (the OCCT class backing recognizeCanonical()) has no
        // overload for TopoDS_Solid/TopoDS_Compound at all -- only Face, Shell, Edge, Wire -- so a
        // whole solid box is never recognized, independent of #1509's ClearStatus fix. Ground-truthed
        // directly against the pinned kernel: IsPlane on a box's own TopoDS_Solid returns false with
        // myStatus left at 1. Individual-face recognition (what #1509 actually fixed) is covered by
        // recognizeCylinderFace/recognizeConeFace/recognizeSphereFace/recognizeLineEdge below.
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.recognizeCanonical() == nil)
    }

    @Test("Canonical recognition callable on cylinder")
    func recognizeCallableOnCylinder() {
        // Same TopoDS_Solid limitation as recognizeCallableOnBox above: a whole cylinder solid is
        // never recognized by this OCCT API, before or after #1509's fix.
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        #expect(cyl.recognizeCanonical() == nil)
    }

    // MARK: - #1509 regression
    //
    // OCCTShapeRecognizeCanonical (OCCTBridge_Surface_Analysis.mm) runs
    // IsPlane -> IsCylinder -> IsCone -> IsSphere -> IsLine -> IsCircle -> IsEllipse on one
    // ShapeAnalysis_CanonicalRecognition instance. Every IsX (barring IsPlane, the first) starts
    // with `if (myStatus != 0) return false;`, and a failed IsPlane/IsCylinder/IsCone/IsSphere
    // check leaves myStatus == 1 (an ordinary "not this type" outcome sets it, not just a genuine
    // error), so without a ClearStatus() between checks, every check past the first that would
    // have succeeded is silently short-circuited to false. Ground-truthed directly against the
    // pinned kernel with the bridge's own exact check sequence, with and without the fix: each
    // fixture below reported type=0 (Unrecognized) before ClearStatus() was added and its true
    // type afterwards.

    @Test("Recognizes a cylindrical face")
    func recognizeCylinderFace() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let cylFace = face(of: cyl, surfaceType: .cylinder)
        else {
            Issue.record("failed to build cylinder / find its cylindrical face")
            return
        }
        guard let form = cylFace.recognizeCanonical() else {
            Issue.record("cylindrical face was not recognized at all")
            return
        }
        #expect(form.type == .cylinder)
        #expect(abs(form.radius - 5) < 1e-6)
    }

    @Test("Recognizes a conical face")
    func recognizeConeFace() {
        guard let cone = Shape.cone(bottomRadius: 5, topRadius: 0, height: 10),
            let coneFace = face(of: cone, surfaceType: .cone)
        else {
            Issue.record("failed to build cone / find its conical face")
            return
        }
        guard let form = coneFace.recognizeCanonical() else {
            Issue.record("conical face was not recognized at all")
            return
        }
        #expect(form.type == .cone)
        #expect(abs(form.radius - 5) < 1e-6)
    }

    @Test("Recognizes a spherical face")
    func recognizeSphereFace() {
        guard let sph = Shape.sphere(radius: 5),
            let sphFace = face(of: sph, surfaceType: .sphere)
        else {
            Issue.record("failed to build sphere / find its spherical face")
            return
        }
        guard let form = sphFace.recognizeCanonical() else {
            Issue.record("spherical face was not recognized at all")
            return
        }
        #expect(form.type == .sphere)
        #expect(abs(form.radius - 5) < 1e-6)
    }

    @Test("Recognizes a straight-line edge")
    func recognizeLineEdge() {
        // IsPlane correctly fails on a bare line (a single line doesn't determine a unique plane)
        // but still leaves myStatus == 1 behind, which -- pre-fix -- poisons IsCylinder, IsCone and
        // IsSphere in turn, so myStatus is still 1 by the time the sequence reaches IsLine.
        guard let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)),
            let edge = Shape.edgeFromCurve(line, u1: 0, u2: 10)
        else {
            Issue.record("failed to build the line edge fixture")
            return
        }
        guard let form = edge.recognizeCanonical() else {
            Issue.record("line edge was not recognized at all")
            return
        }
        #expect(form.type == .line)
    }
}
