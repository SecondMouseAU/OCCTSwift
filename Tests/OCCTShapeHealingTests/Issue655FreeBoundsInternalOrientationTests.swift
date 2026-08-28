import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #655: freeBounds* unaffected by OCCT 8.0.1 INTERNAL/EXTERNAL skip

/// #655 documents `Shape.sectionWiresAtZ(_:tolerance:)` as the one entry point OCCT 8.0.1's
/// `ConnectEdgesToWires` INTERNAL/EXTERNAL skip (OCCT#1408) reaches, and the `freeBounds*` family
/// (this suite) as unaffected, not because its `ShapeAnalysis_FreeBounds` constructor avoids the
/// skip (its own chainage step calls the same `ConnectEdgesToWires`), but because the
/// `BRepBuilderAPI_Sewing::FreeEdge` stage this family runs first never hands it an
/// `.internal`/`.external` free edge to begin with. See `Shape.freeBounds(sewingTolerance:)`'s doc
/// comment for the corrected mechanism, and `Issue655SectionWiresOrientationTests`
/// (`OCCTModelingTests`) for the `sectionWiresAtZ` side that IS affected.
///
/// Fixture: a face with an embedded, fully-`.internal` closed 4-edge loop (not a hole, holes get
/// REVERSED, not INTERNAL), plus a second, disjoint plain face, both in a compound (the
/// `(shape, tolerance)` constructor's documented input shape). Built via the public
/// `Shape.builderMakeWire()`/`.builderAdd(_:)`/`.setOrientation(_:)` API, the same primitives OCCT
/// itself uses to model an embedded (non-hole) feature edge on a face.
@Suite("#655: freeBounds* unaffected by INTERNAL orientation")
struct Issue655FreeBoundsInternalOrientationTests {

    /// Builds a compound of two disjoint square faces. `loopOrientation` sets the orientation of a
    /// second, smaller closed 4-edge loop embedded inside the first face: `.internal` reproduces the
    /// shape #655 measured directly against `ShapeAnalysis_FreeBounds::GetClosedWires()`/
    /// `GetOpenWires()`; `.forward` is the "prove the test fails" injection, the same geometry, with
    /// the loop now a genuine (non-embedded-feature) free-standing boundary the analyzer must report.
    ///
    /// The loop has to be embedded ON a face, not a sibling shape in the compound: a loose wire with
    /// no face ancestor is invisible to `ShapeAnalysis_FreeBounds` regardless of orientation, which
    /// would make this fixture prove nothing about the orientation skip at all.
    ///
    /// The loop's edges are built standalone via `Wire.line` and attached through the raw
    /// `builderAdd` primitive, so they carry no pcurve on face1's plane. That works today --
    /// `forwardLoopIsCounted` returning 3 proves sewing sees them regardless -- but if a future
    /// kernel gets stricter about pcurve-less wires on a face, both tests here move together, and
    /// the failure would read as a behaviour regression rather than a fixture problem.
    ///
    /// Every `builderAdd` call is guarded rather than discarded: a silent add failure would leave
    /// the loop absent from `face1` entirely, which is indistinguishable from the loop being
    /// correctly excluded by orientation -- exactly the gap `freeBoundsUnaffectedByInternalOrientation`
    /// needs to not have.
    static func fixture(loopOrientation: Shape.Orientation) -> Shape? {
        guard
            let outerWire1 = Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true
            ), let face1 = Shape.face(from: outerWire1)
        else { return nil }

        let loopPoints: [SIMD3<Double>] = [
            SIMD3(2, 2, 0), SIMD3(8, 2, 0), SIMD3(8, 8, 0), SIMD3(2, 8, 0),
        ]
        guard let loopWireShape = Shape.builderMakeWire() else { return nil }
        for i in 0..<loopPoints.count {
            guard
                let edgeWire = Wire.line(
                    from: loopPoints[i], to: loopPoints[(i + 1) % loopPoints.count]),
                let edge = edgeWire.edges().first,
                let edgeShape = Shape.fromEdge(edge)
            else { return nil }
            edgeShape.setOrientation(loopOrientation)
            guard loopWireShape.builderAdd(edgeShape) else { return nil }
        }
        loopWireShape.setOrientation(loopOrientation)
        guard face1.builderAdd(loopWireShape) else { return nil }

        guard
            let outerWire2 = Wire.polygon3D(
                [SIMD3(50, 50, 0), SIMD3(60, 50, 0), SIMD3(60, 60, 0), SIMD3(50, 60, 0)],
                closed: true
            ), let face2 = Shape.face(from: outerWire2)
        else { return nil }

