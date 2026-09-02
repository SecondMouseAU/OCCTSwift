import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #1461: `OCCTValidateEdge` used to hardcode `Standard_True` for `BRepLib_ValidateEdge`'s
/// `theSameParameter` constructor argument instead of reading the edge's real
/// `BRep_Tool::SameParameter` flag. That argument is not a mode switch: when true (and the
/// pcurve/3D-curve parameter ranges match), `BRepLib_ValidateEdge::processApprox()` takes a
/// cheap same-t point comparison that assumes the two curves correspond point-for-point at equal
/// parameter values; when false, it falls back to a projection/extrema search instead.
///
/// This suite builds an edge whose 3D curve and pcurve trace the exact same physical straight
/// line but are parametrized differently (the pcurve is "sped up" quadratically), so a
/// same-t comparison reports a large, spurious deviation while the real answer is ~0. The edge's
/// `SameParameter` flag is explicitly set via `OCCTEdgeSetSameParameter` (added for this test; no
/// other Swift-reachable path leaves a non-default `SameParameter` flag on an edge whose
/// parameter ranges still match, which is what's needed to discriminate the two code paths).
@Suite("ValidateEdge SameParameter Tests (#1461)")
struct Issue1461ValidateEdgeSameParameterTests {

    /// Builds an edge whose 3D curve and pcurve trace the identical physical line
    /// `(0,0,0)-(length,0,0)` but at different (linear vs. quadratic) speeds, on a plane face
    /// covering both. Returns `(edge, face)`, or `nil` if any construction step failed.
    private func buildMismatchedEdge(length: Double) -> (OCCTEdgeRef, OCCTFaceRef)? {
        // 3D curve: degree-1 Bezier (0,0,0) -> (length,0,0), domain [0,1], LINEAR speed.
        guard let curve3d = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(length, 0, 0)]) else {
            return nil
        }
        // pcurve: degree-2 Bezier poles (0,0), (length/4,0), (length,0) -- traces the SAME 2D
        // line y=0, x: 0->length, but at a different (non-proportional) speed: warped(0.5)
        // lands at x = 0.375*length, not 0.5*length.
        guard
            let warpedPCurve = Curve2D.bezier(poles: [
                SIMD2(0, 0), SIMD2(length / 4, 0), SIMD2(length, 0),
            ])
        else { return nil }
        guard let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) else { return nil }
        guard let planeFace = Shape.face(from: plane, uRange: -100...100, vRange: -100...100)
        else { return nil }

        // edgeA: only the 3D curve, domain [0,1].
        guard let edgeAHandle = OCCTMakeEdgeFromCurveParams(curve3d.handle, 0, 1) else {
            return nil
        }
        let edgeAShape = Shape(handle: edgeAHandle)

        // edgeB: only the pcurve-on-`plane`, domain [0,1] (its own auto-derived 3D curve is
        // irrelevant; only its pcurve-on-`plane` representation is used below).
        guard
            let edgeBHandle = OCCTMakeEdgeOnSurfaceParams(warpedPCurve.handle, plane.handle, 0, 1)
        else { return nil }
        let edgeBShape = Shape(handle: edgeBHandle)

        // edgeA has no representation for `plane` yet, so this APPENDS edgeB's pcurve-on-plane
        // rep rather than replacing anything: edgeA now carries its own (unchanged) linear 3D
        // curve plus the warped pcurve, both on domain [0,1], on the SAME face.
        OCCTShapeBuildEdgeCopyPCurves(edgeAShape.handle, edgeBShape.handle)

        guard let edgeRef = OCCTEdgeFromShape(edgeAShape.handle) else { return nil }
        guard let faceRef = OCCTFaceFromShape(planeFace.handle) else {
            OCCTEdgeRelease(edgeRef)
            return nil
        }
        return (edgeRef, faceRef)
    }

    @Test("uses the edge's real SameParameter flag, not a hardcoded true")
    func realSameParameterFlagIsUsed() throws {
        let length = 10.0
        let (edgeRef, faceRef) = try #require(buildMismatchedEdge(length: length))
        defer {
            OCCTEdgeRelease(edgeRef)
            OCCTFaceRelease(faceRef)
        }

        // The real, honest flag for this hand-assembled edge: the pcurve was never verified
        // against the 3D curve.
        OCCTEdgeSetSameParameter(edgeRef, false)

        let result = OCCTValidateEdge(edgeRef, faceRef, 1e-3)
        try #require(result.isDone)

        // Correct (extrema/projection-based) answer: both curves trace the identical physical
        // line, so the true deviation is ~0. A hardcoded `Standard_True` instead takes the naive
        // same-parameter path, which wrongly compares (3D curve at t) against (pcurve at t) and
        // reports ~2.5 (a quarter of `length`) at the fixture's own worst point -- see the sibling
        // test below, which proves this fixture actually discriminates the two code paths.
        #expect(result.maxDistance < 0.01)
    }

    @Test("control: forcing SameParameter true on the same fixture reports a spurious deviation")
    func forcedTrueWouldHaveBeenWrong() throws {
        // Same fixture, but with SameParameter left at `true`, matching the old bridge's
        // hardcoded `Standard_True`. This is the "inject the defect" half of proving the test
        // above actually fails without the fix: it demonstrates the fixture discriminates the two
        // code paths, rather than reading ~0 either way.
        let length = 10.0
        let (edgeRef, faceRef) = try #require(buildMismatchedEdge(length: length))
        defer {
            OCCTEdgeRelease(edgeRef)
            OCCTFaceRelease(faceRef)
        }

        OCCTEdgeSetSameParameter(edgeRef, true)

        let result = OCCTValidateEdge(edgeRef, faceRef, 1e-3)
        try #require(result.isDone)
        #expect(result.maxDistance > 1.0)
    }
}
