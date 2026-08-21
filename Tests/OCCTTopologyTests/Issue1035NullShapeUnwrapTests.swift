import Foundation
import Testing

@testable import OCCTSwift

/// #1035: a null `TopoDS_Shape` that survives `TopoDS::Edge`/`TopoDS::Face` and crashes one step
/// later, at the OCCT entry point the cast result is handed to.
///
/// `TopoDS::Edge` is written `theShape.IsNull() ? false : theShape.ShapeType() != TopAbs_EDGE`
/// (`TopoDS.hxx:94`), so a null shape is deliberately not a type mismatch: it casts to a null
/// `TopoDS_Edge` and returns. `BRep_Tool::Curve`, `BRep_Tool::Surface`, `BRep_Tool::Tolerance`,
/// `BRep_Tool::CurveOnSurface`, `BRep_Tool::Degenerated`, `BRepPrimAPI_MakePrism` and
/// `ShapeFix_Shape::Perform` then dereference it, and each is an OS signal rather than a
/// `Standard_Failure`, so the `try`/`catch` every one of these functions already carries makes no
/// difference.
///
/// That is why #1008's cast census came back clean over 345 sites: the cast is safe, and the
/// defect is in what the caller does with the cast result. `Scripts/repro/1035-unwrap-guard/`
/// carries the entry-point sweep that measured which consumers dereference and which cope.
@Suite("A nullified shape refuses the edge/face accessors instead of crashing (#1035)")
struct Issue1035NullShapeUnwrap {

    private func makeBox() throws -> Shape {
        try #require(Shape.box(width: 10, height: 10, depth: 10))
    }

    private func makeNullShape() throws -> Shape {
        try #require(try makeBox().nullified)
    }

    // MARK: - BRep_Tool::Curve

    @Test("extractEdgeCurve3D on a nullified shape returns nil, not a crash")
    func extractEdgeCurve3DRefusesANullifiedShape() throws {
        #expect(try makeNullShape().extractEdgeCurve3D() == nil)
    }

    @Test("edgeCurveWithParams on a nullified shape returns nil, not a crash")
    func edgeCurveWithParamsRefusesANullifiedShape() throws {
        #expect(try makeNullShape().edgeCurveWithParams() == nil)
    }

    // MARK: - BRep_Tool::Surface

    @Test("extractFaceSurface on a nullified shape returns nil, not a crash")
    func extractFaceSurfaceRefusesANullifiedShape() throws {
        #expect(try makeNullShape().extractFaceSurface() == nil)
    }

    @Test("faceSurfaceGeom on a nullified shape returns nil, not a crash")
    func faceSurfaceGeomRefusesANullifiedShape() throws {
        #expect(try makeNullShape().faceSurfaceGeom() == nil)
    }

    // MARK: - BRep_Tool::Tolerance

    @Test("The three tolerance accessors return 0 for a nullified shape, not a crash")
    func theToleranceAccessorsRefuseANullifiedShape() throws {
        let nullShape = try makeNullShape()
        #expect(nullShape.edgeTolerance == 0)
        #expect(nullShape.faceTolerance == 0)
        #expect(nullShape.vertexTolerance == 0)
    }

    // MARK: - BRep_Tool::CurveOnSurface

    @Test("extractEdgePCurve on a nullified shape returns nil, not a crash")
    func extractEdgePCurveRefusesANullifiedShape() throws {
        let nullShape = try makeNullShape()
        #expect(nullShape.extractEdgePCurve(onFace: nullShape) == nil)
    }

    /// The face argument alone is enough: a real edge with a nullified face still reaches
    /// `BRep_Tool::CurveOnSurface`, so both arguments need the guard, not just the first.
    @Test("extractEdgePCurve with a real edge and a nullified face returns nil, not a crash")
    func extractEdgePCurveRefusesANullifiedFaceArgument() throws {
        let edgeShape = try #require(try makeBox().subShapes(ofType: .edge).first)
        #expect(edgeShape.extractEdgePCurve(onFace: try makeNullShape()) == nil)
    }

    // MARK: - BRep_Tool::Degenerated

    @Test("isEdgeDegenerated is false for a nullified shape, not a crash")
    func isEdgeDegeneratedRefusesANullifiedShape() throws {
        #expect(try makeNullShape().isEdgeDegenerated == false)
    }

    // MARK: - ShapeFix_Shape::Perform

    /// `ShapeFix_Shape`'s constructor accepts a null shape and returns; `Perform()` is where it
    /// dereferences. `OCCTShapeHeal` guards for the same reason and its comment names the
    /// constructor, which the sweep shows is not the dereferencing half.
    @Test("ShapeFixer.perform on a nullified shape returns false, not a crash")
    func shapeFixerRefusesANullifiedShape() throws {
        let fixer = ShapeFixer(shape: try makeNullShape())
        #expect(fixer.perform() == false)
        #expect(fixer.shape == nil)
    }

    // MARK: - BRepPrimAPI_MakePrism

    @Test("The two infinite extrusions return nil for a nullified shape, not a crash")
    func theInfiniteExtrusionsRefuseANullifiedShape() throws {
        let nullShape = try makeNullShape()
        #expect(nullShape.extrudedInfinite(direction: SIMD3<Double>(0, 0, 1)) == nil)
        #expect(
            nullShape.extrudedSemiInfinite(direction: SIMD3<Double>(0, 0, 1)) == nil)
    }

    // MARK: - Controls: the same queries still answer for a real shape

    /// A guard that refuses everything would pass every test above. These are the same accessors
    /// on a real edge, face and vertex, so a guard that over-refuses fails here.
    @Test("Every guarded accessor still answers for a real edge, face and vertex")
    func everyGuardedAccessorStillAnswersForARealShape() throws {
        let box = try makeBox()

        let edgeShape = try #require(box.subShapes(ofType: .edge).first)
        #expect(edgeShape.extractEdgeCurve3D() != nil)
        #expect(edgeShape.edgeCurveWithParams() != nil)
        #expect(edgeShape.edgeTolerance > 0)
        #expect(edgeShape.isEdgeDegenerated == false)

        let faceShape = try #require(box.subShapes(ofType: .face).first)
        #expect(faceShape.extractFaceSurface() != nil)
        #expect(faceShape.faceSurfaceGeom() != nil)
        #expect(faceShape.faceTolerance > 0)
        #expect(edgeShape.extractEdgePCurve(onFace: faceShape) != nil)

        let vertexShape = try #require(box.subShapes(ofType: .vertex).first)
        #expect(vertexShape.vertexTolerance > 0)

        // A face, not the solid: BRepPrimAPI_MakePrism on a closed solid legitimately returns
        // nothing, and an earlier draft of this control asserted the solid and failed for that
        // reason rather than for a missing guard.
        #expect(faceShape.extrudedInfinite(direction: SIMD3<Double>(0, 0, 1)) != nil)
    }

    @Test("ShapeFixer still repairs a real shape")
    func shapeFixerStillAnswersForARealShape() throws {
        let fixer = ShapeFixer(shape: try makeBox())
        _ = fixer.perform()
        #expect(fixer.shape != nil)
    }
}
