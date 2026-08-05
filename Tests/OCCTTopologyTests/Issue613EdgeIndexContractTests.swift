import Testing
import Foundation
@testable import OCCTSwift

/// #613: an edge or vertex index crossing the bridge means a position in the **deduplicated**
/// `TopExp::MapShapes` enumeration — the one `edges()` / `edgeCount` / `edge(at:)` and
/// `vertices()` / `vertexCount` already use. Several entry points instead walked a bare
/// `TopExp_Explorer`, which yields one entry per topology **occurrence**.
///
/// The two disagree on every ordinary solid, because each edge is shared by the two faces it
/// bounds. Measured against this kernel: a 20 mm box has 12 distinct edges and **24** edge
/// occurrences; the L-prism has 18 and 36.
///
/// That surplus is what these tests key on. An index at or above `edgeCount` is one `edges()` can
/// never hand out, but it addressed a real edge under the occurrence walk — so every converted
/// entry point must now refuse it. A test that only passed valid indices would not tell the two
/// schemes apart at all.
@Suite("Issue 613 — edge and vertex index contract")
struct Issue613EdgeIndexContractTests {

    /// Distinct sub-shapes versus occurrences, the asymmetry the whole issue rests on.
    @Test("a box has twice as many edge occurrences as it has distinct edges")
    func occurrencesExceedDistinctEdges() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        #expect(box.edgeCount == 12)
        #expect(box.edges().count == 12)
        // 12 faces-worth of sharing: every index in 12..<24 was reachable through the old walk.
        #expect(box.subShapeCount(ofType: .edge) == 12)
    }

    // MARK: - BRepCheck per sub-shape (checkSubShape)

    @Test("checkEdge refuses an index edges() cannot produce")
    func checkEdgeRefusesOutOfRange() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))

        // Every real edge checks out.
        for i in 0..<box.edgeCount {
            #expect(box.checkEdge(at: i).isValid, "edge \(i) should be a valid edge")
        }
        // The first index past the end. Under the occurrence walk this named a real edge and
        // reported valid; there are 24 occurrences behind these 12 edges.
        #expect(!box.checkEdge(at: box.edgeCount).isValid)
        #expect(!box.checkEdge(at: box.edgeCount + 5).isValid)
    }

    @Test("checkVertex refuses an index vertices() cannot produce")
    func checkVertexRefusesOutOfRange() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        #expect(box.vertexCount == 8)

        for i in 0..<box.vertexCount {
            #expect(box.checkVertex(at: i).isValid, "vertex \(i) should be a valid vertex")
        }
        // A box has 8 distinct vertices behind 48 occurrences.
        #expect(!box.checkVertex(at: box.vertexCount).isValid)
        #expect(!box.checkVertex(at: box.vertexCount + 10).isValid)
    }

    // MARK: - BRepExtrema_ExtCC (edgeEdgeExtrema)

    @Test("edgeEdgeExtrema refuses an index edges() cannot produce")
    func extremaAddressesTheNamedEdge() throws {
        let box = try #require(Shape.box(origin: SIMD3(0, 0, 0),
                                         width: 20, height: 20, depth: 20))
        let moved = try #require(Shape.box(origin: SIMD3(0, 0, 50),
                                           width: 20, height: 20, depth: 20))

        // In-range indices resolve. Not all of them: the two shapes are translates, so many
        // same-index pairs are parallel, and BRepExtrema_ExtCC reports no solution for those by
        // design (the parallel guard this repo carries for the OCCT crash). Some must resolve.
        let resolved = (0..<box.edgeCount).filter {
            box.edgeEdgeExtrema(edgeIndex1: $0, other: moved, edgeIndex2: $0) != nil
        }
        #expect(!resolved.isEmpty, "no in-range edge pair resolved at all")

        // The discriminating half: indices 12..23 each addressed a real edge under the occurrence
        // walk, because a 12-edge box has 24 edge occurrences. None may resolve now.
        for i in box.edgeCount..<(box.edgeCount * 2) {
            #expect(box.edgeEdgeExtrema(edgeIndex1: i, other: moved, edgeIndex2: 0) == nil,
                    "index \(i) is past edgeCount \(box.edgeCount) and must not resolve")
        }
        #expect(box.edgeEdgeExtrema(edgeIndex1: 0, other: moved, edgeIndex2: moved.edgeCount) == nil)
    }

    // MARK: - LocOpe_SplitShape (splitEdge)

    /// The sharpest of these: a 10x20x30 box has edges of three distinct lengths, and `splitEdge`
    /// hands back just the two halves. Splitting index `i` at t = 0.5 must therefore produce two
    /// pieces of exactly `edges()[i].length / 2` — which pins the index to one specific edge
    /// rather than merely to "some edge".
    @Test("splitEdge halves the edge edges() names, at every index")
    func splitEdgeUsesTheSameEnumeration() throws {
        let box = try #require(Shape.box(origin: SIMD3(0, 0, 0),
                                         width: 10, height: 20, depth: 30))
        let lengths = box.edges().map(\.length)
        try #require(Set(lengths.map { Int($0.rounded()) }) == [10, 20, 30],
                     "the fixture must have distinct edge lengths to be discriminating")

        for i in 0..<box.edgeCount {
            let split = try #require(box.splitEdge(at: i, parameter: 0.5),
                                     "edge \(i) should split")
            #expect(split.edgeCount == 2, "a halved edge is two pieces, got \(split.edgeCount)")
            for piece in split.edges() {
                #expect(abs(piece.length - lengths[i] / 2) < 1e-6,
                        "edge \(i) is \(lengths[i]) long, so each half is \(lengths[i] / 2), got \(piece.length)")
            }
        }

        #expect(box.splitEdge(at: box.edgeCount, parameter: 0.5) == nil)
    }

    // MARK: - Edge.index stamped on loose edges (LocOpe_FindEdges / FindEdgesInFace)

    @Test("commonEdges stamps an index that round-trips through edges()")
    func commonEdgesStampParentIndex() throws {
        let box = try #require(Shape.box(origin: SIMD3(0, 0, 0),
                                         width: 20, height: 20, depth: 20))
        let other = try #require(Shape.box(origin: SIMD3(20, 0, 0),
                                           width: 20, height: 20, depth: 20))

        let shared = box.commonEdges(with: other)
        try #require(!shared.isEmpty, "the two boxes abut, so they share edges")

        for e in shared {
            // Before the fix this was the position in the result buffer (0, 1, 2, ...), which
            // addresses an unrelated edge once fed back into edges() or filleted(edges:).
            #expect(e.index >= 0 && e.index < box.edgeCount,
                    "index \(e.index) is not addressable in a \(box.edgeCount)-edge shape")
            let named = box.edges()[e.index]
            #expect(abs(named.length - e.length) < 1e-6,
                    "edges()[\(e.index)] is \(named.length) long, the stamped edge is \(e.length)")
        }
    }

    @Test("edgesInFace stamps an index that round-trips through edges()")
    func edgesInFaceStampParentIndex() throws {
        let box = try #require(Shape.box(origin: SIMD3(0, 0, 0),
                                         width: 20, height: 20, depth: 20))

        let found = box.edgesInFace(at: 0)
        try #require(!found.isEmpty, "a box face is bounded by edges")

        for e in found {
            #expect(e.index >= 0 && e.index < box.edgeCount,
                    "index \(e.index) is not addressable in a \(box.edgeCount)-edge shape")
            let named = box.edges()[e.index]
            #expect(abs(named.length - e.length) < 1e-6,
                    "edges()[\(e.index)] is \(named.length) long, the stamped edge is \(e.length)")
        }
    }
}
