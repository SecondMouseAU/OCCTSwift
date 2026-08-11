import Testing
import simd
@testable import OCCTSwift

/// #839: `Shape.droppingSmallEdges(tolerance:)` (Shape+Topology.swift) and
/// `Shape.fixSmallEdges(tolerance:dropSmall: true)` (Shape+ShapeHealing.swift) both build a
/// `ShapeFix_Wireframe`, `SetPrecision(tolerance)`, `ModeDropSmallEdges() = true`,
/// `FixSmallEdges()` -- the identical OCCT recipe -- but used to default to different tolerances
/// (`1e-6` vs `1e-7`), so an edge between the two defaults was dropped by one and kept by the
/// other for the same underlying call. Fixed by aligning `droppingSmallEdges`'s default to `1e-7`,
/// matching `fixSmallEdges` and its sibling `fixWireGaps`.
@Suite("Issue #839: droppingSmallEdges / fixSmallEdges default tolerance alignment")
struct Issue839SmallEdgeToleranceAlignmentTests {

    /// A planar face whose boundary wire has one side split in two by a tiny edge of the given
    /// length. `ShapeFix_Wireframe::MergeSmallEdges` only actually removes/merges a small edge
    /// that belongs to a FACE's wire (its `CheckSmallEdges` companion also detects small edges on
    /// a bare, faceless wire, but nothing ever merges those) -- so the fixture needs a real face,
    /// not just a wire, to exercise removal rather than only detection.
    private func faceWithTinyEdge(length: Double) throws -> Shape {
        let p0 = SIMD3<Double>(0, 0, 0)
        let p1 = SIMD3<Double>(5, 0, 0)
        let p1a = p1 + SIMD3<Double>(length, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)
        let p4 = SIMD3<Double>(0, 10, 0)
        let edges = try [
            (p0, p1), (p1, p1a), (p1a, p2), (p2, p3), (p3, p4), (p4, p0)
        ].map { a, b in try #require(Shape.edgeFromPoints(a, b)) }
        let wireShape = try #require(Shape.wireFromEdges(edges))
        let wire = try #require(Wire(wireShape))
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        return try #require(Shape.face(from: plane, boundary: wire))
    }

    /// The exact scenario #839 reports: an edge sized between the old outlier default (`1e-6`)
    /// and the shared aligned default (`1e-7`). Before the fix, `droppingSmallEdges()` (old
    /// default `1e-6`) drops it while `fixSmallEdges(dropSmall: true)` (`1e-7`) keeps it -- two
    /// APIs documented as the same operation disagreeing on the same geometry. After the fix, both
    /// share `1e-7` and agree.
    @Test("droppingSmallEdges and fixSmallEdges agree at their (now-shared) default")
    func defaultsAgreeOnBorderlineEdge() throws {
        // 3e-7: below the old droppingSmallEdges default (1e-6, would have been dropped) but
        // above the aligned default (1e-7, both now keep it).
        let face = try faceWithTinyEdge(length: 3e-7)
        #expect(face.edges().count == 6, "premise: the fixture starts with 6 boundary edges")

        let dropped = try #require(face.droppingSmallEdges())
        let fixed = try #require(face.fixSmallEdges(dropSmall: true))

        #expect(dropped.edges().count == fixed.edges().count,
                "droppingSmallEdges() and fixSmallEdges(dropSmall: true) disagreed on a 3e-7 edge at their default tolerances")
        #expect(dropped.edges().count == 6,
                "a 3e-7 edge should NOT be dropped at the aligned 1e-7 default")
    }

    /// At a shared EXPLICIT tolerance well above either historical default, both must actually
    /// remove a genuinely small edge and agree on the result -- proving `droppingSmallEdges(
    /// tolerance:)` really is `fixSmallEdges(tolerance:dropSmall: true)` for any tolerance, not
    /// only coincidentally at the (now-aligned) default.
    @Test("both remove a small edge and agree at a shared explicit tolerance")
    func bothAgreeAtASharedExplicitTolerance() throws {
        // 0.1: comfortably smaller than the shared 0.5 tolerance below, and comfortably larger
        // than either historical default (1e-6/1e-7), so this is not near any construction-time
        // healing floor -- the fixture reliably starts with all 6 boundary edges.
        let face = try faceWithTinyEdge(length: 0.1)
        #expect(face.edges().count == 6, "premise: the fixture starts with 6 boundary edges")

        let dropped = try #require(face.droppingSmallEdges(tolerance: 0.5))
        let fixed = try #require(face.fixSmallEdges(tolerance: 0.5, dropSmall: true))

        #expect(dropped.edges().count == fixed.edges().count)
        #expect(dropped.edges().count < 6,
                "a 0.1-length edge should be dropped/merged away by both at a shared 0.5 tolerance")
    }
}
