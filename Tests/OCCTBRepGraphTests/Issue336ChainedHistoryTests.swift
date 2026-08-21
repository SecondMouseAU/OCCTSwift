import Testing
import Foundation
@testable import OCCTSwift

/// #336: a reported "second `*WithFullHistory` op chained onto a prior op's
/// output absorbs zero records" turned out not to be a bug in
/// `add(_:absorbing:inputRoots:operationName:)` at all. The reporter's repro
/// used `Shape.box(width:height:depth:)`, which is documented as **centered
/// at the origin** (see its doc comment and `OCCTShapeCreateBox`), not
/// corner-anchored like raw OCCT's `BRepPrimAPI_MakeBox(w,h,d)`. That made the
/// first "corner" tool land fully *inside* the box and the second "opposite
/// corner" tool land entirely *outside* it (bounding boxes don't even
/// overlap), so the second cut was a genuine geometric no-op, and zero
/// absorbed records was the correct answer.
///
/// Verified two ways: (1) probing the raw `ShapeHistoryRef` directly against
/// `out1.faces()`, bypassing the graph entirely, showed the same zero
/// modified/generated/deleted records, so the boolean's own history
/// construction was never in question. (2) `out1.volume == out2.volume`
/// confirms the second cut changed nothing geometrically.
///
/// What WAS missing: no existing test chained two `*WithFullHistory` ops
/// end-to-end (second op fed from the first op's live, Compound-wrapped
/// output) or passed a non-root node as `inputRoots`, every
/// `GraphHistoryAbsorbTests` case only does a single hop rooted at the
/// graph's own top-level node. These tests close that gap.
@Suite("Chained WithFullHistory absorb (#336)")
struct Issue336ChainedHistoryTests {

    /// Same shape and box-centering as the issue, but with tool placements
    /// that actually clip real corners, proving the chain absorbs correctly
    /// once the geometry genuinely intersects.
    @Test("two chained WithFullHistory cuts both absorb real records")
    func chainedCutsAbsorbAcrossTwoHops() {
        // Shape.box(width:height:depth:) is centered at the origin:
        // [-5,5] x [-10,10] x [-15,15].
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
              let graph = BRepGraph(shape: box),
              let root0Raw = graph.findNode(for: box) else {
            Issue.record("box/graph setup failed"); return
        }
        let root0 = BRepGraph.NodeRef(kind: root0Raw.kind, index: root0Raw.index)

        // Corner-anchored tool clipping the (5, 10, 15) corner.
        guard let tool1 = Shape.box(origin: SIMD3(4, 9, 14), width: 3, height: 3, depth: 3),
              let (out1, hist1) = box.subtractedWithFullHistory(tool1) else {
            Issue.record("hop1 subtract failed"); return
        }

        let before1 = graph.historyRecordCount
        let added1 = graph.add(out1, absorbing: hist1, inputRoots: [root0], operationName: "hop1")
        #expect(added1 != nil, "hop1 add should return the result's topology root")
        #expect(graph.historyRecordCount > before1,
                "hop1 should absorb real records, tool1 genuinely clips a corner of the box")

        guard let out1Solid = out1.subShapes(ofType: .solid).first,
              let root1Raw = graph.findNode(for: out1Solid) else {
            Issue.record("out1Solid/root1 lookup failed"); return
        }
        let root1 = BRepGraph.NodeRef(kind: root1Raw.kind, index: root1Raw.index)

        // Corner-anchored tool clipping the OPPOSITE (-5, -10, -15) corner of
        // the ORIGINAL box, which remains a real corner of out1, since hop1
        // only touched the (5, 10, 15) corner.
        guard let tool2 = Shape.box(origin: SIMD3(-6, -11, -16), width: 3, height: 3, depth: 3),
              let (out2, hist2) = out1.subtractedWithFullHistory(tool2) else {
            Issue.record("hop2 subtract failed"); return
        }
        if let v1 = out1.volume, let v2 = out2.volume {
            #expect(v2 < v1, "hop2's tool genuinely overlaps out1, so its volume must shrink")
        } else {
            Issue.record("volume() failed for out1/out2")
        }

        // This is the exact call the issue reported as broken, chaining a
        // second *WithFullHistory op onto the first op's live output, using a
        // non-root NodeId (root1) as inputRoots.
        let before2 = graph.historyRecordCount
        let added2 = graph.add(out2, absorbing: hist2, inputRoots: [root1], operationName: "hop2")
        #expect(added2 != nil, "hop2 add should return the result's topology root")
        #expect(graph.historyRecordCount > before2,
                "hop2 should absorb real records once its tool genuinely clips a corner of out1")
        #expect(graph.hasHistoryRecord(for: root1),
                "root1 should carry a history record after a real chained cut touched it")
    }

    /// The issue's exact repro, kept as a permanent regression guard: when the
    /// second tool's bounding box does not overlap the first cut's result at
    /// all, absorbing zero records is correct, not a bug. If a future change
    /// to the boolean bridge or the absorb path ever makes this non-zero
    /// (or, worse, silently "recovers" nonexistent history), this test should
    /// catch it.
    @Test("a genuinely non-intersecting second cut absorbs nothing, correctly")
    func nonIntersectingSecondCutAbsorbsNothing() throws {
        let brepURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("issue336-\(UUID().uuidString).brep")
        defer { try? FileManager.default.removeItem(at: brepURL) }

        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            Issue.record("box failed"); return
        }
        try Exporter.writeBREP(shape: box, to: brepURL)
        let loaded = try Shape.loadBREP(from: brepURL)

        guard let graph = BRepGraph(shape: loaded),
              let root0Raw = graph.findNode(for: loaded) else {
            Issue.record("graph/root0 setup failed"); return
        }
        let root0 = BRepGraph.NodeRef(kind: root0Raw.kind, index: root0Raw.index)

        // Fully INSIDE the centered box, an interior cavity cut, not a
        // corner clip, but still a real geometric change.
        guard let tool1 = Shape.box(width: 3, height: 3, depth: 3)?.translated(by: SIMD3(-1, -1, -1)),
              let (out1, hist1) = loaded.subtractedWithFullHistory(tool1) else {
            Issue.record("hop1 subtract failed"); return
        }
        _ = graph.add(out1, absorbing: hist1, inputRoots: [root0], operationName: "hop1")

        guard let out1Solid = out1.subShapes(ofType: .solid).first,
              let root1Raw = graph.findNode(for: out1Solid) else {
            Issue.record("out1Solid/root1 lookup failed"); return
        }
        let root1 = BRepGraph.NodeRef(kind: root1Raw.kind, index: root1Raw.index)

        // Entirely outside out1's [-5,5] x [-10,10] x [-15,15] bounds.
        guard let tool2 = Shape.box(width: 3, height: 3, depth: 3)?.translated(by: SIMD3(8, 18, 28)),
              let (out2, hist2) = out1.subtractedWithFullHistory(tool2) else {
            Issue.record("hop2 subtract failed"); return
        }
        #expect(out1.volume == out2.volume, "a non-intersecting tool must leave the volume unchanged")

        let before2 = graph.historyRecordCount
        let added2 = graph.add(out2, absorbing: hist2, inputRoots: [root1], operationName: "hop2")
        #expect(added2 != nil, "add() itself still succeeds, there is simply nothing to absorb")
        #expect(graph.historyRecordCount == before2,
                "no geometry changed, so no records should be absorbed")
        #expect(!graph.hasHistoryRecord(for: root1))
        #expect(graph.findDerivedOrSelf(of: root1) == [root1],
                "untouched by a real op, root1 should resolve to itself")
    }
}
