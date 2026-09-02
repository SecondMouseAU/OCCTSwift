import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1491 (Finding 1): `Shape.fixSmallCurves(tolerance:)` / `Shape.fixSmallBezierCurves(tolerance:)`
/// (and their bridge functions `OCCTShapeUpgradeFixSmallCurves`/`OCCTShapeUpgradeFixSmallBezierCurves`)
/// were removed rather than fixed in place.
///
/// Investigated and rejected: wiring `ShapeUpgrade_FixSmallCurves`/`FixSmallBezierCurves` into a
/// driving class the way the removed implementation's own comment claimed
/// (`ShapeFix_Wireframe` "internally uses FixSmallCurves logic"). That claim does not hold:
/// `ShapeFix_Wireframe.cxx` never references either class anywhere in its source. Both classes
/// have no standalone `Perform()`/`Compute()` at all (confirmed from their headers); the only two
/// real OCCT callers are `ShapeUpgrade_WireDivide` (which builds a default
/// `ShapeUpgrade_FixSmallCurves` in its own constructor, but reaches its one method, `Approx()`,
/// only as a byproduct of an ACTIVE 3D/2D curve split producing a too-small leftover segment --
/// unreachable from a tolerance-only entry point with no splitting criterion to drive it) and
/// `ShapeUpgrade_ShapeConvertToBezier` (which already wires `FixSmallBezierCurves` into its own
/// internal `WireDivide` automatically, and is already wrapped and exercised via
/// `OCCTShapeConvertToBezier` / `Shape.convertToBezier()`). There is no way to reach either tool
/// class's real work from a standalone `tolerance`-only call without inventing an arbitrary
/// splitting criterion the removed functions' name and contract never promised.
///
/// Removing rather than leaving an unconditional-`nil` stub was the honest choice because the
/// genuinely standalone "fix small edges/curves in a shape" operation ALREADY exists, correctly
/// implemented, faithfully wrapping a real OCCT class:
/// `Shape.fixSmallEdges(tolerance:dropSmall:limitAngle:)`, backed by
/// `ShapeFix_Wireframe::FixSmallEdges()` (`OCCTShapeFixSmallEdges`). A caller reaching for
/// "fix small curves" today should reach for that instead; there is no capability gap left by the
/// removal.
///
/// This suite proves that replacement is not itself a no-op -- i.e. that the exact class of bug
/// #1491 found (an operation silently handing back the caller's unmodified input while looking
/// like success) does not hold for the API this codebase keeps. Per this project's "prove the test
/// fails" policy: stubbing `fixSmallEdges`'s bridge call to `return new OCCTShape(shape->shape);`
/// (the identical no-op shape the two removed functions used) makes `smallEdgeIsActuallyMerged()`
/// fail, since the fixture's edge count would stay at 6 instead of dropping; restoring the real
/// implementation makes it pass.
@Suite("Issue #1491: fixSmallCurves/fixSmallBezierCurves removed, fixSmallEdges is the real replacement")
struct Issue1491FixSmallCurvesRemovalTests {

    /// A planar face whose boundary wire has one side split in two by a tiny edge of the given
    /// length -- the same recipe as `Issue839SmallEdgeToleranceAlignmentTests`' fixture (defined
    /// separately here per this project's Test Layout convention: each domain target owns its own
    /// copy rather than sharing one across suites).
    private func faceWithTinyEdge(length: Double) throws -> Shape {
        let p0 = SIMD3<Double>(0, 0, 0)
        let p1 = SIMD3<Double>(5, 0, 0)
        let p1a = p1 + SIMD3<Double>(length, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)
        let p4 = SIMD3<Double>(0, 10, 0)
        let edges = try [
            (p0, p1), (p1, p1a), (p1a, p2), (p2, p3), (p3, p4), (p4, p0),
        ].map { a, b in try #require(Shape.edgeFromPoints(a, b)) }
        let wireShape = try #require(Shape.wireFromEdges(edges))
        let wire = try #require(Wire(wireShape))
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        return try #require(Shape.face(from: plane, boundary: wire))
    }

    /// The real, kept replacement genuinely merges/removes a small edge -- it is not the same
    /// silent no-op the two removed functions were. A comfortably-small edge (well above either
    /// historical `fixSmallEdges` default, see #839) at a generous explicit tolerance should
    /// reliably drop the boundary edge count from 6 to 5.
    @Test("fixSmallEdges actually removes a small edge (not a no-op)")
    func smallEdgeIsActuallyMerged() throws {
        let face = try faceWithTinyEdge(length: 0.1)
        #expect(face.edges().count == 6, "premise: the fixture starts with 6 boundary edges")

        let fixed = try #require(face.fixSmallEdges(tolerance: 0.5, dropSmall: true))
        #expect(
            fixed.edges().count < 6,
            "fixSmallEdges did not remove/merge a 0.1-length edge at a 0.5 tolerance -- indistinguishable from the no-op #1491 removed"
        )
    }

    /// At a tolerance well below the edge's own length, `fixSmallEdges` must leave the shape
    /// alone -- proving the previous test's drop is a genuine tolerance-driven decision, not an
    /// unconditional edge removal that would trivially pass either assertion.
    @Test("fixSmallEdges leaves a comfortably-large edge untouched")
    func largeEdgeIsUntouched() throws {
        let face = try faceWithTinyEdge(length: 0.1)
        #expect(face.edges().count == 6, "premise: the fixture starts with 6 boundary edges")

        let fixed = try #require(face.fixSmallEdges(tolerance: 1e-7, dropSmall: true))
        #expect(
            fixed.edges().count == 6,
            "a 0.1-length edge should NOT be dropped at a 1e-7 tolerance"
        )
    }
}
