import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.141 / #72 Phase 0: BRepGraph history record readback

@Suite("v0.141 BRepGraph history record readback")
struct BRepGraphHistoryReadbackTests {
    @Test("Recorded 1-to-1 modification survives roundtrip through the API")
    func oneToOneReadback() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = BRepGraph.NodeRef(kind: .face, index: 0)
        let repl = BRepGraph.NodeRef(kind: .face, index: 42)
        graph.recordHistory(operationName: "TestFillet", original: orig, replacements: [repl])

        #expect(graph.historyRecordCount == 1)
        guard let rec = graph.historyRecord(at: 0) else {
            Issue.record("record nil")
            return
        }
        #expect(rec.operationName == "TestFillet")
        #expect(rec.mapping.count == 1)
        #expect(rec.mapping[orig] == [repl])
    }

    @Test("Split (1-to-N) mapping round-trips")
    func splitMapping() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = BRepGraph.NodeRef(kind: .edge, index: 3)
        let a = BRepGraph.NodeRef(kind: .edge, index: 100)
        let b = BRepGraph.NodeRef(kind: .edge, index: 101)
        let c = BRepGraph.NodeRef(kind: .edge, index: 102)
        graph.recordHistory(operationName: "SplitEdge", original: orig, replacements: [a, b, c])

        let rec = graph.historyRecord(at: 0)
        #expect(rec?.mapping[orig] == [a, b, c])
    }

    @Test("Deletion (1-to-0) round-trips")
    func deletionMapping() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = BRepGraph.NodeRef(kind: .face, index: 5)
        graph.recordHistory(operationName: "RemoveFace", original: orig, replacements: [])

        let rec = graph.historyRecord(at: 0)
        #expect(rec?.mapping[orig] == [])
    }

    @Test("FindDerived walks forward through chained records")
    func findDerivedWalksForward() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        // orig → [a] → [b, c]
        let orig = BRepGraph.NodeRef(kind: .edge, index: 1)
        let a = BRepGraph.NodeRef(kind: .edge, index: 10)
        let b = BRepGraph.NodeRef(kind: .edge, index: 20)
        let c = BRepGraph.NodeRef(kind: .edge, index: 21)
        graph.recordHistory(operationName: "Op1", original: orig, replacements: [a])
        graph.recordHistory(operationName: "Op2", original: a, replacements: [b, c])

        let derived = Set(graph.findDerived(of: orig))
        // Transitively, orig should reach b and c (and possibly a depending on OCCT's
        // definition of "leaves", we accept either but require at least b, c).
        #expect(derived.isSuperset(of: [b, c]))
    }

    // MARK: - #167: untouched-vs-deleted disambiguation

    @Test("hasHistoryRecord: true for nodes named in any record's mapping; false otherwise")
    func hasHistoryRecordDistinguishesNamedFromUntouched() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let modified = BRepGraph.NodeRef(kind: .face, index: 0)
        let replaced = BRepGraph.NodeRef(kind: .face, index: 100)
        let deleted = BRepGraph.NodeRef(kind: .face, index: 1)
        let untouched = BRepGraph.NodeRef(kind: .face, index: 2)

        graph.recordHistory(
            operationName: "ModifyFace", original: modified, replacements: [replaced])
        graph.recordHistory(operationName: "DeleteFace", original: deleted, replacements: [])

        #expect(graph.hasHistoryRecord(for: modified), "modified node should be named in a record")
        #expect(
            graph.hasHistoryRecord(for: deleted),
            "explicitly-deleted node should be named in a record")
        #expect(!graph.hasHistoryRecord(for: untouched), "untouched node has no record entry")
    }

    @Test("findDerivedOrSelf: returns derivatives, [] for deleted, [original] for untouched")
    func findDerivedOrSelfDisambiguates() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let modified = BRepGraph.NodeRef(kind: .face, index: 0)
        let replaced = BRepGraph.NodeRef(kind: .face, index: 100)
        let deleted = BRepGraph.NodeRef(kind: .face, index: 1)
        let untouched = BRepGraph.NodeRef(kind: .face, index: 2)

        graph.recordHistory(
            operationName: "ModifyFace", original: modified, replacements: [replaced])
        graph.recordHistory(operationName: "DeleteFace", original: deleted, replacements: [])

        // Modified → derivatives via the existing forward walk
        let modifiedResult = graph.findDerivedOrSelf(of: modified)
        #expect(
            modifiedResult.contains(replaced),
            "modified node should resolve to its replacement(s)")

        // Deleted → empty (record is present but mapping is empty)
        let deletedResult = graph.findDerivedOrSelf(of: deleted)
        #expect(deletedResult.isEmpty, "explicitly-deleted node resolves to []")

        // Untouched → [original] (no record names this node)
        let untouchedResult = graph.findDerivedOrSelf(of: untouched)
        #expect(
            untouchedResult == [untouched],
            "untouched node should resolve to itself at the same index")
    }

    @Test("findDerivedOrSelf preserves findDerived semantics for chained records")
    func findDerivedOrSelfMatchesFindDerivedWhenNonEmpty() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        // orig → [a] → [b, c]
        let orig = BRepGraph.NodeRef(kind: .edge, index: 1)
        let a = BRepGraph.NodeRef(kind: .edge, index: 10)
        let b = BRepGraph.NodeRef(kind: .edge, index: 20)
        let c = BRepGraph.NodeRef(kind: .edge, index: 21)
        graph.recordHistory(operationName: "Op1", original: orig, replacements: [a])
        graph.recordHistory(operationName: "Op2", original: a, replacements: [b, c])

        let derived = Set(graph.findDerived(of: orig))
        let derivedOrSelf = Set(graph.findDerivedOrSelf(of: orig))
        // When findDerived is non-empty, findDerivedOrSelf must return the same set.
        #expect(
            derived == derivedOrSelf,
            "findDerivedOrSelf must equal findDerived when derivatives exist")
    }

    @Test("FindOriginal walks backwards")
    func findOriginalWalksBackward() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = BRepGraph.NodeRef(kind: .face, index: 7)
        let mid = BRepGraph.NodeRef(kind: .face, index: 70)
        let leaf = BRepGraph.NodeRef(kind: .face, index: 700)
        graph.recordHistory(operationName: "A", original: orig, replacements: [mid])
        graph.recordHistory(operationName: "B", original: mid, replacements: [leaf])

        #expect(graph.findOriginal(of: leaf) == orig)
    }

    @Test("Unrecorded node findOriginal returns itself")
    func findOriginalPassthrough() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let node = BRepGraph.NodeRef(kind: .face, index: 3)
        #expect(graph.findOriginal(of: node) == node)
    }
}
