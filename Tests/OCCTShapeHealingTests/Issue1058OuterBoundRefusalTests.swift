import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1058: `SAWireAnalysis.checkOuterBound(wire:face:)` returned `false` both for "this wire is the
// face's outer bound" and from every path that could not run the check at all, so a caller could
// not tell a refusal from a clean verdict. It now returns `Bool?`.
//
// Four refusal mechanisms are separated deliberately, because they have different causes and a
// fixture that trips one says nothing about the others:
//
//   * a `Shape` that is not a wire or not a face, and a null `TopoDS_Shape`, both of which the
//     bridge rejects before OCCT sees them;
//   * a wire whose edges do not assemble, where `ShapeExtend_WireData::WireAPIMake()` returns a
//     null wire and `BRep_Builder::Add` dereferences it with no null test. That one was an
//     uncatchable SIGSEGV before this fix, not a wrong answer;
//   * a wire with no pcurve on the face, which OCCT does not reject. `ShapeAnalysis::TotCross2D`
//     skips every edge whose pcurve on the face is null, so with none left its accumulator is
//     never written and the `+0.0` it starts from signs as a positive area, reporting a foreign
//     wire as the outer bound. Measured on a planar rectangle handed a cylindrical face.
//
// A plane cannot show the last one: `BRep_Tool::CurveOnSurface` projects a 3D curve onto a plane
// when no pcurve is stored, so a foreign wire on a planar face still gets a real answer. What it
// does not cover is a verdict signed off an area that cancels to rounding, which is #1073. See
// `Scripts/repro/1058-outer-bound-refusal/`.
//
// WHAT THESE TESTS ISOLATE, measured on this commit rather than assumed. Every guard in
// `OCCTWireCheckOuterBound` except the first has a test that fails when that guard alone is broken:
//
//   guard 2, `!IsReady()` returning 0        -> `edgelessWireIsRefused` fails, 1 of 6
//   guard 3, the null-`WireAPIMake` check    -> the process SIGSEGVs, no run summary at all
//   guard 4, the pcurve walk                 -> `wireNotOnTheFaceIsRefused` fails, 1 of 6
//   guard 4 inverted to always refuse        -> `cylinderAnswersForItsOwnWire` fails, 1 of 6
//   every refusal returning 0 (pre-#1058)    -> 5 of 6 fail, the whole-contract run
//
// Guard 1, `occtShapeIsType`, is the exception and is carried as green on purpose: revert it to the
// pre-#1058 pointer-only test and nothing moves, because `catch (...)` takes the wrong-typed shape
// and `IsReady()` takes the nullified one. It is kept for two reasons that are not behavioural, an
// explicit refusal rather than a caught exception, and `check-null-handle-guards.py`'s #1026/#1035
// walk, plus one that is: with guard 1 reverted, `IsReady()` is all that stands between a null
// shape and `EmptyCopied()`, and deleting it there SIGSEGVs immediately.
//
// A first draft of this comment claimed guard 2 was backstopped by guard 3 and that only removing
// two guards at once could fail anything. Both halves were wrong, and re-running the matrix after a
// rebase is what caught it: guard 2 returns rather than falling through, so guard 3 never sees the
// edgeless wire.
@Suite("SAWireAnalysis.checkOuterBound separates a refusal from a clean verdict (#1058)")
struct Issue1058OuterBoundRefusalTests {

    /// The lateral face of a radius-5, height-20 cylinder, picked by area rather than by ordinal
    /// so the fixture proves it is the cylindrical face and not one of the two planar caps.
    private func cylinderLateralFace() -> Shape? {
        guard let cyl = Shape.cylinder(radius: 5, height: 20) else { return nil }
        let faces = cyl.subShapes(ofType: .face)
        guard
            let widest = faces.max(by: { ($0.surfaceArea ?? 0) < ($1.surfaceArea ?? 0) }),
            let area = widest.surfaceArea,
            abs(area - 2 * Double.pi * 5 * 20) < 1e-6
        else { return nil }
        return widest
    }

    @Test("The cylinder's own wire answers false, so the fixture is not refused for being curved")
    func cylinderAnswersForItsOwnWire() {
        guard let lateral = cylinderLateralFace() else {
            Issue.record("cylinder fixture failed")
            return
        }
        guard let own = lateral.subShapes(ofType: .wire).first else {
            Issue.record("cylinder lateral face has no wire")
            return
        }
        // The control that isolates the next test's nil to the wire rather than to the face's
        // surface type, and the only assertion here on the non-nil polarity.
        #expect(SAWireAnalysis.checkOuterBound(wire: own, face: lateral) == false)
    }

