import Foundation
import simd
import Testing

@testable import OCCTSwift

/// #2812: four `BRep_Tool` wrappers that took a null `TopoDS_Shape` all the way to an entry point
/// measured to dereference it, behind a `check-null-handle-guards.py` blind spot.
///
/// The gate knew every one of these consumers already: `BRep_Tool::Curve`, `CurveOnSurface`,
/// `Degenerated` and `Range` are all in its `SHAPE_DEREF_QUALIFIED` table, measured uncatchable by
/// `Scripts/repro/1035-unwrap-guard`. What it could not see was the shape arriving there.
/// `SHAPE_CAST_DECL`, added by #1513 for the split-statement cast, demanded whitespace after the
/// type name and so matched only `TopoDS_Edge e = TopoDS::Edge(x->shape);`, never the reference
/// spelling `const TopoDS_Edge& e = TopoDS::Edge(x->shape);` these four use, which is the majority
/// spelling in the bridge (53 sites against 109).
///
/// `Scripts/repro/2812-null-shape-cast-reference-spelling/` carries the measurement: each of the
/// six `BRep_Tool` entry points involved dies on a null shape with signal 11, which no
/// `catch (...)` can absorb, so before the guard every assertion below was a crashed test process
/// rather than a failed expectation.
///
/// The controls are not decoration. A guard written as an unconditional refusal would satisfy
/// every "returns nil" assertion here, so each refusal is paired with the real answer the same
/// call still has to produce.
@Suite("A nullified shape refuses the four reference-cast BRep_Tool wrappers (#2812)")
struct Issue2812CastReferenceSpellingGuard {

    private func makeBox() throws -> Shape {
        try #require(Shape.box(width: 10, height: 10, depth: 10))
    }

    private func makeNullShape() throws -> Shape {
        try #require(try makeBox().nullified)
    }

    /// An edge and a face of the same box that really do carry a pcurve, so the control assertions
    /// measure something.
    private func edgeOnFace() throws -> (edge: Shape, face: Shape) {
        let box = try makeBox()
        for face in box.subShapes(ofType: .face) {
            for edge in box.subShapes(ofType: .edge) {
                if Shape.curveOnSurface(edge: edge, face: face) != nil {
                    return (edge, face)
                }
            }
        }
        throw TestFailure.noEdgeWithAPCurve
    }

    private enum TestFailure: Error { case noEdgeWithAPCurve }

    // MARK: - BRep_Tool::Degenerated (OCCTBRepToolDegenerated)

    @Test("isDegenerated refuses a nullified edge, and still answers for a real one")
    func isDegeneratedRefusesANullifiedEdge() throws {
        #expect(Shape.isDegenerated(edge: try makeNullShape()) == false)
        // A box edge is a real, non-degenerate edge: the guard must not have swallowed the answer.
        let pair = try edgeOnFace()
        #expect(Shape.isDegenerated(edge: pair.edge) == false)
        // And the type test still refuses a shape that is not an edge at all, as TopoDS::Edge did.
        #expect(Shape.isDegenerated(edge: try makeBox()) == false)
    }

    // MARK: - BRep_Tool::CurveOnSurface (OCCTBRepToolCurveOnSurface)

    @Test("curveOnSurface refuses a nullified edge or face, and still returns a real pcurve")
    func curveOnSurfaceRefusesANullifiedShape() throws {
        let pair = try edgeOnFace()
        let nullShape = try makeNullShape()
        #expect(Shape.curveOnSurface(edge: nullShape, face: pair.face) == nil)
        #expect(Shape.curveOnSurface(edge: pair.edge, face: nullShape) == nil)
        #expect(Shape.curveOnSurface(edge: nullShape, face: nullShape) == nil)
        let real = Shape.curveOnSurface(edge: pair.edge, face: pair.face)
        #expect(real != nil)
        if let real {
            #expect(real.last > real.first)
        }
    }

    // MARK: - BRep_Tool::Range (OCCTBRepToolRangeOnFace)

    @Test("rangeOnFace refuses a nullified edge or face, and still returns a real range")
    func rangeOnFaceRefusesANullifiedShape() throws {
        let pair = try edgeOnFace()
        let nullShape = try makeNullShape()
        #expect(Shape.rangeOnFace(edge: nullShape, face: pair.face) == nil)
        #expect(Shape.rangeOnFace(edge: pair.edge, face: nullShape) == nil)
        let real = Shape.rangeOnFace(edge: pair.edge, face: pair.face)
        #expect(real != nil)
        if let real {
            #expect(real.last > real.first)
        }
    }

    // MARK: - BRep_Tool::Curve + CurveOnSurface + Surface (OCCTBRepToolsEvalAndUpdateTol)

    @Test("evalAndUpdateTolerance refuses a nullified edge or face, and still measures a real one")
    func evalAndUpdateToleranceRefusesANullifiedShape() throws {
        let pair = try edgeOnFace()
        let nullShape = try makeNullShape()
        // 0 is this function's only refusal channel, the one it already gave a null pointer.
        #expect(Shape.evalAndUpdateTolerance(edge: nullShape, face: pair.face) == 0)
        #expect(Shape.evalAndUpdateTolerance(edge: pair.edge, face: nullShape) == 0)
        // A real edge on a real face has a positive tolerance, so a guard that refuses everything
        // fails here.
        #expect(Shape.evalAndUpdateTolerance(edge: pair.edge, face: pair.face) > 0)
    }

    // MARK: - the lead that started #2812, which was NOT a defect

    /// `OCCTIntToolsEdgeEdge` has no guard where its sibling `OCCTIntToolsEdgeFace` has one, and
    /// that asymmetry is correct rather than an oversight. Measured in this issue's repro:
    /// `IntTools_EdgeEdge`'s constructor and `Perform()` both cope with a null `TopoDS_Edge` and
    /// answer `IsDone() == false`, while `IntTools_EdgeFace::Perform()` SIGSEGVs on one. This test
    /// exists so that a later sweep adding a guard "for symmetry" has to argue with a measurement,
    /// and so that a kernel bump changing `IntTools_EdgeEdge`'s tolerance of a null edge is caught
    /// here rather than in a user's process.
    @Test("edgeEdgeIntersection on a nullified edge refuses without a guard, by measurement")
    func edgeEdgeIntersectionCopesWithANullifiedEdge() throws {
        let realEdge = try #require(
            Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(2, 0, 0)))
        let nullShape = try makeNullShape()
        #expect(realEdge.edgeEdgeIntersection(with: nullShape) == nil)
        #expect(nullShape.edgeEdgeIntersection(with: realEdge) == nil)
        // A wrong-typed input is a catchable Standard_TypeMismatch from TopoDS::Edge, which the
        // function's own catch turns into the same refusal.
        #expect(realEdge.edgeEdgeIntersection(with: try makeBox()) == nil)
        // The control: two collinear overlapping edges still report their overlap.
        let other = try #require(Shape.edgeFromPoints(SIMD3(1, 0, 0), SIMD3(3, 0, 0)))
        let parts = try #require(realEdge.edgeEdgeIntersection(with: other))
        #expect(!parts.isEmpty)
    }
}
