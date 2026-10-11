import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.141 / #72 Phase 1: TopologyRef recipes + resolver

@Suite("v0.141 TopologyRef resolver")
struct TopologyRefResolverTests {
    private func node(_ kind: BRepGraph.NodeKind, _ index: Int) -> BRepGraph.NodeRef {
        BRepGraph.NodeRef(kind: kind, index: index)
    }

    /// A box graph with history enabled and the log empty, the state every recipe below starts from.
    ///
    /// The nodes the tests record are inventions (face 100 is not in a six-face box) on purpose: the
    /// resolver reads the history log and never the graph's topology, so a recipe that consulted the
    /// topology would be a different resolver.
    private func makeGraph() throws -> BRepGraph {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "box")
        let graph = try #require(BRepGraph(shape: box), "graph of a box")
        graph.isHistoryEnabled = true
        graph.clearHistory()
        try #require(graph.historyRecordCount == 0, "the log must start empty")
        return graph
    }

    @Test("Literal reference to a valid node resolves to itself")
    func literalValid() throws {
        let graph = try makeGraph()
        // Index 0 is the boundary of `isValid` (index >= 0), the last face is the other end, and
        // an edge and a vertex show the kind survives as well as the index.
        let nodes = [
            node(.face, 0), node(.face, graph.faceCount - 1), node(.edge, 7), node(.vertex, 3),
        ]
        for n in nodes {
            #expect(graph.resolve(.literal(n)) == .success(n), "literal \(n)")
        }
    }

    @Test("Literal reference to an invalid node fails")
    func literalInvalid() throws {
        let graph = try makeGraph()
        let sentinel = TopologyRef.literal(.sentinel)
        #expect(graph.resolve(sentinel) == .failure(.invalid(sentinel)))
        // -1 is invalid whatever the kind, and index 0 is the control: the same recipe shape
        // resolves, so a resolver that fails every literal cannot pass this.
        for kind in [BRepGraph.NodeKind.face, .edge, .vertex] {
            let bad = TopologyRef.literal(node(kind, -1))
            #expect(graph.resolve(bad) == .failure(.invalid(bad)), "\(kind) -1")
            let good = node(kind, 0)
            #expect(graph.resolve(.literal(good)) == .success(good), "\(kind) 0")
        }
    }

    @Test("createdBy resolves to the recorded replacement")
    func createdByBasic() throws {
        let graph = try makeGraph()
        let f100 = node(.face, 100)
        let e200 = node(.edge, 200)
        let f101 = node(.face, 101)
        let f102 = node(.face, 102)
        let f300 = node(.face, 300)
        // One operation writes two records, with an unrelated operation's record between them.
        graph.recordHistory(
            operationName: "Extrude_1", original: .sentinel, replacements: [f100, e200, f101])
        graph.recordHistory(operationName: "Other", original: .sentinel, replacements: [f300])
        graph.recordHistory(operationName: "Extrude_1", original: .sentinel, replacements: [f102])

        // The order is (record sequence, position in the record) over the nodes of the asked kind:
        // the edge is skipped, the other operation's face never intrudes, and the second record
        // comes after the first whatever its original.
        var faces: [Result<BRepGraph.NodeRef, TopologyResolutionError>] = []
        for occurrence in 0..<3 {
            faces.append(
                graph.resolve(
                    .createdBy(operationName: "Extrude_1", kind: .face, occurrence: occurrence)))
        }
        #expect(faces == [.success(f100), .success(f101), .success(f102)])

        let edge = graph.resolve(.createdBy(operationName: "Extrude_1", kind: .edge))
        #expect(edge == .success(e200))
        let other = graph.resolve(.createdBy(operationName: "Other", kind: .face))
        #expect(other == .success(f300))

        let past = TopologyRef.createdBy(operationName: "Extrude_1", kind: .face, occurrence: 3)
        #expect(
            graph.resolve(past) == .failure(.occurrenceOutOfRange(past, available: 3, requested: 3))
        )
    }

    @Test("createdBy with unknown operation fails with operationNotFound")
    func createdByMissingOp() throws {
        let graph = try makeGraph()
        let face = node(.face, 100)
        // A record exists, so "nothing matched" is a statement about the NAME: a prefix, a different
        // case, a trailing space and the empty string all name an operation that never happened.
        graph.recordHistory(operationName: "Extrude_1", original: .sentinel, replacements: [face])
        for name in ["Nonexistent", "Extrude", "extrude_1", "Extrude_1 ", ""] {
            let ref = TopologyRef.createdBy(operationName: name, kind: .face)
            #expect(graph.resolve(ref) == .failure(.operationNotFound(name)), "name '\(name)'")
        }
        // The control: the recorded name resolves.
        let recorded = graph.resolve(.createdBy(operationName: "Extrude_1", kind: .face))
        #expect(recorded == .success(face))
    }

    @Test("createdBy with occurrence out of range fails cleanly")
    func createdByOutOfRange() throws {
        let graph = try makeGraph()
        let only = node(.face, 100)
        graph.recordHistory(operationName: "Op", original: .sentinel, replacements: [only])
        let first = graph.resolve(.createdBy(operationName: "Op", kind: .face, occurrence: 0))
        #expect(first == .success(only), "occurrence 0 is the control")
        // One past the end, well past it, and negative: none is clamped into range.
        for occurrence in [1, 5, -1] {
            let ref = TopologyRef.createdBy(
                operationName: "Op", kind: .face, occurrence: occurrence)
            #expect(
                graph.resolve(ref)
                    == .failure(.occurrenceOutOfRange(ref, available: 1, requested: occurrence)),
                "occurrence \(occurrence)")
        }
    }

    @Test("createdBy walks forward through subsequent history to currentForm")
    func createdByForwardWalk() throws {
        let graph = try makeGraph()
        // op1 creates face 10; op2 modifies face 10 -> face 11.
        let created = node(.face, 10)
        let current = node(.face, 11)
        graph.recordHistory(operationName: "Create", original: .sentinel, replacements: [created])
        graph.recordHistory(operationName: "Modify", original: created, replacements: [current])
        // Asking for the face created by "Create" gives the CURRENT form (face 11), not the
        // historical one (face 10), unless the walk is switched off with `leafOccurrence: nil`.
        let walked = graph.resolve(.createdBy(operationName: "Create", kind: .face))
        #expect(walked == .success(current))
        let asCreated = graph.resolve(
            .createdBy(operationName: "Create", kind: .face, leafOccurrence: nil))
        #expect(asCreated == .success(created))

        // A creation that splits, with one half refined again, has two live leaves. The refined
        // half's intermediate (face 21) is neither of them, and leaves come in index order.
        let born = node(.face, 20)
        let a = node(.face, 21)
        let b = node(.face, 22)
        let refined = node(.face, 23)
        graph.recordHistory(operationName: "Born", original: .sentinel, replacements: [born])
        graph.recordHistory(operationName: "Split", original: born, replacements: [a, b])
        graph.recordHistory(operationName: "Refine", original: a, replacements: [refined])
        var leaves: [Result<BRepGraph.NodeRef, TopologyResolutionError>] = []
        for leaf in 0..<2 {
            leaves.append(
                graph.resolve(.createdBy(operationName: "Born", kind: .face, leafOccurrence: leaf)))
        }
        #expect(leaves == [.success(b), .success(refined)])
        let third = TopologyRef.createdBy(operationName: "Born", kind: .face, leafOccurrence: 2)
        #expect(
            graph.resolve(third)
                == .failure(.occurrenceOutOfRange(third, available: 2, requested: 2)))
        let bornAsCreated = graph.resolve(
            .createdBy(operationName: "Born", kind: .face, leafOccurrence: nil))
        #expect(bornAsCreated == .success(born))
    }

    @Test("splitOf picks the Nth replacement of a split original")
    func splitOf() throws {
        let graph = try makeGraph()
        let orig = node(.edge, 3)
        let a = node(.edge, 30)
        let b = node(.edge, 31)
        let bFirst = node(.edge, 310)
        let bSecond = node(.edge, 311)
        graph.recordHistory(operationName: "SplitEdge", original: orig, replacements: [a, b])
        #expect(graph.resolve(.splitOf(original: .literal(orig), occurrence: 0)) == .success(a))
        #expect(graph.resolve(.splitOf(original: .literal(orig), occurrence: 1)) == .success(b))

        // The half it picks is reported in its current form: edge 31 is later split again into
        // 310 and 311, and the first leaf in index order is the one `currentForm` reports.
        graph.recordHistory(operationName: "Refine", original: b, replacements: [bFirst, bSecond])
        #expect(
            graph.resolve(.splitOf(original: .literal(orig), occurrence: 1)) == .success(bFirst))
        #expect(graph.resolve(.splitOf(original: .literal(orig), occurrence: 0)) == .success(a))

        // A 1-to-1 modification is not a split, so there is nothing for the recipe to pick.
        let moved = node(.edge, 4)
        graph.recordHistory(
            operationName: "Move", original: moved, replacements: [node(.edge, 40)])
        let notSplit = TopologyRef.splitOf(original: .literal(moved), occurrence: 0)
        #expect(graph.resolve(notSplit) == .failure(.noCurrentDescendant(notSplit)))
    }

    @Test("splitOf with occurrence out of range fails cleanly")
    func splitOfOutOfRange() throws {
        let graph = try makeGraph()
        let orig = node(.edge, 3)
        let a = node(.edge, 30)
        let b = node(.edge, 31)
        graph.recordHistory(operationName: "SplitEdge", original: orig, replacements: [a, b])
        // The last piece is the control, so a resolver that refuses every occurrence cannot pass.
        #expect(graph.resolve(.splitOf(original: .literal(orig), occurrence: 1)) == .success(b))
        for occurrence in [2, 5, -1] {
            let ref = TopologyRef.splitOf(original: .literal(orig), occurrence: occurrence)
            #expect(
                graph.resolve(ref)
                    == .failure(.occurrenceOutOfRange(ref, available: 2, requested: occurrence)),
                "occurrence \(occurrence)")
        }
    }

    @Test("Ancestor resolution failure propagates")
    func ancestorMissing() throws {
        let graph = try makeGraph()
        // splitOf references an operation that never happened, so it fails, and the error names
        // that ancestor recipe rather than the reason the ancestor failed.
        let missing = TopologyRef.createdBy(operationName: "Nonexistent", kind: .edge)
        let split = TopologyRef.splitOf(original: missing, occurrence: 0)
        #expect(graph.resolve(split) == .failure(.ancestorMissing(missing)))

        // The reason is collapsed on purpose (`resolveAncestor`), so however deep the failure
        // sits, the error names the DIRECT ancestor.
        let outer = TopologyRef.splitOf(original: split, occurrence: 1)
        #expect(graph.resolve(outer) == .failure(.ancestorMissing(split)))
        let contained = TopologyRef.containedIn(parent: missing, kind: .face)
        #expect(graph.resolve(contained) == .failure(.ancestorMissing(missing)))

        // The controls: once the operation is recorded, the same shapes of recipe resolve. The
        // ancestor takes `leafOccurrence: nil` so it is the edge as created, the one the cut split.
        let made = node(.edge, 5)
        let left = node(.edge, 50)
        let right = node(.edge, 51)
        graph.recordHistory(operationName: "Make", original: .sentinel, replacements: [made])
        graph.recordHistory(operationName: "Cut", original: made, replacements: [left, right])
        let ancestor = TopologyRef.createdBy(
            operationName: "Make", kind: .edge, leafOccurrence: nil)
        #expect(graph.resolve(.splitOf(original: ancestor, occurrence: 1)) == .success(right))
        #expect(graph.resolve(.splitOf(original: ancestor, occurrence: 0)) == .success(left))

        let solid = TopologyRef.literal(node(.solid, 0))
        let face = try graph.resolve(.containedIn(parent: solid, kind: .face)).get()
        #expect(face.kind == .face)
        #expect((0..<graph.faceCount).contains(face.index), "a face of the box, got \(face)")
    }
}
