import Foundation
import Testing

@testable import OCCTSwift

/// #2835: an occurrence-aware lookup, so two instances of one part can be told apart.
///
/// #2650 fixed the lookup half: `findNode(for:)` resolves the sub-shapes of a placed instance and
/// answers the DEFINITION node, so both instances of one part in a compound come back as the same
/// `(kind, index)`. That is the kernel's own aliasing. What was missing is the occurrence.
///
/// OCCT's answer is a path, not an id. `BRepGraph/README.md:398` keeps occurrence context out of
/// the storage model and resolves it "through explorer usage paths or layer-side resolvers", and
/// `BRepGraph_ChildExplorer` "visits each occurrence. If Edge[5] is reachable through Face[0] and
/// Face[1], it is visited twice with different accumulated transforms"
/// (`BRepGraph_ChildExplorer.hxx:47`). `BRepGraph_UsagePath` is the identity: "Paths are used to
/// disambiguate multiple occurrences of the same definition reachable through different references
/// or sibling positions" (`BRepGraph_UsagePath.hxx:33`).
///
/// Every expectation below is measured against the pinned kernel in
/// `Scripts/repro/2835-brepgraph-occurrence-lookup/probe-output.txt`, block by block.
///
/// **What makes these tests of this feature rather than of `findNode`.** Each one asserts something
/// that is false under definition-node identity: two occurrences where `findNode` gives one node,
/// two *different* composed locations for one definition, and two *unequal* usage paths whose nodes
/// are all identical. Collapsing the occurrences back together fails all three.
@Suite("BRepGraph occurrence-aware lookup (#2835)")
struct Issue2835OccurrenceLookup {

    /// The fixture the issue is about: one box solid placed twice inside one compound.
    private struct TwoInstances {
        let pair: Shape
        let graph: BRepGraph
        let root: BRepGraph.NodeRef
        let solid: BRepGraph.NodeRef
    }

    private static func twoInstances() -> TwoInstances? {
        guard let box = Shape.box(width: 10, height: 8, depth: 6),
            let moved = box.moved(dx: 50, dy: 0, dz: 0),
            let pair = Shape.compound([box, moved]),
            let graph = BRepGraph(shape: pair),
            let root = graph.findNode(for: pair)
        else { return nil }
        let solids = pair.subShapes(ofType: .solid)
        guard solids.count == 2, let solid = graph.findNode(for: solids[0]) else { return nil }
        return TwoInstances(
            pair: pair,
            graph: graph,
            root: BRepGraph.NodeRef(kind: root.kind, index: root.index),
            solid: BRepGraph.NodeRef(kind: solid.kind, index: solid.index))
    }

    /// One definition, two occurrences. `findNode` cannot express this at all: it returns a single
    /// node for both instances, which is what #2650 measured and closed.
    @Test func oneDefinitionNodeHasTwoOccurrences() {
        guard let f = Self.twoInstances() else {
            Issue.record("fixture construction failed")
            return
        }
        // The premise: the graph holds ONE solid definition for the two instances.
        #expect(f.graph.solidCount == 1)
        let solids = f.pair.subShapes(ofType: .solid)
        if let a = f.graph.findNode(for: solids[0]), let b = f.graph.findNode(for: solids[1]) {
            #expect(a == b)
        }

        // ...and two occurrences of it.
        let occurrences = f.graph.occurrences(ofNode: f.solid, from: f.root)
        #expect(occurrences.count == 2)
        #expect(occurrences.allSatisfy { $0.node == f.solid })
    }

    /// The two occurrences carry different composed placements.
    ///
    /// And they are the placements the compound was built with. A lookup that collapsed them would
    /// return one location, or the same location twice.
    @Test func theTwoOccurrencesCarryTheirOwnComposedLocations() {
        guard let f = Self.twoInstances() else {
            Issue.record("fixture construction failed")
            return
        }
        let occurrences = f.graph.occurrences(ofNode: f.solid, from: f.root)
        guard occurrences.count == 2 else {
            Issue.record("expected 2 occurrences, got \(occurrences.count)")
            return
        }
        // A 3x4 row-major matrix, translation column at 3 / 7 / 11.
        #expect(occurrences[0].location.count == 12)
        #expect(occurrences[1].location.count == 12)
        let xs = occurrences.map { $0.location[3] }.sorted()
        #expect(abs(xs[0] - 0.0) < 1e-9)
        #expect(abs(xs[1] - 50.0) < 1e-9)
        // The distinction, stated as a distinction: the two placements are not the same.
        #expect(occurrences[0].location != occurrences[1].location)
    }

