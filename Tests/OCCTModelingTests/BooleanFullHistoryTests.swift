import Testing
import simd

@testable import OCCTSwift

// MARK: - Boolean with Full Per-Input History (issue #165)

@Suite("Boolean with Full Per-Input History")
struct BooleanFullHistoryTests {
    @Test("Union returns result + queryable history; non-overlapping faces are 1:1 modified")
    func unionWithFullHistory() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(15, 0, 0)))
        let r = try #require(box1.unionWithFullHistory(box2))
        let volume = try #require(r.result.volume)
        #expect(volume > 0)
        // #766: the volume was asserted only `> 0` and the history only `modified.count <= 1`,
        // which an empty history (or a nil result) satisfies. Pinned to the kernel
        // (Scripts/repro/766-modeling-boolean-full-history): two disjoint 1000 mm^3 boxes fuse to
        // 2000, and BRepAlgoAPI_Fuse reports every face of the first box as neither modified,
        // generated nor deleted, because a disjoint solid's faces pass through untouched.
        #expect(abs(volume - 2000) < 1e-6)
        let faces = box1.subShapes(ofType: .face)
        try #require(faces.count == 6)
        for face in faces {
            let rec = r.history.record(of: face)
            #expect(!rec.isDeleted)
            #expect(rec.modified.count == 0)
            #expect(rec.generated.count == 0)
        }
    }

    @Test(
        "Subtract that splits a face → modified or generated mapping returns multiple output faces")
    func subtractedWithFullHistorySplitsFace() throws {
        // A box with a slab subtracted that crosses ALL THE WAY through →
        // top/bottom/side faces are fully bisected into multiple separate
        // output faces (not just punched with an inner hole).
        let big = try #require(Shape.box(width: 20, height: 20, depth: 5))
        // Slab that fully crosses the box in y, splitting it into two halves:
        let tool = try #require(
            Shape.box(width: 30, height: 4, depth: 20)?.translated(by: SIMD3(-5, 8, -5)))
        let r = try #require(big.subtractedWithFullHistory(tool))
        let volume = try #require(r.result.volume)
        let bigVolume = try #require(big.volume)
        #expect(volume > 0)
        #expect(volume < bigVolume)
        // #766: pinned to the kernel (Scripts/repro/766-modeling-boolean-full-history): the slab
        // cuts a 20 x 4 x 5 strip off the +Y side, so 2000 becomes 1600.
        #expect(abs(volume - 1600) < 1e-6)

        // At least one original face should appear twice or more in the
        // output (modified ∪ generated). OCCT classifies face-splits as
        // either depending on internal heuristics, accept either.
        let bigFaces = big.subShapes(ofType: .face)
        try #require(bigFaces.count == 6)
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

        // #766: `foundSplit` is satisfied by any face with two entries in either list. The kernel
        // gives, per face in enumeration order, (modified, generated, deleted) of
        // (1,1,F) (1,0,F) (0,0,F) (0,0,T) (1,1,F) (1,1,F): the +Y face (index 3) lies wholly in the
        // removed strip and is deleted, faces 0, 4 and 5 are each cut into a modified remainder
        // plus a generated piece.
        let recs = bigFaces.map { r.history.record(of: $0) }
        #expect(recs.map { $0.modified.count } == [1, 1, 0, 0, 1, 1])
        #expect(recs.map { $0.generated.count } == [1, 0, 0, 0, 1, 1])
        #expect(recs.map(\.isDeleted) == [false, false, false, true, false, false])
    }

    @Test("Intersect of overlapping boxes returns history; non-overlap region inputs are deleted")
    func intersectionWithFullHistory() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(5, 5, 5)))
        let r = try #require(box1.intersectionWithFullHistory(box2))
        let volume = try #require(r.result.volume)
        let box1Volume = try #require(box1.volume)
        #expect(volume > 0)
        #expect(volume < box1Volume)
        // #766: the volume was only bracketed and the history loop was `_ = r.history.record(...)`,
        // which asserts nothing, so the "non-overlap region inputs are deleted" of the title was
        // never checked. Pinned to the kernel (Scripts/repro/766-modeling-boolean-full-history):
        // the common part is the 5 mm cube, 125; box1's faces at x, y, z = -5 (indices 0, 2, 4)
        // lie outside box2 and are deleted, and its faces at +5 (indices 1, 3, 5) are cut to a
        // modified face and three generated ones each.
        #expect(abs(volume - 125) < 1e-6)
        let faces = box1.subShapes(ofType: .face)
        try #require(faces.count == 6)
        let recs = faces.map { r.history.record(of: $0) }
        #expect(recs.map(\.isDeleted) == [true, false, true, false, true, false])
        #expect(recs.map { $0.modified.count } == [0, 1, 0, 1, 0, 1])
        #expect(recs.map { $0.generated.count } == [0, 3, 0, 3, 0, 3])
    }

    @Test("Splitter at a tool boundary exposes a non-empty result and per-input history")
    func splitWithFullHistory() throws {
        // BRepAlgoAPI_Splitter on a box with a fully-crossing slab tool.
        // The result is a single compound that may contain one or more solids
        // depending on whether the tool fully partitions the input. What we
        // really care about: the operation succeeded and history is queryable.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tool = try #require(
            Shape.box(width: 30, height: 1.0, depth: 20)?.translated(by: SIMD3(-10, 4.5, -5)))

        let r = try #require(box.splitWithFullHistory(by: tool))
        // Splitter result is exposed as the top-level children (pieces). Even
        // if the tool didn't fully partition, the result must contain at least
        // one piece (the un-fragmented input passed through).
        #expect(r.pieces.count >= 1, "split result should contain at least one piece")
        // #766: `>= 1` holds for an unsplit box. Pinned to the kernel
        // (Scripts/repro/766-modeling-boolean-full-history): the slab crosses the box in y, so the
        // result is two pieces.
        #expect(r.pieces.count == 2)

        // Every input face must yield queryable history (no crash, no nil).
        // Splitter never deletes faces outright, at worst it modifies them.
        let faces = box.subShapes(ofType: .face)
        try #require(faces.count == 6)
        for face in faces {
            let rec = r.history.record(of: face)
            #expect(!rec.isDeleted)
        }
        // #766: and, per face in enumeration order, the kernel's (modified, generated) are
        // (2,1) (2,0) (0,0) (1,0) (2,1) (2,0): the faces the slab cuts are modified into two.
        let recs = faces.map { r.history.record(of: $0) }
        #expect(recs.map { $0.modified.count } == [2, 2, 0, 1, 2, 2])
        #expect(recs.map { $0.generated.count } == [1, 0, 0, 0, 1, 0])
    }

    @Test("History handle outlives the operation; record(of:) is callable repeatedly")
    func historyHandleSurvives() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(5, 5, 5)))
        let r = try #require(box1.unionWithFullHistory(box2))
        let boxFaces = box1.subShapes(ofType: .face)
        let face = try #require(boxFaces.first)
        let r1 = r.history.record(of: face)
        let r2 = r.history.record(of: face)
        // Repeated lookups must be deterministic and cheap.
        #expect(r1.modified.count == r2.modified.count)
        #expect(r1.generated.count == r2.generated.count)
        #expect(r1.isDeleted == r2.isDeleted)

        // #766: box1's first face (x = -5) lies outside box2, so every count compared above is 0
        // on both reads and the comparisons hold whatever the history reports, an empty one
        // included. Face 1 (x = +5) is cut by box2; the kernel
        // (Scripts/repro/766-modeling-boolean-full-history) reports 1 modified and 3 generated
        // faces for it, on the first read and the second.
        try #require(boxFaces.count == 6)
        let c1 = r.history.record(of: boxFaces[1])
        let c2 = r.history.record(of: boxFaces[1])
        #expect(c1.modified.count == 1)
        #expect(c1.generated.count == 3)
        #expect(c2.modified.count == c1.modified.count)
        #expect(c2.generated.count == c1.generated.count)
        #expect(!c1.isDeleted)
        #expect(!c2.isDeleted)
    }
}
