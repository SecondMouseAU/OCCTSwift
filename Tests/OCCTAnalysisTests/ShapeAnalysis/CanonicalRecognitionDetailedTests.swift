import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("CanonicalRecognition Detailed Tests")
struct CanonicalRecognitionDetailedTests {
    /// Find the sub-face of `shape` whose analytic surface matches `surfaceType`.
    private func face(of shape: Shape, surfaceType: Face.SurfaceType) -> Shape? {
        shape.subShapes(ofType: .face).first { Face($0)?.surfaceType == surfaceType }
    }

    @Test func recognizePlane() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let result = face.recognizeCanonicalSurface()
                #expect(result.type == .plane)
            }
        }
    }

    // MARK: - #1509 regression
    //
    // OCCTShapeRecognizeCanonicalSurface (OCCTBridge_Healing_Analysis.mm) runs
    // IsPlane -> IsCylinder -> IsCone -> IsSphere on one ShapeAnalysis_CanonicalRecognition
    // instance, the same no-ClearStatus()-between-checks bug as OCCTShapeRecognizeCanonical
    // (CanonicalRecognitionTests.swift). These three tests used to call it on the *whole* cylinder
    // /cone/sphere solid and hedge on the result ("May or may not recognize, depends on which face
    // is checked first" / "Sphere has a single face, should recognize"): ground-truthed directly
    // that neither claim was ever true -- ShapeAnalysis_CanonicalRecognition has no
    // TopoDS_Solid/TopoDS_Compound overload at all (only Face/Shell/Edge/Wire), so a whole solid,
    // single-face or not, is *never* recognized, before or after #1509's fix, and "depends on which
    // face is checked first" doesn't apply since no face is ever individually checked. Fixed to
    // recognize the shape's own single relevant face instead, which is what #1509 actually affects:
    // ground-truthed with and without ClearStatus() that each fixture below reports type=0
    // (Unrecognized) before the fix and its true type afterwards.

    @Test func recognizeCylinder() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let cylFace = face(of: cyl, surfaceType: .cylinder)
        else {
            Issue.record("failed to build cylinder / find its cylindrical face")
            return
        }
        let result = cylFace.recognizeCanonicalSurface()
        #expect(result.type == .cylinder)
        #expect(abs(result.param1 - 5) < 1e-6)
    }

    @Test func recognizeCone() {
        guard let cone = Shape.cone(bottomRadius: 5, topRadius: 0, height: 10),
            let coneFace = face(of: cone, surfaceType: .cone)
        else {
            Issue.record("failed to build cone / find its conical face")
            return
        }
        let result = coneFace.recognizeCanonicalSurface()
        #expect(result.type == .cone)
        #expect(abs(result.param1 - 5) < 1e-6)
    }

    @Test func recognizeSphere() {
        guard let sph = Shape.sphere(radius: 5),
            let sphFace = face(of: sph, surfaceType: .sphere)
        else {
            Issue.record("failed to build sphere / find its spherical face")
            return
        }
        let result = sphFace.recognizeCanonicalSurface()
        #expect(result.type == .sphere)
        #expect(abs(result.param1 - 5) < 1e-6)
    }

    @Test func recognizeEdgeLine() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            var foundLine = false
            for edge in edges {
                let result = edge.recognizeCanonicalCurve()
                if result.type == .line {
                    foundLine = true
                    break
                }
            }
            #expect(foundLine)
        }
    }

    // OCCTShapeRecognizeCanonicalCurve (OCCTBridge_Healing_Analysis.mm) runs
    // IsLine -> IsCircle -> IsEllipse, with no IsPlane call at all -- unlike the Face-oriented
    // functions above, so its no-ClearStatus()-between-checks bug (fixed alongside the other two
    // as part of #1509) doesn't actually manifest on a genuine single edge: ground-truthed that
    // IsConic (the private helper behind IsLine/IsCircle/IsEllipse) only sets myStatus on being
    // asked about a Face rather than an Edge/Wire, so an ordinary curve-type mismatch between two
    // IsX calls on a real edge leaves myStatus at 0 regardless of the fix. These two are still real
    // coverage of OCCTShapeRecognizeCanonicalCurve's happy path for the issue's own circular/
    // elliptical-edge fixtures (and of the sibling-file fix landing, which the null-shape-guard
    // tests below don't touch), just not proof of #1509 recurring on their own.
    @Test func recognizeEdgeCircle() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5),
            let edge = Shape.edgeFromCurve(circle)
        else {
            Issue.record("failed to build the circle edge fixture")
            return
        }
        let result = edge.recognizeCanonicalCurve()
        #expect(result.type == .circle)
        #expect(abs(result.param1 - 5) < 1e-6)
    }

    @Test func recognizeEdgeEllipse() {
        guard
            let ellipse = Curve3D.ellipse(
                center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5),
            let edge = Shape.edgeFromCurve(ellipse)
        else {
            Issue.record("failed to build the ellipse edge fixture")
            return
        }
        let result = edge.recognizeCanonicalCurve()
        #expect(result.type == .ellipse)
        #expect(abs(result.param1 - 10) < 1e-6)
        #expect(abs(result.param2 - 5) < 1e-6)
    }

    // #1438: OCCTShapeRecognizeCanonicalSurface had no guard at all (not even a pointer check),
    // and ShapeAnalysis_CanonicalRecognition's constructor unconditionally dereferences the
    // shape's TShape (TopoDS_Shape::ShapeType()), an uncatchable SIGSEGV on a nullified wrapper --
    // `catch (...)` cannot absorb it. `.nullified` is a real, public, non-crashing way to get a
    // non-null wrapper pointer around a null TopoDS_Shape.
    @Test func recognizeCanonicalSurfaceOnNullShapeDoesNotCrash() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10), let nullShape = box.nullified
        else {
            Issue.record("failed to build box / nullified shape")
            return
        }
        let result = nullShape.recognizeCanonicalSurface(tolerance: 1e-4)
        #expect(result.type == .none)
    }

    // #1438: same crash mechanism as recognizeCanonicalSurfaceOnNullShapeDoesNotCrash above, for
    // OCCTShapeRecognizeCanonicalCurve.
    @Test func recognizeCanonicalCurveOnNullShapeDoesNotCrash() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10), let nullShape = box.nullified
        else {
            Issue.record("failed to build box / nullified shape")
            return
        }
        let result = nullShape.recognizeCanonicalCurve(tolerance: 1e-4)
        #expect(result.type == .none)
    }
}