    /// The usage paths are unequal in the reference and the sibling order, not in the nodes.
    ///
    /// Measured, block D: every node on the two paths is identical and only the `Solid[0]` step's
    /// `ChildRef` and `StepIndex` differ.
    ///
    /// This is the assertion no definition-node lookup can satisfy, and the one that says the
    /// bridge has to emit all three fields of `BRepGraph_UsagePath::Step`.
    @Test func theTwoUsagePathsDifferOnlyInTheReferenceAndTheSiblingOrder() {
        guard let f = Self.twoInstances() else {
            Issue.record("fixture construction failed")
            return
        }
        let occurrences = f.graph.occurrences(ofNode: f.solid, from: f.root)
        guard occurrences.count == 2 else {
            Issue.record("expected 2 occurrences, got \(occurrences.count)")
            return
        }
        let first = occurrences[0].path
        let second = occurrences[1].path

        #expect(first != second)
        #expect(first.count == second.count)
        #expect(first.count == 2)  // Compound[0] then Solid[0]

        // Every node is the same on both paths, so nodes alone cannot tell them apart.
        #expect(first.map { $0.node } == second.map { $0.node })

        // The root step owns no reference entry and has no sibling order.
        #expect(first.first?.refKind == nil)
        #expect(first.first?.stepIndex == -1)

        // The split is at the second step, in both the ref index and the sibling order.
        guard let a = first.last, let b = second.last else {
            Issue.record("empty path")
            return
        }
        #expect(a.node == f.solid)
        #expect(b.node == f.solid)
        #expect(a.refKind == .child)
        #expect(b.refKind == .child)
        #expect(a.refIndex != b.refIndex)
        #expect(a.stepIndex != b.stepIndex)
        #expect([a.stepIndex, b.stepIndex].sorted() == [0, 1])
    }

    /// A picked sub-shape of a placed instance answers every occurrence of its part.
    ///
    /// That is the downstream "which instance of that part is this" question. Twelve faces resolve
    /// to six definitions, each with two occurrences.
    @Test func aPickedFaceOfAPlacedInstanceAnswersBothOccurrences() {
        guard let f = Self.twoInstances() else {
            Issue.record("fixture construction failed")
            return
        }
        let faces = f.pair.subShapes(ofType: .face)
        #expect(faces.count == 12)
        #expect(f.graph.faceCount == 6)

        var total = 0
        for face in faces {
            let occurrences = f.graph.occurrences(of: face, from: f.root)
            #expect(occurrences.count == 2)
            #expect(Set(occurrences.map { $0.path }).count == 2)
            total += occurrences.count
        }
        // Six definitions, picked through twelve sub-shapes, two occurrences each.
        #expect(total == 24)
    }

    /// Nesting composes, and the paths get longer rather than ambiguous.
    ///
    /// Measured, block E: a compound of two compounds each holding the same box twice gives four
    /// solid occurrences with three-step paths, distinguished at two different levels.
    @Test func nestedCompoundsGiveFourDistinctOccurrences() {
        guard let box = Shape.box(width: 10, height: 8, depth: 6),
            let a = box.moved(dx: 0, dy: 0, dz: 0),
            let b = box.moved(dx: 100, dy: 0, dz: 0),
            let c = box.moved(dx: 0, dy: 50, dz: 0),
            let d = box.moved(dx: 100, dy: 50, dz: 0),
            let inner1 = Shape.compound([a, b]),
            let inner2 = Shape.compound([c, d]),
            let outer = Shape.compound([inner1, inner2]),
            let graph = BRepGraph(shape: outer),
            let rootPair = graph.findNode(for: outer)
        else {
            Issue.record("fixture construction failed")
            return
        }
        let root = BRepGraph.NodeRef(kind: rootPair.kind, index: rootPair.index)
        #expect(graph.solidCount == 1)

        let solids = outer.subShapes(ofType: .solid)
        guard solids.count == 4, let solidPair = graph.findNode(for: solids[0]) else {
            Issue.record("expected 4 placed solids, got \(solids.count)")
            return
        }
        let solid = BRepGraph.NodeRef(kind: solidPair.kind, index: solidPair.index)

        let occurrences = graph.occurrences(ofNode: solid, from: root)
        #expect(occurrences.count == 4)
        // Four distinct paths for one definition node.
        #expect(Set(occurrences.map { $0.path }).count == 4)
        #expect(occurrences.allSatisfy { $0.path.count == 3 })
        // Four distinct placements, matching the four the fixture was built with.
        let placements = occurrences.map { ($0.location[3], $0.location[7]) }.sorted {
            ($0.0, $0.1) < ($1.0, $1.1)
        }
        #expect(placements.map { $0.0 } == [0, 0, 100, 100])
        #expect(placements.map { $0.1 } == [0, 50, 0, 50])
    }

