import Foundation
import Testing

@testable import OCCTSwift

/// #336: a reported "second `*WithFullHistory` op chained onto a prior op's
/// output absorbs zero records" turned out not to be a bug in
/// `add(_:absorbing:inputRoots:operationName:)` at all.
///
/// The reporter's repro
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

    /// What a corner cut leaves in the history, by the kind of node each record is keyed on.
    ///
    /// Clipping one corner of a box touches the solid, the three faces and three edges that meet
    /// at the corner, and deletes the corner's one vertex: a Modified and a Generated record for
    /// each face and each edge (the faces and edges split into the pieces the cut leaves), one
    /// Modified record for the solid, and one Deleted record (empty replacements) for the vertex.
    /// That is 1 + 3 * 2 + 3 * 2 + 1 = 14 records, which is what the kernel gives for each hop.
    private struct CornerCut: Equatable {
        var solids = Set<Int>()
        var faces = Set<Int>()
        var edges = Set<Int>()
        var deletedVertices = Set<Int>()
        var records = 0

        init(_ records: ArraySlice<BRepGraph.HistoryRecord>) {
            for record in records {
                self.records += 1
                for (key, replacements) in record.mapping {
                    switch key.kind {
                    case .solid: solids.insert(key.index)
                    case .face: faces.insert(key.index)
                    case .edge: edges.insert(key.index)
                    case .vertex: if replacements.isEmpty { deletedVertices.insert(key.index) }
                    default: break
                    }
                }
            }
        }

        func expectIsOneCorner(_ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(
                records == 14, "\(what): records, got \(records)", sourceLocation: sourceLocation)
            #expect(
                solids.count == 1, "\(what): one solid, got \(solids)",
                sourceLocation: sourceLocation)
            #expect(
                faces.count == 3, "\(what): the 3 faces at the corner, got \(faces)",
                sourceLocation: sourceLocation)
            #expect(
                edges.count == 3, "\(what): the 3 edges at the corner, got \(edges)",
                sourceLocation: sourceLocation)
            #expect(
                deletedVertices.count == 1,
                "\(what): the corner vertex deleted, got \(deletedVertices)",
                sourceLocation: sourceLocation)
        }
    }

    /// A node of `shape` in `graph`, as the `NodeRef` the history calls take.
    private func nodeRef(of shape: Shape, in graph: BRepGraph) throws -> BRepGraph.NodeRef {
        let raw = try #require(graph.findNode(for: shape), "the shape is a node of the graph")
        return BRepGraph.NodeRef(kind: raw.kind, index: raw.index)
    }

    /// Same shape and box-centering as the issue, but with tool placements
    /// that actually clip real corners, proving the chain absorbs correctly
    /// once the geometry genuinely intersects.
    @Test("two chained WithFullHistory cuts both absorb real records")
    func chainedCutsAbsorbAcrossTwoHops() throws {
        // Shape.box(width:height:depth:) is centered at the origin:
        // [-5,5] x [-10,10] x [-15,15], volume 6000.
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let graph = try #require(BRepGraph(shape: box))
        let root0 = try nodeRef(of: box, in: graph)
        #expect(graph.historyRecordCount == 0, "nothing is recorded before the first hop")

        // Corner-anchored tool clipping the (5, 10, 15) corner: it overlaps the box in the
        // unit cube [4,5] x [9,10] x [14,15], so the cut removes volume 1.
        let tool1 = try #require(Shape.box(origin: SIMD3(4, 9, 14), width: 3, height: 3, depth: 3))
        let (out1, hist1) = try #require(box.subtractedWithFullHistory(tool1), "hop1 subtract")
        let v1 = try #require(out1.volume, "out1 has a volume")
        #expect(abs(v1 - 5999) < 1e-6, "hop1 removes the unit corner cube, got \(v1)")

        let before1 = graph.historyRecordCount
        let added1 = graph.add(out1, absorbing: hist1, inputRoots: [root0], operationName: "hop1")
        // The result is added as its own topology root, the node findNode(for:) finds for it.
        let out1Root = try nodeRef(of: out1, in: graph)
        #expect(added1 == out1Root, "hop1 returns out1's root")
        let hop1Records = graph.historyRecords.dropFirst(before1)
        CornerCut(hop1Records).expectIsOneCorner("hop1")
        #expect(
            hop1Records.allSatisfy { $0.operationName == "hop1" },
            "every record hop1 added carries hop1's label")

        let out1Solid = try #require(out1.subShapes(ofType: .solid).first, "out1 has a solid")
        let root1 = try nodeRef(of: out1Solid, in: graph)

        // Corner-anchored tool clipping the OPPOSITE (-5, -10, -15) corner of
        // the ORIGINAL box, which remains a real corner of out1, since hop1
        // only touched the (5, 10, 15) corner. It overlaps in [-5,-3] x [-10,-8] x [-15,-13],
        // a cube of side 2, so the cut removes volume 8.
        let tool2 = try #require(
            Shape.box(origin: SIMD3(-6, -11, -16), width: 3, height: 3, depth: 3))
        let (out2, hist2) = try #require(out1.subtractedWithFullHistory(tool2), "hop2 subtract")
        let v2 = try #require(out2.volume, "out2 has a volume")
        #expect(abs(v2 - 5991) < 1e-6, "hop2 removes the 2-sided corner cube, got \(v2)")

        // This is the exact call the issue reported as broken, chaining a
        // second *WithFullHistory op onto the first op's live output, using a
        // non-root NodeId (root1) as inputRoots.
        let before2 = graph.historyRecordCount
        let added2 = graph.add(out2, absorbing: hist2, inputRoots: [root1], operationName: "hop2")
        let out2Root = try nodeRef(of: out2, in: graph)
        #expect(added2 == out2Root, "hop2 returns out2's root")
        let hop2Records = graph.historyRecords.dropFirst(before2)
        CornerCut(hop2Records).expectIsOneCorner("hop2")
        #expect(
            hop2Records.allSatisfy { $0.operationName == "hop2" },
            "every record hop2 added carries hop2's label, and none of hop1's is rewritten")
        #expect(
            graph.historyRecords.prefix(before2).allSatisfy { $0.operationName == "hop1" },
            "hop2 leaves hop1's records as they were")
        #expect(
            graph.hasHistoryRecord(for: root1),
            "root1 should carry a history record after a real chained cut touched it")
    }

    /// The issue's exact repro, kept as a permanent regression guard: when the
    /// second tool's bounding box does not overlap the first cut's result at
    /// all, absorbing zero records is correct, not a bug.
    ///
    /// If a future change
    /// to the boolean bridge or the absorb path ever makes this non-zero
    /// (or, worse, silently "recovers" nonexistent history), this test should
    /// catch it.
    @Test("a genuinely non-intersecting second cut absorbs nothing, correctly")
    func nonIntersectingSecondCutAbsorbsNothing() throws {
        let brepURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("issue336-\(UUID().uuidString).brep")
        defer { try? FileManager.default.removeItem(at: brepURL) }

        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        try Exporter.writeBREP(shape: box, to: brepURL)
        let loaded = try Shape.loadBREP(from: brepURL)

        let graph = try #require(BRepGraph(shape: loaded))
        let root0 = try nodeRef(of: loaded, in: graph)

        // Fully INSIDE the centered box, an interior cavity cut, not a
        // corner clip, but still a real geometric change: a 3 x 3 x 3 void, volume 27.
        let tool1 = try #require(
            Shape.box(width: 3, height: 3, depth: 3)?.translated(by: SIMD3(-1, -1, -1)))
        let (out1, hist1) = try #require(loaded.subtractedWithFullHistory(tool1), "hop1 subtract")
        let v1 = try #require(out1.volume, "out1 has a volume")
        #expect(abs(v1 - 5973) < 1e-6, "the cavity removes 27 from 6000, got \(v1)")
        let hop1 = graph.add(out1, absorbing: hist1, inputRoots: [root0], operationName: "hop1")
        #expect(hop1 != nil, "hop1 adds")

        let out1Solid = try #require(out1.subShapes(ofType: .solid).first, "out1 has a solid")
        let root1 = try nodeRef(of: out1Solid, in: graph)

        // Entirely outside out1's [-5,5] x [-10,10] x [-15,15] bounds.
        let tool2 = try #require(
            Shape.box(width: 3, height: 3, depth: 3)?.translated(by: SIMD3(8, 18, 28)))
        let (out2, hist2) = try #require(out1.subtractedWithFullHistory(tool2), "hop2 subtract")
        // Both volumes required: two nils would compare equal and pass.
        let v2 = try #require(out2.volume, "out2 has a volume")
        #expect(
            abs(v2 - v1) < 1e-9, "a non-intersecting tool must leave the volume unchanged")

        let before2 = graph.historyRecordCount
        #expect(before2 > 0, "the control: hop1 did record, so an empty hop2 is not an empty graph")
        let added2 = graph.add(out2, absorbing: hist2, inputRoots: [root1], operationName: "hop2")
        let out2Root = try nodeRef(of: out2, in: graph)
        #expect(
            added2 == out2Root, "add() itself still succeeds, there is simply nothing to absorb")
        #expect(
            graph.historyRecordCount == before2,
            "no geometry changed, so no records should be absorbed")
        #expect(!graph.historyRecords.contains { $0.operationName == "hop2" })
        #expect(!graph.hasHistoryRecord(for: root1))
        #expect(
            graph.findDerivedOrSelf(of: root1) == [root1],
            "untouched by a real op, root1 should resolve to itself")
    }
}
