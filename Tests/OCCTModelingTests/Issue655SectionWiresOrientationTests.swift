import Testing
import Foundation
@testable import OCCTSwift

/// OCCT 8.0.1 (OCCT#1408, the merged form of OCCT#1331) makes
/// `ShapeAnalysis_FreeBounds::ConnectEdgesToWires` skip edges whose orientation is `.internal` or
/// `.external`. That C++ entry point appears exactly once in this bridge, inside
/// `OCCTShapeSectionWiresAtZ` (`OCCTBridge_Modeling.mm`), which backs
/// `Shape.sectionWiresAtZ(_:tolerance:)` -- a CAM sectioning API. The `freeBounds*` family
/// (`Shape.freeBounds`, `freeBoundsAnalysis`, `freeBoundsClosedCount`, `freeBoundsClosedWires`,
/// `freeBoundsOpenWires`) goes through `ShapeAnalysis_FreeBounds`'s constructor instead, and that
/// constructor's own chainage step *does* call `ConnectEdgesToWires`, so it is not a different
/// entry point that avoids the changed code. What actually keeps this family unaffected is
/// upstream: the edges it feeds in come from `BRepBuilderAPI_Sewing::FreeEdge`, and in every case
/// measured that sewing stage never produced an `.internal`/`.external` free edge for the skip to
/// act on (see `Issue655FreeBoundsInternalOrientationTests` in `OCCTShapeHealingTests`, which
/// covers this half directly).
///
/// `BRepAlgoAPI_Section` does not invent `.internal`/`.external` edges out of an ordinary
/// transverse cut, but it DOES pass an already-`.internal`/`.external` input edge through
/// unchanged when the cutting plane is exactly coincident with that edge -- the "same domain"
/// case OCCT's Boolean-operation machinery takes for input already lying in the section plane.
/// Since `Shape.setOrientation(_:)` is public API, a caller can construct exactly that input,
/// which is what `fixture(orientation:)` below does, making the 8.0.1 skip observably reachable
/// through `sectionWiresAtZ`.
///
/// Measured directly against both kernels before writing this test (v1.15.18, OCCT 8.0.0p1, vs.
/// the pinned v2.0.0-kernel.1, OCCT V8_0_1): a compound of one closed square (4 FORWARD edges) and
/// one disjoint floating edge coincident with the cut plane, marked `.internal`, sections to 2
/// wires (the square, plus the floating edge as its own open 1-edge wire) on the old kernel and 1
/// wire (just the square) on the new one.
///
/// #655 also asks whether the same upstream change's removal of `isUsedManifoldMode` (the
/// separate closure detection non-manifold wires -- in `ShapeExtend_WireData`'s own vocabulary, a
/// wire built from `.internal`/`.external` edges -- used to get) is independently reachable. It is
/// not, on either of this bridge's two entry points:
///
/// - Through `ConnectEdgesToWires` (`sectionWiresAtZ`'s path): the new outer skip removes every
///   `.internal`/`.external` edge before any per-edge wire is built, so the old fallback's own
///   trigger condition (the first candidate wire having zero ordinary edges and at least one
///   non-manifold one) can never be satisfied again. The wire-count change measured above is
///   fully attributable to the skip alone.
/// - Through the `(shape, tolerance)` constructor (the `freeBounds*` path): a face's embedded,
///   fully-`.internal` closed wire (4 edges) never appears in either `GetClosedWires()` or
///   `GetOpenWires()`'s output on EITHER kernel -- verified directly, not inferred. Free-bound
///   candidacy excludes `.internal`/`.external` sub-wires upstream of `connectWiresToWiresImpl`,
///   independent of the 8.0.1 change.
@Suite("sectionWiresAtZ drops a coincident INTERNAL/EXTERNAL edge (OCCT 8.0.1, #655)")
struct Issue655SectionWiresOrientationTests {

    /// A closed unit square (4 edges, all FORWARD) plus one disjoint, floating segment carrying
    /// `orientation` -- all lying exactly in the z=3 cut plane, with the floating edge listed
    /// first in the compound (matching the order the issue's own repro used, where the affected
    /// edge is `arrwires->Value(1)`).
    ///
    /// Compound order is NOT load-bearing for these assertions: the floating edge shares no vertex
    /// with the square, so nothing here needs a merge-order or reversal decision to come out right
    /// (measured directly by reordering the compound and re-running; all three tests below were
    /// unchanged). That's different from the issue's own case B, where an INTERNAL edge visited
    /// before a square that still needs a reversal genuinely does depend on order; this fixture just
    /// doesn't build that case, since it never merges with anything.
    ///
    /// `orientation` is the fixture's single dial: swapping it from `.internal` to `.forward` is
    /// the "prove the test fails" injection for `internalEdgeExcluded()` below -- it changes
    /// nothing about the geometry, only whether the skip applies.
    static func fixture(orientation: Shape.Orientation) -> Shape? {
        guard let squareWire = Wire.polygon3D(
            [SIMD3(0, 0, 3), SIMD3(10, 0, 3), SIMD3(10, 10, 3), SIMD3(0, 10, 3)],
            closed: true
        ), let square = Shape.fromWire(squareWire) else { return nil }

        guard let floatingWire = Wire.line(from: SIMD3(2, 2, 3), to: SIMD3(4, 4, 3)),
              let floatingEdge = floatingWire.edges().first,
              let floatingShape = Shape.fromEdge(floatingEdge) else { return nil }
        floatingShape.setOrientation(orientation)

        return Shape.compound([floatingShape, square])
    }

    @Test("A coincident INTERNAL edge is excluded from the returned wires")
    func internalEdgeExcluded() {
        guard let shape = Self.fixture(orientation: .internal) else {
            Issue.record("fixture build failed")
            return
        }
        let wires = shape.sectionWiresAtZ(3.0, tolerance: 1e-6)
        // Only the closed square comes back; the coincident INTERNAL edge is dropped by OCCT
        // 8.0.1's ConnectEdgesToWires (OCCT#1408).
        #expect(wires.count == 1, "expected 1 wire (the square only), got \(wires.count)")
        if let only = wires.first {
            #expect(only.edges().count == 4, "expected the square's 4 edges, got \(only.edges().count)")
            #expect(only.curveInfo?.isClosed == true, "expected the surviving wire to be closed")
        }
    }

    @Test("The same coincident edge, left FORWARD, is NOT excluded (contrast fixture)")
    func forwardEdgeNotExcluded() {
        guard let shape = Self.fixture(orientation: .forward) else {
            Issue.record("fixture build failed")
            return
        }
        let wires = shape.sectionWiresAtZ(3.0, tolerance: 1e-6)
        // The floating FORWARD edge shares no vertex with the square, so it must survive as its
        // own open 1-edge wire: 2 wires total. This is the injected-failure check for
        // internalEdgeExcluded() above, run as its own assertion rather than a disabled test --
        // if orientation stopped mattering, this would start failing too.
        #expect(wires.count == 2, "expected 2 wires (square + floating edge), got \(wires.count)")
    }

    @Test("An EXTERNAL edge is excluded the same way as INTERNAL")
    func externalEdgeExcluded() {
        guard let shape = Self.fixture(orientation: .external) else {
            Issue.record("fixture build failed")
            return
        }
        let wires = shape.sectionWiresAtZ(3.0, tolerance: 1e-6)
        #expect(wires.count == 1, "expected 1 wire (the square only), got \(wires.count)")
    }
}