    /// An unplaced single part is not a special case: exactly one occurrence, at the identity.
    ///
    /// Measured, block G4.
    @Test func anUnplacedSinglePartHasExactlyOneOccurrence() {
        guard let box = Shape.box(width: 10, height: 8, depth: 6),
            let graph = BRepGraph(shape: box),
            let rootPair = graph.findNode(for: box)
        else {
            Issue.record("fixture construction failed")
            return
        }
        let root = BRepGraph.NodeRef(kind: rootPair.kind, index: rootPair.index)
        #expect(rootPair.kind == .solid)

        let faces = box.subShapes(ofType: .face)
        guard let facePair = graph.findNode(for: faces[0]) else {
            Issue.record("face did not resolve")
            return
        }
        let occurrences = graph.occurrences(
            ofNode: BRepGraph.NodeRef(kind: facePair.kind, index: facePair.index), from: root)
        #expect(occurrences.count == 1)
        if let only = occurrences.first {
            // The identity, as twelve doubles.
            #expect(only.location == [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0])
            #expect(only.path.count == 3)  // Solid[0] / Shell[0] / Face[0]
        }
    }

    /// The root/self match emits the root once.
    ///
    /// Traversing to the root's own kind and index gives a one-step path carrying no reference and
    /// a sibling order of -1. Measured, block G1.
    @Test func theRootIsItsOwnSingleOccurrence() {
        guard let f = Self.twoInstances() else {
            Issue.record("fixture construction failed")
            return
        }
        let occurrences = f.graph.occurrences(ofNode: f.root, from: f.root)
        #expect(occurrences.count == 1)
        if let only = occurrences.first {
            #expect(only.path.count == 1)
            #expect(only.path[0].node == f.root)
            #expect(only.path[0].refKind == nil)
            #expect(only.path[0].refIndex == -1)
            #expect(only.path[0].stepIndex == -1)
        }
    }

    /// Out-of-range inputs answer empty rather than failing.
    ///
    /// That is what the explorer does: a root the graph does not have emits nothing and does not
    /// throw (measured, block G3). Written as one test walking a list rather than
    /// `@Test(arguments:)`, because a `(String, ...)` argument element corrupts the Swift task
    /// allocator whatever the body does (swiftlang/swift#91639, see CLAUDE.md's Test Conventions).
    @Test func outOfRangeNodesAnswerEmpty() {
        guard let f = Self.twoInstances() else {
            Issue.record("fixture construction failed")
            return
        }
        let cases: [(label: String, node: BRepGraph.NodeRef, root: BRepGraph.NodeRef)] = [
            (
                "target index the graph does not have",
                BRepGraph.NodeRef(kind: .face, index: 99), f.root
            ),
            (
                "root index the graph does not have", f.solid,
                BRepGraph.NodeRef(kind: .compound, index: 99)
            ),
            ("negative target index", BRepGraph.NodeRef(kind: .face, index: -1), f.root),
        ]
        for c in cases {
            let occurrences = f.graph.occurrences(ofNode: c.node, from: c.root)
            #expect(occurrences.isEmpty, "\(c.label) should answer empty")
        }

        // A shape the graph never ingested has no node, so the shape overload answers empty too.
        if let stranger = Shape.box(width: 3, height: 3, depth: 3),
            let moved = stranger.moved(dx: 999, dy: 0, dz: 0)
        {
            #expect(f.graph.occurrences(of: moved, from: f.root).isEmpty)
        }
    }
}
