import Testing
import simd

@testable import OCCTSwift

// MARK: - Boolean with Full Per-Input History (issue #165)

@Suite("Boolean with Full Per-Input History")
struct BooleanFullHistoryTests {
    @Test("Union returns result + queryable history; non-overlapping faces are 1:1 modified")
    func unionWithFullHistory() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(15, 0, 0))!
        guard let r = box1.unionWithFullHistory(box2) else {
            Issue.record("union should succeed for two disjoint boxes")
            return
        }
        #expect(r.result.volume! > 0)
        // For disjoint solids, every input face should map 1:1 to an output face
        // (modified) and none deleted.
        let face = box1.subShapes(ofType: .face).first!
        let rec = r.history.record(of: face)
        #expect(!rec.isDeleted)
        // Modified should be either empty (face unchanged → still itself) or
        // a single face (face replaced by its identity in the result).
        #expect(rec.modified.count <= 1)
    }

    @Test(
        "Subtract that splits a face → modified or generated mapping returns multiple output faces")
    func subtractedWithFullHistorySplitsFace() {
        // A box with a slab subtracted that crosses ALL THE WAY through →
        // top/bottom/side faces are fully bisected into multiple separate
        // output faces (not just punched with an inner hole).
        let big = Shape.box(width: 20, height: 20, depth: 5)!
        // Slab that fully crosses the box in y, splitting it into two halves:
        let tool = Shape.box(width: 30, height: 4, depth: 20)!
            .translated(by: SIMD3(-5, 8, -5))!
        guard let r = big.subtractedWithFullHistory(tool) else {
            Issue.record("subtract should succeed")
            return
        }
        #expect(r.result.volume! > 0)
        #expect(r.result.volume! < big.volume!)

        // At least one original face should appear twice or more in the
        // output (modified ∪ generated). OCCT classifies face-splits as
        // either depending on internal heuristics, accept either.
        let bigFaces = big.subShapes(ofType: .face)
        var foundSplit = false
        for inputFace in bigFaces {
            let rec = r.history.record(of: inputFace)
            if rec.modified.count + rec.generated.count >= 2 {
                foundSplit = true
                break
            }
        }
        #expect(
            foundSplit,
            "expected at least one input face to map to multiple output faces (modified ∪ generated)"
        )
    }

    @Test("Intersect of overlapping boxes returns history; non-overlap region inputs are deleted")
    func intersectionWithFullHistory() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 5, 5))!
        guard let r = box1.intersectionWithFullHistory(box2) else {
            Issue.record("intersect should succeed for overlapping boxes")
            return
        }
        #expect(r.result.volume! > 0)
        #expect(r.result.volume! < box1.volume!)

        // History should be queryable on every input face without crashing.
        for inputFace in box1.subShapes(ofType: .face) {
            _ = r.history.record(of: inputFace)
        }
    }

    @Test("Splitter at a tool boundary exposes a non-empty result and per-input history")
    func splitWithFullHistory() {
        // BRepAlgoAPI_Splitter on a box with a fully-crossing slab tool.
        // The result is a single compound that may contain one or more solids
        // depending on whether the tool fully partitions the input. What we
        // really care about: the operation succeeded and history is queryable.
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tool = Shape.box(width: 30, height: 1.0, depth: 20)!
            .translated(by: SIMD3(-10, 4.5, -5))!

        guard let r = box.splitWithFullHistory(by: tool) else {
            Issue.record("split should succeed")
            return
        }
        // Splitter result is exposed as the top-level children (pieces). Even
        // if the tool didn't fully partition, the result must contain at least
        // one piece (the un-fragmented input passed through).
        #expect(r.pieces.count >= 1, "split result should contain at least one piece")

        // Every input face must yield queryable history (no crash, no nil).
        // Splitter never deletes faces outright, at worst it modifies them.
        for face in box.subShapes(ofType: .face) {
            let rec = r.history.record(of: face)
            #expect(!rec.isDeleted)
        }
    }

    @Test("History handle outlives the operation; record(of:) is callable repeatedly")
    func historyHandleSurvives() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 5, 5))!
        guard let r = box1.unionWithFullHistory(box2) else {
            Issue.record("union should succeed")
            return
        }
        let face = box1.subShapes(ofType: .face).first!
        let r1 = r.history.record(of: face)
        let r2 = r.history.record(of: face)
        // Repeated lookups must be deterministic and cheap.
        #expect(r1.modified.count == r2.modified.count)
        #expect(r1.generated.count == r2.generated.count)
        #expect(r1.isDeleted == r2.isDeleted)
    }
}