        return Shape.compound([face1, face2])
    }

    @Test("An embedded INTERNAL loop is absent from both closed and open free bounds")
    func freeBoundsUnaffectedByInternalOrientation() {
        guard let shape = Self.fixture(loopOrientation: .internal) else {
            Issue.record("fixture build failed")
            return
        }
        // Fixture sanity check: the assertions below alone cannot distinguish "the loop was
        // excluded from free bounds" from "the loop was never attached to face1 at all" -- both
        // look identical downstream. This confirms the input actually carries all 12 edges (the
        // two faces' 8 outer edges plus the embedded loop's 4) before asserting anything about
        // what comes back out.
        #expect(
            shape.subShapeCount(ofType: .edge) == 12,
            "fixture must carry the embedded loop's 4 edges")
        // Only the two faces' own 4-edge outer boundaries come back; the embedded INTERNAL loop
        // never becomes a free-bound candidate in the first place (see doc comment above).
        #expect(
            shape.freeBoundsClosedCount(tolerance: 1e-6) == 2,
            "expected 2 closed wires (the two faces' outer boundaries only)")
        #expect(
            shape.freeBoundsClosedWires(tolerance: 1e-6)?.subShapeCount(ofType: .edge) == 8,
            "expected 8 edges total (4 per face); the INTERNAL loop's 4 must not be counted")
        #expect(
            (shape.freeBoundsOpenWires(tolerance: 1e-6)?.subShapeCount(ofType: .wire) ?? 0) == 0,
            "the INTERNAL loop must not surface as an open free bound either")

        if let result = shape.freeBounds(sewingTolerance: 1e-6) {
            #expect(result.closedCount == 2, "freeBounds() must agree with freeBoundsClosedCount")
            #expect(result.openCount == 0, "freeBounds() must agree with freeBoundsOpenWires")
        } else {
            Issue.record("freeBounds() returned nil; expected the two outer boundaries")
        }
    }

    /// The "prove the test fails" injection for the test above: the same fixture with the embedded
    /// loop's orientation changed from `.internal` to `.forward`. A FORWARD loop entirely inside
    /// face1, sharing no vertex with face1's outer boundary, is a genuine second free-bound
    /// candidate on that face, so it must now be counted, as its own closed wire, alongside the two
    /// outer boundaries. Run as a live contrast fixture (not a disabled test) so a future change
    /// that stops the exclusion from mattering fails this test too.
    @Test("The same loop, left FORWARD, IS counted (contrast fixture)")
    func forwardLoopIsCounted() {
        guard let shape = Self.fixture(loopOrientation: .forward) else {
            Issue.record("fixture build failed")
            return
        }
        #expect(
            shape.freeBoundsClosedCount(tolerance: 1e-6) == 3,
            "expected 3 closed wires (2 outer boundaries + the now-visible loop)")
    }

    /// `freeBoundsAnalysis(tolerance:)` (and every sibling built on `FreeBoundsProperties`) takes a
    /// `tolerance <= 0` as a documented request for a different OCCT constructor with no sewing
    /// stage at all: `ShapeAnalysis_FreeBoundsProperties::DispatchBounds()` picks
    /// `ShapeAnalysis_FreeBounds(shape, splitClosed, splitOpen)` instead of the
    /// `(shape, toler, splitClosed, splitOpen)` sewing overload the tests above exercise. Both
    /// overloads end in the same `ConnectEdgesToWires` call the OCCT 8.0.1 INTERNAL/EXTERNAL skip
    /// lives in, but this one reaches it via `ShapeAnalysis_Shell::CheckOrientedShells`/
    /// `FreeEdges()`, never via `BRepBuilderAPI_Sewing`. Round 2's tests never exercised this
    /// branch (both used `tolerance: 1e-6`), so the doc's "unaffected on either kernel" note was an
    /// unmeasured extrapolation from the sewing branch's reasoning for this input. This measures it
    /// directly instead.
    ///
    /// Two things this proves, together:
    /// - The `.internal` loop is still absent at `tolerance <= 0`, matching the sewing branch, so
    ///   the doc's guarantee now holds on this input because it was checked, not assumed.
    /// - The `.forward` control disagrees sharply between branches: 3 closed wires under sewing
    ///   (chained into one wire with the outer boundary) versus 2 closed + 4 open under
    ///   shared-topology (the loop's four edges come back unchained). That divergence is the
    ///   evidence that the two branches are doing genuinely different things, which is what makes
    ///   the `.internal` agreement a real result rather than the two branches trivially agreeing on
    ///   everything.
    ///
    /// `0.0` and a negative tolerance are both tested because the doc says "0 or below" selects
    /// this branch; a test of only `0.0` would leave "below" unmeasured.
    ///
    /// This cannot distinguish, and does not claim to, *why* the `.internal` loop is absent here:
    /// `ShapeAnalysis_FreeBounds`'s shared-topology constructor defaults `checkinternaledges` to
    /// `false` (`ShapeAnalysis_FreeBounds.hxx:98`), so the internal edges may never reach
    /// `FreeEdges()` as candidates at all, rather than being collected and then dropped by the same
    /// skip the sewing branch's chainage step hits. Both produce the same observable result, which
    /// is the only thing measured and the only thing the doc claims.
    @Test(
        "At tolerance <= 0 (no sewing stage), the .internal exclusion still holds, and .forward proves the branches genuinely differ",
        arguments: [
            (Shape.Orientation.internal, 0.0, 2, 0),
            (Shape.Orientation.internal, -1.0, 2, 0),
            (Shape.Orientation.forward, 0.0, 2, 4),
            (Shape.Orientation.forward, -1.0, 2, 4),
        ]
    )
    func sharedTopologyBranchMeasuredDirectly(
        loopOrientation: Shape.Orientation, tolerance: Double, expectedClosed: Int,
        expectedOpen: Int
    ) {
        guard let shape = Self.fixture(loopOrientation: loopOrientation) else {
            Issue.record("fixture build failed")
            return
        }
        let analysis = shape.freeBoundsAnalysis(tolerance: tolerance)
        #expect(
            analysis.closedCount == expectedClosed,
            "orientation \(loopOrientation), tolerance \(tolerance): expected \(expectedClosed) closed wires, got \(analysis.closedCount)"
        )
        #expect(
            analysis.openCount == expectedOpen,
            "orientation \(loopOrientation), tolerance \(tolerance): expected \(expectedOpen) open wires, got \(analysis.openCount)"
        )
    }
}
