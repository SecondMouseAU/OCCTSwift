import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.141 / #72 Phase 0: BRepGraph history record readback

@Suite("v0.141 BRepGraph history record readback")
struct BRepGraphHistoryReadbackTests {
    private func node(_ kind: BRepGraph.NodeKind, _ index: Int) -> BRepGraph.NodeRef {
        BRepGraph.NodeRef(kind: kind, index: index)
    }

    /// A box graph with history enabled and the log empty. The recorded nodes are inventions on
    /// purpose: the log stores whatever it is given and never checks it against the topology.
    private func makeGraph() throws -> BRepGraph {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "box")
        let graph = try #require(BRepGraph(shape: box), "graph of a box")
        graph.isHistoryEnabled = true
        graph.clearHistory()
        try #require(graph.historyRecordCount == 0, "the log must start empty")
        return graph
    }

    @Test("Recorded 1-to-1 modification survives roundtrip through the API")
    func oneToOneReadback() throws {
        let graph = try makeGraph()
        let orig = node(.face, 0)
        let repl = node(.face, 42)
        graph.recordHistory(operationName: "TestFillet", original: orig, replacements: [repl])

        #expect(graph.historyRecordCount == 1)
        let rec = try #require(graph.historyRecord(at: 0), "record 0")
        #expect(rec.operationName == "TestFillet")
        // OCCT numbers a record by its position in the log: `SequenceNumber = myRecords.Size()`
        // in BRepGraph_LayerHistory::Record, taken before the append.
        #expect(rec.sequenceNumber == 0)
        #expect(rec.mapping == [orig: [repl]])

        // A second record is numbered 1 and the first keeps 0, and the log has no record 1 yet
        // to read before it is written, nor a record -1 at all.
        #expect(graph.historyRecord(at: 1) == nil)
        graph.recordHistory(
            operationName: "Second", original: node(.face, 1), replacements: [node(.face, 43)])
        let second = try #require(graph.historyRecord(at: 1), "record 1")
        #expect(second.operationName == "Second")
        #expect(second.sequenceNumber == 1)
        let firstAgain = try #require(graph.historyRecord(at: 0), "record 0 after a second record")
        #expect(firstAgain.sequenceNumber == 0)
        #expect(graph.historyRecord(at: 2) == nil)
        #expect(graph.historyRecord(at: -1) == nil)
    }

    @Test("Split (1-to-N) mapping round-trips")
    func splitMapping() throws {
        let graph = try makeGraph()
        // Deliberately not in ascending index order, so a readback that sorts, or reverses, or
        // de-duplicates its replacements is not mistaken for one that preserves them.
        let orig = node(.edge, 3)
        let a = node(.edge, 102)
        let b = node(.edge, 100)
        let c = node(.edge, 101)
        graph.recordHistory(operationName: "SplitEdge", original: orig, replacements: [a, b, c])

        let rec = try #require(graph.historyRecord(at: 0), "record 0")
        #expect(rec.mapping.count == 1)
        #expect(rec.mapping[orig] == [a, b, c])
    }

    @Test("Deletion (1-to-0) round-trips")
    func deletionMapping() throws {
        let graph = try makeGraph()
        let orig = node(.face, 5)
        let bystander = node(.face, 6)
        graph.recordHistory(operationName: "RemoveFace", original: orig, replacements: [])

        let rec = try #require(graph.historyRecord(at: 0), "record 0")
        #expect(rec.mapping == [orig: []])
        // OCCT turns a record with no replacements into a deletion and adds the original to the
        // deleted set (BRepGraph_LayerHistory::Record), so the readback of the deletion and the
        // deleted-set queries agree, and a node nobody consumed is not in either.
        #expect(graph.historyIsDeleted(orig))
        #expect(graph.historyDeletedNodes == [orig])
        #expect(!graph.historyIsDeleted(bystander))
    }

    @Test("FindDerived walks forward through chained records")
    func findDerivedWalksForward() throws {
        let graph = try makeGraph()
        // orig -> [a] -> [b, c]
        let orig = node(.edge, 1)
        let a = node(.edge, 10)
        let b = node(.edge, 20)
        let c = node(.edge, 21)
        graph.recordHistory(operationName: "Op1", original: orig, replacements: [a])
        graph.recordHistory(operationName: "Op2", original: a, replacements: [b, c])

        // OCCT's contract for FindDerived: every transitively reachable descendant, intermediate
        // nodes and leaves alike, not the original itself, in breadth-first order.
        #expect(graph.findDerived(of: orig) == [a, b, c])
        #expect(graph.findDerived(of: a) == [b, c])
        #expect(graph.findDerived(of: b) == [])
        #expect(graph.findDerived(of: node(.edge, 2)) == [], "a node no record names")
    }

    // MARK: - #167: untouched-vs-deleted disambiguation

    @Test("hasHistoryRecord: true for nodes named in any record's mapping; false otherwise")
    func hasHistoryRecordDistinguishesNamedFromUntouched() throws {
        let graph = try makeGraph()
        let modified = node(.face, 0)
        let replaced = node(.face, 100)
        let deleted = node(.face, 1)
        let untouched = node(.face, 2)

        graph.recordHistory(
            operationName: "ModifyFace", original: modified, replacements: [replaced])
        graph.recordHistory(operationName: "DeleteFace", original: deleted, replacements: [])

        #expect(graph.hasHistoryRecord(for: modified), "modified node should be named in a record")
        #expect(
            graph.hasHistoryRecord(for: deleted),
            "explicitly-deleted node should be named in a record")
        #expect(!graph.hasHistoryRecord(for: untouched), "untouched node has no record entry")
        // Named means named as an ORIGINAL: the node a record produced is not named by it, and
        // the kind is part of the name (edge 0 is not face 0).
        #expect(!graph.hasHistoryRecord(for: replaced), "a replacement is not an original")
        #expect(!graph.hasHistoryRecord(for: node(.edge, 0)), "same index, different kind")
    }

    @Test("findDerivedOrSelf: returns derivatives, [] for deleted, [original] for untouched")
    func findDerivedOrSelfDisambiguates() throws {
        let graph = try makeGraph()
        let modified = node(.face, 0)
        let replaced = node(.face, 100)
        let deleted = node(.face, 1)
        let untouched = node(.face, 2)

        graph.recordHistory(
            operationName: "ModifyFace", original: modified, replacements: [replaced])
        graph.recordHistory(operationName: "DeleteFace", original: deleted, replacements: [])

        // Modified: exactly its derivatives, without the node itself.
        #expect(graph.findDerivedOrSelf(of: modified) == [replaced])
        // Deleted: empty (the record is present and its mapping is empty).
        #expect(graph.findDerivedOrSelf(of: deleted) == [])
        // Untouched: itself, at the same index (no record names this node).
        #expect(graph.findDerivedOrSelf(of: untouched) == [untouched])
    }

    @Test("findDerivedOrSelf preserves findDerived semantics for chained records")
    func findDerivedOrSelfMatchesFindDerivedWhenNonEmpty() throws {
        let graph = try makeGraph()
        // orig -> [a] -> [b, c]
        let orig = node(.edge, 1)
        let a = node(.edge, 10)
        let b = node(.edge, 20)
        let c = node(.edge, 21)
        graph.recordHistory(operationName: "Op1", original: orig, replacements: [a])
        graph.recordHistory(operationName: "Op2", original: a, replacements: [b, c])

        // When findDerived is non-empty, findDerivedOrSelf returns the same sequence, which is
        // pinned absolutely so two functions that are wrong the same way cannot agree.
        #expect(graph.findDerived(of: orig) == [a, b, c])
        #expect(graph.findDerivedOrSelf(of: orig) == [a, b, c])
        #expect(graph.findDerivedOrSelf(of: a) == [b, c])
    }

    @Test("FindOriginal walks backwards")
    func findOriginalWalksBackward() throws {
        let graph = try makeGraph()
        let orig = node(.face, 7)
        let mid = node(.face, 70)
        let leaf = node(.face, 700)
        graph.recordHistory(operationName: "A", original: orig, replacements: [mid])
        graph.recordHistory(operationName: "B", original: mid, replacements: [leaf])

        // The root, not the immediate parent: two hops from the leaf.
        #expect(graph.findOriginal(of: leaf) == orig)
        #expect(graph.findOriginal(of: mid) == orig)
        // The root has no original of its own.
        #expect(graph.findOriginal(of: orig) == orig)
    }

    @Test("Unrecorded node findOriginal returns itself")
    func findOriginalPassthrough() throws {
        let graph = try makeGraph()
        let node3 = node(.face, 3)
        #expect(graph.findOriginal(of: node3) == node3, "an empty log")

        // With records present, a node they do not mention still comes back as itself and is not
        // confused with any original or replacement they do mention.
        graph.recordHistory(
            operationName: "A", original: node(.face, 7), replacements: [node(.face, 70)])
        #expect(graph.findOriginal(of: node3) == node3, "a log that does not mention it")
        #expect(graph.findOriginal(of: node(.edge, 7)) == node(.edge, 7), "same index, other kind")
    }

    // MARK: - Readback shapes the original tests did not reach

    @Test("A record's replacements keep their own kinds, not the original's or the first one's")
    func mixedKindReplacements() throws {
        let graph = try makeGraph()
        // A face that modifies into a face while generating an edge and a vertex, the shape a
        // boolean's Generated records take.
        let orig = node(.face, 4)
        let replacements = [node(.face, 40), node(.edge, 41), node(.vertex, 42)]
        graph.recordHistory(
            operationName: "Mixed", original: orig, replacements: replacements)
        let rec = try #require(graph.historyRecord(at: 0), "record 0")
        #expect(rec.mapping[orig] == replacements)
    }

    @Test("A mapping longer than the readback's first buffer round-trips whole")
    func mappingBeyondInitialBuffer() throws {
        let graph = try makeGraph()
        // The readback asks for 8 replacements first and asks again when the bridge reports more.
        let orig = node(.edge, 2)
        var replacements: [BRepGraph.NodeRef] = []
        for i in 0..<12 {
            replacements.append(node(.edge, 200 - 7 * i))
        }
        graph.recordHistory(operationName: "Shatter", original: orig, replacements: replacements)
        let rec = try #require(graph.historyRecord(at: 0), "record 0")
        #expect(rec.mapping[orig]?.count == 12)
        #expect(rec.mapping[orig] == replacements)
    }

    @Test("findDerived with more descendants than its first buffer returns all of them")
    func findDerivedBeyondInitialBuffer() throws {
        let graph = try makeGraph()
        // The query asks for 16 first and asks again when the bridge reports more.
        let orig = node(.edge, 1)
        var replacements: [BRepGraph.NodeRef] = []
        for i in 0..<20 {
            replacements.append(node(.edge, 300 + i))
        }
        graph.recordHistory(operationName: "Shatter", original: orig, replacements: replacements)
        #expect(graph.findDerived(of: orig) == replacements)
    }
}
