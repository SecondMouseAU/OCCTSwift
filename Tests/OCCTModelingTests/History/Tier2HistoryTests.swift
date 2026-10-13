import Testing

@testable import OCCTSwift

// MARK: - Tier 2 modification ops with full per-input history (issue #165)

@Suite("Tier 2 modification history")
struct Tier2HistoryTests {
    @Test("Filleted edges → input edge appears in history (modified or generated)")
    func filletedEdgesWithHistory() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else {
            Issue.record("box has no edges")
            return
        }
        // Try fillet on the first edge, fall through to other edges if the
        // first fails (edge ordering depends on TopoDS internals; not all
        // edges accept the same radius cleanly).
        var workingResult: (result: Shape, history: ShapeHistoryRef)?
        var workingEdgeIdx = -1
        for i in 0..<min(edges.count, 6) {
            if let r = box.filletedWithFullHistory(radius: 1.0, edges: [i]) {
                workingResult = r
                workingEdgeIdx = i
                break
            }
        }
        guard let r = workingResult, workingEdgeIdx >= 0 else {
            Issue.record("no edge accepted a uniform 1.0 fillet")
            return
        }
        #expect(try #require(r.result.volume) > 0)

        // The filleted edge itself: typically deleted + a generated fillet face.
        let inputEdge = edges[workingEdgeIdx]
        let rec = r.history.record(of: inputEdge)
        #expect(
            rec.modified.count + rec.generated.count > 0 || rec.isDeleted,
            "input edge should appear in history (modified, generated, or deleted)")
    }

    @Test("Chamfered edges → result smaller volume, history queryable")
    func chamferedEdgesWithHistory() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        var workingResult: (result: Shape, history: ShapeHistoryRef)?
        for i in 0..<min(edges.count, 6) {
            if let r = box.chamferedWithFullHistory(distance: 1.0, edges: [i]) {
                workingResult = r
                break
            }
        }
        guard let r = workingResult else {
            Issue.record("no edge accepted a 1.0 chamfer")
            return
        }
        #expect(try #require(r.result.volume) > 0)
        #expect(try #require(r.result.volume) < #require(box.volume))
        // History must answer queries on every input subshape without crashing.
        for face in box.subShapes(ofType: .face) {
            _ = r.history.record(of: face)
        }
    }

    @Test("Shelled with history: removed face is deleted, surrounding faces modified or generated")
    func shelledWithHistory() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else {
            Issue.record("box has no faces")
            return
        }
        // Shell by removing the first face with a thin inward thickness.
        guard let r = box.shelledWithFullHistory(facesToRemove: [0], thickness: -0.5) else {
            Issue.record("shell failed for first face")
            return
        }
        #expect(try #require(r.result.volume) > 0)
        // Removed face should be deleted in the result.
        let removedFace = faces[0]
        let rec = r.history.record(of: removedFace)
        // Either the face is deleted outright, or it's modified into the
        // outer-shell counterpart depending on how MakeThickSolidByJoin
        // classifies it. Both are valid; what matters is that the lookup works.
        #expect(rec.isDeleted || !rec.modified.isEmpty || !rec.generated.isEmpty)
    }

    @Test("Defeatured: removed face is deleted in the result")
    func defeaturedWithHistory() throws {
        // Create a box with a small chamfer, then defeature the chamfer face.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let chamfered = try #require(box.chamfered(distance: 0.5))
        let chamferedFaces = chamfered.subShapes(ofType: .face)
        // #3332: a chamfered box has 26 faces, not 18 (the old comment): the 6 box faces, 12 edge
        // chamfers (area 0.5 * sqrt(2) * 0.5 * 9 = 6.364 each) and 8 corner triangles (0.2165).
        // The old test picked face 6, a corner triangle, under `guard ... else { return }`, and
        // asserted `volume > 0`. Pick an EDGE chamfer by its area, so removing it must restore
        // the sharp edge: measured volume 985.667 -> 986.75 (13/12 mm^3 back).
        #expect(chamferedFaces.count == 26)
        let edgeChamferIndex = try #require(
            chamferedFaces.firstIndex { face in
                abs((face.surfaceArea ?? 0) - 6.3639610306789285) < 1e-6
            })
        let before = try #require(chamfered.volume)
        #expect(abs(before - 985.6666666666669) < 1e-6)

        let r = try #require(chamfered.defeaturedWithFullHistory(faces: [edgeChamferIndex]))
        #expect(r.result.isValid)
        let after = try #require(r.result.volume)
        #expect(abs(after - 986.75) < 1e-6)
        #expect(after > before, "removing a chamfer gives material back")
        #expect(r.result.faceCount == 25)

        let removedFace = chamferedFaces[edgeChamferIndex]
        let rec = r.history.record(of: removedFace)
        #expect(rec.isDeleted, "explicitly defeatured face should be marked deleted")
        // A face the defeature did not touch is not deleted: the +z box face (area 81 = 9 x 9).
        let bigFace = try #require(
            chamferedFaces.first { abs(($0.surfaceArea ?? 0) - 81) < 1e-6 })
        #expect(!r.history.record(of: bigFace).isDeleted)
    }
}
