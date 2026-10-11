import Foundation
import Testing

@testable import OCCTSwift

@Suite("CanonicalRecognition Detailed Tests")
struct CanonicalRecognitionDetailedTests {
    /// Find the sub-face of `shape` whose analytic surface matches `surfaceType`.
    private func face(of shape: Shape, surfaceType: Face.SurfaceType) -> Shape? {
        shape.subShapes(ofType: .face).first { Face($0)?.surfaceType == surfaceType }
    }

    // #1859: this sat inside `if let box` and `if let face`, so a box with no faces passed it, and
    // it checked only the type. The first face in subShapes order is the box's x = -5 side,
    // measured in Scripts/repro/766-canonical-recognition-detailed/transcript.txt.
    @Test func recognizePlane() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.subShapes(ofType: .face).first)
        let result = face.recognizeCanonicalSurface()
        #expect(result.type == .plane)
        // The recognised plane is x = -5: normal along X, through a point with x = -5.
        #expect(abs(abs(result.direction.x) - 1) < 1e-9)
        #expect(abs(result.origin.x - -5) < 1e-9)
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

    /// The recognised parameters, not only the type and radius: the axis, where it passes, and
    /// that the answer moves with the shape.
    ///
    /// The fixtures are measured on the pinned kernel (`Scripts/repro/2983-leftovers/`): a
    /// cylinder, a cone and a sphere built at the origin recognise at the origin with the axis
    /// along +Z, and each translated copy recognises at its own centre. A recogniser that
    /// returned the right type with a default placement would pass the untranslated case alone.
    private func expectOrigin(
        _ got: (x: Double, y: Double, z: Double), _ want: SIMD3<Double>, _ what: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            abs(got.x - want.x) < 1e-9, "\(what) x: got \(got.x)", sourceLocation: sourceLocation)
        #expect(
            abs(got.y - want.y) < 1e-9, "\(what) y: got \(got.y)", sourceLocation: sourceLocation)
        #expect(
            abs(got.z - want.z) < 1e-9, "\(what) z: got \(got.z)", sourceLocation: sourceLocation)
    }

    @Test func recognizeCylinder() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 20), "the cylinder builds")
        let cylFace = try #require(
            face(of: cyl, surfaceType: .cylinder), "the cylinder has a cylindrical face")
        let result = cylFace.recognizeCanonicalSurface()
        #expect(result.type == .cylinder)
        #expect(abs(result.param1 - 5) < 1e-6)
        #expect(abs(result.gap) < 1e-9, "the face is exactly cylindrical, got gap \(result.gap)")
        expectOrigin(result.origin, SIMD3(0, 0, 0), "cylinder axis point")
        expectOrigin(result.direction, SIMD3(0, 0, 1), "cylinder axis")

        // Moved off the origin in x and y: the axis passes through the new position. The z of
        // the reported axis point is any point on the axis, so only x and y are pinned.
        let moved = try #require(cyl.translated(by: SIMD3(3, -2, 0)), "the copy translates")
        let movedFace = try #require(face(of: moved, surfaceType: .cylinder))
        let movedResult = movedFace.recognizeCanonicalSurface()
        #expect(movedResult.type == .cylinder)
        #expect(abs(movedResult.param1 - 5) < 1e-6)
        #expect(abs(movedResult.origin.x - 3) < 1e-9, "axis x: got \(movedResult.origin.x)")
        #expect(abs(movedResult.origin.y - -2) < 1e-9, "axis y: got \(movedResult.origin.y)")
        expectOrigin(movedResult.direction, SIMD3(0, 0, 1), "moved cylinder axis")
    }

    @Test func recognizeCone() throws {
        let cone = try #require(
            Shape.cone(bottomRadius: 5, topRadius: 0, height: 10), "the cone builds")
        let coneFace = try #require(
            face(of: cone, surfaceType: .cone), "the cone has a conical face")
        let result = coneFace.recognizeCanonicalSurface()
        #expect(result.type == .cone)
        #expect(abs(result.param1 - 5) < 1e-6)
        // The semi-angle is atan(5 / 10), the radius lost over the height, and it is reported
        // negative because the radius shrinks along the +Z axis the cone is built on.
        #expect(
            abs(result.param2 - -atan(0.5)) < 1e-9,
            "semi-angle should be -atan(5/10) = -0.4636, got \(result.param2)")
        expectOrigin(result.origin, SIMD3(0, 0, 0), "cone reference point")
        expectOrigin(result.direction, SIMD3(0, 0, 1), "cone axis")

        let moved = try #require(cone.translated(by: SIMD3(3, -2, 1)), "the copy translates")
        let movedFace = try #require(face(of: moved, surfaceType: .cone))
        let movedResult = movedFace.recognizeCanonicalSurface()
        #expect(movedResult.type == .cone)
        expectOrigin(movedResult.origin, SIMD3(3, -2, 1), "moved cone reference point")
        #expect(abs(movedResult.param2 - -atan(0.5)) < 1e-9, "moving does not change the angle")
    }

    @Test func recognizeSphere() throws {
        let sph = try #require(Shape.sphere(radius: 5), "the sphere builds")
        let sphFace = try #require(
            face(of: sph, surfaceType: .sphere), "the sphere has a spherical face")
        let result = sphFace.recognizeCanonicalSurface()
        #expect(result.type == .sphere)
        #expect(abs(result.param1 - 5) < 1e-6)
        expectOrigin(result.origin, SIMD3(0, 0, 0), "sphere centre")

        let moved = try #require(sph.translated(by: SIMD3(3, -2, 1)), "the copy translates")
        let movedFace = try #require(face(of: moved, surfaceType: .sphere))
        let movedResult = movedFace.recognizeCanonicalSurface()
        #expect(movedResult.type == .sphere)
        #expect(abs(movedResult.param1 - 5) < 1e-6)
        expectOrigin(movedResult.origin, SIMD3(3, -2, 1), "moved sphere centre")
    }

    // #1862: this sat inside `if let box` and passed on the first line it found. Every one of a
    // box's twelve edges is a straight line, and the kernel recognises all twelve.
    @Test func recognizeEdgeLine() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        for edge in edges {
            #expect(edge.recognizeCanonicalCurve().type == .line)
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
    @Test func recognizeEdgeCircle() throws {
        let circle = try #require(
            Curve3D.circle(center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 5),
            "the circle builds")
        let edge = try #require(Shape.edgeFromCurve(circle), "the circle edge builds")
        let result = edge.recognizeCanonicalCurve()
        #expect(result.type == .circle)
        #expect(abs(result.param1 - 5) < 1e-6)
        expectOrigin(result.origin, SIMD3(1, 2, 3), "circle centre")
        expectOrigin(result.direction, SIMD3(0, 0, 1), "circle normal")
    }

    @Test func recognizeEdgeEllipse() throws {
        let ellipse = try #require(
            Curve3D.ellipse(
                center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5),
            "the ellipse builds")
        let edge = try #require(Shape.edgeFromCurve(ellipse), "the ellipse edge builds")
        let result = edge.recognizeCanonicalCurve()
        #expect(result.type == .ellipse)
        #expect(abs(result.param1 - 10) < 1e-6)
        #expect(abs(result.param2 - 5) < 1e-6)
        expectOrigin(result.origin, SIMD3(1, 2, 3), "ellipse centre")
        expectOrigin(result.direction, SIMD3(0, 0, 1), "ellipse normal")
    }

    // #1438: OCCTShapeRecognizeCanonicalSurface had no guard at all (not even a pointer check),
    // and ShapeAnalysis_CanonicalRecognition's constructor unconditionally dereferences the
    // shape's TShape (TopoDS_Shape::ShapeType()), an uncatchable SIGSEGV on a nullified wrapper --
    // `catch (...)` cannot absorb it. `.nullified` is a real, public, non-crashing way to get a
    // non-null wrapper pointer around a null TopoDS_Shape.
    @Test func recognizeCanonicalSurfaceOnNullShapeDoesNotCrash() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "the box builds")
        let nullShape = try #require(box.nullified, "the box nullifies")
        let result = nullShape.recognizeCanonicalSurface(tolerance: 1e-4)
        #expect(result.type == .none)
        #expect(result.param1 == 0 && result.param2 == 0, "no parameter is reported for nothing")
        // The control: a real face of the same box is recognised, so `.none` above is the guard
        // speaking and not a recogniser that never answers.
        let face = try #require(box.subShapes(ofType: .face).first)
        #expect(face.recognizeCanonicalSurface(tolerance: 1e-4).type == .plane)
    }

    // #1438: same crash mechanism as recognizeCanonicalSurfaceOnNullShapeDoesNotCrash above, for
    // OCCTShapeRecognizeCanonicalCurve.
    @Test func recognizeCanonicalCurveOnNullShapeDoesNotCrash() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "the box builds")
        let nullShape = try #require(box.nullified, "the box nullifies")
        let result = nullShape.recognizeCanonicalCurve(tolerance: 1e-4)
        #expect(result.type == .none)
        #expect(result.param1 == 0 && result.param2 == 0, "no parameter is reported for nothing")
        // The control: a real edge of the same box is recognised, so `.none` above is the guard
        // speaking and not a recogniser that never answers.
        let edge = try #require(box.subShapes(ofType: .edge).first)
        #expect(edge.recognizeCanonicalCurve(tolerance: 1e-4).type == .line)
    }
}