    @Test("A wire with no pcurve on the face is refused, not reported as the outer bound")
    func wireNotOnTheFaceIsRefused() {
        guard let panel = panelWithCentredWindow(), let lateral = cylinderLateralFace()
        else {
            Issue.record("fixtures failed")
            return
        }
        guard let panelWire = panel.subShapes(ofType: .wire).first else {
            Issue.record("panel has no wire")
            return
        }
        // Before #1058 this was `false`, the same answer a face's own outer wire gives, produced
        // by signing a zero area no edge contributed to.
        #expect(SAWireAnalysis.checkOuterBound(wire: panelWire, face: lateral) == nil)
    }

    @Test("A Shape that is not a wire is refused, and so is one that is not a face")
    func wrongTypedShapeIsRefused() {
        guard
            let panel = panelWithCentredWindow(),
            let box = Shape.box(width: 1, height: 1, depth: 1)
        else {
            Issue.record("fixtures failed")
            return
        }
        guard let panelWire = panel.subShapes(ofType: .wire).first else {
            Issue.record("panel has no wire")
            return
        }
        #expect(SAWireAnalysis.checkOuterBound(wire: box, face: panel) == nil)
        #expect(SAWireAnalysis.checkOuterBound(wire: panelWire, face: box) == nil)
    }

    @Test("A null shape is refused rather than crashing")
    func nullShapeIsRefused() {
        guard let panel = panelWithCentredWindow() else {
            Issue.record("panel fixture failed")
            return
        }
        guard let panelWire = panel.subShapes(ofType: .wire).first, let empty = panel.nullified
        else {
            Issue.record("panel has no wire, or could not be nullified")
            return
        }
        #expect(SAWireAnalysis.checkOuterBound(wire: empty, face: panel) == nil)
        #expect(SAWireAnalysis.checkOuterBound(wire: panelWire, face: empty) == nil)
    }

    @Test("A wire with no edges is refused")
    func edgelessWireIsRefused() {
        guard let panel = panelWithCentredWindow(), let wire = Shape.builderMakeWire() else {
            Issue.record("fixtures failed")
            return
        }
        // A real, non-null TopoDS_Wire carrying nothing, so it clears the type guard and stops at
        // ShapeAnalysis_Wire::IsReady(), which is `IsLoaded() && !myFace.IsNull()` and false for a
        // WireData of zero edges. This does isolate that guard: make it return 0 instead of -1,
        // leaving every other guard in place, and this is the one test of six that fails.
        #expect(wire.subShapes(ofType: .edge).isEmpty)
        #expect(SAWireAnalysis.checkOuterBound(wire: wire, face: panel) == nil)
    }

    @Test("A wire whose edges do not assemble is refused rather than taking the process down")
    func disconnectedEdgeWireIsRefused() {
        guard
            let panel = panelWithCentredWindow(),
            let wire = Shape.builderMakeWire(),
            let a = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(1, 0, 0)),
            let b = Shape.edgeFromPoints(SIMD3(5, 5, 0), SIMD3(6, 5, 0))
        else {
            Issue.record("fixtures failed")
            return
        }
        #expect(wire.builderAdd(a))
        #expect(wire.builderAdd(b))
        // Two edges that share no vertex, so BRepBuilderAPI_MakeWire cannot assemble them and
        // ShapeExtend_WireData::WireAPIMake() returns a null wire. Against `main` this is a
        // SIGSEGV inside BRep_Builder::Add, which takes the whole test process with it rather
        // than failing this expectation.
        //
        // The edge count is asserted, not assumed: a wire that ended up with no edges is refused
        // by IsReady() instead, one guard earlier, so this test would stay green while covering
        // nothing. Measured by replacing both adds with discards, which left it passing. This is
        // the only test behind the null-WireAPIMake guard, and prove-the-test-fails.md's "a matrix
        // proves guards, not fixtures" is exactly this hole.
        #expect(wire.subShapes(ofType: .edge).count == 2)
        #expect(SAWireAnalysis.checkOuterBound(wire: wire, face: panel) == nil)
    }
}
